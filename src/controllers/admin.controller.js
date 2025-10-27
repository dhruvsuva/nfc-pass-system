const express = require('express');
const { authenticateToken, adminOnly, adminOrManager, auditLog } = require('../utils/auth.middleware');
const {
  dailyResetValidation,
  statsQueryValidation,
  handleValidationErrors,
  getCurrentDate
} = require('../utils/validators');
const PassModel = require('../models/pass.model');
const SettingsModel = require('../models/settings.model');
const redisService = require('../services/redis.service');
const verifyService = require('../services/verify.service');
const { executeQuery, getDailyLogTableName, tableExists } = require('../config/db');
const logger = require('../utils/logger');
const LoggingService = require('../services/logging.service');

const router = express.Router();

// POST /api/admin/reset-daily
router.post('/reset-daily',
  authenticateToken,
  adminOnly, // Only admin can perform daily reset
  dailyResetValidation,
  handleValidationErrors,
  auditLog('DAILY_RESET'),
  async (req, res) => {
    try {
      const { date, confirm } = req.body;
      const resetDate = date || getCurrentDate();
      
      // Validate confirmation
      if (confirm !== 'true') {
        return res.status(400).json({
          error: 'Daily reset requires explicit confirmation',
          code: 'CONFIRMATION_REQUIRED',
          message: 'Set confirm=true to proceed with daily reset'
        });
      }
      
      // Allow multiple resets per day - validation removed as per admin request
      
      logger.info(`Starting daily reset for date: ${resetDate} by ${req.user.username}`);
      
      // Perform daily reset
      const resetCount = await PassModel.resetDailyPasses();
      
      // Log daily reset
      await LoggingService.logDailyReset({
        date: resetDate,
        passesReset: resetCount
      }, req.user, req);
      
      // Update last reset date
      await SettingsModel.setLastResetDate(resetDate);
      
      // Rebuild Redis cache to reflect the reset
      const cacheStats = await redisService.rebuildAllCaches();
      
      // Emit socket event for real-time notifications
      const io = req.app.get('io');
      if (io) {
        io.emit('daily:reset', {
          date: resetDate,
          resetCount,
          performedBy: req.user.username,
          timestamp: new Date().toISOString(),
          cacheStats
        });
      }
      
      logger.info(`Daily reset completed: ${resetCount} passes reset for date ${resetDate}`);
      
      res.status(200).json({
        message: 'Daily reset completed successfully',
        summary: {
          date: resetDate,
          passesReset: resetCount,
          performedBy: req.user.username,
          timestamp: new Date().toISOString(),
          cacheRebuilt: {
            activeCount: cacheStats.activeCount,
            blockedCount: cacheStats.blockedCount
          }
        }
      });
      
    } catch (error) {
      logger.error('Daily reset error:', error);
      
      // Log daily reset error
      await LoggingService.logError('daily_reset_error', error, req.user, req, { 
        action: 'daily_reset', 
        date: req.body.date || getCurrentDate() 
      });
      
      res.status(500).json({
        error: 'Daily reset failed',
        code: 'RESET_ERROR',
        message: process.env.NODE_ENV === 'development' ? error.message : 'Internal server error'
      });
    }
  }
);

