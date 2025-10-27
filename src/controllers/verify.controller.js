const express = require('express');
const rateLimit = require('express-rate-limit');
const { authenticateToken, allRoles, auditLog } = require('../utils/auth.middleware');
const { verifyPassValidation, syncLogsValidation, handleValidationErrors } = require('../utils/validators');
const verifyService = require('../services/verify.service');
const SettingsModel = require('../models/settings.model');
const logger = require('../utils/logger');
const LoggingService = require('../services/logging.service');

const router = express.Router();

// Dynamic rate limiting middleware for verification endpoint
const verifyRateLimit = async (req, res, next) => {
  try {
    // Get rate limit from settings or use default
    let maxRequests = 100; // Default fallback
    try {
      maxRequests = await SettingsModel.getVerifyRateLimit();
    } catch (error) {
      logger.warn('Could not get verify rate limit from settings, using default:', error.message);
    }
    
    const windowMs = parseInt(process.env.VERIFY_RATE_LIMIT_WINDOW_MS) || 60000; // 1 minute
    
    const limiter = rateLimit({
      windowMs,
      max: maxRequests,
      message: {
        error: 'Too many verification requests, please try again later.',
        code: 'VERIFY_RATE_LIMIT_EXCEEDED',
        maxRequests,
        windowMs
      },
      standardHeaders: true,
      legacyHeaders: false,
      // trustProxy setting removed - will inherit from Express app configuration
      keyGenerator: (req) => {
        // Rate limit per IP
        return req.ip;
      },
      skip: (req) => {
        // Skip rate limiting for admin users in development
        return process.env.NODE_ENV === 'development' && req.user?.role === 'admin';
      }
    });
    
    return limiter(req, res, next);
  } catch (error) {
    logger.error('Error in verify rate limit middleware:', error);
    // Continue without rate limiting if there's an error
    next();
  }
};

// Rate limiting for sync logs (less restrictive)
const syncLogsRateLimit = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 50, // 50 sync requests per 15 minutes
  message: {
    error: 'Too many sync requests, please try again later.',
    code: 'SYNC_RATE_LIMIT_EXCEEDED'
  },
  standardHeaders: true,
  legacyHeaders: false
  // trustProxy setting removed - will inherit from Express app configuration
});

// POST /api/pass/verify
router.post('/verify',
  authenticateToken,
  allRoles, // All authenticated users can verify
  verifyRateLimit, // Apply dynamic rate limiting
  verifyPassValidation,
  handleValidationErrors,
  auditLog('PASS_VERIFICATION'),
  async (req, res) => {
    const startTime = Date.now();
    
    try {
      const { uid, scanned_by} = req.body;
      
      // Validate that scanned_by matches the authenticated user or user has admin/manager role
      if (req.user.role === 'bouncer' && req.user.id !== scanned_by) {
        return res.status(403).json({
          error: 'Bouncer can only scan with their own user ID',
          code: 'INVALID_SCANNED_BY'
        });
      }
      
      logger.info(`Verification request: UID=${uid}, User=${scanned_by}`);
      
      // Get scanned_by user info for verification
      const scannedByUser = await require('../models/user.model').findById(scanned_by);
      if (!scannedByUser) {
        return res.status(404).json({
          error: 'Scanned by user not found',
          code: 'USER_NOT_FOUND'
        });
      }
      
      // Perform verification
      const result = await verifyService.verifyPass(uid, scannedByUser);
      
      // Log verification to system logs
      try {
        if (scannedByUser && result.pass_info) {
          await LoggingService.logVerifyPass(
            {
              pass_id: result.pass_info.pass_id,
              uid: uid,
              pass_type: result.pass_info.pass_type,
              category: result.pass_info.category,
              people_allowed: result.pass_info.people_allowed,
              status: result.status
            },
            result,
            scannedByUser,
            req
          );
        }
      } catch (logError) {
        logger.error('Failed to log verification to system logs:', logError);
      }
      
      // Log the result
      logger.info(`Verification result: UID=${uid}, Status=${result.status}, Time=${result.processing_time_ms}ms`);
      
      // Return appropriate status code based on result
      const statusCode = result.success ? 200 : 
                        result.status === 'blocked' ? 403 :
                        result.status === 'used' ? 200 : // Return 200 for used status to show popup
                        result.status === 'prompt_multi_use' ? 200 : // Special case for multi-use prompt
                        result.status === 'error' ? 500 : 400;
      
      res.status(statusCode).json(result);
      
    } catch (error) {
      logger.error('Verification endpoint error:', error);
      
      // Log verification error
      await LoggingService.logError('verify_pass_error', error, req.user, req, { 
        action: 'verify_pass', 
        uid: req.body.uid
      });
      
      res.status(500).json({
        error: 'Verification failed',
        code: 'VERIFICATION_ERROR',
        message: process.env.NODE_ENV === 'development' ? error.message : 'Internal server error',
        processing_time_ms: Date.now() - startTime
      });
    }
  }
);

