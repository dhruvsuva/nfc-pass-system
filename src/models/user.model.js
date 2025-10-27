const { executeQuery } = require('../config/db');
const bcrypt = require('bcryptjs');
const logger = require('../utils/logger');

class UserModel {
  static async findById(id) {
    try {
      const query = 'SELECT id, username, role, status, assigned_category, created_at, updated_at, blocked_at, blocked_by, block_reason FROM users WHERE id = ? AND status != "deleted"';
      const result = await executeQuery(query, [id]);
      return result[0] || null;
    } catch (error) {
      logger.error('Error finding user by ID:', error);
      throw error;
    }
  }

  static async findByUsername(username) {
    try {
      const query = 'SELECT * FROM users WHERE username = ? AND status = "active"';
      const result = await executeQuery(query, [username]);
      return result[0] || null;
    } catch (error) {
      logger.error('Error finding user by username:', error);
      throw error;
    }
  }

  static async create(userData) {
    try {
      const { username, password, role = 'bouncer', status = 'active', assigned_category = null } = userData;
      
      // Hash password
      const saltRounds = 12;
      const password_hash = await bcrypt.hash(password, saltRounds);
      
      const query = `
        INSERT INTO users (username, password_hash, role, status, assigned_category, created_at, updated_at) 
        VALUES (?, ?, ?, ?, ?, NOW(), NOW())
      `;
      
      const result = await executeQuery(query, [username, password_hash, role, status, assigned_category]);
      
      // Return the created user (without password)
      return await this.findById(result.insertId);
    } catch (error) {
      logger.error('Error creating user:', error);
      throw error;
    }
  }

  static async updatePassword(id, newPassword) {
    try {
      const saltRounds = 10;
      const password_hash = await bcrypt.hash(newPassword, saltRounds);
      
      const query = 'UPDATE users SET password_hash = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?';
      await executeQuery(query, [password_hash, id]);
      
      return true;
    } catch (error) {
      logger.error('Error updating user password:', error);
      throw error;
    }
  }

  static async updateStatus(id, status) {
    try {
      const query = 'UPDATE users SET status = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?';
      await executeQuery(query, [status, id]);
      
      return await this.findById(id);
    } catch (error) {
      logger.error('Error updating user status:', error);
      throw error;
    }
  }

  static async blockUser(id, blockedBy, blockReason) {
    try {
      const query = `
        UPDATE users 
        SET status = 'disabled', 
            blocked_at = NOW(), 
            blocked_by = ?, 
            block_reason = ?, 
            updated_at = NOW() 
        WHERE id = ?
      `;
      await executeQuery(query, [blockedBy, blockReason, id]);
      
      return await this.findById(id);
    } catch (error) {
      logger.error('Error blocking user:', error);
      throw error;
    }
  }

  static async unblockUser(id, unblockedBy) {
    try {
      const query = `
        UPDATE users 
        SET status = 'active', 
            blocked_at = NULL, 
            blocked_by = NULL, 
            block_reason = NULL, 
            updated_at = NOW() 
        WHERE id = ?
      `;
      await executeQuery(query, [id]);
      
      return await this.findById(id);
    } catch (error) {
      logger.error('Error unblocking user:', error);
      throw error;
    }
  }

  static async assignCategory(id, category) {
    try {
      const query = 'UPDATE users SET assigned_category = ?, updated_at = NOW() WHERE id = ?';
      await executeQuery(query, [category, id]);
      
      return await this.findById(id);
    } catch (error) {
      logger.error('Error assigning category to user:', error);
      throw error;
    }
  }

  static async verifyPassword(plainPassword, hashedPassword) {
    try {
      return await bcrypt.compare(plainPassword, hashedPassword);
    } catch (error) {
      logger.error('Error verifying password:', error);
      throw error;
    }
  }

