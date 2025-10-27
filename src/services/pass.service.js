const PassModel = require('../models/pass.model');
const CategoriesModel = require('../models/categories.model');
const DailyLogsService = require('./daily-logs.service');
const { executeQuery } = require('../config/db');
const redisService = require('./redis.service');
const logger = require('../utils/logger');
const { formatDateForDB } = require('../utils/validators');

class PassService {
  async createPass(passData, createdBy) {
    try {
      // Check if UID exists in database first (excluding deleted)
      const existingPass = await PassModel.findByUid(passData.uid);
      if (existingPass) {
        // Log duplicate creation attempt
        const duplicateLogData = {
          action_type: 'create_pass',
          user_id: createdBy?.id || null,
          role: createdBy?.role || null,
          pass_id: null,
          uid: passData.uid,
          scanned_at: new Date(),
          scanned_by: null,
          remaining_uses: null,
          consumed_count: null,
          category: passData.category || null,
          pass_type: passData.pass_type || null,
          ip_address: null,
          user_agent: null,
          details: JSON.stringify({
            message: 'Duplicate pass creation attempted',
            uid: passData.uid,
            existing_pass_id: existingPass.id,
            existing_status: existingPass.status,
            user: createdBy ? `${createdBy.username} (${createdBy.role})` : 'Unknown',
            attempt_time: new Date().toISOString()
          }),
          result: 'failure',
          error_message: `Pass with UID ${passData.uid} already exists`
        };
        
        try {
          await DailyLogsService.insertLog(duplicateLogData);
          logger.info(`Duplicate creation attempt logged: UID=${passData.uid}, User=${createdBy?.username}`);
        } catch (logError) {
          logger.error('Failed to log duplicate creation attempt:', logError);
        }
        
        const error = new Error(`Pass with UID ${passData.uid} already exists`);
        error.code = 'DUPLICATE_UID';
        error.statusCode = 409;
        throw error;
      }

      // Check Redis cache for stale data and clean if necessary
      const cachedPass = await redisService.getActivePass(passData.uid);
      if (cachedPass) {
        logger.warn(`Found stale cache data for UID ${passData.uid}, removing...`);
        await redisService.removeActivePass(passData.uid);
        await redisService.removeBlockedPass(passData.uid);
      }

      // Format pass data
      const formattedData = {
        ...passData,
        created_by: createdBy,
        valid_from: passData.valid_from ? formatDateForDB(passData.valid_from) : null,
        valid_to: passData.valid_to ? formatDateForDB(passData.valid_to) : null
      };

      // Create pass in database (model will handle duplicate UID errors)
      const newPass = await PassModel.create(formattedData);

      // Add to Redis cache if active
      if (newPass.status === 'active') {
        await redisService.addActivePass(newPass.uid, newPass);
      }

      // Log successful pass creation
      const creationLogData = {
        action_type: 'create_pass',
        user_id: createdBy?.id || null,
        role: createdBy?.role || null,
        pass_id: newPass.pass_id || null,
        uid: newPass.uid,
        scanned_at: new Date(),
        scanned_by: null,
        remaining_uses: newPass.max_uses,
        consumed_count: 0,
        category: newPass.category || null,
        pass_type: newPass.pass_type || null,
        ip_address: null,
        user_agent: null,
        details: JSON.stringify({
          message: 'Pass created successfully',
          pass_id: newPass.pass_id,
          uid: newPass.uid,
          category: newPass.category,
          pass_type: newPass.pass_type,
          max_uses: newPass.max_uses,
          people_allowed: newPass.people_allowed,
          status: newPass.status,
          user: createdBy ? `${createdBy.username} (${createdBy.role})` : 'Unknown',
          creation_time: new Date().toISOString()
        }),
        result: 'success',
        error_message: null
      };
      
      try {
        await DailyLogsService.insertLog(creationLogData);
        logger.info(`Pass creation logged: UID=${newPass.uid}, User=${createdBy?.username}`);
      } catch (logError) {
        logger.error('Failed to log pass creation:', logError);
      }

      logger.info(`Pass created: UID=${newPass.uid}, ID=${newPass.id}`);
      return newPass;
    } catch (error) {
      // Re-throw the error with proper code if it's a duplicate UID
      if (error.code === 'DUPLICATE_UID') {
        logger.warn(`Duplicate UID attempted: ${passData.uid}`);
      } else {
        logger.error('Error creating pass:', error);
      }
      throw error;
    }
  }

