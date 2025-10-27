const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { getRedisClient } = require('../config/redis');
const { executeQuery, getDailyLogTableName, createDailyLogTable, tableExists, getDB } = require('../config/db');
const PassModel = require('../models/pass.model');
const DailyLogsService = require('./daily-logs.service');
const redisService = require('./redis.service');
const logger = require('../utils/logger');
const { getCurrentDate, getCurrentDateTime } = require('../utils/validators');

class VerifyService {
  constructor() {
    this.luaScript = null;
    this.loadLuaScript();
  }

  loadLuaScript() {
    try {
      const scriptPath = path.join(__dirname, '../utils/lock.lua');
      this.luaScript = fs.readFileSync(scriptPath, 'utf8');
      logger.info('Lua script loaded successfully');
    } catch (error) {
      logger.error('Failed to load Lua script:', error);
      throw error;
    }
  }

  async verifyPass(uid, scannedBy, deviceLocalId = null) {
    const startTime = Date.now();
    let logResult = 'invalid';
    let passInfo = null;
    
    try {
      // Step 1: Check if pass is blocked in Redis
      const isBlocked = await redisService.isPassBlocked(uid);
      if (isBlocked) {
        // Get pass details even for blocked passes
        const pass = await this.getPassWithUsage(uid);
        logResult = 'blocked';
        await this.logVerification(uid, pass?.pass_id || null, scannedBy, logResult, deviceLocalId);
        
        const response = {
          success: false,
          status: 'blocked',
          message: 'This pass is blocked',
          uid,
          scanned_by: scannedBy,
          timestamp: getCurrentDateTime(),
          processing_time_ms: Date.now() - startTime
        };
        
        // Include pass details if available
        if (pass) {
          response.pass_info = {
            pass_id: pass.pass_id,
            category: pass.category,
            pass_type: pass.pass_type,
            people_allowed: pass.people_allowed,
            max_uses: pass.max_uses,
            used_count: pass.used_count,
            remaining_uses: pass.max_uses - pass.used_count,
            last_scan_at: null // Field removed
          };
        }
        
        return response;
      }

      // Step 2: Fetch pass by UID (Redis or DB)
      const pass = await this.getPassWithUsage(uid);
      
      if (!pass) {
        logResult = 'invalid';
        await this.logVerification(uid, null, scannedBy, logResult, deviceLocalId);
        return {
          success: false,
          status: 'invalid',
          message: 'Pass not found',
          uid,
          scanned_by: scannedBy,
          timestamp: getCurrentDateTime(),
          processing_time_ms: Date.now() - startTime
        };
      }

      passInfo = {
        pass_id: pass.pass_id,
        pass_db_id: pass.id,
        people_allowed: pass.people_allowed,
        category: pass.category,
        category_name: pass.category_name,
        pass_type: pass.pass_type,
        max_uses: pass.max_uses,
        used_count: pass.used_count,
        remaining_uses: pass.max_uses - pass.used_count,
        last_scan_at: null // Field removed
      };

      logger.info(`Pass info created for UID=${uid}: pass_type=${passInfo.pass_type}, max_uses=${passInfo.max_uses}, used_count=${passInfo.used_count}, remaining_uses=${passInfo.remaining_uses}`);

      // Step 2.5: Check if bouncer is authorized for this category
      if (scannedBy && scannedBy.role === 'bouncer') {
        const bouncer = await this.getBouncerDetails(scannedBy.id);
        if (bouncer && bouncer.assigned_category) {
          // Bouncer can verify: their assigned category only
          const isAssignedCategory = bouncer.assigned_category === pass.category;
          
          if (!isAssignedCategory) {
            logResult = 'unauthorized';
            await this.logVerification(uid, pass.pass_id, scannedBy, logResult, deviceLocalId, {
              pass_category: pass.category,
              bouncer_assigned_category: bouncer.assigned_category,
              verification_attempt: 'category_mismatch'
            });
            return {
              success: false,
              status: 'unauthorized',
              message: `You are not authorized to verify this category. This pass is for ${pass.category} category, but you are assigned to ${bouncer.assigned_category} category.`,
              uid,
              scanned_by: scannedBy,
              pass_category: pass.category,
              bouncer_assigned_category: bouncer.assigned_category,
              timestamp: getCurrentDateTime(),
              processing_time_ms: Date.now() - startTime
            };
          }
        }
      }

      logger.debug(`Pass info for UID=${uid}: type=${pass.pass_type}, remaining_uses=${passInfo.remaining_uses}`);

      // Step 3: Check for unlimited pass type - unlimited verification
      if (passInfo.pass_type === 'unlimited') {
        // Unlimited passes have unlimited usage - just log and return success
        logResult = 'valid';
        
        // Update scan tracking for unlimited passes
        await this.updateScanTracking(pass.id, scannedBy.id);
        
        await this.logVerification(uid, pass.pass_id, scannedBy, logResult, deviceLocalId, {
          remaining_uses: 'unlimited',
          consumed_count: 0, // Don't increment for unlimited passes
          unlimited_pass: true
        });
        
        // Update Redis cache with latest pass info
        try {
          await redisService.addActivePass(uid, pass);
        } catch (cacheError) {
          logger.warn('Failed to update Redis cache for unlimited pass:', cacheError);
        }
        
        return {
          success: true,
          status: 'valid',
          message: 'Unlimited pass verified successfully',
          uid,
          scanned_by: scannedBy,
          remaining_uses: 'unlimited',
          pass_info: {
            pass_id: pass.pass_id,
            category: pass.category,
            category_name: pass.category_name,
            pass_type: pass.pass_type,
            people_allowed: pass.people_allowed,
            max_uses: 'unlimited',
            used_count: pass.used_count, // Don't increment for unlimited passes
            remaining_uses: 'unlimited',
            last_used_at: getCurrentDateTime(),
            last_used_by: scannedBy,
            unlimited_pass: true
          },
          timestamp: getCurrentDateTime(),
          processing_time_ms: Date.now() - startTime
        };
      }

      // Step 4: Check if pass has remaining uses (for non-unlimited passes)
      if (passInfo.remaining_uses <= 0) {
        logResult = 'used';
        await this.logVerification(uid, pass.pass_id, scannedBy, logResult, deviceLocalId, {
          remaining_uses: 0
        });
        
        // Get the actual last used timestamp from verification logs
        const lastUsedTimestamp = await this.getLastUsedTimestamp(uid);
        
        return {
          success: false,
          status: 'used',
          message: `This pass has already been used. Remaining uses: 0`,
          uid,
          scanned_by: scannedBy,
          remaining_uses: 0,
          pass_info: {
            pass_id: pass.pass_id,
            category: pass.category,
            pass_type: pass.pass_type,
            people_allowed: pass.people_allowed,
            max_uses: pass.max_uses,
            used_count: pass.used_count,
            remaining_uses: 0,
            last_scan_at: null, // Field removed
            last_used_at: lastUsedTimestamp || null
          },
          timestamp: getCurrentDateTime(),
          processing_time_ms: Date.now() - startTime
        };
      }

      // Step 5: Check for seasonal pass 15-minute rule (similar to session pass logic)
      if (passInfo.pass_type === 'seasonal') {
        logger.info(`Seasonal pass detected for UID=${uid}`);
        const lastUsedAt = await this.getLastUsedTimestamp(uid);
        logger.info(`Last used timestamp for UID=${uid}: ${lastUsedAt}`);
        
        if (lastUsedAt) {
          const lastUsedTime = new Date(lastUsedAt);
          const currentTime = new Date();
          const timeDiff = currentTime - lastUsedTime;
          const fifteenMinutes = 15 * 60 * 1000; // 15 minutes in milliseconds
          
          logger.info(`Time difference for UID=${uid}: ${timeDiff}ms, Fifteen minutes: ${fifteenMinutes}ms`);
          
          // If last used within 15 minutes, show multi-use prompt
          if (timeDiff < fifteenMinutes) {
            logger.info(`Seasonal pass within 15 minutes for UID=${uid}, triggering multi-use prompt`);
            const remainingTime = Math.ceil((fifteenMinutes - timeDiff) / 1000); // seconds
            
            // Generate a prompt token for seasonal multi-use
            const promptToken = this.generatePromptToken(uid, 'seasonal_multi_use');
            
            // Store prompt data in Redis with 15-minute expiry
            await this.storePromptData(promptToken, {
              uid,
              pass_id: pass.pass_id,
              pass_type: 'seasonal',
              remaining_uses: passInfo.remaining_uses,
              last_used_at: lastUsedAt,
              expires_at: new Date(currentTime.getTime() + fifteenMinutes).toISOString()
            });
            
            logResult = 'prompt_seasonal_multi_use';
            await this.logVerification(uid, pass.pass_id, scannedBy, logResult, deviceLocalId, {
              remaining_uses: passInfo.remaining_uses,
              last_used_at: lastUsedAt,
              time_since_last_use: Math.round(timeDiff / 1000),
              prompt_token: promptToken
            });
            
            return {
              success: true,
              status: 'prompt_seasonal_multi_use',
              message: `Seasonal pass scanned within 15 minutes. You can use multiple entries.`,
              uid,
              scanned_by: scannedBy,
              remaining_uses: passInfo.remaining_uses,
              prompt_token: promptToken,
              last_used_at: lastUsedAt,
              time_remaining_seconds: remainingTime,
              pass_info: {
                pass_id: pass.pass_id,
                category: pass.category,
                pass_type: pass.pass_type,
                people_allowed: pass.people_allowed,
                max_uses: pass.max_uses,
                used_count: pass.used_count,
                remaining_uses: passInfo.remaining_uses,
                last_used_at: lastUsedAt,
                prompt_token: promptToken
              },
              timestamp: getCurrentDateTime(),
              processing_time_ms: Date.now() - startTime
            };
        } else {
          logger.info(`Seasonal pass outside 15 minutes for UID=${uid}, proceeding with normal verification`);
        }
        } else {
          logger.info(`No last used timestamp found for seasonal pass UID=${uid}, proceeding with normal verification`);
        }
      }


      // Step 6: Handle normal pass verification (for non-unlimited passes)
      {
        // Validate pass.id before atomic decrement
        if (!pass.id) {
          logger.error(`Pass ID is null/undefined for UID=${uid}`, { pass });
          logResult = 'error';
          await this.logVerification(uid, pass.pass_id, scannedBy, logResult, deviceLocalId);
          return {
            success: false,
            status: 'error',
            message: 'Invalid pass data - missing ID',
            uid,
            scanned_by: scannedBy,
            timestamp: getCurrentDateTime(),
            processing_time_ms: Date.now() - startTime
          };
        }
        
        // Acquire Redis lock for this UID to prevent concurrent access
        const lockAcquired = await redisService.setVerifyLock(uid, 10); // 10 second TTL
        
        if (!lockAcquired) {
          logResult = 'error';
          await this.logVerification(uid, pass.pass_id, scannedBy, logResult, deviceLocalId);
          return {
            success: false,
            status: 'error',
            message: 'Verification failed due to concurrent access',
            uid,
            scanned_by: scannedBy,
            timestamp: getCurrentDateTime(),
            processing_time_ms: Date.now() - startTime
          };
        }
        
        try {
          // Re-fetch pass data to ensure we have the latest state
          const latestPass = await this.getPassWithUsage(uid);
          if (!latestPass) {
            await redisService.releaseVerifyLock(uid);
            logResult = 'invalid';
            await this.logVerification(uid, pass.pass_id, scannedBy, logResult, deviceLocalId);
            return {
              success: false,
              status: 'invalid',
              message: 'Pass not found',
              uid,
              scanned_by: scannedBy,
              timestamp: getCurrentDateTime(),
              processing_time_ms: Date.now() - startTime
            };
          }
          
          // Check remaining uses again with latest data
          const latestRemainingUses = latestPass.max_uses - latestPass.used_count;
          if (latestRemainingUses <= 0) {
            await redisService.releaseVerifyLock(uid);
            logResult = 'used';
            await this.logVerification(uid, pass.pass_id, scannedBy, logResult, deviceLocalId, {
              remaining_uses: 0
            });
            
            return {
              success: false,
              status: 'used',
              message: 'Pass already used',
              uid,
              scanned_by: scannedBy,
              remaining_uses: 0,
              pass_info: {
                pass_id: pass.pass_id,
                category: pass.category,
                pass_type: pass.pass_type,
                people_allowed: pass.people_allowed,
                max_uses: pass.max_uses,
                used_count: latestPass.used_count,
                remaining_uses: 0,
                last_scan_at: null // Field removed
              },
              timestamp: getCurrentDateTime(),
              processing_time_ms: Date.now() - startTime
            };
          }
          
          
          // Normal verification - atomically decrement remaining uses
          const decrementResult = await this.atomicDecrementUsage(latestPass.id, scannedBy);
          
          if (decrementResult.success) {
            logResult = 'valid';
            const newRemainingUses = latestRemainingUses - 1;
            
            await this.logVerification(uid, pass.pass_id, scannedBy, logResult, deviceLocalId, {
              remaining_uses: newRemainingUses,
              consumed_count: 1
            });
            
            // Update Redis cache with latest pass info
            try {
              const updatedPass = await PassModel.findByUid(uid);
              if (updatedPass) {
                await redisService.addActivePass(uid, updatedPass);
              }
            } catch (cacheError) {
              logger.warn('Failed to update Redis cache for normal pass verification:', cacheError);
            }
            
            return {
              success: true,
              status: 'valid',
              message: newRemainingUses > 0 
                ? `Pass verified successfully. Remaining uses: ${newRemainingUses}`
                : 'Pass verified successfully',
              uid,
              scanned_by: scannedBy,
              remaining_uses: newRemainingUses,
              pass_info: {
                pass_id: pass.pass_id,
                category: pass.category,
                category_name: pass.category_name,
                pass_type: pass.pass_type,
                people_allowed: pass.people_allowed,
                max_uses: pass.max_uses,
                used_count: latestPass.used_count + 1,
                remaining_uses: newRemainingUses,
                last_used_at: getCurrentDateTime(),
                last_used_by: scannedBy
              },
              timestamp: getCurrentDateTime(),
              processing_time_ms: Date.now() - startTime
            };
          } else {
            // Atomic decrement failed - check if it's due to insufficient uses
            if (decrementResult.error === 'insufficient_uses') {
              logResult = 'used';
              await this.logVerification(uid, pass.pass_id, scannedBy, logResult, deviceLocalId, {
                remaining_uses: 0
              });
              
              // Get the actual last used timestamp from verification logs
              const lastUsedTimestamp = await this.getLastUsedTimestamp(uid);
              
              return {
                success: false,
                status: 'used',
                message: `This pass has already been used. Remaining uses: 0`,
                uid,
                scanned_by: scannedBy,
                remaining_uses: 0,
                pass_info: {
                  pass_id: pass.pass_id,
                  category: pass.category,
                  pass_type: pass.pass_type,
                  people_allowed: pass.people_allowed,
                  max_uses: pass.max_uses,
                  used_count: latestPass.used_count,
                  remaining_uses: 0,
                  last_scan_at: null, // Field removed
                  last_used_at: lastUsedTimestamp || null
                },
                timestamp: getCurrentDateTime(),
                processing_time_ms: Date.now() - startTime
              };
            } else {
              // Other errors
              logResult = 'error';
              await this.logVerification(uid, pass.pass_id, scannedBy, logResult, deviceLocalId);
              return {
                success: false,
                status: 'error',
                message: 'Verification failed - ' + (decrementResult.error || 'unknown error'),
                uid,
                scanned_by: scannedBy,
                timestamp: getCurrentDateTime(),
                processing_time_ms: Date.now() - startTime
              };
            }
          }
        } finally {
          // Always release the lock
          await redisService.releaseVerifyLock(uid);
        }
      }
      
    } catch (error) {
      logger.error('Verification error:', error);
      
      // Log the error
      await this.logVerification(uid, passInfo?.pass_id || null, scannedBy, 'error', deviceLocalId);
      
      return {
        success: false,
        status: 'error',
        message: 'Internal verification error',
        uid,
        scanned_by: scannedBy,
        timestamp: getCurrentDateTime(),
        processing_time_ms: Date.now() - startTime
      };
    }
  }

