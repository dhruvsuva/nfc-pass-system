const LogsModel = require('../models/logs.model');
const DailyLogsService = require('./daily-logs.service');
const logger = require('../utils/logger');

class LoggingService {
  // Helper to get system logs socket handler for real-time updates
  static getSystemLogsSocket() {
    try {
      // Get the app instance from the global scope or require it
      const { app } = require('../server');
      const getSystemLogsSocket = app.get('getSystemLogsSocket');
      return getSystemLogsSocket ? getSystemLogsSocket() : null;
    } catch (error) {
      // Fallback: try to get from global if server module is not available
      if (global.systemLogsSocketHandler) {
        return global.systemLogsSocketHandler;
      }
      logger.debug('System logs socket handler not available:', error.message);
      return null;
    }
  }

  // Helper to emit new system log via WebSocket
  static async emitNewSystemLog(logData) {
    try {
      const socketHandler = this.getSystemLogsSocket();
      if (socketHandler && socketHandler.emitNewSystemLog) {
        // Get the full log data with user information
        const fullLogData = await LogsModel.getLogById(logData.id);
        if (fullLogData) {
          socketHandler.emitNewSystemLog(fullLogData);
        }
      }
    } catch (error) {
      logger.debug('Failed to emit new system log via WebSocket:', error.message);
    }
  }
  // Helper to extract IP and User Agent from request
  static extractRequestInfo(req) {
    // Add null safety check
    if (!req) {
      return { ip_address: null, user_agent: null };
    }
    
    const ip_address = req.ip || 
                      (req.connection && req.connection.remoteAddress) || 
                      (req.socket && req.socket.remoteAddress) || 
                      (req.connection && req.connection.socket && req.connection.socket.remoteAddress) ||
                      (req.headers && req.headers['x-forwarded-for']) ||
                      (req.headers && req.headers['x-real-ip']) ||
                      null;
    const user_agent = req.get ? req.get('User-Agent') : (req.headers && req.headers['user-agent']) || null;
    
    return { ip_address, user_agent };
  }

  // Authentication Logs
  static async logLogin(user, req, success = true) {
    const { ip_address, user_agent } = this.extractRequestInfo(req);
    
    try {
      const logId = await LogsModel.createLog({
        action_type: success ? 'login' : 'login_failed',
        user_id: user.id,
        role: user.role,
        ip_address,
        user_agent,
        details: {
          username: user.username,
          login_time: new Date().toISOString(),
          success
        },
        result: success ? 'success' : 'failure',
        error_message: success ? null : 'Login failed'
      });
      
      // Emit real-time update
      if (logId) {
        await this.emitNewSystemLog({ id: logId });
      }
      
      return logId;
    } catch (error) {
      logger.error('Failed to log login:', error);
      return null;
    }
  }

  static async logLogout(user, req) {
    const { ip_address, user_agent } = this.extractRequestInfo(req);
    
    try {
      const logId = await LogsModel.createLog({
        action_type: 'logout',
        user_id: user.id,
        role: user.role,
        ip_address,
        user_agent,
        details: {
          username: user.username,
          logout_time: new Date().toISOString()
        },
        result: 'success'
      });
      
      // Emit real-time update
      if (logId) {
        await this.emitNewSystemLog({ id: logId });
      }
    } catch (error) {
      logger.error('Failed to log logout:', error);
    }
  }

  static async logTokenRefresh(user, req, success = true, errorMessage = null) {
    const { ip_address, user_agent } = this.extractRequestInfo(req);
    
    try {
      const logId = await LogsModel.createLog({
        action_type: success ? 'token_refresh' : 'token_refresh_failed',
        user_id: user ? user.id : null,
        role: user ? user.role : null,
        ip_address,
        user_agent,
        details: {
          username: user ? user.username : 'unknown',
          refresh_time: new Date().toISOString(),
          error_message: errorMessage
        },
        result: success ? 'success' : 'failure',
        error_message: success ? null : errorMessage
      });
      
      // Emit real-time update
      if (logId) {
        await this.emitNewSystemLog({ id: logId });
      }
      
      return logId;
    } catch (error) {
      logger.error('Failed to log token refresh:', error);
      return null;
    }
  }