  async createBulkPasses(passesData, createdBy) {
    try {
      const results = {
        total: passesData.length,
        created: 0,
        duplicates: 0,
        errors: []
      };

      // Check for duplicates in the batch
      const uids = passesData.map(p => p.uid);
      const uniqueUids = [...new Set(uids)];
      if (uids.length !== uniqueUids.length) {
        throw new Error('Duplicate UIDs found in the batch');
      }

      // Check for existing UIDs in database
      const existingChecks = await Promise.all(
        uids.map(uid => PassModel.isUidExists(uid))
      );
      
      const validPasses = [];
      for (let i = 0; i < passesData.length; i++) {
        if (existingChecks[i]) {
          results.duplicates++;
          results.errors.push({
            uid: passesData[i].uid,
            error: 'UID already exists'
          });
        } else {
          validPasses.push({
            ...passesData[i],
            created_by: createdBy
          });
        }
      }

      if (validPasses.length > 0) {
        // Create passes in database
        const createdPasses = await PassModel.createBulk(validPasses);
        results.created = createdPasses.length;

        // Add active passes to Redis cache
        const activePassPromises = validPasses
          .filter(pass => pass.status === 'active' || !pass.status)
          .map(async (pass) => {
            try {
              const fullPass = await PassModel.findByUid(pass.uid);
              if (fullPass) {
                await redisService.addActivePass(pass.uid, fullPass);
              }
            } catch (error) {
              logger.error(`Failed to add pass ${pass.uid} to Redis:`, error);
            }
          });

        await Promise.allSettled(activePassPromises);
        
        // Log bulk creation
        const bulkLogData = {
          action_type: 'bulk_create_pass',
          user_id: createdBy?.id || null,
          role: createdBy?.role || null,
          pass_id: null,
          uid: null, // No single UID for bulk operations
          scanned_at: new Date(),
          scanned_by: null,
          remaining_uses: null,
          consumed_count: null,
          category: null,
          pass_type: null,
          ip_address: null,
          user_agent: null,
          details: JSON.stringify({
            message: 'Bulk pass creation completed',
            total_attempted: results.total,
            successful_creations: results.created,
            duplicates_found: results.duplicates,
            created_uids: validPasses.map(p => p.uid),
            duplicate_uids: results.errors.map(e => e.uid),
            user: createdBy ? `${createdBy.username} (${createdBy.role})` : 'Unknown',
            creation_time: new Date().toISOString()
          }),
          result: results.created > 0 ? 'success' : 'failure',
          error_message: results.duplicates > 0 ? `${results.duplicates} duplicate UIDs found` : null
        };
        
        try {
          await DailyLogsService.insertLog(bulkLogData);
          logger.info(`Bulk creation logged: ${results.created} created, ${results.duplicates} duplicates, User=${createdBy?.username}`);
        } catch (logError) {
          logger.error('Failed to log bulk creation:', logError);
        }
      }

      logger.info(`Bulk pass creation: ${results.created}/${results.total} created, ${results.duplicates} duplicates`);
      return results;
    } catch (error) {
      logger.error('Error creating bulk passes:', error);
      throw error;
    }
  }

  async createBulkPassesNFC(passesData, createdBy) {
    try {
      const results = {
        total: passesData.length,
        created: 0,
        duplicates: 0,
        errors: [],
        successful_uids: [],
        duplicate_uids: []
      };

      // Process each pass individually to handle duplicates gracefully
      for (const passData of passesData) {
        try {
          // Check if UID already exists
          const existingPass = await PassModel.findByUid(passData.uid);
          if (existingPass) {
            results.duplicates++;
            results.duplicate_uids.push(passData.uid);
            results.errors.push({
              uid: passData.uid,
              error: 'UID already exists',
              existing_pass_id: existingPass.pass_id
            });
            continue;
          }

          // Create the pass
          const newPass = await this.createPass(passData, createdBy);
          results.created++;
          results.successful_uids.push(passData.uid);
          
          // Log individual pass creation for audit trail
          logger.info('Bulk Pass Creation - Individual Pass', {
            action: 'BULK_PASS_CREATE_INDIVIDUAL',
            pass_id: newPass.pass_id,
            uid: newPass.uid,
            pass_type: newPass.pass_type,
            category: newPass.category,
            people_allowed: newPass.people_allowed,
            max_uses: newPass.max_uses,
            created_by: createdBy,
            bulk_operation: true,
            timestamp: new Date().toISOString()
          });
          
          // Emit socket event for real-time updates
          const io = require('../server').io;
          if (io) {
            io.emit('pass:created', {
              uid: newPass.uid,
              pass_id: newPass.pass_id,
              pass_type: newPass.pass_type,
              category: newPass.category,
              created_by: createdBy,
              timestamp: new Date().toISOString()
            });
          }
          
        } catch (error) {
          if (error.code === 'DUPLICATE_UID') {
            results.duplicates++;
            results.duplicate_uids.push(passData.uid);
            results.errors.push({
              uid: passData.uid,
              error: 'UID already exists'
            });
          } else {
            results.errors.push({
              uid: passData.uid,
              error: error.message
            });
          }
        }
      }

      logger.info(`NFC Bulk pass creation: ${results.created}/${results.total} created, ${results.duplicates} duplicates`);
      return results;
    } catch (error) {
      logger.error('Error creating bulk passes via NFC:', error);
      throw error;
    }
  }

