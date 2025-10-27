const { executeQuery } = require('../config/db');
const logger = require('../utils/logger');

class DailyLogsService {
  // Get today's date in YYYY_MM_DD format
  static getTodayDateString() {
    const today = new Date();
    const year = today.getFullYear();
    const month = String(today.getMonth() + 1).padStart(2, '0');
    const day = String(today.getDate()).padStart(2, '0');
    return `${year}_${month}_${day}`;
  }

  // Get table name for a specific date
  static getTableName(date = null) {
    if (!date) {
      return `daily_logs_${this.getTodayDateString()}`;
    }
    
    // If date is provided, format it
    if (date instanceof Date) {
      const year = date.getFullYear();
      const month = String(date.getMonth() + 1).padStart(2, '0');
      const day = String(date.getDate()).padStart(2, '0');
      return `daily_logs_${year}_${month}_${day}`;
    }
    
    // If date is string, use as is
    return `daily_logs_${date}`;
  }

  // Create daily logs table if it doesn't exist
  static async createDailyTable(date = null) {
    const tableName = this.getTableName(date);
    
    try {
      const query = `
        CREATE TABLE IF NOT EXISTS \`${tableName}\` (
          id BIGINT PRIMARY KEY AUTO_INCREMENT,
          action_type ENUM(
            'verify_pass', 'create_pass', 'bulk_create_pass', 
            'delete_pass', 'block_pass', 'unblock_pass', 'reset_single_pass'
          ) NOT NULL,
          user_id BIGINT NULL,
          role ENUM('admin', 'manager', 'bouncer', 'system') NULL,
          pass_id CHAR(36) NULL,
          uid VARCHAR(128) NULL,
          scanned_at TIMESTAMP NULL,
          scanned_by BIGINT NULL,
          remaining_uses INT NULL,
          consumed_count INT NULL,
          category VARCHAR(50) NULL,
          pass_type VARCHAR(20) NULL,
          ip_address VARCHAR(45) NULL,
          user_agent TEXT NULL,
          details JSON NULL,
          result ENUM('success', 'failure', 'error') NOT NULL DEFAULT 'success',
          error_message TEXT NULL,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          INDEX idx_action_type (action_type),
          INDEX idx_user_id (user_id),
          INDEX idx_role (role),
          INDEX idx_pass_id (pass_id),
          INDEX idx_uid (uid),
          INDEX idx_result (result),
          INDEX idx_created_at (created_at),
          INDEX idx_action_user (action_type, user_id),
          INDEX idx_action_date (action_type, created_at)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
      `;
      
      await executeQuery(query);
      logger.info(`Daily logs table created/verified: ${tableName}`);
      return tableName;
    } catch (error) {
      logger.error(`Failed to create daily logs table ${tableName}:`, error);
      throw error;
    }
  }

  // Insert log into daily table
  static async insertLog(logData, date = null) {
    const tableName = this.getTableName(date);
    
    try {
      // Ensure table exists
      await this.createDailyTable(date);
      
      const query = `
        INSERT INTO \`${tableName}\` (
          action_type, user_id, role, pass_id, uid,
          scanned_at, scanned_by, remaining_uses, consumed_count, 
          category, pass_type, ip_address, user_agent, details, result, error_message
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      `;
      
      const params = [
        logData.action_type,
        logData.user_id ?? null,
        logData.role ?? null,
        logData.pass_id ?? null,
        logData.uid ?? null,
        logData.scanned_at ?? null,
        logData.scanned_by ?? null,
        logData.remaining_uses ?? null,
        logData.consumed_count ?? null,
        logData.category ?? null,
        logData.pass_type ?? null,
        logData.ip_address ?? null,
        logData.user_agent ?? null,
        logData.details ? JSON.stringify(logData.details) : null,
        logData.result ?? 'success',
        logData.error_message ?? null
      ];
      
      const result = await executeQuery(query, params);
      logger.debug(`Log inserted into ${tableName}: ID ${result.insertId}`);
      return result.insertId;
    } catch (error) {
      logger.error(`Failed to insert log into ${tableName}:`, error);
      throw error;
    }
  }

