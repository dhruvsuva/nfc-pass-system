const express = require('express');
const { authenticateToken, allRoles, adminOrManager, adminOnly } = require('../utils/auth.middleware');
const {
  handleValidationErrors,
  getPaginationParams
} = require('../utils/validators');
const LogsModel = require('../models/logs.model');
const logger = require('../utils/logger');

const router = express.Router();

// GET /api/system-logs - Get system logs with filters and pagination
router.get('/',
  authenticateToken,
  allRoles, // Allow all authenticated users (admin, manager, bouncer)
  async (req, res) => {
    try {
      const {
        action_type,
        user_id,
        role,
        pass_id,
        uid,
        result,
        start_date,
        end_date,
        search
      } = req.query;
      
      const pagination = getPaginationParams(req);
      
      // Build filters object
      const filters = {
        page: pagination.page,
        limit: pagination.limit
      };
      
      if (action_type) filters.action_type = action_type;
      if (user_id) filters.user_id = parseInt(user_id);
      if (role) filters.role = role;
      if (pass_id) filters.pass_id = pass_id;
      if (uid) filters.uid = uid;
      if (result) filters.result = result;
      if (start_date) filters.start_date = start_date;
      if (end_date) filters.end_date = end_date;
      if (search) filters.search = search;
      
      // For bouncer role, add category-based filtering
      if (req.user.role === 'bouncer') {
        const UserModel = require('../models/user.model');
        
        // Get bouncer's assigned category
        const bouncer = await UserModel.findByIdIncludeInactive(req.user.id);
        if (!bouncer || !bouncer.assigned_category) {
          return res.status(403).json({
            error: 'Bouncer does not have an assigned category',
            code: 'NO_ASSIGNED_CATEGORY'
          });
        }
        
        // Add category filter - bouncer can only see logs for their assigned category
        filters.bouncer_category = bouncer.assigned_category;
      }
      
      // Get logs with filters
      const result_data = await LogsModel.getLogs(filters);
      
      logger.info(`System logs retrieved: ${result_data.logs.length} logs for user ${req.user.username}`);
      
      res.status(200).json({
        message: 'System logs retrieved successfully',
        logs: result_data.logs,
        pagination: {
          page: result_data.page,
          limit: result_data.limit,
          total: result_data.total,
          totalPages: result_data.totalPages
        },
        filters: {
          action_type,
          user_id,
          role,
          pass_id,
          uid,
          result,
          start_date,
          end_date,
          search
        }
      });
      
    } catch (error) {
      logger.error('Get system logs error:', error);
      
      res.status(500).json({
        error: 'Failed to retrieve system logs',
        code: 'GET_SYSTEM_LOGS_ERROR',
        message: process.env.NODE_ENV === 'development' ? error.message : 'Internal server error'
      });
    }
  }
);

// GET /api/system-logs/stats - Get system logs statistics
router.get('/stats',
  authenticateToken,
  adminOrManager,
  async (req, res) => {
    try {
      const { start_date, end_date } = req.query;
      
      const stats = await LogsModel.getLogStats(start_date, end_date);
      
      // Process stats into a more readable format
      const processedStats = {
        total: 0,
        by_action: {},
        by_result: {},
        by_action_result: {}
      };
      
      stats.forEach(stat => {
        processedStats.total += stat.count;
        
        // By action type
        if (!processedStats.by_action[stat.action_type]) {
          processedStats.by_action[stat.action_type] = 0;
        }
        processedStats.by_action[stat.action_type] += stat.count;
        
        // By result
        if (!processedStats.by_result[stat.result]) {
          processedStats.by_result[stat.result] = 0;
        }
        processedStats.by_result[stat.result] += stat.count;
        
        // By action and result combination
        const key = `${stat.action_type}_${stat.result}`;
        processedStats.by_action_result[key] = stat.count;
      });
      
      logger.info(`System logs stats retrieved for period ${start_date || 'all'} to ${end_date || 'all'}`);
      
      res.status(200).json({
        message: 'System logs statistics retrieved successfully',
        stats: processedStats,
        period: {
          start_date: start_date || null,
          end_date: end_date || null
        }
      });
      
    } catch (error) {
      logger.error('Get system logs stats error:', error);
      
      res.status(500).json({
        error: 'Failed to retrieve system logs statistics',
        code: 'GET_SYSTEM_LOGS_STATS_ERROR',
        message: process.env.NODE_ENV === 'development' ? error.message : 'Internal server error'
      });
    }
  }
);

// GET /api/system-logs/:id - Get specific system log by ID
router.get('/:id',
  authenticateToken,
  adminOrManager,
  async (req, res) => {
    try {
      const logId = parseInt(req.params.id);
      
      if (isNaN(logId)) {
        return res.status(400).json({
          error: 'Invalid log ID',
          code: 'INVALID_LOG_ID'
        });
      }
      
      const log = await LogsModel.getLogById(logId);
      
      if (!log) {
        return res.status(404).json({
          error: 'Log not found',
          code: 'LOG_NOT_FOUND'
        });
      }
      
      logger.info(`System log retrieved: ID=${logId} by user ${req.user.username}`);
      
      res.status(200).json({
        message: 'System log retrieved successfully',
        log
      });
      
    } catch (error) {
      logger.error('Get system log by ID error:', error);
      
      res.status(500).json({
        error: 'Failed to retrieve system log',
        code: 'GET_SYSTEM_LOG_ERROR',
        message: process.env.NODE_ENV === 'development' ? error.message : 'Internal server error'
      });
    }
  }
);

// GET /api/system-logs/actions - Get available action types
router.get('/actions',
  authenticateToken,
  adminOrManager,
  async (req, res) => {
    try {
      // Get distinct action types from logs
      const actions = await LogsModel.getDistinctActionTypes();
      
      res.status(200).json({
        message: 'Available action types retrieved successfully',
        actions,
        count: actions.length
      });
      
    } catch (error) {
      logger.error('Get action types error:', error);
      
      res.status(500).json({
        error: 'Failed to retrieve action types',
        code: 'GET_ACTION_TYPES_ERROR',
        message: process.env.NODE_ENV === 'development' ? error.message : 'Internal server error'
      });
    }
  }
);

module.exports = router;