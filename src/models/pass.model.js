const { executeQuery, executeTransaction } = require('../config/db');
const { v4: uuidv4 } = require('uuid');
const logger = require('../utils/logger');

class PassModel {
  static async findById(id) {
    try {
      const query = `
        SELECT p.*, u.username as created_by_username,
               p.category as category_name, p.category as category_color, p.category as category_description
        FROM passes p 
        LEFT JOIN users u ON p.created_by = u.id 
        WHERE p.id = ? AND p.status != 'deleted'
      `;
      const result = await executeQuery(query, [id]);
      return result[0] || null;
    } catch (error) {
      logger.error('Error finding pass by ID:', error);
      throw error;
    }
  }

  static async findByUid(uid) {
    try {
      const query = `
        SELECT p.*, u.username as created_by_username,
               p.category as category_name, p.category as category_color, p.category as category_description
        FROM passes p 
        LEFT JOIN users u ON p.created_by = u.id 
        WHERE p.uid = ? AND p.status != 'deleted'
      `;
      const result = await executeQuery(query, [uid]);
      return result[0] || null;
    } catch (error) {
      logger.error('Error finding pass by UID:', error);
      throw error;
    }
  }

  static async findByPassId(passId) {
    try {
      const query = `
        SELECT p.*, u.username as created_by_username,
               p.category as category_name, p.category as category_color, p.category as category_description
        FROM passes p 
        LEFT JOIN users u ON p.created_by = u.id 
        WHERE p.pass_id = ? AND p.status != 'deleted'
      `;
      const result = await executeQuery(query, [passId]);
      return result[0] || null;
    } catch (error) {
      logger.error('Error finding pass by pass_id:', error);
      throw error;
    }
  }

  // Helper method to find pass by UID including deleted ones
  static async findByUidIncludingDeleted(uid) {
    try {
      const query = `
        SELECT p.*, p.category as category_name 
        FROM passes p
        WHERE p.uid = ?
        LIMIT 1
      `;
      const result = await executeQuery(query, [uid]);
      return result.length > 0 ? result[0] : null;
    } catch (error) {
      logger.error('Error finding pass by UID (including deleted):', error);
      throw error;
    }
  }

  // Helper method to hard delete a pass from database
  static async hardDelete(id) {
    try {
      const query = `DELETE FROM passes WHERE id = ?`;
      await executeQuery(query, [id]);
      logger.info(`Pass hard deleted from database: ID=${id}`);
    } catch (error) {
      logger.error('Error hard deleting pass:', error);
      throw error;
    }
  }

  static async create(passData) {
    try {
      const {
        uid,
        pass_type,
        category,
        people_allowed = 1,
        valid_from = null,
        valid_to = null,
        created_by
      } = passData;
      
      // Check for existing non-deleted pass with same UID
      const existingPass = await this.findByUid(uid);
      if (existingPass) {
        const duplicateError = new Error('Card already registered');
        duplicateError.code = 'DUPLICATE_UID';
        duplicateError.statusCode = 409;
        duplicateError.existingPassId = existingPass.id;
        throw duplicateError;
      }

      // Check for deleted pass with same UID and hard delete it
      const deletedPass = await this.findByUidIncludingDeleted(uid);
      if (deletedPass && deletedPass.status === 'deleted') {
        logger.info(`Found deleted pass with UID ${uid}, hard deleting it to allow new pass creation`);
        await this.hardDelete(deletedPass.id);
      }
      
      const pass_id = uuidv4();
      
      // Set default max_uses based on pass_type
      let finalPassType = pass_type;
      let maxUses;
      
      const defaultMaxUses = {
        'daily': 1,
        'seasonal': 11,
        'unlimited': 999999
      };
      
      maxUses = passData.max_uses || defaultMaxUses[pass_type] || 1;
      
      // Category validation - just use the category name directly
      if (!category) {
        throw new Error('Category is required for pass creation');
      }
      
      const query = `
        INSERT INTO passes (
          uid, pass_id, pass_type, category, people_allowed, 
          created_by, status, max_uses, used_count,
          created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, 'active', ?, 0, NOW(), NOW())
      `;
      
      const result = await executeQuery(query, [
        uid, pass_id, finalPassType, category, people_allowed,
        created_by, maxUses
      ]);
      
      // Return the created pass with remaining_uses calculated
      const createdPass = await this.findById(result.insertId);
      if (createdPass) {
        createdPass.remaining_uses = createdPass.max_uses - createdPass.used_count;
      }
      return createdPass;
    } catch (error) {
      // Handle any remaining database errors
      if (error.code === 'DUPLICATE_UID') {
        throw error; // Re-throw our custom duplicate error
      }
      
      // Handle MySQL duplicate entry error
      if (error.code === 'ER_DUP_ENTRY' && error.message.includes('passes.uid')) {
        // Find the existing pass to get its ID
        try {
          const existingPass = await this.findByUid(passData.uid);
          const duplicateError = new Error('Card already registered');
          duplicateError.code = 'DUPLICATE_UID';
          duplicateError.statusCode = 409;
          duplicateError.existingPassId = existingPass?.id;
          throw duplicateError;
        } catch (findError) {
          // If we can't find the existing pass, still throw duplicate error
          const duplicateError = new Error('Card already registered');
          duplicateError.code = 'DUPLICATE_UID';
          duplicateError.statusCode = 409;
          throw duplicateError;
        }
      }
      
      logger.error('Error creating pass:', error);
      throw error;
    }
  }

