const { executeQuery } = require('../config/db');
const { getPaginationParams, validateDateRange } = require('../utils/validators');
const logger = require('../utils/logger');

class LogsController {
  // Get system logs with filtering and pagination
  async getSystemLogs(req, res) {
    try {
      const pagination = getPaginationParams(req);
      const {
        action_type,
        result,
        role,
        search,
        start_date,
        end_date
      } = req.query;
      
      // Validate date range if provided
      if (start_date && end_date) {
        const dateValidation = validateDateRange(start_date, end_date);
        if (!dateValidation.valid) {
        return res.status(400).json({
            error: dateValidation.message,
            code: 'INVALID_DATE_RANGE'
          });
        }
      }

      // Build WHERE clause
      const whereConditions = [];
      const params = [];
      
      if (action_type) {
        whereConditions.push('l.action_type = ?');
        params.push(action_type);
      }
      
      if (result) {
        whereConditions.push('l.result = ?');
        params.push(result);
      }
      
      if (role) {
        whereConditions.push('u.role = ?');
        params.push(role);
      }

      if (search) {
        whereConditions.push('(l.action_type LIKE ? OR l.details LIKE ? OR u.username LIKE ?)');
        const searchPattern = `%${search}%`;
        params.push(searchPattern, searchPattern, searchPattern);
      }

      if (start_date) {
        whereConditions.push('l.created_at >= ?');
        params.push(start_date);
      }

      if (end_date) {
        whereConditions.push('l.created_at <= ?');
        params.push(end_date);
      }

      const whereClause = whereConditions.length > 0 
        ? `WHERE ${whereConditions.join(' AND ')}`
        : '';

      // Get total count
      const countQuery = `
        SELECT COUNT(*) as total
        FROM logs l
        LEFT JOIN users u ON l.user_id = u.id
        ${whereClause}
      `;
      
      const [countResult] = await executeQuery(countQuery, params);
      const total = countResult[0] ? countResult[0].total : 0;

      // Get logs with pagination
      const logsQuery = `
        SELECT 
          l.id,
          l.action_type,
          l.created_at,
          l.result,
          l.details,
          l.ip_address,
          l.user_agent,
          u.username,
          u.role
        FROM logs l
        LEFT JOIN users u ON l.user_id = u.id
        ${whereClause}
        ORDER BY l.created_at DESC
        LIMIT ? OFFSET ?
      `;

      const offset = (pagination.page - 1) * pagination.limit;
      const logsResult = await executeQuery(logsQuery, [...params, pagination.limit, offset]);
      const logs = logsResult || [];

      const totalPages = Math.ceil(total / pagination.limit);
      
      res.status(200).json({
        message: 'System logs retrieved successfully',
        logs: logs,
        pagination: {
          page: pagination.page,
          limit: pagination.limit,
          total: total,
          totalPages: totalPages,
          hasNextPage: pagination.page < totalPages,
          hasPrevPage: pagination.page > 1
        },
        filters: {
          action_type,
          result,
          role,
          search,
          start_date,
          end_date
        }
      });
      
    } catch (error) {
      logger.error('Error retrieving system logs:', error);
      res.status(500).json({
        error: 'Failed to retrieve system logs',
        code: 'GET_SYSTEM_LOGS_ERROR',
        message: error.message
      });
    }
  }