  // Pass Management Logs
  static async logCreatePass(pass, createdBy, req) {
    const { ip_address, user_agent } = this.extractRequestInfo(req);
    
    try {
      // Log to daily table for pass operations
      const logId = await DailyLogsService.insertLog({
        action_type: 'create_pass',
        user_id: createdBy.id,
        role: createdBy.role,
        pass_id: pass.pass_id,
        uid: pass.uid,
        ip_address,
        user_agent,
        details: {
          pass_type: pass.pass_type,
          category: pass.category,
          created_by: createdBy.username,
          creation_time: new Date().toISOString(),
          pass_details: {
            uid: pass.uid,
            pass_type: pass.pass_type,
            category: pass.category
          }
        },
        result: 'success'
      });
      
      return logId;
    } catch (error) {
      logger.error('Failed to log create pass:', error);
      return null;
    }
  }

  static async logBulkCreatePass(bulkResult, createdBy, req) {
    const { ip_address, user_agent } = this.extractRequestInfo(req);
    
    try {
      // Log to daily table for pass operations
      const logId = await DailyLogsService.insertLog({
        action_type: 'bulk_create_pass',
        user_id: createdBy.id,
        role: createdBy.role,
        ip_address,
        user_agent,
        details: {
          bulk_id: bulkResult.bulk_id,
          total_requested: bulkResult.total_requested,
          success_count: bulkResult.success_count,
          error_count: bulkResult.error_count,
          pass_type: bulkResult.pass_type,
          category: bulkResult.category,
          created_by_username: createdBy.username,
          errors: bulkResult.errors || []
        },
        result: bulkResult.error_count > 0 ? 'error' : 'success'
      });
      
      return logId;
    } catch (error) {
      logger.error('Failed to log bulk create pass:', error);
      return null;
    }
  }

  static async logDeletePass(pass, deletedBy, req) {
    const { ip_address, user_agent } = this.extractRequestInfo(req);
    
    try {
      const logId = await LogsModel.createLog({
        action_type: 'delete_pass',
        user_id: deletedBy.id,
        role: deletedBy.role,
        pass_id: pass.pass_id,
        uid: pass.uid,
        ip_address,
        user_agent,
        details: {
          pass_type: pass.pass_type,
          category: pass.category,
          deleted_by: deletedBy.username,
          deletion_time: new Date().toISOString(),
          pass_details: {
            uid: pass.uid,
            pass_type: pass.pass_type,
            category: pass.category
          }
        },
        result: 'success'
      });
      
      // Emit real-time update
      if (logId) {
        await this.emitNewSystemLog({ id: logId });
      }
      
      return logId;
    } catch (error) {
      logger.error('Failed to log delete pass:', error);
      return null;
    }
  }

  static async logBlockUnblockPass(pass, action, actionBy, req) {
    const { ip_address, user_agent } = this.extractRequestInfo(req);
    
    try {
      const logId = await LogsModel.createLog({
        action_type: action === 'block' ? 'block_pass' : 'unblock_pass',
        user_id: actionBy.id,
        role: actionBy.role,
        pass_id: pass.pass_id,
        uid: pass.uid,
        ip_address,
        user_agent,
        details: {
          action,
          pass_type: pass.pass_type,
          category: pass.category,
          action_by: actionBy.username,
          action_time: new Date().toISOString(),
          previous_status: pass.status
        },
        result: 'success'
      });
      
      // Emit real-time update
      if (logId) {
        await this.emitNewSystemLog({ id: logId });
      }
      
      return logId;
    } catch (error) {
      logger.error('Failed to log block/unblock pass:', error);
      return null;
    }
  }