// GET /api/admin/stats
router.get('/stats',
  authenticateToken,
  adminOrManager,
  statsQueryValidation,
  handleValidationErrors,
  async (req, res) => {
    try {
      const { from, to, category } = req.query;
      
      if (!from || !to) {
        return res.status(400).json({
          error: 'From and to dates are required',
          code: 'MISSING_DATE_RANGE'
        });
      }
      
      logger.info(`Generating stats report: ${from} to ${to}`);
      
      // Generate date range
      const startDate = new Date(from);
      const endDate = new Date(to);
      const dates = [];
      
      for (let d = new Date(startDate); d <= endDate; d.setDate(d.getDate() + 1)) {
        dates.push(d.toISOString().split('T')[0]);
      }
      
      const stats = {
        dateRange: { from, to },
        totalDays: dates.length,
        summary: {
          totalScans: 0,
          validScans: 0,
          invalidScans: 0,
          blockedScans: 0,
          duplicateScans: 0
        },
        byDate: {},
        byCategory: {},
        byHour: {},
        byResult: {
          valid: 0,
          invalid: 0,
          blocked: 0,
          duplicate: 0
        }
      };
      
      // Query each daily table
      for (const date of dates) {
        const tableName = getDailyLogTableName(date);
        const exists = await tableExists(tableName);
        
        if (exists) {
          // Base query with optional filters
          let baseQuery = `FROM ${tableName} l LEFT JOIN passes p ON l.pass_id = p.id WHERE 1=1`;
          const params = [];
          
          if (category) {
            baseQuery += ' AND p.category = ?';
            params.push(category);
          }
          
          // Get daily statistics
          const queries = [
            // Total by result
            `SELECT l.result, COUNT(*) as count ${baseQuery} GROUP BY l.result`,
            
            // By category (if passes data available)
            `SELECT p.category, l.result, COUNT(*) as count ${baseQuery} AND p.category IS NOT NULL GROUP BY p.category, l.result`,
            
            // By hour
            `SELECT HOUR(l.created_at) as hour, l.result, COUNT(*) as count ${baseQuery} GROUP BY HOUR(l.created_at), l.result`
          ];
          
          const [resultData, categoryData, hourData] = await Promise.all(
            queries.map(query => executeQuery(query, params))
          );
          
          // Initialize daily stats
          stats.byDate[date] = {
            total: 0,
            valid: 0,
            invalid: 0,
            blocked: 0,
            duplicate: 0
          };
          
          // Process result data
          resultData.forEach(row => {
            stats.summary.totalScans += row.count;
            stats.byResult[row.result] += row.count;
            stats.byDate[date].total += row.count;
            stats.byDate[date][row.result] += row.count;
          });
          
          // Process category data
          categoryData.forEach(row => {
            if (!stats.byCategory[row.category]) {
              stats.byCategory[row.category] = {
                total: 0,
                valid: 0,
                invalid: 0,
                blocked: 0,
                duplicate: 0
              };
            }
            stats.byCategory[row.category].total += row.count;
            stats.byCategory[row.category][row.result] += row.count;
          });
          
          // Process hour data
          hourData.forEach(row => {
            const hourKey = `${row.hour.toString().padStart(2, '0')}:00`;
            if (!stats.byHour[hourKey]) {
              stats.byHour[hourKey] = {
                total: 0,
                valid: 0,
                invalid: 0,
                blocked: 0,
                duplicate: 0
              };
            }
            stats.byHour[hourKey].total += row.count;
            stats.byHour[hourKey][row.result] += row.count;
          });
        } else {
          // No data for this date
          stats.byDate[date] = {
            total: 0,
            valid: 0,
            invalid: 0,
            blocked: 0,
            duplicate: 0
          };
        }
      }
      
      // Calculate summary totals
      stats.summary.validScans = stats.byResult.valid;
      stats.summary.invalidScans = stats.byResult.invalid;
      stats.summary.blockedScans = stats.byResult.blocked;
      stats.summary.duplicateScans = stats.byResult.duplicate;
      
      // Add success rate
      stats.summary.successRate = stats.summary.totalScans > 0 ? 
        Math.round((stats.summary.validScans / stats.summary.totalScans) * 100) : 0;
      
      logger.info(`Stats report generated: ${stats.summary.totalScans} total scans`);
      
      res.status(200).json({
        message: 'Statistics retrieved successfully',
        stats,
        filters: {
          category
        },
        generatedAt: new Date().toISOString()
      });
      
    } catch (error) {
      logger.error('Get stats error:', error);
      
      res.status(500).json({
        error: 'Failed to retrieve statistics',
        code: 'STATS_ERROR',
        message: process.env.NODE_ENV === 'development' ? error.message : 'Internal server error'
      });
    }
  }
);

// GET /api/admin/cache-debug/:uid
router.get('/cache-debug/:uid',
  authenticateToken,
  adminOnly,
  async (req, res) => {
    try {
      const { uid } = req.params;
      
      // Check database
      const dbPass = await PassModel.findByUid(uid);
      
      // Check Redis cache
      const activeCache = await redisService.getActivePass(uid);
      const isBlocked = await redisService.isPassBlocked(uid);
      
      const debugInfo = {
        uid,
        database: {
          exists: !!dbPass,
          pass: dbPass ? {
            id: dbPass.id,
            pass_id: dbPass.pass_id,
            status: dbPass.status,
            created_at: dbPass.created_at
          } : null
        },
        redis_cache: {
          in_active_cache: !!activeCache,
          active_cache_data: activeCache,
          in_blocked_cache: isBlocked
        },
        cache_consistency: {
          db_exists_cache_missing: !!dbPass && !activeCache && dbPass.status === 'active',
          cache_exists_db_missing: !!activeCache && !dbPass,
          status_mismatch: dbPass && activeCache && dbPass.status !== activeCache.status
        }
      };
      
      res.status(200).json({
        message: 'Cache debug information retrieved',
        debug: debugInfo
      });
      
    } catch (error) {
      logger.error('Cache debug error:', error);
      res.status(500).json({
        error: 'Failed to retrieve cache debug information',
        code: 'CACHE_DEBUG_ERROR',
        message: process.env.NODE_ENV === 'development' ? error.message : 'Internal server error'
      });
    }
  }
);