  async deletePass(passId, deletedBy) {
    try {
      const pass = await PassModel.findById(passId);
      if (!pass) {
        throw new Error('Pass not found');
      }

      // Soft delete the pass
      const deletedPass = await PassModel.softDelete(passId);

      // Remove from Redis caches completely
      await redisService.removeActivePass(pass.uid);
      await redisService.removeBlockedPass(pass.uid);
      
      // Also clear any verification locks for this UID
      try {
        await redisService.releaseVerifyLock(pass.uid);
      } catch (lockError) {
        logger.warn(`Could not release verify lock for ${pass.uid}:`, lockError);
      }

      logger.info(`Pass deleted and cache cleared: UID=${pass.uid}, ID=${passId}, DeletedBy=${deletedBy}`);
      return deletedPass;
    } catch (error) {
      logger.error('Error deleting pass:', error);
      throw error;
    }
  }

  async blockPass(passId, blockedBy) {
    try {
      const pass = await PassModel.findById(passId);
      if (!pass) {
        throw new Error('Pass not found');
      }

      if (pass.status === 'deleted') {
        throw new Error('Cannot block a deleted pass');
      }

      // Update pass status to blocked
      const blockedPass = await PassModel.updateStatus(passId, 'blocked');

      // Update Redis caches
      await redisService.removeActivePass(pass.uid);
      await redisService.addBlockedPass(pass.uid);

      logger.info(`Pass blocked: UID=${pass.uid}, ID=${passId}, BlockedBy=${blockedBy}`);
      return {
        pass: blockedPass,
        event: {
          type: 'pass:blocked',
          data: {
            uid: pass.uid,
            pass_id: pass.pass_id,
            blocked_by: blockedBy,
            timestamp: new Date().toISOString()
          }
        }
      };
    } catch (error) {
      logger.error('Error blocking pass:', error);
      throw error;
    }
  }

  async unblockPass(passId, unblockedBy) {
    try {
      const pass = await PassModel.findById(passId);
      if (!pass) {
        throw new Error('Pass not found');
      }

      if (pass.status !== 'blocked') {
        throw new Error('Pass is not currently blocked');
      }

      // Update pass status to active
      const unblockedPass = await PassModel.updateStatus(passId, 'active');

      // Update Redis caches
      await redisService.removeBlockedPass(pass.uid);
      await redisService.addActivePass(pass.uid, unblockedPass);

      logger.info(`Pass unblocked: UID=${pass.uid}, ID=${passId}, UnblockedBy=${unblockedBy}`);
      return {
        pass: unblockedPass,
        event: {
          type: 'pass:unblocked',
          data: {
            uid: pass.uid,
            pass_id: pass.pass_id,
            unblocked_by: unblockedBy,
            timestamp: new Date().toISOString()
          }
        }
      };
    } catch (error) {
      logger.error('Error unblocking pass:', error);
      throw error;
    }
  }