  async consumePrompt(promptToken, consumeCount, scannedBy) {
    const startTime = Date.now();
    
    try {
      // Retrieve and validate prompt data
      const promptData = await this.getPromptData(promptToken);
      
      if (!promptData) {
        return {
          success: false,
          status: 'invalid_token',
          message: 'Invalid or expired prompt token',
          timestamp: getCurrentDateTime(),
          processing_time_ms: Date.now() - startTime
        };
      }
      
      // Validate consume count
      if (consumeCount <= 0 || consumeCount > promptData.remaining_uses) {
        return {
          success: false,
          status: 'invalid_count',
          message: `Invalid consume count. Must be between 1 and ${promptData.remaining_uses}`,
          remaining_uses: promptData.remaining_uses,
          timestamp: getCurrentDateTime(),
          processing_time_ms: Date.now() - startTime
        };
      }
      
      // Atomically decrement usage by consume count
      const decrementResult = await this.atomicDecrementUsage(promptData.pass_db_id, scannedBy, consumeCount);
      
      if (decrementResult.success) {
        const newRemainingUses = promptData.remaining_uses - consumeCount;
        
        // Log the consumption
        await this.logVerification(
          promptData.uid, 
          promptData.pass_id, 
          scannedBy, 
          'valid', 
          promptData.device_local_id,
          {
            remaining_uses: newRemainingUses,
            consumed_count: consumeCount,
            prompt_consumption: true
          }
        );
        
        // Clean up prompt data
        await this.deletePromptData(promptToken);
        
        return {
          success: true,
          status: 'consumed',
          message: `Successfully consumed ${consumeCount} entries`,
          uid: promptData.uid,
          scanned_by: scannedBy,
          consumed_count: consumeCount,
          remaining_uses: newRemainingUses,
          timestamp: getCurrentDateTime(),
          processing_time_ms: Date.now() - startTime
        };
      } else {
        return {
          success: false,
          status: 'error',
          message: 'Failed to consume entries due to concurrent access',
          timestamp: getCurrentDateTime(),
          processing_time_ms: Date.now() - startTime
        };
      }
      
    } catch (error) {
      logger.error('Consume prompt error:', error);
      return {
        success: false,
        status: 'error',
        message: 'Internal error during prompt consumption',
        timestamp: getCurrentDateTime(),
        processing_time_ms: Date.now() - startTime
      };
    }
  }