// POST /api/pass/consume-prompt
router.post('/consume-prompt',
  authenticateToken,
  allRoles, // All authenticated users can consume prompts
  auditLog('PASS_CONSUME_PROMPT'),
  async (req, res) => {
    const startTime = Date.now();
    
    try {
      const { prompt_token, consume_count, scanned_by } = req.body;
      
      // Validate required fields
      if (!prompt_token || !consume_count || !scanned_by) {
        return res.status(400).json({
          error: 'Missing required fields',
          code: 'MISSING_FIELDS',
          required: ['prompt_token', 'consume_count', 'scanned_by']
        });
      }
      
      // Validate consume_count is a positive integer
      if (!Number.isInteger(consume_count) || consume_count <= 0) {
        return res.status(400).json({
          error: 'consume_count must be a positive integer',
          code: 'INVALID_CONSUME_COUNT'
        });
      }
      
      // Validate that scanned_by matches the authenticated user or user has admin/manager role
      if (req.user.role === 'bouncer' && req.user.id !== scanned_by) {
        return res.status(403).json({
          error: 'Bouncer can only consume with their own user ID',
          code: 'INVALID_SCANNED_BY'
        });
      }
      
      logger.info(`Consume prompt request: Token=${prompt_token.substring(0, 8)}..., Count=${consume_count}, User=${scanned_by}`);
      
      // Perform prompt consumption
      const result = await verifyService.consumePrompt(prompt_token, consume_count, scanned_by);
      
      // Log session consumption (only if successful)
      if (result.success && result.uid) {
        try {
          // Create a minimal pass object for logging
          const passForLogging = {
            uid: result.uid,
            pass_id: result.uid, // Using UID as pass_id for logging
            pass_type: 'session', // We know it's a session pass from the context
            category: 'Unknown' // We don't have category info in the result
          };
          await LoggingService.logSessionConsume(passForLogging, consume_count, req.user, req);
        } catch (logError) {
          logger.error('Failed to log session consumption:', logError);
        }
      }
      
      // Log the result
      logger.info(`Consume prompt result: Status=${result.status}, Count=${result.consumed_count || 0}, Time=${result.processing_time_ms}ms`);
      
      // Return appropriate status code based on result
      const statusCode = result.success ? 200 : 
                        result.status === 'invalid_token' ? 400 :
                        result.status === 'invalid_count' ? 400 :
                        result.status === 'error' ? 500 : 400;
      
      res.status(statusCode).json(result);
      
    } catch (error) {
      logger.error('Consume prompt error:', error);
      
      // Log consume error
      await LoggingService.logError('consume_session_error', error, req.user, req, { 
        action: 'consume_session', 
        prompt_token: req.body.prompt_token?.substring(0, 8) + '...', 
        consume_count: req.body.consume_count
      });
      
      res.status(500).json({
        error: 'Prompt consumption failed',
        code: 'CONSUME_PROMPT_ERROR',
        message: process.env.NODE_ENV === 'development' ? error.message : 'Internal server error'
      });
    }
  }
);