  async resetPass(passId, resetBy, reason = null) {
    try {
      const pass = await PassModel.findById(passId);
      if (!pass) {
        throw new Error('Pass not found');
      }

      // Allow resetting if:
      // 1. Pass status is 'used' (for daily passes)
      // 2. Pass is fully consumed (used_count >= max_uses) regardless of type
      // 3. Pass is blocked (we can reset usage counts for blocked passes)
      // Check if pass is deleted first
      if (pass.status === 'deleted') {
        throw new Error('Cannot reset a deleted pass');
      }

      const isUsedPass = pass.status === 'used';
      const isFullyConsumed = pass.used_count >= (pass.max_uses || 1);
      const isBlockedPass = pass.status === 'blocked';
      
      if (!isUsedPass && !isFullyConsumed && !isBlockedPass) {
        {
          throw new Error('Only used passes can be reset');
        }
      }

      // Update pass and reset usage counts while preserving blocked status
      let resetPass;
      let newStatus;
      
      if (isBlockedPass) {
        // For blocked passes, reset usage counts but keep blocked status
        newStatus = 'blocked';
      } else {
        // For daily passes, reset to active status
        newStatus = 'active';
      }

      // Reset usage counts and update status appropriately
      await PassModel.updateStatus(passId, newStatus);
      const query = 'UPDATE passes SET used_count = 0, updated_at = NOW() WHERE id = ?';
      await executeQuery(query, [passId]);
      resetPass = await PassModel.findById(passId);

      // Update Redis cache - only add to active cache if not blocked
      if (newStatus !== 'blocked') {
        await redisService.addActivePass(pass.uid, resetPass);
      } else {
        // For blocked passes, remove from active cache but don't add to blocked cache
        // as the pass should remain visible in the list but not usable
        await redisService.removeActivePass(pass.uid);
      }

      logger.info(`Pass reset: UID=${pass.uid}, ID=${passId}, ResetBy=${resetBy}, Reason=${reason}, NewStatus=${newStatus}`);
      return {
        pass: resetPass,
        event: {
          type: 'pass:reset',
          data: {
            uid: pass.uid,
            pass_id: pass.pass_id,
            reset_by: resetBy,
            reason: reason,
            new_status: newStatus,
            timestamp: new Date().toISOString()
          }
        }
      };
    } catch (error) {
      logger.error('Error resetting pass:', error);
      throw error;
    }
  }

  async findPassByUID(uid) {
    try {
      const pass = await PassModel.findByUid(uid);
      if (!pass) {
        return null;
      }

      // Check Redis cache first for active passes
      const cachedPass = await redisService.getActivePass(uid);
      if (cachedPass) {
        return cachedPass;
      }

      // If not in cache but exists in DB, add to cache if active
      if (pass.status === 'active') {
        await redisService.addActivePass(uid, pass);
      }

      return pass;
    } catch (error) {
      logger.error('Error finding pass by UID:', error);
      throw error;
    }
  }

  async findPassByUIDWithUsage(uid) {
    try {
      const query = `
        SELECT p.*, u.username as created_by_username,
               COALESCE(p.max_uses, 1) as max_uses,
               COALESCE(p.used_count, 0) as used_count,
               (COALESCE(p.max_uses, 1) - COALESCE(p.used_count, 0)) as remaining_uses
        FROM passes p
        LEFT JOIN users u ON p.created_by = u.id
        WHERE p.uid = ? AND p.status != 'deleted'
      `;
      
      const result = await executeQuery(query, [uid]);
      return result.length > 0 ? result[0] : null;
    } catch (error) {
      logger.error('Error finding pass by UID with usage:', error);
      throw error;
    }
  }

  async getAllPassesWithPagination(filters = {}, pagination = {}) {
    try {
      const { page = 1, limit = 20 } = pagination;
      const offset = (page - 1) * limit;
      
      let whereConditions = [];
      let queryParams = [];
      
      // Build WHERE conditions
      if (filters.status) {
        whereConditions.push('p.status = ?');
        queryParams.push(filters.status);
      } else {
        whereConditions.push('p.status != ?');
        queryParams.push('deleted');
      }
      
      if (filters.pass_type) {
        whereConditions.push('p.pass_type = ?');
        queryParams.push(filters.pass_type);
      }
      
      if (filters.category) {
        whereConditions.push('p.category = ?');
        queryParams.push(filters.category);
      }
      
      if (filters.created_by) {
        whereConditions.push('p.created_by = ?');
        queryParams.push(filters.created_by);
      }
      
      if (filters.uid) {
        whereConditions.push('p.uid LIKE ?');
        queryParams.push(`%${filters.uid}%`);
      }
      
      if (filters.pass_id) {
        whereConditions.push('p.pass_id LIKE ?');
        queryParams.push(`%${filters.pass_id}%`);
      }
      
      if (filters.search) {
        whereConditions.push('(p.uid LIKE ? OR p.pass_id LIKE ? OR p.category LIKE ? OR p.pass_type LIKE ? OR p.status LIKE ? OR u.username LIKE ?)');
        queryParams.push(`%${filters.search}%`, `%${filters.search}%`, `%${filters.search}%`, `%${filters.search}%`, `%${filters.search}%`, `%${filters.search}%`);
      }
      
      const whereClause = whereConditions.length > 0 ? 'WHERE ' + whereConditions.join(' AND ') : '';
      
      // Count total records - include JOIN for search functionality
      const countQuery = `
        SELECT COUNT(*) as total
        FROM passes p
        LEFT JOIN users u ON p.created_by = u.id
        ${whereClause}
      `;
      
      const countResult = await executeQuery(countQuery, queryParams);
      const total = countResult[0].total;
      
      // Get paginated results - use string interpolation for LIMIT/OFFSET
      const limitValue = parseInt(limit);
      const offsetValue = parseInt(offset);
      
      const dataQuery = `
        SELECT p.*, u.username as created_by_username,
               COALESCE(p.max_uses, 1) as max_uses,
               COALESCE(p.used_count, 0) as used_count,
               (COALESCE(p.max_uses, 1) - COALESCE(p.used_count, 0)) as remaining_uses
        FROM passes p
        LEFT JOIN users u ON p.created_by = u.id
        ${whereClause}
        ORDER BY p.created_at DESC
        LIMIT ${limitValue} OFFSET ${offsetValue}
      `;
      
      const passes = await executeQuery(dataQuery, queryParams);
      
      return {
        passes,
        total,
        page,
        limit,
        totalPages: Math.ceil(total / limit)
      };
    } catch (error) {
      logger.error('Error getting passes with pagination:', error);
      throw error;
    }
  }