  // Verification Logs
  static async logVerifyPass(pass, verificationResult, scannedBy, req) {
    const { ip_address, user_agent } = this.extractRequestInfo(req);
    
    try {
      // Enhanced verification details with additional metadata
      const enhancedDetails = {
        pass_type: pass.pass_type,
        category: pass.category,
        verification_result: verificationResult.status,
        message: verificationResult.message,
        scanned_by_username: scannedBy.username,
        scanned_by_role: scannedBy.role,
        scan_time: new Date().toISOString(),
        people_allowed: pass.people_allowed,
        previous_status: pass.status,
        // Additional context
        device_info: {
          ip_address,
          user_agent: user_agent ? user_agent.substring(0, 200) : null // Truncate for storage
        },
        pass_metadata: {
          created_at: pass.created_at,
          updated_at: pass.updated_at,
          used_count: pass.used_count || 0,
          remaining_uses: pass.remaining_uses
        },
        verification_context: {
          timestamp: new Date().toISOString(),
          timezone: Intl.DateTimeFormat().resolvedOptions().timeZone,
          verification_type: verificationResult.verificationType || 'standard',
          consumed_count: verificationResult.consumedCount || 1
        }
      };

      // Log to daily table for pass operations
      const logId = await DailyLogsService.insertLog({
        action_type: 'verify_pass',
        user_id: scannedBy.id,
        role: scannedBy.role,
        pass_id: pass.pass_id,
        uid: pass.uid,
        ip_address,
        user_agent,
        details: enhancedDetails,
        result: verificationResult.status === 'valid' ? 'success' : 'failure'
      });
    } catch (error) {
      logger.error('Failed to log verify pass:', error);
    }
  }

  static async logSessionConsume(pass, consumeCount, scannedBy, req) {
    const { ip_address, user_agent } = this.extractRequestInfo(req);
    
    try {
      // Log to daily table for pass operations
      const logId = await DailyLogsService.insertLog({
        action_type: 'session_consume',
        user_id: scannedBy.id,
        role: scannedBy.role,
        pass_id: pass.pass_id,
        uid: pass.uid,
        ip_address,
        user_agent,
        details: {
          consume_count: consumeCount,
          pass_type: pass.pass_type,
          category: pass.category,
          scanned_by_username: scannedBy.username,
          consume_time: new Date().toISOString()
        },
        result: 'success'
      });
    } catch (error) {
      logger.error('Failed to log session consume:', error);
    }
  }

  // Reset Logs
  static async logResetSinglePass(pass, resetBy, req) {
    const { ip_address, user_agent } = this.extractRequestInfo(req);
    
    try {
      const logId = await LogsModel.createLog({
        action_type: 'reset_single_pass',
        user_id: resetBy.id,
        role: resetBy.role,
        pass_id: pass.pass_id,
        uid: pass.uid,
        ip_address,
        user_agent,
        details: {
          pass_type: pass.pass_type,
          category: pass.category,
          previous_status: pass.status,
          reset_by_username: resetBy.username,
          reset_time: new Date().toISOString()
        },
        result: 'success'
      });
      
      // Emit real-time update
      if (logId) {
        await this.emitNewSystemLog({ id: logId });
      }
      
      return logId;
    } catch (error) {
      logger.error('Failed to log reset single pass:', error);
      return null;
    }
  }

  static async logResetDailyPasses(resetResult, resetBy, req) {
    const { ip_address, user_agent } = this.extractRequestInfo(req);
    
    try {
      const logId = await LogsModel.createLog({
        action_type: 'reset_daily_passes',
        user_id: resetBy.id,
        role: resetBy.role,
        ip_address,
        user_agent,
        details: {
          total_reset_count: resetResult.reset_count,
          reset_date: resetResult.reset_date,
          reset_by_username: resetBy.username,
          reset_time: new Date().toISOString(),
          affected_categories: resetResult.categories || []
        },
        result: 'success'
      });
      
      // Emit real-time update
      if (logId) {
        await this.emitNewSystemLog({ id: logId });
      }
      
      return logId;
    } catch (error) {
      logger.error('Failed to log reset daily passes:', error);
      return null;
    }
  }

  // User Management Logs
  static async logCreateUser(newUser, createdBy, req) {
    const { ip_address, user_agent } = this.extractRequestInfo(req);
    
    try {
      const logId = await LogsModel.createLog({
        action_type: 'create_user',
        user_id: createdBy.id,
        role: createdBy.role,
        target_user_id: newUser.id,
        ip_address,
        user_agent,
        details: {
          new_username: newUser.username,
          new_user_assigned_category: newUser.assigned_category,
          new_user_role: newUser.role,
          new_user_status: newUser.status,
          created_by_username: createdBy.username
        },
        result: 'success'
      });
      
      // Emit real-time update
      if (logId) {
        await this.emitNewSystemLog({ id: logId });
      }
      
      return logId;
    } catch (error) {
      logger.error('Failed to log create user:', error);
      return null;
    }
  }