  static async getAllUsers(filters = {}) {
    try {
      // Simple query with audit fields
      const query = 'SELECT id, username, role, status, assigned_category, created_at, updated_at, blocked_at, blocked_by, block_reason FROM users ORDER BY created_at DESC';
      const result = await executeQuery(query, []);
      return result;
    } catch (error) {
      logger.error('Error getting all users:', error);
      throw error;
    }
  }

  static async findAllWithPagination(options = {}) {
    try {
      const {
        page = 1,
        limit = 20,
        filters = {},
        sortBy = 'created_at',
        sortOrder = 'DESC'
      } = options;

      // Build WHERE clause
      const whereConditions = [];
      const params = [];

      // Search filter (username)
      if (filters.search) {
        whereConditions.push('username LIKE ?');
        params.push(`%${filters.search}%`);
      }

      // Role filter
      if (filters.role) {
        whereConditions.push('role = ?');
        params.push(filters.role);
      }

      // Status filter
      if (filters.status) {
        whereConditions.push('status = ?');
        params.push(filters.status);
      }

      const whereClause = whereConditions.length > 0 ? 'WHERE ' + whereConditions.join(' AND ') : '';

      // Validate sortBy to prevent SQL injection
      const validSortColumns = ['id', 'username', 'role', 'status', 'created_at', 'updated_at'];
      const safeSortBy = validSortColumns.includes(sortBy) ? sortBy : 'created_at';
      const safeSortOrder = ['ASC', 'DESC'].includes(sortOrder.toUpperCase()) ? sortOrder.toUpperCase() : 'DESC';

      // Get total count
      const countQuery = `SELECT COUNT(*) as count FROM users ${whereClause}`;
      const countResult = await executeQuery(countQuery, params);
      const totalCount = countResult[0].count;

      // Calculate pagination
      const totalPages = Math.ceil(totalCount / limit);
      const offset = (page - 1) * limit;

      // Get paginated results
      const dataQuery = `
        SELECT id, username, role, status, assigned_category, created_at, updated_at, blocked_at, blocked_by, block_reason
        FROM users 
        ${whereClause} 
        ORDER BY ${safeSortBy} ${safeSortOrder} 
        LIMIT ${parseInt(limit)} OFFSET ${parseInt(offset)}
      `;
      
      const users = await executeQuery(dataQuery, params);

      return {
        users,
        totalCount,
        totalPages,
        currentPage: page,
        hasNextPage: page < totalPages,
        hasPrevPage: page > 1
      };
    } catch (error) {
      logger.error('Error in findAllWithPagination:', error);
      throw error;
    }
  }

  static async getUserStats() {
    try {
      const query = `
        SELECT 
          role,
          status,
          COUNT(*) as count
        FROM users 
        GROUP BY role, status
      `;
      
      const result = await executeQuery(query);
      
      // Format the result
      const stats = {
        total: 0,
        byRole: { admin: 0, manager: 0, bouncer: 0 },
        byStatus: { active: 0, blocked: 0, deleted: 0 },
        detailed: result
      };
      
      result.forEach(row => {
        const count = parseInt(row.count);
        stats.total += count;
        stats.byRole[row.role] = (stats.byRole[row.role] || 0) + count;
        stats.byStatus[row.status] = (stats.byStatus[row.status] || 0) + count;
      });
      
      return stats;
    } catch (error) {
      logger.error('Error getting user stats:', error);
      throw error;
    }
  }