  async getBouncerDetails(bouncerId) {
    try {
      const query = 'SELECT id, username, role, assigned_category FROM users WHERE id = ? AND role = "bouncer"';
      const result = await executeQuery(query, [bouncerId]);
      return result[0] || null;
    } catch (error) {
      logger.error('Error getting bouncer details:', error);
      return null;
    }
  }

  async getPassWithUsage(uid) {
    try {
      // Try Redis cache first
      try {
        const cachedPass = await redisService.getActivePass(uid);
        if (cachedPass && cachedPass.max_uses !== undefined) {
          logger.info(`Redis cached pass data for UID=${uid}:`, JSON.stringify(cachedPass, null, 2));
          logger.info(`Redis cached pass used_count: ${cachedPass.used_count}, max_uses: ${cachedPass.max_uses}`);
          // Ensure cached pass has proper id field (map pass_db_id to id)
          if (cachedPass.pass_db_id && !cachedPass.id) {
            cachedPass.id = cachedPass.pass_db_id;
          }
          return cachedPass;
        }
      } catch (redisError) {
        logger.warn('Redis not available for pass cache, falling back to database:', redisError.message);
      }
      
      // Fallback to database with usage info
      const pass = await PassModel.findByUidWithUsage(uid);
      logger.info(`Database pass data for UID=${uid}:`, JSON.stringify(pass, null, 2));
      logger.info(`Database pass used_count: ${pass?.used_count}, max_uses: ${pass?.max_uses}`);
      
      // Try to update Redis cache if pass is active (but don't fail if Redis is down)
      if (pass && pass.status === 'active') {
        try {
          await redisService.addActivePass(uid, pass);
        } catch (redisError) {
          logger.warn('Failed to update Redis cache, continuing without cache:', redisError.message);
        }
      }
      
      return pass;
    } catch (error) {
      logger.error('Error getting pass with usage:', error);
      throw error;
    }
  }

