const { executeQuery } = require('../config/db');
const logger = require('../utils/logger');

class LogsModel {
  // Create logs table
  static async createTable() {
    const query = `
      CREATE TABLE IF NOT EXISTS logs (
        id BIGINT PRIMARY KEY AUTO_INCREMENT,
        action_type ENUM(
          'login', 'logout', 'login_failed',
          'create_user', 'update_user', 'delete_user',
          'block_user', 'unblock_user',
          'create_category', 'update_category', 'delete_category',
          'system_error', 'api_error', 'auth_error',
          'sync_start', 'sync_complete', 'sync_error',
          'daily_reset_error'
        ) NOT NULL,
        user_id BIGINT NULL,
        role ENUM('admin', 'manager', 'bouncer', 'system') NULL,
        ip_address VARCHAR(45) NULL,
        user_agent TEXT NULL,
        details JSON NULL,
        result ENUM('success', 'failure', 'error') NOT NULL DEFAULT 'success',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        INDEX idx_action_type (action_type),
        INDEX idx_user_id (user_id),
        INDEX idx_role (role),
        INDEX idx_result (result),
        INDEX idx_created_at (created_at),
        INDEX idx_action_user (action_type, user_id),
        INDEX idx_action_date (action_type, created_at),
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    `;
    
    try {
      await executeQuery(query);
      logger.info('Logs table created successfully');
      return true;
    } catch (error) {
      logger.error('Error creating logs table:', error);
      throw error;
    }
  }

  // Insert a new log entry
  static async createLog({
    action_type,
    user_id = null,
    role = null,
    ip_address = null,
    user_agent = null,
    details = null,
    result = 'success'
  }) {
    const query = `
      INSERT INTO logs (
        action_type, user_id, role, ip_address, user_agent, details, result
      ) VALUES (?, ?, ?, ?, ?, ?, ?)
    `;
    
    const params = [
      action_type,
      user_id,
      role,
      ip_address,
      user_agent,
      details ? JSON.stringify(details) : null,
      result
    ];

    try {
      const result = await executeQuery(query, params);
      logger.debug('Log entry created:', { id: result.insertId, action_type, user_id });
      return result.insertId;
    } catch (error) {
      logger.error('Error creating log entry:', error);
      throw error;
    }
  }

  // Get logs with filters and pagination
  static async getLogs({
    action_type = null,
    user_id = null,
    role = null,
    result = null,
    start_date = null,
    end_date = null,
    page = 1,
    limit = 50,
    search = null
  }) {
    // Debug logging
    logger.info('getLogs called with parameters:', {
      action_type, user_id, role, result, start_date, end_date, page, limit, search
    });
    
    let whereConditions = [];
    let params = [];

    if (action_type) {
      whereConditions.push('l.action_type = ?');
      params.push(action_type);
    }

    if (user_id) {
      whereConditions.push('l.user_id = ?');
      params.push(user_id);
    }

    if (role) {
      whereConditions.push('l.role = ?');
      params.push(role);
    }

    if (result) {
      whereConditions.push('l.result = ?');
      params.push(result);
    }

    if (start_date) {
      whereConditions.push('l.created_at >= ?');
      params.push(start_date);
    }

    if (end_date) {
      whereConditions.push('l.created_at <= ?');
      params.push(end_date);
    }

    if (search) {
      whereConditions.push('(l.details LIKE ? OR u.username LIKE ?)');
      params.push(`%${search}%`, `%${search}%`);
    }

    const whereClause = whereConditions.length > 0 ? `WHERE ${whereConditions.join(' AND ')}` : '';
    
    // Ensure limit and offset are integers
    const limitInt = parseInt(limit, 10);
    const offsetInt = (parseInt(page, 10) - 1) * limitInt;

    // Get total count
    const countQuery = `
      SELECT COUNT(*) as total 
      FROM logs l
      LEFT JOIN users u ON l.user_id = u.id
      ${whereClause}
    `;
    
    const countResult = await executeQuery(countQuery, params);
    const total = countResult[0].total;

    // Get logs with user details
    const query = `
      SELECT 
        l.*,
        u.username,
        u.assigned_category
      FROM logs l
      LEFT JOIN users u ON l.user_id = u.id
      ${whereClause}
      ORDER BY l.created_at DESC
      LIMIT ${limitInt} OFFSET ${offsetInt}
    `;

    // Debug logging
    logger.info('Executing query with parameters:', {
      query: query.replace(/\s+/g, ' ').trim(),
      params: params,
      paramTypes: params.map(p => typeof p)
    });
    
    const logs = await executeQuery(query, params);

    // Parse JSON details
    logs.forEach(log => {
      if (log.details) {
        try {
          log.details = JSON.parse(log.details);
        } catch (e) {
          log.details = null;
        }
      }
    });

    return {
      logs,
      page: parseInt(page, 10),
      limit: limitInt,
      total,
      totalPages: Math.ceil(total / limitInt)
    };
  }

  // Get single log by ID
  static async getLogById(id) {
    const query = `
      SELECT 
        l.*,
        u.username,
        u.assigned_category
      FROM logs l
      LEFT JOIN users u ON l.user_id = u.id
      WHERE l.id = ?
    `;

    try {
      const result = await executeQuery(query, [id]);
      if (result.length === 0) {
        return null;
      }

      const log = result[0];
      if (log.details) {
        try {
          log.details = JSON.parse(log.details);
        } catch (e) {
          log.details = null;
        }
      }

      return log;
    } catch (error) {
      logger.error('Error getting log by ID:', error);
      throw error;
    }
  }

  // Get logs statistics
  static async getLogStats(start_date = null, end_date = null) {
    let whereClause = '';
    let params = [];

    if (start_date && end_date) {
      whereClause = 'WHERE created_at BETWEEN ? AND ?';
      params = [start_date, end_date];
    } else if (start_date) {
      whereClause = 'WHERE created_at >= ?';
      params = [start_date];
    } else if (end_date) {
      whereClause = 'WHERE created_at <= ?';
      params = [end_date];
    }

    const query = `
      SELECT 
        action_type,
        result,
        COUNT(*) as count
      FROM logs
      ${whereClause}
      GROUP BY action_type, result
      ORDER BY action_type, result
    `;

    try {
      const stats = await executeQuery(query, params);
      return stats;
    } catch (error) {
      logger.error('Error getting log stats:', error);
      throw error;
    }
  }

  // Get distinct action types
  static async getDistinctActionTypes() {
    const query = `
      SELECT DISTINCT action_type
      FROM logs
      ORDER BY action_type
    `;

    try {
      const result = await executeQuery(query);
      return result.map(row => row.action_type);
    } catch (error) {
      logger.error('Error getting distinct action types:', error);
      throw error;
    }
  }

  // Clean old logs (optional - for maintenance)
  static async cleanOldLogs(daysToKeep = 90) {
    const query = `
      DELETE FROM logs 
      WHERE created_at < DATE_SUB(NOW(), INTERVAL ? DAY)
    `;

    try {
      const result = await executeQuery(query, [daysToKeep]);
      logger.info(`Cleaned ${result.affectedRows} old log entries`);
      return result.affectedRows;
    } catch (error) {
      logger.error('Error cleaning old logs:', error);
      throw error;
    }
  }
}

module.exports = LogsModel;