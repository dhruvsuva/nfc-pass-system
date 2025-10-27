const express = require('express');
const { authenticateToken, adminOnly, adminOrManager, allRoles, auditLog } = require('../utils/auth.middleware');
const {
  createPassValidation,
  bulkCreatePassValidation,
  passIdValidation,
  resetPassValidation,
  handleValidationErrors,
  getPaginationParams
} = require('../utils/validators');
const passService = require('../services/pass.service');
const bulkService = require('../services/bulk.service');
const logger = require('../utils/logger');
const LoggingService = require('../services/logging.service');

const router = express.Router();

// POST /api/pass/create
router.post('/create',
  authenticateToken,
  adminOrManager,
  createPassValidation,
  handleValidationErrors,
  auditLog('PASS_CREATE'),
  async (req, res) => {
    let passData = null;
    
    try {
      passData = req.body;
      
      // Validate pass data
      const validationErrors = await passService.validatePassData(passData);
      if (validationErrors.length > 0) {
        return res.status(422).json({
          error: 'Pass validation failed',
          code: 'VALIDATION_ERROR',
          details: validationErrors
        });
      }
      
      const newPass = await passService.createPass(passData, req.user.id);
      
      // Log successful pass creation
      await LoggingService.logCreatePass(newPass, req.user, req);
      
      logger.info(`Pass created successfully: ${newPass.uid}`);
      
      res.status(201).json({
        message: 'Pass created successfully',
        pass: newPass
      });
      
    } catch (error) {
      logger.error('Create pass error:', error);
      
      // Log failed pass creation (only if passData is available)
      if (passData) {
        try {
          await LoggingService.logCreatePass(passData, req.user, req, false, error.message);
        } catch (logError) {
          logger.error('Failed to log pass creation error:', logError);
        }
      }
      
      // Handle duplicate UID error
      if (error.code === 'DUPLICATE_UID' && passData && passData.uid) {
        // Find the existing pass to include in response
        try {
          const existingPass = await passService.findPassByUID(passData.uid);
          return res.status(409).json({
            error: 'Card already registered',
            code: 'DUPLICATE_UID',
            message: `This card is already registered (pass_id: ${existingPass?.pass_id || 'unknown'})`,
            existingPassId: error.existingPassId || existingPass?.id,
            existing_pass: existingPass ? {
              pass_id: existingPass.pass_id,
              pass_type: existingPass.pass_type,
              category: existingPass.category,
              status: existingPass.status,
              created_at: existingPass.created_at
            } : null
          });
        } catch (findError) {
          logger.error('Failed to find existing pass:', findError);
          return res.status(409).json({
            error: 'Card already registered',
            code: 'DUPLICATE_UID',
            message: 'This card is already registered'
          });
        }
      }
      
      res.status(500).json({
        error: 'Failed to create pass',
        code: 'CREATE_ERROR',
        message: process.env.NODE_ENV === 'development' ? error.message : 'Internal server error'
      });
    }
  }
);