  async atomicDecrementUsage(passId, scannedBy, decrementBy = 1) {
    const mysql = require('mysql2/promise');
    let connection = null;
    
    try {
      // Validate parameters to prevent undefined values
      if (passId === null || passId === undefined) {
        return { success: false, error: 'invalid_pass_id' };
      }
      
      if (scannedBy === null || scannedBy === undefined) {
        return { success: false, error: 'invalid_scanned_by' };
      }
      
      if (decrementBy === null || decrementBy === undefined || decrementBy < 1) {
        return { success: false, error: 'invalid_decrement_value' };
      }
      
      // Get a new connection for transaction
      const db = getDB();
      connection = await db.getConnection();
      
      // Start transaction
      await connection.beginTransaction();
      
      // Lock the row and check current state
      const [rows] = await connection.execute(
        'SELECT id, max_uses, used_count FROM passes WHERE id = ? FOR UPDATE',
        [passId]
      );
      
      if (rows.length === 0) {
        await connection.rollback();
        return { success: false, error: 'pass_not_found' };
      }
      
      const pass = rows[0];
      const remainingUses = pass.max_uses - pass.used_count;
      
      if (remainingUses < decrementBy) {
        await connection.rollback();
        return { success: false, error: 'insufficient_uses' };
      }
      
      // Update the pass with new usage count and scan tracking
      const [updateResult] = await connection.execute(
        `UPDATE passes 
         SET used_count = used_count + ?, 
             last_scan_at = CURRENT_TIMESTAMP,
             last_scan_by = ?,
             updated_at = CURRENT_TIMESTAMP
         WHERE id = ?`,
        [decrementBy, scannedBy.id, passId]
      );
      
      if (updateResult.affectedRows > 0) {
        // Commit transaction
        await connection.commit();
        
        // Update Redis cache
        try {
          const updatedPass = await PassModel.findById(passId);
          if (updatedPass && updatedPass.status === 'active') {
            await redisService.addActivePass(updatedPass.uid, updatedPass);
          }
        } catch (cacheError) {
          logger.warn('Failed to update Redis cache after pass verification:', cacheError);
          // Don't fail the verification if cache update fails
        }
        
        return { success: true };
      } else {
        await connection.rollback();
        return { success: false, error: 'update_failed' };
      }
      
    } catch (error) {
      if (connection) {
        try {
          await connection.rollback();
        } catch (rollbackError) {
          logger.error('Error rolling back transaction:', rollbackError);
        }
      }
      logger.error('Error in atomic decrement usage:', error);
      return { success: false, error: 'database_error' };
    } finally {
      if (connection) {
        try {
          connection.release();
        } catch (closeError) {
          logger.error('Error releasing database connection:', closeError);
        }
      }
    }
  }