  static async logUpdateUser(updatedUser, updatedBy, req, changes = {}) {
    const { ip_address, user_agent } = this.extractRequestInfo(req);
    
    try {
      const logId = await LogsModel.createLog({
        action_type: 'update_user',
        user_id: updatedBy.id,
        role: updatedBy.role,
        target_user_id: updatedUser.id,
        ip_address,
        user_agent,
        details: {
          target_username: updatedUser.username,
          updated_by_username: updatedBy.username,
          changes: changes,
          update_time: new Date().toISOString()
        },
        result: 'success'
      });
      
      // Emit real-time update
      if (logId) {
        await this.emitNewSystemLog({ id: logId });
      }
      
      return logId;
    } catch (error) {
      logger.error('Failed to log update user:', error);
      return null;
    }
  }

  static async logDeleteUser(deletedUser, deletedBy, req) {
    const { ip_address, user_agent } = this.extractRequestInfo(req);
    
    try {
      const logId = await LogsModel.createLog({
        action_type: 'delete_user',
        user_id: deletedBy.id,
        role: deletedBy.role,
        target_user_id: deletedUser.id,
        ip_address,
        user_agent,
        details: {
          deleted_username: deletedUser.username,
          deleted_user_assigned_category: deletedUser.assigned_category,
          deleted_user_role: deletedUser.role,
          deleted_by_username: deletedBy.username
        },
        result: 'success'
      });
      
      // Emit real-time update
      if (logId) {
        await this.emitNewSystemLog({ id: logId });
      }
      
      return logId;
    } catch (error) {
      logger.error('Failed to log delete user:', error);
      return null;
    }
  }

  static async logBlockUnblockUser(targetUser, action, actionBy, req, reason = null) {
    const { ip_address, user_agent } = this.extractRequestInfo(req);
    
    try {
      const logId = await LogsModel.createLog({
        action_type: action === 'block' ? 'block_user' : 'unblock_user',
        user_id: actionBy.id,
        role: actionBy.role,
        target_user_id: targetUser.id,
        ip_address,
        user_agent,
        details: {
          target_username: targetUser.username,
          target_user_role: targetUser.role,
          action_by_username: actionBy.username,
          action: action,
          reason: reason,
          action_time: new Date().toISOString()
        },
        result: 'success'
      });
      
      // Emit real-time update
      if (logId) {
        await this.emitNewSystemLog({ id: logId });
      }
      
      return logId;
    } catch (error) {
      logger.error(`Failed to log ${action} user:`, error);
      return null;
    }
  }

  static async logChangePassword(targetUser, changedBy, req) {
    const { ip_address, user_agent } = this.extractRequestInfo(req);
    
    try {
      const logId = await LogsModel.createLog({
        action_type: 'change_password',
        user_id: changedBy.id,
        role: changedBy.role,
        target_user_id: targetUser.id,
        ip_address,
        user_agent,
        details: {
          target_username: targetUser.username,
          target_user_role: targetUser.role,
          changed_by_username: changedBy.username,
          change_time: new Date().toISOString()
        },
        result: 'success'
      });
      
      // Emit real-time update
      if (logId) {
        await this.emitNewSystemLog({ id: logId });
      }
      
      return logId;
    } catch (error) {
      logger.error('Failed to log change password:', error);
      return null;
    }
  }