  static async createBulk(passesData) {
    try {
      const queries = [];
      const createdPasses = [];
      
      // First, check for existing passes (both active and deleted) and handle them
      for (const passData of passesData) {
        const { uid } = passData;
        
        // Check for existing non-deleted pass with same UID
        const existingPass = await this.findByUid(uid);
        if (existingPass) {
          const duplicateError = new Error(`Card already registered: ${uid}`);
          duplicateError.code = 'DUPLICATE_UID';
          duplicateError.statusCode = 409;
          duplicateError.existingPassId = existingPass.id;
          duplicateError.uid = uid;
          throw duplicateError;
        }

        // Check for deleted pass with same UID and hard delete it
        const deletedPass = await this.findByUidIncludingDeleted(uid);
        if (deletedPass && deletedPass.status === 'deleted') {
          logger.info(`Found deleted pass with UID ${uid}, hard deleting it to allow bulk pass creation`);
          await this.hardDelete(deletedPass.id);
        }
      }
      
      for (const passData of passesData) {
        const {
          uid,
          pass_type,
          category,
          people_allowed = 1,
          valid_from = null,
          valid_to = null,
          created_by,
          max_uses = null
        } = passData;
        
        logger.info(`Creating pass with UID: ${uid}`);
        
        const pass_id = uuidv4();
        
        // Set default max_uses based on pass_type
        let finalPassType = pass_type;
        let finalMaxUses;
        
        const defaultMaxUses = {
          'daily': 1,
          'seasonal': 11,
          'unlimited': 999999
        };
        
        finalMaxUses = max_uses || defaultMaxUses[pass_type] || 1;
        
        // Category validation - just use the category name directly
        if (!category) {
          throw new Error('Category is required for pass creation');
        }
        
        queries.push({
          query: `
            INSERT INTO passes (
              uid, pass_id, pass_type, category, people_allowed, 
              created_by, status, max_uses, used_count,
              created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, 'active', ?, 0, NOW(), NOW())
          `,
          params: [
            uid, pass_id, finalPassType, category, people_allowed,
            created_by, finalMaxUses
          ]
        });
        
        createdPasses.push({ uid, pass_id });
      }
      
      await executeTransaction(queries);
      return createdPasses;
    } catch (error) {
      logger.error('Error creating bulk passes:', error);
      throw error;
    }
  }

  static async updateStatus(id, status) {
    try {
      const query = 'UPDATE passes SET status = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?';
      await executeQuery(query, [status, id]);
      
      // For deleted status, we need to fetch the pass including deleted ones
      if (status === 'deleted') {
        const selectQuery = `
          SELECT p.*, u.username as created_by_username,
                 p.category as category_name, p.category as category_color, p.category as category_description
        FROM passes p 
        LEFT JOIN users u ON p.created_by = u.id 
        WHERE p.id = ?
        `;
        const result = await executeQuery(selectQuery, [id]);
        return result[0] || null;
      }
      
      return await this.findById(id);
    } catch (error) {
      logger.error('Error updating pass status:', error);
      throw error;
    }
  }

  static async softDelete(id) {
    try {
      return await this.updateStatus(id, 'deleted');
    } catch (error) {
      logger.error('Error soft deleting pass:', error);
      throw error;
    }
  }

  static async resetDailyPasses() {
    try {
      // Get current date for daily log table
      const currentDate = new Date().toISOString().split('T')[0]; // YYYY-MM-DD format
      const dailyLogTable = `daily_logs_${currentDate.replace(/-/g, '_')}`;
      
      // Start transaction to reset both passes and clear daily logs
      const queries = [
        {
          query: `
            UPDATE passes 
            SET status = 'active', used_count = 0, updated_at = CURRENT_TIMESTAMP 
            WHERE (status = 'used' OR used_count >= COALESCE(max_uses, 1)) 
            AND pass_type = 'daily' 
            AND status != 'deleted'
          `,
          params: []
        }
      ];
      
      // Check if daily log table exists and clear it
      const { executeTransaction, tableExists } = require('../config/db');
      const exists = await tableExists(dailyLogTable);
      if (exists) {
        queries.push({
          query: `DELETE FROM ${dailyLogTable} WHERE result = 'valid'`,
          params: []
        });
      }
      
      // Get count of passes that will be reset before executing transaction
      const countQuery = `
        SELECT COUNT(*) as count 
        FROM passes 
        WHERE (status = 'used' OR used_count >= COALESCE(max_uses, 1)) 
        AND pass_type = 'daily' 
        AND status != 'deleted'
      `;
      const countResult = await executeQuery(countQuery);
      const resetCount = countResult[0].count;
      
      // Execute all queries in transaction
      await executeTransaction(queries);
      
      return resetCount;
    } catch (error) {
      logger.error('Error resetting daily passes:', error);
      throw error;
    }
  }