  generatePromptToken() {
    return crypto.randomBytes(32).toString('hex');
  }

  async storePromptData(token, data) {
    try {
      const redis = getRedisClient();
      const key = `prompt:${token}`;
      // Use 5 minutes (300 seconds) expiry for all passes
      const expiryTime = 300;
      await redis.setEx(key, expiryTime, JSON.stringify(data));
    } catch (error) {
      logger.error('Error storing prompt data:', error);
      throw error;
    }
  }

  async getPromptData(token) {
    try {
      const redis = getRedisClient();
      const key = `prompt:${token}`;
      const data = await redis.get(key);
      return data ? JSON.parse(data) : null;
    } catch (error) {
      logger.error('Error getting prompt data:', error);
      return null;
    }
  }

  async deletePromptData(token) {
    try {
      const redis = getRedisClient();
      const key = `prompt:${token}`;
      await redis.del(key);
    } catch (error) {
      logger.error('Error deleting prompt data:', error);
    }
  }

  async getLastUsedTimestamp(uid) {
    try {
      // Search through daily log tables for the last successful verification
      // Start from today and go back up to 30 days
      const today = new Date();
      
      for (let i = 0; i < 30; i++) {
        const date = new Date(today);
        date.setDate(date.getDate() - i);
        const dateStr = date.toISOString().split('T')[0].replace(/-/g, '_');
        const tableName = `daily_logs_${dateStr}`;
        
        try {
          const exists = await tableExists(tableName);
          if (!exists) continue;
          
          const query = `
            SELECT created_at 
            FROM ${tableName} 
            WHERE uid = ? AND result = 'valid' 
            ORDER BY created_at DESC 
            LIMIT 1
          `;
          
          const result = await executeQuery(query, [uid]);
          if (result.length > 0) {
            return result[0].created_at;
          }
        } catch (error) {
          logger.error(`Error querying ${tableName}:`, error);
          continue;
        }
      }
      
      return null; // No successful verification found in the last 30 days
    } catch (error) {
      logger.error('Error getting last used timestamp:', error);
      return null;
    }
  }