  // Get logs from daily table
  static async getLogs(date = null, options = {}) {
    const tableName = this.getTableName(date);
    
    try {
      // Check if table exists
      const tableExists = await this.tableExists(tableName);
      if (!tableExists) {
        return [];
      }

      const {
        action_type = null,
        user_id = null,
        role = null,
        pass_id = null,
        uid = null,
        result = null,
        start_date = null,
        end_date = null,
        limit = 100,
        offset = 0
      } = options;

      let query = `SELECT * FROM \`${tableName}\` WHERE 1=1`;
      const params = [];

      if (action_type) {
        query += ` AND action_type = ?`;
        params.push(action_type);
      }
      if (user_id) {
        query += ` AND user_id = ?`;
        params.push(user_id);
      }
      if (role) {
        query += ` AND role = ?`;
        params.push(role);
      }
      if (pass_id) {
        query += ` AND pass_id = ?`;
        params.push(pass_id);
      }
      if (uid) {
        query += ` AND uid = ?`;
        params.push(uid);
      }
      if (result) {
        query += ` AND result = ?`;
        params.push(result);
      }
      if (start_date) {
        query += ` AND created_at >= ?`;
        params.push(start_date);
      }
      if (end_date) {
        query += ` AND created_at <= ?`;
        params.push(end_date);
      }

      query += ` ORDER BY created_at DESC LIMIT ${parseInt(limit)} OFFSET ${parseInt(offset)}`;

      const logs = await executeQuery(query, params);
      return logs;
    } catch (error) {
      logger.error(`Failed to get logs from ${tableName}:`, error);
      throw error;
    }
  }

  // Check if table exists
  static async tableExists(tableName) {
    try {
      const query = `
        SELECT COUNT(*) as count 
        FROM information_schema.tables 
        WHERE table_schema = DATABASE() 
        AND table_name = ?
      `;
      const result = await executeQuery(query, [tableName]);
      return result[0].count > 0;
    } catch (error) {
      logger.error(`Failed to check if table exists ${tableName}:`, error);
      return false;
    }
  }

  // Get table statistics
  static async getTableStats(tableName) {
    try {
      const query = `SELECT COUNT(*) as total_logs FROM \`${tableName}\``;
      const result = await executeQuery(query);
      return {
        table_name: tableName,
        total_logs: result[0].total_logs
      };
    } catch (error) {
      logger.error(`Failed to get stats for ${tableName}:`, error);
      return {
        table_name: tableName,
        total_logs: 0,
        error: error.message
      };
    }
  }

  // Get all daily tables
  static async getAllDailyTables() {
    try {
      const query = `
        SELECT table_name 
        FROM information_schema.tables 
        WHERE table_schema = DATABASE() 
        AND table_name LIKE 'daily_logs_%'
        ORDER BY table_name DESC
      `;
      const tables = await executeQuery(query);
      return tables.map(row => row.table_name);
    } catch (error) {
      logger.error('Failed to get daily tables:', error);
      return [];
    }
  }

  // Clean up old daily tables (older than specified days)
  static async cleanupOldTables(daysToKeep = 30) {
    try {
      const cutoffDate = new Date();
      cutoffDate.setDate(cutoffDate.getDate() - daysToKeep);
      
      const allTables = await this.getAllDailyTables();
      const tablesToDelete = [];
      
      for (const tableName of allTables) {
        // Extract date from table name (daily_logs_YYYY_MM_DD)
        const dateMatch = tableName.match(/daily_logs_(\d{4})_(\d{2})_(\d{2})/);
        if (dateMatch) {
          const [, year, month, day] = dateMatch;
          const tableDate = new Date(year, month - 1, day);
          
          if (tableDate < cutoffDate) {
            tablesToDelete.push(tableName);
          }
        }
      }
      
      // Delete old tables
      for (const tableName of tablesToDelete) {
        try {
          await executeQuery(`DROP TABLE IF EXISTS \`${tableName}\``);
          logger.info(`Deleted old daily logs table: ${tableName}`);
        } catch (error) {
          logger.error(`Failed to delete table ${tableName}:`, error);
        }
      }
      
      return {
        deleted_tables: tablesToDelete,
        count: tablesToDelete.length
      };
    } catch (error) {
      logger.error('Failed to cleanup old daily tables:', error);
      throw error;
    }
  }
}

module.exports = DailyLogsService;