// POST /api/pass/create-bulk (NFC streaming mode)
router.post('/create-bulk',
  authenticateToken,
  adminOrManager,
  bulkCreatePassValidation,
  handleValidationErrors,
  auditLog('PASS_BULK_CREATE'),
  async (req, res) => {
    try {
      const { uids, pass_type, category, people_allowed, max_uses} = req.body;
      
      // Validate required fields
      if (!uids || !Array.isArray(uids) || uids.length === 0) {
        return res.status(400).json({
          error: 'UIDs array is required and must not be empty',
          code: 'MISSING_UIDS'
        });
      }
      
      if (!pass_type || !category || !people_allowed) {
        return res.status(400).json({
          error: 'pass_type, category, and people_allowed are required',
          code: 'MISSING_REQUIRED_FIELDS'
        });
      }
      
      // Set default max_uses based on pass_type if not provided
      const defaultMaxUses = {
        'daily': 1,
        'seasonal': 11
      };
      const finalMaxUses = max_uses || defaultMaxUses[pass_type] || 1;
      
      logger.info(`Bulk pass creation started: ${uids.length} UIDs, type: ${pass_type}`);
      
      // Remove duplicates, preserving first occurrence
      const uniqueUids = [...new Set(uids)];
      const duplicateCount = uids.length - uniqueUids.length;
      
      if (duplicateCount > 0) {
        logger.info(`Removed ${duplicateCount} duplicate UIDs from batch, preserving first occurrences`);
      }
      
      // Create pass data for each UID with proper validation
      const passesData = uniqueUids.map(uid => ({
        uid,
        pass_type,
        category,
        people_allowed,
        max_uses: finalMaxUses
      }));

      // Validate each pass data before creation
      for (const passData of passesData) {
        const validationErrors = await passService.validatePassData(passData);
        if (validationErrors.length > 0) {
          return res.status(422).json({
            error: 'Pass validation failed',
            code: 'VALIDATION_ERROR',
            details: validationErrors,
            uid: passData.uid
          });
        }
      }

      const result = await bulkService.createBulkPassesREST(passesData, req.user.id);
      
      // Log bulk pass creation
      await LoggingService.logBulkCreatePass(
        {
          bulk_id: result.bulk_id || 'bulk_' + Date.now(),
          total_requested: result.total,
          success_count: result.created,
          error_count: result.errors.length,
          pass_type,
          category,
          people_allowed,
          max_uses: finalMaxUses,
          batches: result.batches,
          errors: result.errors || []
        },
        req.user,
        req
      );
      
      logger.info(`Bulk pass creation completed: ${result.created}/${result.total} created, ${result.duplicates} duplicates`);
      
      const statusCode = result.errors.length > 0 ? 207 : 201; // 207 = Multi-Status
      
      res.status(statusCode).json({
        message: 'Bulk pass creation completed',
        total: result.total,
        created: result.created,
        duplicates: result.duplicates,
        errors: result.errors || [],
        batches: result.batches || 1,
        summary: {
          total: result.total,
          created: result.created,
          duplicates: result.duplicates,
          errors: result.errors.length
        }
      });
      
    } catch (error) {
      logger.error('Bulk create pass error:', error);
      
      // Log bulk creation error
      await LoggingService.logError('bulk_create_error', error, req.user, req, {
        action: 'bulk_create_pass',
        uids_count: req.body.uids?.length || 0,
        pass_type: req.body.pass_type,
        category: req.body.category
      });
      
      res.status(500).json({
        error: 'Failed to create bulk passes',
        code: 'BULK_CREATE_ERROR',
        message: process.env.NODE_ENV === 'development' ? error.message : 'Internal server error'
      });
    }
  }
);

// DELETE /api/pass/:id
router.delete('/:id',
  authenticateToken,
  adminOrManager,
  passIdValidation,
  handleValidationErrors,
  auditLog('PASS_DELETE'),
  async (req, res) => {
    try {
      const passId = parseInt(req.params.id);
      
      const deletedPass = await passService.deletePass(passId, req.user.id);
      
      // Log pass deletion
      await LoggingService.logDeletePass(deletedPass, req.user, req);
      
      logger.info(`Pass deleted successfully: ID=${passId}`);
      
      res.status(200).json({
        message: 'Pass deleted successfully',
        pass: deletedPass
      });
      
    } catch (error) {
      logger.error('Delete pass error:', error);
      
      // Log delete error
      await LoggingService.logError('delete_pass_error', error, req.user, req, {
        action: 'delete_pass',
        pass_id: passId
      });
      
      if (error.message === 'Pass not found') {
        return res.status(404).json({
          error: 'Pass not found',
          code: 'PASS_NOT_FOUND'
        });
      }
      
      res.status(500).json({
        error: 'Failed to delete pass',
        code: 'DELETE_ERROR',
        message: process.env.NODE_ENV === 'development' ? error.message : 'Internal server error'
      });
    }
  }
);