  static async logAssignCategory(targetUser, category, assignedBy, req) {
    const { ip_address, user_agent } = this.extractRequestInfo(req);
    
    try {
      const logId = await LogsModel.createLog({
        action_type: 'assign_category',
        user_id: assignedBy.id,
        role: assignedBy.role,
        target_user_id: targetUser.id,
        ip_address,
        user_agent,
        details: {
          target_username: targetUser.username,
          target_user_role: targetUser.role,
          assigned_category: category,
          assigned_by_username: assignedBy.username,
          assignment_time: new Date().toISOString()
        },
        result: 'success'
      });
      
      // Emit real-time update
      if (logId) {
        await this.emitNewSystemLog({ id: logId });
      }
      
      return logId;
    } catch (error) {
      logger.error('Failed to log assign category:', error);
      return null;
    }
  }

  // Category Management Logs
  static async logCreateCategory(category, createdBy, req) {
    const { ip_address, user_agent } = this.extractRequestInfo(req);
    
    try {
      const logId = await LogsModel.createLog({
        action_type: 'create_category',
        user_id: createdBy.id,
        role: createdBy.role,
        ip_address,
        user_agent,
        details: {
          category_name: category.name,
          category_color: category.color_code,
          category_description: category.description,
          created_by_username: createdBy.username,
          creation_time: new Date().toISOString()
        },
        result: 'success'
      });
      
      // Emit real-time update
      if (logId) {
        await this.emitNewSystemLog({ id: logId });
      }
      
      return logId;
    } catch (error) {
      logger.error('Failed to log create category:', error);
      return null;
    }
  }

  static async logUpdateCategory(updatedCategory, originalCategory, updatedBy, req, changes = {}) {
    const { ip_address, user_agent } = this.extractRequestInfo(req);
    
    try {
      const logId = await LogsModel.createLog({
        action_type: 'update_category',
        user_id: updatedBy.id,
        role: updatedBy.role,
        ip_address,
        user_agent,
        details: {
          category_name: updatedCategory.name,
          original_name: originalCategory.name,
          updated_by_username: updatedBy.username,
          changes: changes,
          update_time: new Date().toISOString()
        },
        result: 'success'
      });
      
      // Emit real-time update
      if (logId) {
        await this.emitNewSystemLog({ id: logId });
      }
      
      return logId;
    } catch (error) {
      logger.error('Failed to log update category:', error);
      return null;
    }
  }

  static async logDeleteCategory(deletedCategory, deletedBy, req) {
    const { ip_address, user_agent } = this.extractRequestInfo(req);
    
    try {
      const logId = await LogsModel.createLog({
        action_type: 'delete_category',
        user_id: deletedBy.id,
        role: deletedBy.role,
        ip_address,
        user_agent,
        details: {
          deleted_category_name: deletedCategory.name,
          deleted_category_color: deletedCategory.color_code,
          deleted_category_description: deletedCategory.description,
          deleted_by_username: deletedBy.username,
          deletion_time: new Date().toISOString()
        },
        result: 'success'
      });
      
      // Emit real-time update
      if (logId) {
        await this.emitNewSystemLog({ id: logId });
      }
      
      return logId;
    } catch (error) {
      logger.error('Failed to log delete category:', error);
      return null;
    }
  }