  static async findAll(options = {}) {
    try {
      const { where = {}, limit, offset, orderBy = 'created_at', orderDirection = 'DESC' } = options;
      
      let query = 'SELECT id, username, role, status, assigned_category, created_at, updated_at, blocked_at, blocked_by, block_reason FROM users';
      const params = [];
      const conditions = [];
      
      // Build WHERE clause
      if (where.role) {
        conditions.push('role = ?');
        params.push(where.role);
      }
      
      if (where.status) {
        conditions.push('status = ?');
        params.push(where.status);
      }
      
      if (where.username) {
        conditions.push('username LIKE ?');
        params.push(`%${where.username}%`);
      }
      
      if (conditions.length > 0) {
        query += ' WHERE ' + conditions.join(' AND ');
      }
      
      // Add ORDER BY
      query += ` ORDER BY ${orderBy} ${orderDirection}`;
      
      // Add LIMIT and OFFSET
      if (limit) {
        query += ' LIMIT ?';
        params.push(parseInt(limit) || 10);
        
        if (offset) {
          query += ' OFFSET ?';
          params.push(parseInt(offset) || 0);
        }
      }
      
      const result = await executeQuery(query, params);
      return result;
    } catch (error) {
      logger.error('Error finding all users:', error);
      throw error;
    }
  }

  static async count(where = {}) {
    try {
      let query = 'SELECT COUNT(*) as count FROM users';
      const params = [];
      const conditions = [];
      
      // Build WHERE clause
      if (where.role) {
        conditions.push('role = ?');
        params.push(where.role);
      }
      
      if (where.status) {
        conditions.push('status = ?');
        params.push(where.status);
      }
      
      if (where.username) {
        conditions.push('username LIKE ?');
        params.push(`%${where.username}%`);
      }
      
      if (conditions.length > 0) {
        query += ' WHERE ' + conditions.join(' AND ');
      }
      
      const result = await executeQuery(query, params);
      return result[0].count;
    } catch (error) {
      logger.error('Error counting users:', error);
      throw error;
    }
  }

  static async update(id, updateData) {
    try {
      const fields = [];
      const params = [];
      
      // Build SET clause
      if (updateData.username) {
        fields.push('username = ?');
        params.push(updateData.username);
      }
      
      if (updateData.assigned_category !== undefined) {
        fields.push('assigned_category = ?');
        params.push(updateData.assigned_category);
      }
      
      if (updateData.role) {
        fields.push('role = ?');
        params.push(updateData.role);
      }
      
      if (updateData.status) {
        fields.push('status = ?');
        params.push(updateData.status);
      }


      if (updateData.password_hash) {
        fields.push('password_hash = ?');
        params.push(updateData.password_hash);
      }
      
      if (updateData.blocked_at !== undefined) {
        fields.push('blocked_at = ?');
        params.push(updateData.blocked_at);
      }
      
      if (updateData.blocked_by !== undefined) {
        fields.push('blocked_by = ?');
        params.push(updateData.blocked_by);
      }
      
      if (updateData.block_reason !== undefined) {
        fields.push('block_reason = ?');
        params.push(updateData.block_reason);
      }
      
      if (updateData.deleted_at !== undefined) {
        fields.push('deleted_at = ?');
        params.push(updateData.deleted_at);
      }
      
      if (updateData.deleted_by !== undefined) {
        fields.push('deleted_by = ?');
        params.push(updateData.deleted_by);
      }
      
      if (updateData.unblocked_at !== undefined) {
        fields.push('unblocked_at = ?');
        params.push(updateData.unblocked_at);
      }
      
      if (updateData.unblocked_by !== undefined) {
        fields.push('unblocked_by = ?');
        params.push(updateData.unblocked_by);
      }
      
      // Always update updated_at
      fields.push('updated_at = NOW()');
      
      if (fields.length === 1) { // Only updated_at
        throw new Error('No fields to update');
      }
      
      params.push(id);
      
      const query = `UPDATE users SET ${fields.join(', ')} WHERE id = ?`;
      await executeQuery(query, params);
      
      // Return updated user
      return await this.findById(id);
    } catch (error) {
      logger.error('Error updating user:', error);
      throw error;
    }
  }

  static async findByIdIncludeInactive(id) {
    try {
      const query = 'SELECT id, username, role, status, assigned_category, created_at, updated_at, blocked_at, blocked_by, block_reason FROM users WHERE id = ?';
      const result = await executeQuery(query, [id]);
      return result[0] || null;
    } catch (error) {
      logger.error('Error finding user by ID (include inactive):', error);
      throw error;
    }
  }