  async getRecentLogsForPass(uid, limit = 10) {
    try {
      const { getDailyLogTableName, tableExists } = require('../config/db');
      const logs = [];
      const today = new Date();
      
      for (let i = 0; i < 30; i++) {
        const date = new Date(today);
        date.setDate(date.getDate() - i);
        const dateStr = date.toISOString().split('T')[0];
        const tableName = getDailyLogTableName(dateStr);
        
        try {
          // Check if table exists before querying
          const exists = await tableExists(tableName);
          if (!exists) {
            continue;
          }
          
          const remaining = Math.max(0, limit - logs.length);
          if (remaining === 0) {
            break;
          }
          const query = `
            SELECT * FROM ${tableName}
            WHERE uid = ?
            ORDER BY created_at DESC
            LIMIT ${Number(remaining)}
          `;
          const dayLogs = await executeQuery(query, [uid]);
          logs.push(...dayLogs);
          
          if (logs.length >= limit) {
            break;
          }
        } catch (tableError) {
          // Log the specific error but continue with other tables
          logger.warn(`Error querying table ${tableName}: ${tableError.message}`);
          continue;
        }
      }
      
      // Sort by timestamp descending (fallback to created_at) and return limited results
      return logs
        .sort((a, b) => new Date(b.created_at) - new Date(a.created_at))
        .slice(0, limit);
    } catch (error) {
      logger.error('Error getting recent logs for pass:', error);
      return [];
    }
  }

  async getPassDetails(passId) {
    try {
      const pass = await PassModel.findById(passId);
      if (!pass) {
        throw new Error('Pass not found');
      }

      // Get recent logs for this pass (last 7 days)
      const recentLogs = await this.getPassRecentLogs(pass.uid, 7);

      return {
        ...pass,
        recent_logs: recentLogs
      };
    } catch (error) {
      logger.error('Error getting pass details:', error);
      throw error;
    }
  }

  async getPassRecentLogs(uid, days = 7) {
    try {
      const { executeQuery, getDailyLogTableName, tableExists } = require('../config/db');
      const logs = [];
      
      // Get logs from the last N days
      for (let i = 0; i < days; i++) {
        const date = new Date();
        date.setDate(date.getDate() - i);
        const dateStr = date.toISOString().split('T')[0];
        const tableName = getDailyLogTableName(dateStr);
        
        const exists = await tableExists(tableName);
        if (exists) {
          const query = `
            SELECT * FROM ${tableName} 
            WHERE uid = ? 
            ORDER BY created_at DESC 
            LIMIT 10
          `;
          const dayLogs = await executeQuery(query, [uid]);
          logs.push(...dayLogs);
        }
      }

      // Sort by timestamp descending and limit to 20 most recent
      return logs
        .sort((a, b) => new Date(b.created_at) - new Date(a.created_at))
        .slice(0, 20);
    } catch (error) {
      logger.error('Error getting pass recent logs:', error);
      return [];
    }
  }