  // Enhanced Error Logs with file backup and categorization
  static async logError(errorType, error, user = null, req = null, additionalDetails = {}) {
    const errorTimestamp = new Date().toISOString();
    const { ip_address, user_agent } = req ? this.extractRequestInfo(req) : { ip_address: null, user_agent: null };
    
    // Enhanced error categorization
    const errorCategory = this.categorizeError(error, errorType);
    const errorSeverity = this.determineErrorSeverity(error, errorType);
    
    // Create enhanced error details
    const enhancedErrorDetails = {
      error_type: errorType,
      error_category: errorCategory,
      error_severity: errorSeverity,
      error_time: errorTimestamp,
      error_stack: error.stack || null,
      error_code: error.code || null,
      error_name: error.name || 'Error',
      system_info: {
        node_version: process.version,
        platform: process.platform,
        memory_usage: process.memoryUsage(),
        uptime: process.uptime()
      },
      request_context: req ? {
        method: req.method,
        url: req.originalUrl || req.url,
        headers: this.sanitizeHeaders(req.headers),
        body_size: req.body ? JSON.stringify(req.body).length : 0
      } : null,
      user_context: user ? {
        user_id: user.id,
        username: user.username,
        role: user.role
      } : null,
      ...additionalDetails
    };

    try {
      // Always write to file first (backup mechanism)
      await this.writeErrorToFile(enhancedErrorDetails, error);
      
      // Check if logs table exists before trying to create a log
      const checkTableQuery = `
        SELECT COUNT(*) as count 
        FROM information_schema.tables 
        WHERE table_schema = ? AND table_name = ?
      `;
      
      const db = require('../config/db');
      const result = await db.executeQuery(checkTableQuery, [process.env.DB_NAME, 'logs']);
      
      if (result[0].count === 0) {
        logger.warn('Logs table does not exist, error logged to file only');
        return null;
      }
      
      const logId = await LogsModel.createLog({
        action_type: 'system_error',
        user_id: user ? user.id : null,
        role: user ? user.role : null,
        ip_address,
        user_agent,
        details: enhancedErrorDetails,
        result: 'error',
        error_message: error.message || error.toString()
      });
      
      // Emit real-time update with error severity
      if (logId) {
        await this.emitNewSystemLog({ 
          id: logId,
          error_severity: errorSeverity,
          error_category: errorCategory,
          requires_attention: errorSeverity === 'critical' || errorSeverity === 'high'
        });
      }
      
      return logId;
    } catch (logError) {
      logger.error('Failed to log error to database:', logError);
      // Ensure file backup exists even if DB logging fails
      await this.writeErrorToFile(enhancedErrorDetails, error, logError);
      return null;
    }
  }

  // Helper method to categorize errors
  static categorizeError(error, errorType) {
    if (error.code) {
      if (error.code.startsWith('ER_')) return 'database';
      if (error.code === 'ECONNREFUSED') return 'connection';
      if (error.code === 'ETIMEDOUT') return 'timeout';
      if (error.code === 'ENOTFOUND') return 'dns';
    }
    
    if (error.name) {
      if (error.name.includes('Validation')) return 'validation';
      if (error.name.includes('Auth')) return 'authentication';
      if (error.name.includes('Permission')) return 'authorization';
      if (error.name.includes('Syntax')) return 'syntax';
    }
    
    if (errorType) {
      if (errorType.includes('api')) return 'api';
      if (errorType.includes('auth')) return 'authentication';
      if (errorType.includes('db')) return 'database';
      if (errorType.includes('file')) return 'filesystem';
    }
    
    return 'general';
  }

  // Helper method to determine error severity
  static determineErrorSeverity(error, errorType) {
    // Critical errors that require immediate attention
    if (error.code === 'ECONNREFUSED' || 
        error.message?.includes('database') ||
        error.message?.includes('connection') ||
        errorType?.includes('critical')) {
      return 'critical';
    }
    
    // High priority errors
    if (error.name?.includes('Auth') ||
        error.code?.startsWith('ER_') ||
        errorType?.includes('security') ||
        errorType?.includes('auth')) {
      return 'high';
    }
    
    // Medium priority errors
    if (error.name?.includes('Validation') ||
        errorType?.includes('api') ||
        errorType?.includes('user')) {
      return 'medium';
    }
    
    // Low priority errors (warnings, info)
    return 'low';
  }

  // Helper method to sanitize headers (remove sensitive data)
  static sanitizeHeaders(headers) {
    const sanitized = { ...headers };
    delete sanitized.authorization;
    delete sanitized.cookie;
    delete sanitized['x-api-key'];
    return sanitized;
  }

  // Helper method to write errors to file (backup mechanism)
  static async writeErrorToFile(errorDetails, originalError, dbError = null) {
    try {
      const fs = require('fs').promises;
      const path = require('path');
      
      const errorLogDir = path.join(process.cwd(), 'logs', 'errors');
      await fs.mkdir(errorLogDir, { recursive: true });
      
      const date = new Date().toISOString().split('T')[0];
      const errorLogFile = path.join(errorLogDir, `error-${date}.log`);
      
      const logEntry = {
        timestamp: new Date().toISOString(),
        error_details: errorDetails,
        original_error: {
          message: originalError.message,
          stack: originalError.stack,
          name: originalError.name,
          code: originalError.code
        },
        db_logging_error: dbError ? {
          message: dbError.message,
          stack: dbError.stack
        } : null
      };
      
      await fs.appendFile(errorLogFile, JSON.stringify(logEntry) + '\n');
    } catch (fileError) {
      // Last resort - log to console if file writing fails
      logger.error('Failed to write error to file:', fileError);
      logger.error('Original error that failed to log:', originalError);
    }
  }