// POST /api/pass/sync-logs
router.post('/sync-logs',
  authenticateToken,
  allRoles, // All authenticated users can sync logs
  syncLogsRateLimit,
  syncLogsValidation,
  handleValidationErrors,
  auditLog('SYNC_OFFLINE_LOGS'),
  async (req, res) => {
    const startTime = Date.now();
    
    try {
      const { logs } = req.body;
      
      // Log sync start
      await LoggingService.logSyncStart(req.user, req, 'offline_logs', logs.length);
      
      logger.info(`Sync logs request: ${logs.length} logs from user ${req.user.username}`);
      
      // Validate that all logs belong to the authenticated user (for bouncer role)
      if (req.user.role === 'bouncer') {
        const invalidLogs = logs.filter(log => log.scanned_by !== req.user.id);
        if (invalidLogs.length > 0) {
          await LoggingService.logSyncError(req.user, req, new Error('Invalid log ownership'), 'offline_logs', logs.length);
          return res.status(403).json({
            error: 'Bouncer can only sync logs scanned by themselves',
            code: 'INVALID_LOG_OWNERSHIP',
            invalidCount: invalidLogs.length
          });
        }
      }
      
      // Sync the logs
      const result = await verifyService.syncOfflineLogs(logs);
      
      // Calculate sync duration
      const duration = Date.now() - startTime;
      result.duration = duration;
      
      // Log sync completion
      await LoggingService.logSyncComplete(req.user, req, result, 'offline_logs');
      
      logger.info(`Sync logs result: ${result.synced}/${result.total} synced, ${result.errors.length} errors`);
      
      // Return success even if some logs failed
      const statusCode = result.errors.length === 0 ? 200 : 207; // 207 = Multi-Status
      
      res.status(statusCode).json({
        message: 'Log sync completed',
        total: result.total,
        synced: result.synced,
        errors: result.errors.length,
        errorDetails: result.errors.length > 0 ? result.errors : undefined,
        duration
      });
      
    } catch (error) {
      // Log sync error
      await LoggingService.logSyncError(req.user, req, error, 'offline_logs', req.body?.logs?.length || 0);
      
      logger.error('Sync logs endpoint error:', error);
      
      res.status(500).json({
        error: 'Log sync failed',
        code: 'SYNC_ERROR',
        message: process.env.NODE_ENV === 'development' ? error.message : 'Internal server error'
      });
    }
  }
);

// GET /api/pass/verify/stats (for debugging and monitoring)
router.get('/verify/stats',
  authenticateToken,
  require('../utils/auth.middleware').adminOrManager,
  async (req, res) => {
    try {
      const { from, to } = req.query;
      
      if (!from || !to) {
        return res.status(400).json({
          error: 'From and to dates are required',
          code: 'MISSING_DATE_RANGE'
        });
      }
      
      const stats = await verifyService.getVerificationStats({ from, to });
      
      res.status(200).json({
        message: 'Verification statistics retrieved',
        dateRange: { from, to },
        stats
      });
      
    } catch (error) {
      logger.error('Verification stats endpoint error:', error);
      
      res.status(500).json({
        error: 'Failed to retrieve verification statistics',
        code: 'STATS_ERROR',
        message: process.env.NODE_ENV === 'development' ? error.message : 'Internal server error'
      });
    }
  }
);

// GET /api/pass/verify/health (health check for verification system)
router.get('/verify/health',
  authenticateToken,
  require('../utils/auth.middleware').adminOrManager,
  async (req, res) => {
    try {
      const redisService = require('../services/redis.service');
      
      // Check Redis cache stats
      const cacheStats = await redisService.getCacheStats();
      
      // Check if Lua script is loaded
      const luaScriptLoaded = verifyService.luaScript !== null;
      
      // Check rate limiting settings
      const rateLimitSettings = {
        maxRequests: await SettingsModel.getVerifyRateLimit(),
        windowMs: parseInt(process.env.VERIFY_RATE_LIMIT_WINDOW_MS) || 60000
      };
      
      res.status(200).json({
        message: 'Verification system health check',
        status: 'healthy',
        components: {
          luaScript: luaScriptLoaded ? 'loaded' : 'not_loaded',
          redisCache: cacheStats,
          rateLimit: rateLimitSettings
        },
        timestamp: new Date().toISOString()
      });
      
    } catch (error) {
      logger.error('Verification health check error:', error);
      
      res.status(500).json({
        message: 'Verification system health check failed',
        status: 'unhealthy',
        error: error.message,
        timestamp: new Date().toISOString()
      });
    }
  }
);

// Session multi-use confirmation endpoint
router.post('/confirm-multi-use',
  authenticateToken,
  allRoles,
  async (req, res) => {
    try {
      const { uid, prompt_token, selected_count } = req.body;
      
      // Validate input
      if (!uid || !prompt_token || !selected_count) {
        return res.status(400).json({
          success: false,
          message: 'Missing required fields: uid, prompt_token, selected_count'
        });
      }
      
      if (selected_count < 1) {
        return res.status(400).json({
          success: false,
          message: 'Selected count must be at least 1'
        });
      }
      
      // Use the consumePrompt method from verify service
      const result = await verifyService.consumePrompt(prompt_token, selected_count, req.user);
      
      if (result.success) {
        res.json({
          success: true,
          status: 'valid',
          remaining_uses: result.remaining_uses,
          consumed_count: result.consumed_count,
          message: `Session pass used for ${result.consumed_count} people`
        });
      } else {
        res.status(400).json({
          success: false,
          message: result.message,
          status: result.status
        });
      }
      
    } catch (error) {
      logger.error('Error confirming session multi-use:', error);
      res.status(500).json({
        success: false,
        message: 'Internal server error'
      });
    }
  }
);

module.exports = router;