// GET /api/admin/cache-debug - General cache debug information
router.get('/cache-debug',
  authenticateToken,
  adminOnly,
  async (req, res) => {
    try {
      // Get Redis connection info
      const redisClient = redisService.getClient();
      const redisConnected = await redisService.isConnected();
      const connectionStatus = redisService.getConnectionStatus();
      const redisInfo = redisConnected ? await redisClient.info('memory') : '';
      
      // Get cache statistics only if connected
      let activePassesCount = 0;
      let blockedPassesCount = 0;
      let allKeys = [];
      let activePassKeys = [];
      let blockedPassKeys = [];
      let lockKeys = [];
      
      if (redisConnected) {
        try {
          activePassesCount = await redisService.getActivePassesCount();
          blockedPassesCount = await redisService.getBlockedPassesCount();
          allKeys = await redisClient.keys('*');
          activePassKeys = allKeys.filter(key => key.startsWith('active_pass:'));
          blockedPassKeys = allKeys.filter(key => key.startsWith('blocked_pass:'));
          lockKeys = allKeys.filter(key => key.startsWith('verify_lock:'));
        } catch (error) {
          logger.error('Error getting cache statistics:', error);
        }
      }
      
      // Parse memory usage from Redis info
      let memoryUsage = 0;
      if (redisInfo) {
        const memoryMatch = redisInfo.match(/used_memory:(\d+)/);
        if (memoryMatch) {
          memoryUsage = parseInt(memoryMatch[1]);
        }
      }
      
      const debugInfo = {
        redis: {
          connected: redisConnected,
          status: connectionStatus.status,
          rawStatus: redisClient ? redisClient.status : 'no_client',
          totalKeys: allKeys.length,
          memoryUsage: memoryUsage,
          connectionDetails: connectionStatus
        },
        cache_counts: {
          activePasses: activePassesCount,
          blockedPasses: blockedPassesCount
        },
        keys: {
          activePasses: activePassKeys.length,
          blockedPasses: blockedPassKeys.length,
          lockKeys: lockKeys.length,
          total: allKeys.length
        },
        key_samples: redisConnected ? {
          activePassKeys: activePassKeys.slice(0, 5), // First 5 keys as samples
          blockedPassKeys: blockedPassKeys.slice(0, 5),
          lockKeys: lockKeys.slice(0, 5)
        } : {
          activePassKeys: [],
          blockedPassKeys: [],
          lockKeys: []
        }
      };
      
      res.status(200).json({
        message: 'Cache debug information retrieved',
        debug: debugInfo
      });
      
    } catch (error) {
      logger.error('General cache debug error:', error);
      res.status(500).json({
        error: 'Failed to retrieve cache debug information',
        code: 'CACHE_DEBUG_ERROR',
        message: process.env.NODE_ENV === 'development' ? error.message : 'Internal server error'
      });
    }
  }
);

// GET /api/admin/cache-stats
router.get('/cache-stats',
  authenticateToken,
  adminOnly,
  async (req, res) => {
    try {
      const cacheStats = await redisService.getCacheStats();
      const connectionStatus = redisService.getConnectionStatus();
      
      res.status(200).json({
        redis_status: connectionStatus.connected ? 'Connected' : 'Disconnected',
        total_keys: cacheStats.activePassesCount + cacheStats.blockedPassesCount,
        memory_usage: 'N/A', // Redis memory usage would require additional implementation
        active_passes: cacheStats.activePassesCount,
        blocked_passes: cacheStats.blockedPassesCount,
        lock_keys: 0, // Lock keys count would require additional implementation
        timestamp: cacheStats.timestamp
      });
      
    } catch (error) {
      logger.error('Cache stats error:', error);
      res.status(500).json({
        error: 'Failed to get cache statistics',
        code: 'CACHE_STATS_ERROR',
        message: process.env.NODE_ENV === 'development' ? error.message : 'Internal server error'
      });
    }
  }
);

// POST /api/admin/clear-cache (clear all cache)
router.post('/clear-cache',
  authenticateToken,
  adminOnly,
  auditLog('CLEAR_ALL_CACHE'),
  async (req, res) => {
    try {
      // Clear all cache entries
      await redisService.clearAllCaches();
      
      logger.info(`All cache cleared by ${req.user.role} ${req.user.username}`);
      
      res.status(200).json({
        message: 'All cache cleared successfully'
      });
      
    } catch (error) {
      logger.error('Clear all cache error:', error);
      res.status(500).json({
        error: 'Failed to clear all cache',
        code: 'CLEAR_ALL_CACHE_ERROR',
        message: process.env.NODE_ENV === 'development' ? error.message : 'Internal server error'
      });
    }
  }
);