  // API Access Logs (for failed attempts)
  static async logApiAccess(req, user = null, success = true, errorMessage = null) {
    try {
      const { ip_address, user_agent } = this.extractRequestInfo(req);
      
      const logId = await LogsModel.createLog({
        action_type: success ? 'api_access' : 'api_error',
        user_id: user ? user.id : null,
        role: user ? user.role : null,
        ip_address,
        user_agent,
        details: {
          endpoint: req.originalUrl || req.url,
          method: req.method,
          success,
          error_message: errorMessage,
          timestamp: new Date().toISOString()
        },
        result: success ? 'success' : 'failure',
        error_message: errorMessage
      });
      
      // Emit real-time update for failed API access attempts
      if (logId && !success) {
        await this.emitNewSystemLog({ id: logId });
      }
    } catch (error) {
      logger.error('Failed to log API access:', error);
    }
  }

  // Sync Operations Logging
  static async logSyncStart(user, req, syncType = 'offline_logs', itemCount = 0) {
    try {
      const { ip_address, user_agent } = this.extractRequestInfo(req);
      
      const logId = await LogsModel.createLog({
        action_type: 'sync_start',
        user_id: user.id,
        role: user.role,
        ip_address,
        user_agent,
        details: {
          sync_type: syncType,
          item_count: itemCount,
          sync_by: user.username,
          sync_start_time: new Date().toISOString()
        },
        result: 'success'
      });
      
      // Emit real-time update
      if (logId) {
        await this.emitNewSystemLog({ id: logId });
      }
      
      return logId;
    } catch (error) {
      logger.error('Failed to log sync start:', error);
      return null;
    }
  }

  static async logSyncComplete(user, req, syncResult, syncType = 'offline_logs') {
    try {
      const { ip_address, user_agent } = this.extractRequestInfo(req);
      
      const logId = await LogsModel.createLog({
        action_type: 'sync_complete',
        user_id: user.id,
        role: user.role,
        ip_address,
        user_agent,
        details: {
          sync_type: syncType,
          total_items: syncResult.total || 0,
          successful_items: syncResult.synced || syncResult.successful || 0,
          failed_items: syncResult.failed || 0,
          sync_completed_by: user.username,
          sync_completion_time: new Date().toISOString(),
          sync_duration: syncResult.duration || null,
          error_details: syncResult.errors || []
        },
        result: (syncResult.failed || 0) === 0 ? 'success' : 'error'
      });
      
      logger.info(`Sync completed by user ${user.username}: ${syncResult.synced || syncResult.successful}/${syncResult.total} items synced`);
      
      // Emit real-time update
      if (logId) {
        await this.emitNewSystemLog({ id: logId });
      }
      
      return logId;
    } catch (error) {
      logger.error('Failed to log sync completion:', error);
      return null;
    }
  }

  static async logSyncError(user, req, error, syncType = 'offline_logs', itemCount = 0) {
    try {
      const { ip_address, user_agent } = this.extractRequestInfo(req);
      
      const logId = await LogsModel.createLog({
        action_type: 'sync_error',
        user_id: user ? user.id : null,
        role: user ? user.role : null,
        ip_address,
        user_agent,
        details: {
          sync_type: syncType,
          item_count: itemCount,
          sync_attempted_by: user ? user.username : 'unknown',
          error_time: new Date().toISOString(),
          error_details: error.message || error.toString()
        },
        result: 'error',
        error_message: error.message || error.toString()
      });
      
      logger.error(`Sync error for user ${user ? user.username : 'unknown'}: ${error.message}`);
      
      // Emit real-time update
      if (logId) {
        await this.emitNewSystemLog({ id: logId });
      }
    } catch (logError) {
      logger.error('Failed to log sync error:', logError);
    }
  }