  static async getActivePasses() {
    try {
      const query = `
        SELECT uid, pass_id, id as pass_db_id, status, people_allowed, pass_type, category
        FROM passes 
        WHERE status = 'active'
      `;
      
      const result = await executeQuery(query);
      return result;
    } catch (error) {
      logger.error('Error getting active passes:', error);
      throw error;
    }
  }

  static async getBlockedPasses() {
    try {
      const query = 'SELECT uid FROM passes WHERE status = "blocked"';
      const result = await executeQuery(query);
      return result.map(row => row.uid);
    } catch (error) {
      logger.error('Error getting blocked passes:', error);
      throw error;
    }
  }

  static async getAllPasses(filters = {}) {
    try {
      let query = `
        SELECT p.*, u.username as created_by_username 
        FROM passes p 
        LEFT JOIN users u ON p.created_by = u.id 
        WHERE p.status != 'deleted'
      `;
      const params = [];
      
      if (filters.status) {
        query += ' AND p.status = ?';
        params.push(filters.status);
      }
      
      if (filters.pass_type) {
        query += ' AND p.pass_type = ?';
        params.push(filters.pass_type);
      }
      
      if (filters.category) {
        query += ' AND p.category = ?';
        params.push(filters.category);
      }
      
      if (filters.created_by) {
        query += ' AND p.created_by = ?';
        params.push(filters.created_by);
      }
      
      query += ' ORDER BY p.created_at DESC';
      
      if (filters.limit) {
        query += ` LIMIT ${parseInt(filters.limit)}`;
      }
      
      if (filters.offset) {
        query += ` OFFSET ${parseInt(filters.offset)}`;
      }
      
      const result = await executeQuery(query, params);
      return result;
    } catch (error) {
      logger.error('Error getting all passes:', error);
      throw error;
    }
  }

  static async getPassStats() {
    try {
      const query = `
        SELECT 
          pass_type,
          category,
          status,
          COUNT(*) as count
        FROM passes 
        WHERE status != 'deleted'
        GROUP BY pass_type, category, status
        ORDER BY pass_type, category, status
      `;
      
      const result = await executeQuery(query);
      return result;
    } catch (error) {
      logger.error('Error getting pass stats:', error);
      throw error;
    }
  }

  static async isUidExists(uid) {
    try {
      const query = 'SELECT COUNT(*) as count FROM passes WHERE uid = ? AND status != "deleted"';
      const result = await executeQuery(query, [uid]);
      return result[0].count > 0;
    } catch (error) {
      logger.error('Error checking UID existence:', error);
      throw error;
    }
  }

  static async updateScanInfo(id, scannedBy) {
    try {
      const query = `
        UPDATE passes 
        SET updated_at = CURRENT_TIMESTAMP
        WHERE id = ?
      `;
      await executeQuery(query, [id]);
      return await this.findById(id);
    } catch (error) {
      logger.error('Error updating scan info:', error);
      throw error;
    }
  }

  static async incrementUsedCount(id, incrementBy = 1) {
    try {
      const query = `
        UPDATE passes 
        SET used_count = used_count + ?, updated_at = CURRENT_TIMESTAMP
        WHERE id = ?
      `;
      await executeQuery(query, [incrementBy, id]);
      return await this.findById(id);
    } catch (error) {
      logger.error('Error incrementing used count:', error);
      throw error;
    }
  }

  static async resetUsedCount(id) {
    try {
      const query = `
        UPDATE passes 
        SET used_count = 0, updated_at = CURRENT_TIMESTAMP
        WHERE id = ?
      `;
      await executeQuery(query, [id]);
      return await this.findById(id);
    } catch (error) {
      logger.error('Error resetting used count:', error);
      throw error;
    }
  }

  static async findByUidWithUsage(uid) {
    try {
      const query = `
        SELECT p.*, u.username as created_by_username,
               p.category as category_name, p.category as category_color, p.category as category_description,
               (p.max_uses - p.used_count) as remaining_uses
        FROM passes p 
        LEFT JOIN users u ON p.created_by = u.id 
        WHERE p.uid = ? AND p.status != 'deleted'
      `;
      const result = await executeQuery(query, [uid]);
      return result[0] || null;
    } catch (error) {
      logger.error('Error finding pass by UID with usage:', error);
      throw error;
    }
  }

  static async getPassesByIds(ids) {
    try {
      if (!ids || ids.length === 0) return [];
      
      const placeholders = ids.map(() => '?').join(',');
      const query = `
        SELECT p.*, u.username as created_by_username 
        FROM passes p 
        LEFT JOIN users u ON p.created_by = u.id 
        WHERE p.id IN (${placeholders}) AND p.status != 'deleted'
      `;
      
      const result = await executeQuery(query, ids);
      return result;
    } catch (error) {
      logger.error('Error getting passes by IDs:', error);
      throw error;
    }
  }
}

module.exports = PassModel;