  async logVerification(uid, passId, scannedBy, result, deviceLocalId = null, additionalData = {}) {
    try {
      // Check if logs table exists before trying to create a log
      const checkTableQuery = `
        SELECT COUNT(*) as count 
        FROM information_schema.tables 
        WHERE table_schema = ? AND table_name = ?
      `;
      
      const db = require('../config/db');
      const dbName = process.env.DB_NAME || 'app';
      const result1 = await db.executeQuery(checkTableQuery, [dbName, 'logs']);
      
      if (result1[0].count === 0) {
        logger.warn('Logs table does not exist, skipping verification log creation');
        return null;
      }
      
      // Get current date for daily logs table
      const currentDate = getCurrentDate();
      const tableName = getDailyLogTableName(currentDate);
      
      // Check if daily logs table exists, create if not
      const tableExists = await this.checkDailyTableExists(tableName);
      if (!tableExists) {
        await createDailyLogTable(currentDate);
      }
      
      // Prepare data for insertion
      let remainingUses = additionalData.remaining_uses !== undefined ? 
        additionalData.remaining_uses : null;
      
      // Convert "unlimited" string to integer for database storage
      if (remainingUses === 'unlimited') {
        remainingUses = -1; // Use -1 to represent unlimited passes
      }
      
      const consumedCount = additionalData.consumed_count !== undefined ? 
        additionalData.consumed_count : 1;
      
      const promptConsumption = additionalData.prompt_consumption === true;
      
      const offlineSync = additionalData.offline_sync === true;
      
      // Get pass details for category and pass_type
      let category = null;
      let passType = null;
      
      if (passId) {
        try {
          // passId is actually pass_id (UUID), not database ID
          const passQuery = `SELECT category, pass_type FROM passes WHERE pass_id = ?`;
          const passResult = await executeQuery(passQuery, [passId]);
          if (passResult.length > 0) {
            category = passResult[0].category;
            passType = passResult[0].pass_type;
          }
        } catch (error) {
          logger.warn(`Failed to fetch pass details for logging: ${error.message}`);
        }
      }
      
      // Map verification results to database enum values
      const resultMapping = {
        'valid': 'success',
        'invalid': 'failure', 
        'used': 'failure',
        'unauthorized': 'failure',
        'blocked': 'failure',
        'error': 'error'
      };
      
      const dbResult = resultMapping[result] || 'error';
      
      // Create detailed status message based on verification result
      let statusMessage = '';
      let details = {};
      
      switch (result) {
        case 'valid':
          statusMessage = 'Pass verified successfully';
          details = {
            message: statusMessage,
            remaining_uses: remainingUses,
            total_uses: consumedCount,
            category: category,
            pass_type: passType,
            user: scannedBy ? `${scannedBy.username} (${scannedBy.role})` : 'Unknown',
            scan_time: new Date().toISOString()
          };
          break;
        case 'used':
          statusMessage = 'Pass already used up';
          details = {
            message: statusMessage,
            remaining_uses: 0,
            total_uses: consumedCount,
            category: category,
            pass_type: passType,
            user: scannedBy ? `${scannedBy.username} (${scannedBy.role})` : 'Unknown',
            scan_time: new Date().toISOString()
          };
          break;
        case 'invalid':
          statusMessage = 'Pass not found or invalid';
          details = {
            message: statusMessage,
            uid: uid,
            user: scannedBy ? `${scannedBy.username} (${scannedBy.role})` : 'Unknown',
            scan_time: new Date().toISOString()
          };
          break;
        case 'unauthorized':
          statusMessage = 'User not authorized to verify this pass';
          details = {
            message: statusMessage,
            uid: uid,
            category: category,
            user: scannedBy ? `${scannedBy.username} (${scannedBy.role})` : 'Unknown',
            scan_time: new Date().toISOString()
          };
          break;
        case 'blocked':
          statusMessage = 'Pass is blocked';
          details = {
            message: statusMessage,
            uid: uid,
            category: category,
            pass_type: passType,
            user: scannedBy ? `${scannedBy.username} (${scannedBy.role})` : 'Unknown',
            scan_time: new Date().toISOString()
          };
          break;
        case 'error':
          statusMessage = 'Verification failed due to system error';
          details = {
            message: statusMessage,
            uid: uid,
            user: scannedBy ? `${scannedBy.username} (${scannedBy.role})` : 'Unknown',
            scan_time: new Date().toISOString(),
            error: 'System error during verification'
          };
          break;
        default:
          statusMessage = 'Unknown verification result';
          details = {
            message: statusMessage,
            uid: uid,
            user: scannedBy ? `${scannedBy.username} (${scannedBy.role})` : 'Unknown',
            scan_time: new Date().toISOString()
          };
      }

      // Prepare log data for DailyLogsService
      const logData = {
        action_type: 'verify_pass',
        user_id: scannedBy?.id || null,
        role: scannedBy?.role || null,
        pass_id: passId || null,
        uid: uid || null,
        scanned_at: new Date(),
        scanned_by: scannedBy?.id || null,
        remaining_uses: remainingUses !== undefined ? remainingUses : null,
        consumed_count: consumedCount || 0,
        category: category || null,
        pass_type: passType || null,
        ip_address: null, // Will be set by the controller if available
        user_agent: null, // Will be set by the controller if available
        details: JSON.stringify(details),
        result: dbResult,
        error_message: result === 'error' ? statusMessage : null
      };
      
      // Use DailyLogsService to insert the log
      await DailyLogsService.insertLog(logData);
      
      logger.debug(`Verification logged: UID=${uid}, Result=${result}`);
      return true;
    } catch (error) {
      logger.error('Failed to log verification:', error);
      // If this is an offline sync operation, throw the error so it can be handled properly
      if (additionalData.offline_sync) {
        throw error;
      }
      // Don't throw error to prevent verification failure due to logging issues
      return false;
    }
  }
  