  // Get daily logs with filtering and pagination
  async getDailyLogs(req, res) {
    try {
      const pagination = getPaginationParams(req);
      const {
        action_type,
        result,
        role,
        search,
        start_date,
        end_date
      } = req.query;

      // Get today's table name
      const today = new Date();
      const tableName = `daily_logs_${today.getFullYear()}_${String(today.getMonth() + 1).padStart(2, '0')}_${String(today.getDate()).padStart(2, '0')}`;

      // Check if table exists
      const tableExistsQuery = `
        SELECT COUNT(*) as count 
        FROM information_schema.tables 
        WHERE table_schema = DATABASE() 
        AND table_name = ?
      `;
      
      const [tableExistsResult] = await executeQuery(tableExistsQuery, [tableName]);
      
      if (!tableExistsResult[0] || tableExistsResult[0].count === 0) {
        return res.status(200).json({
          message: 'Daily logs retrieved successfully',
          logs: [],
          pagination: {
            page: pagination.page,
            limit: pagination.limit,
            total: 0,
            totalPages: 0,
            hasNextPage: false,
            hasPrevPage: false
          },
          filters: req.query
        });
      }

      // Build WHERE clause
      const whereConditions = [];
      const params = [];

      if (action_type) {
        whereConditions.push('action_type = ?');
        params.push(action_type);
      }
      
      if (result) {
        whereConditions.push('result = ?');
        params.push(result);
      }
      
      if (role) {
        whereConditions.push('role = ?');
        params.push(role);
      }

      if (search) {
        whereConditions.push('(action_type LIKE ? OR uid LIKE ? OR details LIKE ?)');
        const searchPattern = `%${search}%`;
        params.push(searchPattern, searchPattern, searchPattern);
      }

      if (start_date) {
        whereConditions.push('created_at >= ?');
        params.push(start_date);
      }

      if (end_date) {
        whereConditions.push('created_at <= ?');
        params.push(end_date);
      }

      const whereClause = whereConditions.length > 0 
        ? `WHERE ${whereConditions.join(' AND ')}`
        : '';
      
      // Get total count
      const countQuery = `
        SELECT COUNT(*) as total
        FROM ${tableName}
        ${whereClause}
      `;
      
      const [countResult] = await executeQuery(countQuery, params);
      const total = countResult[0] ? countResult[0].total : 0;

      // Get logs with pagination
      const logsQuery = `
        SELECT *
        FROM ${tableName}
        ${whereClause}
        ORDER BY created_at DESC
        LIMIT ? OFFSET ?
      `;

      const offset = (pagination.page - 1) * pagination.limit;
      const logsResult = await executeQuery(logsQuery, [...params, pagination.limit, offset]);
      const logs = logsResult || [];

      const totalPages = Math.ceil(total / pagination.limit);
      
      res.status(200).json({
        message: 'Daily logs retrieved successfully',
        logs: logs,
        pagination: {
          page: pagination.page,
          limit: pagination.limit,
          total: total,
          totalPages: totalPages,
          hasNextPage: pagination.page < totalPages,
          hasPrevPage: pagination.page > 1
        },
        filters: {
          action_type,
          result,
          role,
          search,
          start_date,
          end_date
        }
      });
      
    } catch (error) {
      logger.error('Error retrieving daily logs:', error);
      res.status(500).json({
        error: 'Failed to retrieve daily logs',
        code: 'GET_DAILY_LOGS_ERROR',
        message: error.message
      });
    }
  }

  // Get combined logs (both system and daily)
  async getCombinedLogs(req, res) {
    try {
      const pagination = getPaginationParams(req);
      const {
        action_type,
        result,
        role,
        search,
        start_date,
        end_date
      } = req.query;

      // Get system logs data directly
      let systemLogs = [];
      let systemTotal = 0;
      try {
        const systemResult = await this._getSystemLogsData(req.query);
        systemLogs = systemResult.logs;
        systemTotal = systemResult.total;
      } catch (error) {
        logger.warn('Failed to get system logs for combined view:', error.message);
      }

      // Get daily logs data directly
      let dailyLogs = [];
      let dailyTotal = 0;
      try {
        const dailyResult = await this._getDailyLogsData(req.query);
        dailyLogs = dailyResult.logs;
        dailyTotal = dailyResult.total;
      } catch (error) {
        logger.warn('Failed to get daily logs for combined view:', error.message);
      }

      const totalLogs = systemTotal + dailyTotal;
      const totalPages = Math.ceil(totalLogs / pagination.limit);
      
      res.status(200).json({
        message: 'Combined logs retrieved successfully',
        system_logs: systemLogs,
        daily_logs: dailyLogs,
        pagination: {
          page: pagination.page,
          limit: pagination.limit,
          total: totalLogs,
          totalPages: totalPages,
          hasNextPage: pagination.page < totalPages,
          hasPrevPage: pagination.page > 1
        },
        filters: {
          action_type,
          result,
          role,
          search,
          start_date,
          end_date
        }
      });
      
    } catch (error) {
      logger.error('Error retrieving combined logs:', error);
      res.status(500).json({
        error: 'Failed to retrieve combined logs',
        code: 'GET_COMBINED_LOGS_ERROR',
        message: error.message
      });
    }
  }