  async getCompleteUsageHistory(uid) {
    try {
      const { executeQuery, getDailyLogTableName, tableExists } = require('../config/db');
      const logs = [];
      
      // Get logs from the last 90 days (comprehensive history)
      for (let i = 0; i < 90; i++) {
        const date = new Date();
        date.setDate(date.getDate() - i);
        const dateStr = date.toISOString().split('T')[0];
        const tableName = getDailyLogTableName(dateStr);
        
        const exists = await tableExists(tableName);
        if (exists) {
          const query = `
            SELECT 
              l.*,
              u.username as verified_by_username,
              u.role as verified_by_role,
              'Unknown' as location
            FROM ${tableName} l
            LEFT JOIN users u ON l.scanned_by = u.id
            WHERE l.uid = ? 
            ORDER BY l.created_at DESC
          `;
          const dayLogs = await executeQuery(query, [uid]);
          logs.push(...dayLogs);
        }
      }

      // Sort by timestamp descending (latest first)
      const sortedLogs = logs
        .sort((a, b) => new Date(b.created_at) - new Date(a.created_at))
        .map(log => ({
          id: log.id,
          scanned_at: log.scanned_at || log.created_at,
          verified_by: log.verified_by_username || 'Unknown',
          verified_by_role: log.verified_by_role || 'Unknown',
          location: log.location || 'Unknown Location',
          people_count: log.people_count || 1,
          status: log.status || 'success',
          device_info: log.device_info || null,
          notes: log.notes || null
        }));

      return sortedLogs;
    } catch (error) {
      logger.error('Error getting complete usage history:', error);
      return [];
    }
  }

  async getAllPasses(filters = {}, pagination = {}) {
    try {
      const passes = await PassModel.getAllPasses({ ...filters, ...pagination });
      return passes;
    } catch (error) {
      logger.error('Error getting all passes:', error);
      throw error;
    }
  }

  async getPassStats() {
    try {
      const stats = await PassModel.getPassStats();
      const cacheStats = await redisService.getCacheStats();
      
      return {
        database: stats,
        cache: cacheStats
      };
    } catch (error) {
      logger.error('Error getting pass stats:', error);
      throw error;
    }
  }

  async resetAllPasses(resetBy, reason = null) {
    try {
      logger.info(`Starting reset all passes by user ${resetBy}, reason: ${reason}`);
      
      // Get count of passes that will be reset before executing
      const countQuery = `
        SELECT COUNT(*) as count 
        FROM passes 
        WHERE (status = 'used' OR used_count >= COALESCE(max_uses, 1)) 
        AND status != 'deleted'
      `;
      const countResult = await executeQuery(countQuery);
      const resetCount = countResult[0].count;
      
      // Reset all passes (not just daily) - remove daily restriction
      const resetQuery = `
        UPDATE passes 
        SET status = CASE 
          WHEN status = 'blocked' THEN 'blocked'
          ELSE 'active'
        END,
        used_count = 0, 
        updated_at = CURRENT_TIMESTAMP 
        WHERE (status = 'used' OR used_count >= COALESCE(max_uses, 1)) 
        AND status != 'deleted'
      `;
      
      await executeQuery(resetQuery);
      
      // Rebuild Redis cache to reflect the reset
      await redisService.rebuildAllCaches();
      
      logger.info(`Reset all passes completed: ${resetCount} passes reset`);
      
      return {
        reset_count: resetCount,
        reset_by: resetBy,
        reason: reason,
        timestamp: new Date().toISOString()
      };
    } catch (error) {
      logger.error('Error resetting all passes:', error);
      throw error;
    }
  }

  async validatePassData(passData) {
    const errors = [];

    // Validate UID format
    if (!/^[a-zA-Z0-9]{4,128}$/.test(passData.uid)) {
      errors.push('UID must be 4-128 alphanumeric characters');
    }

    // Validate pass type
    if (!['daily', 'seasonal', 'unlimited'].includes(passData.pass_type)) {
      errors.push('Pass type must be daily, seasonal, or unlimited');
    }

    // Validate people allowed
    if (passData.people_allowed < 1 || passData.people_allowed > 100) {
      errors.push('People allowed must be between 1 and 100');
    }

    // Validate category - just use category name directly
    if (!passData.category) {
      errors.push('Category is required');
    }

    // Validate date range for passes that have dates
    if (passData.valid_from && passData.valid_to) {
      const fromDate = new Date(passData.valid_from);
      const toDate = new Date(passData.valid_to);
      
      if (fromDate >= toDate) {
        errors.push('Valid from date must be before valid to date');
      }
    }

    return errors;
  }
}

module.exports = new PassService();