// PATCH /api/pass/:id/block
router.patch('/:id/block',
  authenticateToken,
  adminOnly, // Only admin can block passes
  passIdValidation,
  handleValidationErrors,
  auditLog('PASS_BLOCK'),
  async (req, res) => {
    const passId = parseInt(req.params.id);
    
    try {
      
      const result = await passService.blockPass(passId, req.user.id);
      
      // Log pass blocking
      await LoggingService.logBlockUnblockPass(result.pass, 'block', req.user, req);
      
      // Emit socket event for real-time notifications
      const io = req.app.get('io');
      if (io) {
        io.emit(result.event.type, result.event.data);
      }
      
      logger.info(`Pass blocked successfully: ID=${passId}`);
      
      res.status(200).json({
        message: 'Pass blocked successfully',
        pass: result.pass
      });
      
    } catch (error) {
      logger.error('Block pass error:', error);
      
      // Log block error
      await LoggingService.logError('block_pass_error', error, req.user, req, {
        action: 'block_pass',
        pass_id: passId
      });
      
      if (error.message === 'Pass not found') {
        return res.status(404).json({
          error: 'Pass not found',
          code: 'PASS_NOT_FOUND'
        });
      }
      
      if (error.message.includes('Cannot block')) {
        return res.status(400).json({
          error: error.message,
          code: 'INVALID_OPERATION'
        });
      }
      
      res.status(500).json({
        error: 'Failed to block pass',
        code: 'BLOCK_ERROR',
        message: process.env.NODE_ENV === 'development' ? error.message : 'Internal server error'
      });
    }
  }
);

// PATCH /api/pass/:id/unblock
router.patch('/:id/unblock',
  authenticateToken,
  adminOnly, // Only admin can unblock passes
  passIdValidation,
  handleValidationErrors,
  auditLog('PASS_UNBLOCK'),
  async (req, res) => {
    const passId = parseInt(req.params.id);
    
    try {
      const result = await passService.unblockPass(passId, req.user.id);
      
      // Log pass unblocking
      await LoggingService.logBlockUnblockPass(result.pass, 'unblock', req.user, req);
      
      // Emit socket event for real-time notifications
      const io = req.app.get('io');
      if (io) {
        io.emit(result.event.type, result.event.data);
      }
      
      logger.info(`Pass unblocked successfully: ID=${passId}`);
      
      res.status(200).json({
        message: 'Pass unblocked successfully',
        pass: result.pass
      });
      
    } catch (error) {
      logger.error('Unblock pass error:', error);
      
      // Log unblock error
      await LoggingService.logError('unblock_pass_error', error, req.user, req, {
        action: 'unblock_pass',
        pass_id: passId
      });
      
      if (error.message === 'Pass not found') {
        return res.status(404).json({
          error: 'Pass not found',
          code: 'PASS_NOT_FOUND'
        });
      }
      
      if (error.message.includes('not currently blocked')) {
        return res.status(400).json({
          error: error.message,
          code: 'INVALID_OPERATION'
        });
      }
      
      res.status(500).json({
        error: 'Failed to unblock pass',
        code: 'UNBLOCK_ERROR',
        message: process.env.NODE_ENV === 'development' ? error.message : 'Internal server error'
      });
    }
  }
);

// PATCH /api/pass/:id/reset
router.patch('/:id/reset',
  authenticateToken,
  adminOrManager, // Admin or Manager can reset passes
  passIdValidation,
  resetPassValidation,
  handleValidationErrors,
  auditLog('PASS_RESET'),
  async (req, res) => {
    const passId = parseInt(req.params.id);
    try {
      const { reason } = req.body;
      
      const result = await passService.resetPass(passId, req.user.id, reason);
      
      // Log pass reset
      await LoggingService.logResetSinglePass(result.pass, req.user, req);
      
      // Emit socket event for real-time notifications
      const io = req.app.get('io');
      if (io) {
        io.emit(result.event.type, result.event.data);
      }
      
      logger.info(`Pass reset successfully: ID=${passId}`);
      
      res.status(200).json({
        message: 'Pass reset successfully',
        pass: result.pass
      });
      
    } catch (error) {
      logger.error('Reset pass error:', error);
      
      // Log reset error
      await LoggingService.logError('reset_pass_error', error, req.user, req, {
        action: 'reset_pass',
        pass_id: passId,
        reason: req.body.reason
      });
      
      if (error.message === 'Pass not found') {
        return res.status(404).json({
          error: 'Pass not found',
          code: 'PASS_NOT_FOUND'
        });
      }
      
      if (error.message.includes('Only used passes')) {
        return res.status(400).json({
          error: error.message,
          code: 'INVALID_OPERATION'
        });
      }
      
      res.status(500).json({
        error: 'Failed to reset pass',
        code: 'RESET_ERROR',
        message: process.env.NODE_ENV === 'development' ? error.message : 'Internal server error'
      });
    }
  }
);