// POST /api/admin/clear-cache/:uid
router.post('/clear-cache/:uid',
  authenticateToken,
  adminOnly,
  async (req, res) => {
    try {
      const { uid } = req.params;
      
      // Clear all cache entries for this UID
      await redisService.removeActivePass(uid);
      await redisService.removeBlockedPass(uid);
      await redisService.releaseVerifyLock(uid);
      
      logger.info(`Cache cleared for UID ${uid} by ${req.user.role} ${req.user.username}`);
      
      res.status(200).json({
        message: 'Cache cleared successfully',
        uid
      });
      
    } catch (error) {
      logger.error('Clear cache error:', error);
      res.status(500).json({
        error: 'Failed to clear cache',
        code: 'CLEAR_CACHE_ERROR',
        message: process.env.NODE_ENV === 'development' ? error.message : 'Internal server error'
      });
    }
  }
);

// GET /api/admin/system-info
router.get('/system-info',
  authenticateToken,
  adminOnly,
  async (req, res) => {
    try {
      // Get system information
      const [passStats, cacheStats, settings] = await Promise.all([
        PassModel.getPassStats(),
        redisService.getCacheStats(),
        SettingsModel.getAll()
      ]);
      
      const systemInfo = {
        version: settings.system_version || '1.0.0',
        environment: process.env.NODE_ENV || 'development',
        uptime: process.uptime(),
        lastResetDate: settings.last_reset_date || 'Never',
        database: {
          passStats
        },
        cache: cacheStats,
        settings: {
          dailyResetEnabled: settings.daily_reset_enabled === 'true',
          verifyRateLimit: parseInt(settings.verify_rate_limit) || 100,
          bulkBatchSize: parseInt(settings.bulk_batch_size) || 100
        },
        server: {
          nodeVersion: process.version,
          platform: process.platform,
          memory: process.memoryUsage(),
          pid: process.pid
        }
      };
      
      res.status(200).json({
        message: 'System information retrieved successfully',
        systemInfo,
        timestamp: new Date().toISOString()
      });
      
    } catch (error) {
      logger.error('Get system info error:', error);
      
      res.status(500).json({
        error: 'Failed to retrieve system information',
        code: 'SYSTEM_INFO_ERROR',
        message: process.env.NODE_ENV === 'development' ? error.message : 'Internal server error'
      });
    }
  }
);

// POST /api/admin/rebuild-cache
router.post('/rebuild-cache',
  authenticateToken,
  adminOnly,
  auditLog('REBUILD_CACHE'),
  async (req, res) => {
    try {
      logger.info(`Cache rebuild initiated by ${req.user.username}`);
      
      const cacheStats = await redisService.rebuildAllCaches();
      
      // Emit socket event
      const io = req.app.get('io');
      if (io) {
        io.emit('cache:rebuilt', {
          ...cacheStats,
          rebuiltBy: req.user.username,
          timestamp: new Date().toISOString()
        });
      }
      
      logger.info(`Cache rebuild completed: Active=${cacheStats.activeCount}, Blocked=${cacheStats.blockedCount}`);
      
      res.status(200).json({
        message: 'Cache rebuilt successfully',
        stats: cacheStats,
        rebuiltBy: req.user.username,
        timestamp: new Date().toISOString()
      });
      
    } catch (error) {
      logger.error('Rebuild cache error:', error);
      
      res.status(500).json({
        error: 'Failed to rebuild cache',
        code: 'REBUILD_CACHE_ERROR',
        message: process.env.NODE_ENV === 'development' ? error.message : 'Internal server error'
      });
    }
  }
);

// GET /api/admin/settings
router.get('/settings',
  authenticateToken,
  adminOrManager,
  async (req, res) => {
    try {
      const settings = await SettingsModel.getAll();
      
      logger.info(`Settings retrieved by ${req.user.username}`);
      
      res.status(200).json({
        message: 'Settings retrieved successfully',
        settings,
        retrievedBy: req.user.username,
        timestamp: new Date().toISOString()
      });
      
    } catch (error) {
      logger.error('Get settings error:', error);
      
      res.status(500).json({
        error: 'Failed to retrieve settings',
        code: 'GET_SETTINGS_ERROR',
        message: process.env.NODE_ENV === 'development' ? error.message : 'Internal server error'
      });
    }
  }
);