  async checkDailyTableExists(tableName) {
    try {
      // Check if table exists
      const query = `
        SELECT COUNT(*) as count 
        FROM information_schema.tables 
        WHERE table_schema = ? AND table_name = ?
      `;
      
      const result = await executeQuery(query, [process.env.DB_NAME || 'app', tableName]);
      return result[0].count > 0;
    } catch (error) {
      logger.error(`Failed to check if table ${tableName} exists:`, error);
      return false;
    }
  }

  async syncOfflineLogs(logs) {
    try {
      const results = {
        total: logs.length,
        synced: 0,
        errors: []
      };
      
      for (const log of logs) {
        try {
          await this.logVerification(
            log.uid,
            log.pass_id,
            log.scanned_by,
            log.result,
            null, // device_local_id removed
            {
              remaining_uses: log.remaining_uses,
              consumed_count: log.consumed_count || 1,
              offline_sync: true
            }
          );
          results.synced++;
        } catch (error) {
          results.errors.push({
            log,
            error: error.message
          });
        }
      }
      
      logger.info(`Offline logs sync: ${results.synced}/${results.total} synced`);
      return results;
    } catch (error) {
      logger.error('Error syncing offline logs:', error);
      throw error;
    }
  }

  async getVerificationStats(dateRange) {
    try {
      const stats = {
        total_verifications: 0,
        valid_verifications: 0,
        blocked_verifications: 0,
        duplicate_verifications: 0,
        invalid_verifications: 0,
        error_verifications: 0,
        multi_use_prompts: 0,
        consumed_entries: 0
      };
      
      // Query daily log tables for the date range
      const startDate = new Date(dateRange.start);
      const endDate = new Date(dateRange.end);
      
      for (let date = new Date(startDate); date <= endDate; date.setDate(date.getDate() + 1)) {
        const dateStr = date.toISOString().split('T')[0].replace(/-/g, '_');
        const tableName = `daily_logs_${dateStr}`;
        
        try {
          const exists = await tableExists(tableName);
          if (!exists) continue;
          
          const query = `
            SELECT 
              result,
              COUNT(*) as count,
              SUM(consumed_count) as total_consumed
            FROM ${tableName}
            GROUP BY result
          `;
          
          const results = await executeQuery(query);
          
          for (const row of results) {
            stats.total_verifications += row.count;
            stats[`${row.result}_verifications`] += row.count;
            
            if (row.result === 'valid') {
              stats.consumed_entries += row.total_consumed || row.count;
            }
          }
          
          // Count multi-use prompts
          const promptQuery = `
            SELECT COUNT(*) as prompt_count
            FROM ${tableName}
            WHERE prompt_consumption = true
          `;
          
          const promptResults = await executeQuery(promptQuery);
          if (promptResults.length > 0) {
            stats.multi_use_prompts += promptResults[0].prompt_count;
          }
          
        } catch (tableError) {
          // Table might not exist, continue
          continue;
        }
      }
      
      return stats;
    } catch (error) {
      logger.error('Error getting verification stats:', error);
      throw error;
    }
  }