// POST /api/pass/reset-all
router.post('/reset-all',
  authenticateToken,
  adminOnly, // Only admin can reset all passes
  auditLog('PASS_RESET_ALL'),
  async (req, res) => {
    try {
      const { reason, confirm } = req.body;
      
      // Validate confirmation
      if (confirm !== 'true') {
        return res.status(400).json({
          error: 'Reset all passes requires explicit confirmation',
          code: 'CONFIRMATION_REQUIRED',
          message: 'Set confirm=true to proceed with resetting all passes'
        });
      }
      
      logger.info(`Starting reset all passes by ${req.user.username}`);
      
      // Reset all passes (no daily restriction)
      const result = await passService.resetAllPasses(req.user.id, reason);
      
      // Log reset all passes
      await LoggingService.logResetAllPasses(result, req.user, req);
      
      // Emit socket event for real-time notifications
      const io = req.app.get('io');
      if (io) {
        io.emit('pass:reset-all', {
          resetCount: result.reset_count,
          performedBy: req.user.username,
          reason: reason,
          timestamp: new Date().toISOString()
        });
      }
      
      logger.info(`Reset all passes completed: ${result.reset_count} passes reset`);
      
      res.status(200).json({
        message: 'All passes reset successfully',
        summary: {
          passesReset: result.reset_count,
          performedBy: req.user.username,
          reason: reason,
          timestamp: new Date().toISOString()
        }
      });
      
    } catch (error) {
      logger.error('Reset all passes error:', error);
      
      // Log reset all error
      await LoggingService.logError('reset_all_passes_error', error, req.user, req, {
        action: 'reset_all_passes',
        reason: req.body.reason
      });
      
      res.status(500).json({
        error: 'Failed to reset all passes',
        code: 'RESET_ALL_ERROR',
        message: process.env.NODE_ENV === 'development' ? error.message : 'Internal server error'
      });
    }
  }
);

// GET /api/pass/search?uid=<uid> - Must be before /:id route
router.get('/search',
  authenticateToken,
  allRoles, // Allow all authenticated users (admin, manager, bouncer)
  async (req, res) => {
    try {
      const { uid } = req.query;
      
      if (!uid) {
        return res.status(400).json({
          error: 'UID parameter is required',
          code: 'MISSING_UID'
        });
      }
      
      const pass = await passService.findPassByUIDWithUsage(uid);
      
      if (!pass) {
        return res.status(404).json({
          error: 'Pass not found',
          code: 'PASS_NOT_FOUND'
        });
      }
      
      // Get recent logs for this pass
      const recentLogs = await passService.getRecentLogsForPass(uid, 10);
      
      res.status(200).json({
        message: 'Pass found successfully',
        pass: {
          ...pass,
          remaining_uses: pass.max_uses - pass.used_count
        },
        recent_logs: recentLogs
      });
      
    } catch (error) {
      logger.error('Search pass error:', error);
      
      res.status(500).json({
        error: 'Failed to search pass',
        code: 'SEARCH_ERROR',
        message: process.env.NODE_ENV === 'development' ? error.message : 'Internal server error'
      });
    }
  }
);