  // Enhanced API Error Logging
  static async logUnauthorizedAttempt(req, attemptType = 'access', details = {}) {
    const { ip_address, user_agent } = this.extractRequestInfo(req);
    
    try {
      const logId = await LogsModel.createLog({
        action_type: 'unauthorized_attempt',
        user_id: null,
        role: null,
        ip_address,
        user_agent,
        details: {
          attempt_type: attemptType,
          endpoint: req.originalUrl || req.url,
          method: req.method,
          attempt_time: new Date().toISOString(),
          ...details
        },
        result: 'failure'
      });
      
      // Emit real-time update for security events
      if (logId) {
        await this.emitNewSystemLog({ id: logId });
      }
      
      return logId;
    } catch (error) {
      logger.error('Failed to log unauthorized attempt:', error);
      return null;
    }
  }

  static async logApiError(user, req, error, errorType = 'api_error') {
    try {
      // Check if logs table exists before trying to create a log
      const checkTableQuery = `
        SELECT COUNT(*) as count 
        FROM information_schema.tables 
        WHERE table_schema = ? AND table_name = ?
      `;
      
      const db = require('../config/db');
      const result = await db.executeQuery(checkTableQuery, [process.env.DB_NAME, 'logs']);
      
      if (result[0].count === 0) {
        logger.warn('Logs table does not exist, skipping log creation');
        return null;
      }
      
      const { ip_address, user_agent } = this.extractRequestInfo(req);
      
      // Extract user info if available
      const userId = user ? user.id : null;
      const userRole = user ? user.role : null;
      
      // Format error details
      const errorDetails = {
        error_type: errorType,
        error_name: error.name || null,
        error_code: error.code || null,
        stack_trace: error.stack || null,
        request_path: req ? (req.path || req.originalUrl || null) : null,
        request_method: req ? req.method : null,
        request_params: req ? req.params : null,
        request_query: req ? req.query : null,
        timestamp: new Date().toISOString()
      };
      
      const logId = await LogsModel.createLog({
        action_type: 'api_error',
        user_id: userId,
        role: userRole,
        ip_address,
        user_agent,
        details: errorDetails,
        result: 'error',
        error_message: error.message || 'Unknown error'
      });
      
      // Emit real-time update
      if (logId) {
        await this.emitNewSystemLog({ id: logId });
      }
      
      return logId;
    } catch (logError) {
      logger.error('Failed to log API error:', logError);
      return null;
    }
  }

  // Daily Reset Logging
  static async logDailyReset(resetResult, resetBy, req) {
    const { ip_address, user_agent } = this.extractRequestInfo(req);
    
    try {
      const logId = await LogsModel.createLog({
        action_type: 'reset_daily_passes',
        user_id: resetBy.id,
        role: resetBy.role,
        ip_address,
        user_agent,
        details: {
          reset_by: resetBy.username,
          reset_date: resetResult.date,
          passes_reset: resetResult.passesReset || 0,
          users_affected: resetResult.usersAffected || 0,
          reset_time: new Date().toISOString(),
          action: 'daily_reset'
        },
        result: 'success'
      });
      
      // Emit real-time update
      if (logId) {
        await this.emitNewSystemLog({ id: logId });
      }
    } catch (error) {
      logger.error('Failed to log daily reset:', error);
    }
  }

  static async logResetAllPasses(resetResult, resetBy, req) {
    try {
      const { ip_address, user_agent } = this.extractRequestInfo(req);
      
      const logData = await LogsModel.create({
        action: 'reset_all_passes',
        entity_type: 'pass',
        entity_id: null, // No specific pass ID for reset all
        user_id: resetBy.id,
        details: {
          reset_count: resetResult.reset_count,
          reset_type: 'all',
          reason: resetResult.reason,
          performed_by: resetBy.username,
          timestamp: new Date().toISOString()
        },
        ip_address,
        user_agent
      });

      // Emit new log via WebSocket
      await this.emitNewSystemLog(logData);

      logger.info(`Reset all passes logged: ${resetResult.reset_count} passes reset by ${resetBy.username}`);
    } catch (error) {
      logger.error('Error logging reset all passes:', error);
    }
  }
}

module.exports = LoggingService;