  isPassExpired(pass) {
    if (!pass || !pass.valid_to || pass.valid_to === null || pass.valid_to === undefined) {
      return false;
    }
    
    const expiryDate = new Date(pass.valid_to);
    const currentDate = new Date();
    
    // Check if expiry date is valid
    if (isNaN(expiryDate.getTime())) {
      return false;
    }
    
    return expiryDate < currentDate;
  }

  /**
   * Update scan tracking for passes (unlimited passes)
   * @param {number} passId - Pass database ID
   * @param {number} scannedByUserId - User ID who scanned the pass
   */
  async updateScanTracking(passId, scannedByUserId) {
    try {
      const { executeQuery } = require('../config/db');
      
      const updateResult = await executeQuery(
        `UPDATE passes 
         SET last_scan_at = CURRENT_TIMESTAMP,
             last_scan_by = ?,
             updated_at = CURRENT_TIMESTAMP
         WHERE id = ?`,
        [scannedByUserId, passId]
      );
      
      if (updateResult.affectedRows > 0) {
        logger.debug(`Updated scan tracking for pass ID ${passId}, scanned by user ${scannedByUserId}`);
        return true;
      } else {
        logger.warn(`Failed to update scan tracking for pass ID ${passId}`);
        return false;
      }
    } catch (error) {
      logger.error('Error updating scan tracking:', error);
      throw error;
    }
  }
}

module.exports = new VerifyService();