// GET /api/pass/:id
router.get('/:id',
  authenticateToken,
  adminOrManager,
  passIdValidation,
  handleValidationErrors,
  async (req, res) => {
    try {
      const passId = parseInt(req.params.id);
      
      const passDetails = await passService.getPassDetails(passId);
      
      res.status(200).json({
        message: 'Pass details retrieved successfully',
        pass: passDetails
      });
      
    } catch (error) {
      logger.error('Get pass details error:', error);
      
      if (error.message === 'Pass not found') {
        return res.status(404).json({
          error: 'Pass not found',
          code: 'PASS_NOT_FOUND'
        });
      }
      
      res.status(500).json({
        error: 'Failed to retrieve pass details',
        code: 'GET_ERROR',
        message: process.env.NODE_ENV === 'development' ? error.message : 'Internal server error'
      });
    }
  }
);

// GET /api/passes (list all passes with filters and search)
router.get('/',
  authenticateToken,
  adminOrManager,
  async (req, res) => {
    try {
      const { status, pass_type, category, created_by, search, uid, pass_id } = req.query;
      const pagination = getPaginationParams(req);
      
      const filters = {};
      if (status) filters.status = status;
      if (pass_type) filters.pass_type = pass_type;
      if (category) filters.category = category;
      if (created_by) filters.created_by = parseInt(created_by);
      if (search) filters.search = search;
      if (uid) filters.uid = uid;
      if (pass_id) filters.pass_id = pass_id;
      
      const result = await passService.getAllPassesWithPagination(filters, pagination);
      
      res.status(200).json({
        message: 'Passes retrieved successfully',
        passes: result.passes,
        pagination: {
          page: pagination.page,
          limit: pagination.limit,
          total: result.total,
          totalPages: Math.ceil(result.total / pagination.limit),
          hasNextPage: pagination.page < Math.ceil(result.total / pagination.limit),
          hasPrevPage: pagination.page > 1
        },
        filters
      });
      
    } catch (error) {
      logger.error('Get passes error:', error);
      
      res.status(500).json({
        error: 'Failed to retrieve passes',
        code: 'GET_ERROR',
        message: process.env.NODE_ENV === 'development' ? error.message : 'Internal server error'
      });
    }
  }
);

// GET /api/passes/uid/:uid (get pass by UID with complete usage details)
router.get('/uid/:uid',
  authenticateToken,
  adminOrManager,
  async (req, res) => {
    try {
      const { uid } = req.params;
      
      if (!uid) {
        return res.status(400).json({
          error: 'UID parameter is required',
          code: 'MISSING_UID'
        });
      }
      
      const pass = await passService.findPassByUIDWithUsage(uid);
      
      if (!pass) {
        return res.status(404).json({
          error: 'Pass not found',
          code: 'PASS_NOT_FOUND'
        });
      }
      
      // Get complete usage history for this pass (all logs)
      const usageHistory = await passService.getCompleteUsageHistory(uid);
      
      // Calculate remaining uses
      const remainingUses = pass.max_uses ? Math.max(0, pass.max_uses - pass.used_count) : null;
      
      res.status(200).json({
        message: 'Pass details retrieved successfully',
        pass: {
          ...pass,
          remaining_uses: remainingUses
        },
        usage_history: usageHistory,
        statistics: {
          total_scans: pass.used_count || 0,
          remaining_uses: remainingUses,
          is_unlimited: !pass.max_uses,
          last_used: usageHistory.length > 0 ? usageHistory[0].scanned_at : null
        }
      });
      
    } catch (error) {
      logger.error('Get pass by UID error:', error);
      
      res.status(500).json({
        error: 'Failed to retrieve pass details',
        code: 'GET_ERROR',
        message: process.env.NODE_ENV === 'development' ? error.message : 'Internal server error'
      });
    }
  }
);

// GET /api/pass/stats
router.get('/stats',
  authenticateToken,
  adminOrManager,
  async (req, res) => {
    try {
      const stats = await passService.getPassStats();
      
      res.status(200).json({
        message: 'Pass statistics retrieved successfully',
        stats
      });
      
    } catch (error) {
      logger.error('Get pass stats error:', error);
      
      res.status(500).json({
        error: 'Failed to retrieve pass statistics',
        code: 'STATS_ERROR',
        message: process.env.NODE_ENV === 'development' ? error.message : 'Internal server error'
      });
    }
  }
);

module.exports = router;