  // Helper method to get system logs data without response
  async _getSystemLogsData(query) {
    const page = parseInt(query.page) || 1;
    const limit = parseInt(query.limit) || 50;
    const pagination = { page, limit };
    const {
      action_type,
      result,
      role,
      search,
      start_date,
      end_date
    } = query;

    // Build WHERE clause
    const whereConditions = [];
    const params = [];

      if (action_type) {
        whereConditions.push('l.action_type = ?');
        params.push(action_type);
      }

      if (result) {
        whereConditions.push('l.result = ?');
        params.push(result);
      }

    if (role) {
      whereConditions.push('u.role = ?');
      params.push(role);
    }

    if (search) {
      whereConditions.push('(action LIKE ? OR details LIKE ? OR u.username LIKE ?)');
      const searchPattern = `%${search}%`;
      params.push(searchPattern, searchPattern, searchPattern);
    }

    if (start_date) {
      whereConditions.push('created_at >= ?');
      params.push(start_date);
    }

    if (end_date) {
      whereConditions.push('created_at <= ?');
      params.push(end_date);
    }

    const whereClause = whereConditions.length > 0 
      ? `WHERE ${whereConditions.join(' AND ')}`
      : '';

    // Get total count
    const countQuery = `
      SELECT COUNT(*) as total
      FROM logs l
      LEFT JOIN users u ON l.user_id = u.id
      ${whereClause}
    `;
    
    const [countResult] = await executeQuery(countQuery, params);
    const total = countResult[0] ? countResult[0].total : 0;

    // Get logs with pagination
    const logsQuery = `
      SELECT 
        l.id,
        l.action_type,
        l.created_at,
        l.result,
        l.details,
        l.ip_address,
        l.user_agent,
        u.username,
        u.role
      FROM logs l
      LEFT JOIN users u ON l.user_id = u.id
      ${whereClause}
      ORDER BY l.created_at DESC
      LIMIT ? OFFSET ?
    `;

    const offset = (pagination.page - 1) * pagination.limit;
    const logsResult = await executeQuery(logsQuery, [...params, pagination.limit, offset]);
    const logs = logsResult || [];

    return { logs, total };
  }

  // Helper method to get daily logs data without response
  async _getDailyLogsData(query) {
    const page = parseInt(query.page) || 1;
    const limit = parseInt(query.limit) || 50;
    const pagination = { page, limit };
    const {
      action_type,
      result,
      role,
      search,
      start_date,
      end_date
    } = query;

    // Get today's table name
    const today = new Date();
    const tableName = `daily_logs_${today.getFullYear()}_${String(today.getMonth() + 1).padStart(2, '0')}_${String(today.getDate()).padStart(2, '0')}`;

    // Check if table exists
    const tableExistsQuery = `
      SELECT COUNT(*) as count 
      FROM information_schema.tables 
      WHERE table_schema = DATABASE() 
      AND table_name = ?
    `;
    
    const [tableExistsResult] = await executeQuery(tableExistsQuery, [tableName]);
    
    if (tableExistsResult[0].count === 0) {
      return { logs: [], total: 0 };
    }

    // Build WHERE clause
    const whereConditions = [];
    const params = [];

    if (action_type) {
      whereConditions.push('action_type = ?');
      params.push(action_type);
    }

    if (result) {
      whereConditions.push('result = ?');
      params.push(result);
    }

    if (role) {
      whereConditions.push('role = ?');
      params.push(role);
    }

    if (search) {
      whereConditions.push('(action_type LIKE ? OR uid LIKE ? OR details LIKE ?)');
      const searchPattern = `%${search}%`;
      params.push(searchPattern, searchPattern, searchPattern);
    }

    if (start_date) {
      whereConditions.push('created_at >= ?');
      params.push(start_date);
    }

    if (end_date) {
      whereConditions.push('created_at <= ?');
      params.push(end_date);
    }

    const whereClause = whereConditions.length > 0 
      ? `WHERE ${whereConditions.join(' AND ')}`
      : '';

    // Get total count
    const countQuery = `
      SELECT COUNT(*) as total
      FROM ${tableName}
      ${whereClause}
    `;
    
    const [countResult] = await executeQuery(countQuery, params);
    const total = countResult[0] ? countResult[0].total : 0;

    // Get logs with pagination
    const logsQuery = `
      SELECT *
      FROM ${tableName}
      ${whereClause}
      ORDER BY created_at DESC
      LIMIT ? OFFSET ?
    `;

    const offset = (pagination.page - 1) * pagination.limit;
    const logsResult = await executeQuery(logsQuery, [...params, pagination.limit, offset]);
    const logs = logsResult || [];

    return { logs, total };
  }