  static async checkUsernameExists(username, excludeId = null) {
    try {
      let query = 'SELECT id FROM users WHERE username = ?';
      const params = [username];
      
      if (excludeId) {
        query += ' AND id != ?';
        params.push(excludeId);
      }
      
      const result = await executeQuery(query, params);
      return result.length > 0;
    } catch (error) {
      logger.error('Error checking username exists:', error);
      throw error;
    }
  }

  static async bulkUpdate(whereConditions, updateData) {
    try {
      const fields = [];
      const params = [];
      
      // Build SET clause
      if (updateData.status) {
        fields.push('status = ?');
        params.push(updateData.status);
      }
      
      if (updateData.deleted_at !== undefined) {
        fields.push('deleted_at = ?');
        params.push(updateData.deleted_at);
      }
      
      if (updateData.deleted_by !== undefined) {
        fields.push('deleted_by = ?');
        params.push(updateData.deleted_by);
      }
      
      if (updateData.blocked_at !== undefined) {
        fields.push('blocked_at = ?');
        params.push(updateData.blocked_at);
      }
      
      if (updateData.blocked_by !== undefined) {
        fields.push('blocked_by = ?');
        params.push(updateData.blocked_by);
      }
      
      if (updateData.block_reason !== undefined) {
        fields.push('block_reason = ?');
        params.push(updateData.block_reason);
      }
      
      // Always update updated_at
      fields.push('updated_at = NOW()');
      
      if (fields.length === 1) { // Only updated_at
        throw new Error('No fields to update');
      }
      
      // Build WHERE clause
      const whereConditionsList = [];
      
      if (whereConditions.role && Array.isArray(whereConditions.role)) {
        const placeholders = whereConditions.role.map(() => '?').join(', ');
        whereConditionsList.push(`role IN (${placeholders})`);
        params.push(...whereConditions.role);
      } else if (whereConditions.role) {
        whereConditionsList.push('role = ?');
        params.push(whereConditions.role);
      }
      
      if (whereConditions.status) {
        whereConditionsList.push('status = ?');
        params.push(whereConditions.status);
      }
      
      // Exclude admin users from bulk operations
      whereConditionsList.push('role != ?');
      params.push('admin');
      
      const whereClause = whereConditionsList.length > 0 ? 'WHERE ' + whereConditionsList.join(' AND ') : '';
      
      const query = `UPDATE users SET ${fields.join(', ')} ${whereClause}`;
      const result = await executeQuery(query, params);
      
      return result.affectedRows;
    } catch (error) {
      logger.error('Error bulk updating users:', error);
      throw error;
    }
  }

  static async delete(id) {
    try {
      const query = 'DELETE FROM users WHERE id = ?';
      const result = await executeQuery(query, [id]);
      return result.affectedRows > 0;
    } catch (error) {
      logger.error('Error deleting user:', error);
      throw error;
    }
  }

  static async bulkDelete(whereConditions) {
    try {
      const whereConditionsList = [];
      const params = [];
      
      // Build WHERE conditions
      if (whereConditions.role && Array.isArray(whereConditions.role)) {
        const placeholders = whereConditions.role.map(() => '?').join(', ');
        whereConditionsList.push(`role IN (${placeholders})`);
        params.push(...whereConditions.role);
      }
      
      // Always exclude admin users from bulk delete
      whereConditionsList.push('role != ?');
      params.push('admin');
      
      const whereClause = whereConditionsList.length > 0 ? 'WHERE ' + whereConditionsList.join(' AND ') : '';
      
      const query = `DELETE FROM users ${whereClause}`;
      const result = await executeQuery(query, params);
      
      return result.affectedRows;
    } catch (error) {
      logger.error('Error bulk deleting users:', error);
      throw error;
    }
  }
}

module.exports = UserModel;