// POST /api/admin/sync-logs
router.post('/sync-logs',
  authenticateToken,
  adminOrManager,
  auditLog('SYNC_LOGS'),
  async (req, res) => {
    const startTime = Date.now();
    
    try {
      const { logs } = req.body;
      
      if (!logs || !Array.isArray(logs)) {
        return res.status(400).json({
          error: 'Invalid request format',
          message: 'logs array is required'
        });
      }
      
      if (logs.length === 0) {
        return res.json({
          success: true,
          processed: 0,
          successful: 0,
          failed: 0,
          message: 'No logs to process'
        });
      }
      
      if (logs.length > 1000) {
        return res.status(400).json({
          error: 'Batch size too large',
          message: 'Maximum 1000 logs per batch'
        });
      }
      
      // Log sync start
      await LoggingService.logSyncStart(req.user, req, 'admin_logs', logs.length);
      
      let successful = 0;
      let failed = 0;
      const failedLogs = [];
      
      logger.info(`Processing batch sync of ${logs.length} logs from ${req.user.username}`);
      
      for (const logData of logs) {
        try {
          // Validate required fields
          if (!logData.action || !logData.uid || !logData.timestamp) {
            failed++;
            failedLogs.push({
              log: logData,
              error: 'Missing required fields (action, uid, timestamp)'
            });
            continue;
          }
          
          // Process the log entry
          await LoggingService.logAction(
            logData.action,
            logData.uid,
            req.user,
            req,
            logData.details || {},
            new Date(logData.timestamp)
          );
          
          successful++;
        } catch (error) {
          failed++;
          failedLogs.push({
            log: logData,
            error: error.message
          });
          logger.error(`Failed to process log for ${logData.uid}:`, error);
        }
      }
      
      // Calculate sync duration
      const duration = Date.now() - startTime;
      const result = {
        total: logs.length,
        processed: successful,
        errors: failed,
        duration
      };
      
      // Log sync completion
      await LoggingService.logSyncComplete(req.user, req, result, 'admin_logs');
      
      logger.info(`Batch sync completed: ${successful} successful, ${failed} failed`);
      
      res.json({
        success: true,
        processed: logs.length,
        successful,
        failed,
        failedLogs: failed > 0 ? failedLogs : undefined,
        duration
      });
      
    } catch (error) {
      // Log sync error
      await LoggingService.logSyncError(req.user, req, error, 'admin_logs', req.body?.logs?.length || 0);
      
      logger.error('Error in batch sync logs:', error);
      res.status(500).json({
        error: 'Failed to process batch sync',
        message: error.message
      });
    }
  }
);

// PUT /api/admin/settings
router.put('/settings',
  authenticateToken,
  adminOnly,
  auditLog('UPDATE_SETTINGS'),
  async (req, res) => {
    try {
      const allowedSettings = [
        'daily_reset_enabled',
        'verify_rate_limit',
        'bulk_batch_size',
        'system_version'
      ];
      
      const updates = {};
      
      // Filter and validate settings
      Object.keys(req.body).forEach(key => {
        if (allowedSettings.includes(key)) {
          updates[key] = req.body[key];
        }
      });
      
      if (Object.keys(updates).length === 0) {
        return res.status(400).json({
          error: 'No valid settings provided',
          code: 'NO_VALID_SETTINGS',
          allowedSettings
        });
      }
      
      // Validate specific settings
      if (updates.verify_rate_limit && (isNaN(updates.verify_rate_limit) || updates.verify_rate_limit < 1)) {
        return res.status(400).json({
          error: 'Verify rate limit must be a positive number',
          code: 'INVALID_RATE_LIMIT'
        });
      }
      
      if (updates.bulk_batch_size && (isNaN(updates.bulk_batch_size) || updates.bulk_batch_size < 1 || updates.bulk_batch_size > 1000)) {
        return res.status(400).json({
          error: 'Bulk batch size must be between 1 and 1000',
          code: 'INVALID_BATCH_SIZE'
        });
      }
      
      // Update settings
      await SettingsModel.updateMultiple(updates);
      
      logger.info(`Settings updated by ${req.user.username}: ${Object.keys(updates).join(', ')}`);
      
      res.status(200).json({
        message: 'Settings updated successfully',
        updatedSettings: updates,
        updatedBy: req.user.username,
        timestamp: new Date().toISOString()
      });
      
    } catch (error) {
      logger.error('Update settings error:', error);
      
      res.status(500).json({
        error: 'Failed to update settings',
        code: 'UPDATE_SETTINGS_ERROR',
        message: process.env.NODE_ENV === 'development' ? error.message : 'Internal server error'
      });
    }
  }
);

module.exports = router;