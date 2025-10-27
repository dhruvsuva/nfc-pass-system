const { executeQuery } = require('../config/db');
const logger = require('../utils/logger');

class SettingsModel {
  static async get(key) {
    try {
      const query = 'SELECT setting_value FROM settings WHERE setting_key = ?';
      const result = await executeQuery(query, [key]);
      return result[0] ? result[0].setting_value : null;
    } catch (error) {
      logger.error('Error getting setting:', error);
      throw error;
    }
  }

  static async set(key, value) {
    try {
      const query = `
        INSERT INTO settings (setting_key, setting_value) 
        VALUES (?, ?) 
        ON DUPLICATE KEY UPDATE 
        setting_value = VALUES(setting_value), 
        updated_at = CURRENT_TIMESTAMP
      `;
      
      await executeQuery(query, [key, value]);
      return true;
    } catch (error) {
      logger.error('Error setting value:', error);
      throw error;
    }
  }

  static async getAll() {
    try {
      const query = 'SELECT setting_key, setting_value, updated_at FROM settings ORDER BY setting_key';
      const result = await executeQuery(query);
      
      // Convert to key-value object
      const settings = {};
      result.forEach(row => {
        settings[row.setting_key] = row.setting_value;
      });
      
      return settings;
    } catch (error) {
      logger.error('Error getting all settings:', error);
      throw error;
    }
  }

  static async getMultiple(keys) {
    try {
      if (!keys || keys.length === 0) return {};
      
      const placeholders = keys.map(() => '?').join(',');
      const query = `SELECT setting_key, setting_value FROM settings WHERE setting_key IN (${placeholders})`;
      const result = await executeQuery(query, keys);
      
      // Convert to key-value object
      const settings = {};
      result.forEach(row => {
        settings[row.setting_key] = row.setting_value;
      });
      
      return settings;
    } catch (error) {
      logger.error('Error getting multiple settings:', error);
      throw error;
    }
  }

  static async delete(key) {
    try {
      const query = 'DELETE FROM settings WHERE setting_key = ?';
      const result = await executeQuery(query, [key]);
      return result.affectedRows > 0;
    } catch (error) {
      logger.error('Error deleting setting:', error);
      throw error;
    }
  }

  static async getLastResetDate() {
    try {
      const value = await this.get('last_reset_date');
      return value || '1970-01-01';
    } catch (error) {
      logger.error('Error getting last reset date:', error);
      throw error;
    }
  }

  static async setLastResetDate(date) {
    try {
      return await this.set('last_reset_date', date);
    } catch (error) {
      logger.error('Error setting last reset date:', error);
      throw error;
    }
  }

  static async getSystemVersion() {
    try {
      const value = await this.get('system_version');
      return value || '1.0.0';
    } catch (error) {
      logger.error('Error getting system version:', error);
      throw error;
    }
  }

  static async isDailyResetEnabled() {
    try {
      const value = await this.get('daily_reset_enabled');
      return value === 'true';
    } catch (error) {
      logger.error('Error checking daily reset enabled:', error);
      throw error;
    }
  }

  static async setDailyResetEnabled(enabled) {
    try {
      return await this.set('daily_reset_enabled', enabled ? 'true' : 'false');
    } catch (error) {
      logger.error('Error setting daily reset enabled:', error);
      throw error;
    }
  }

  static async getVerifyRateLimit() {
    try {
      const value = await this.get('verify_rate_limit');
      return parseInt(value) || 100;
    } catch (error) {
      logger.error('Error getting verify rate limit:', error);
      throw error;
    }
  }

  static async getBulkBatchSize() {
    try {
      const value = await this.get('bulk_batch_size');
      return parseInt(value) || 100;
    } catch (error) {
      logger.error('Error getting bulk batch size:', error);
      throw error;
    }
  }

  static async updateMultiple(settings) {
    try {
      const promises = Object.entries(settings).map(([key, value]) => 
        this.set(key, value)
      );
      
      await Promise.all(promises);
      return true;
    } catch (error) {
      logger.error('Error updating multiple settings:', error);
      throw error;
    }
  }
}

module.exports = SettingsModel;