  // Get log statistics
  async getLogStats(req, res) {
    try {
      const { start_date, end_date } = req.query;

      // Get today's table name
      const today = new Date();
      const tableName = `daily_logs_${today.getFullYear()}_${String(today.getMonth() + 1).padStart(2, '0')}_${String(today.getDate()).padStart(2, '0')}`;

      // Check if daily logs table exists
      const tableExistsQuery = `
        SELECT COUNT(*) as count 
        FROM information_schema.tables 
        WHERE table_schema = DATABASE() 
        AND table_name = ?
      `;
      
      const [tableExistsResult] = await executeQuery(tableExistsQuery, [tableName]);
      const dailyLogsTableExists = tableExistsResult[0] ? tableExistsResult[0].count > 0 : false;

      // Build date filter for system logs
      let systemLogsDateFilter = '';
      let systemLogsParams = [];
      if (start_date && end_date) {
        systemLogsDateFilter = 'WHERE created_at >= ? AND created_at <= ?';
        systemLogsParams = [start_date, end_date];
      }

      // Get system logs statistics
      const systemLogsStatsQuery = `
        SELECT 
          action_type,
          result,
          COUNT(*) as count
        FROM logs
        ${systemLogsDateFilter}
        GROUP BY action_type, result
        ORDER BY action_type, result
      `;

      const [systemLogsStats] = await executeQuery(systemLogsStatsQuery, systemLogsParams);

      // Get daily logs statistics if table exists
      let dailyLogsStats = [];
      if (dailyLogsTableExists) {
        let dailyLogsDateFilter = '';
        let dailyLogsParams = [];
        if (start_date && end_date) {
          dailyLogsDateFilter = 'WHERE created_at >= ? AND created_at <= ?';
          dailyLogsParams = [start_date, end_date];
        }

        const dailyLogsStatsQuery = `
          SELECT 
            action_type,
            result,
            COUNT(*) as count
          FROM ${tableName}
          ${dailyLogsDateFilter}
          GROUP BY action_type, result
          ORDER BY action_type, result
        `;

        const [dailyLogsStatsResult] = await executeQuery(dailyLogsStatsQuery, dailyLogsParams);
        dailyLogsStats = dailyLogsStatsResult;
      }
      
      res.status(200).json({
        message: 'Log statistics retrieved successfully',
        system_logs: systemLogsStats,
        daily_logs: dailyLogsStats,
        period: {
          start_date: start_date || null,
          end_date: end_date || null
        }
      });
      
    } catch (error) {
      logger.error('Error retrieving log statistics:', error);
      res.status(500).json({
        error: 'Failed to retrieve log statistics',
        code: 'GET_LOG_STATS_ERROR',
        message: error.message
      });
    }
  }
}

module.exports = new LogsController();