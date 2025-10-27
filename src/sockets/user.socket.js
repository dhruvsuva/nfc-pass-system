const logger = require('../utils/logger');

/**
 * User Management Socket Events
 * Handles real-time events for user management operations
 */
class UserSocket {
  constructor(io) {
    this.io = io;
    this.setupEventHandlers();
  }
  
  setupEventHandlers() {
    this.io.on('connection', (socket) => {
      logger.info(`User connected to user management socket: ${socket.id}`);
      
      // Join admin room for user management events
      socket.on('join:admin', (data) => {
        if (data.user && data.user.role === 'admin') {
          socket.join('admin_room');
          logger.info(`Admin ${data.user.username} joined admin room`);
          
          socket.emit('joined:admin', {
            success: true,
            message: 'Joined admin room successfully'
          });
        } else {
          socket.emit('error', {
            message: 'Unauthorized: Admin access required'
          });
        }
      });
      
      // Leave admin room
      socket.on('leave:admin', () => {
        socket.leave('admin_room');
        logger.info(`Socket ${socket.id} left admin room`);
      });
      
      // Handle user status requests
      socket.on('user:status:request', (data) => {
        if (data.userId) {
          // Emit user status to requesting socket
          socket.emit('user:status:response', {
            userId: data.userId,
            status: 'active', // This would be fetched from database
            timestamp: new Date().toISOString()
          });
        }
      });
      
      // Handle disconnect
      socket.on('disconnect', () => {
        logger.info(`User disconnected from user management socket: ${socket.id}`);
      });
    });
  }
  
  // Emit user created event
  emitUserCreated(userData, createdBy) {
    this.io.to('admin_room').emit('user:created', {
      user: {
        id: userData.id,
        username: userData.username,
        role: userData.role,
        status: userData.status,
        createdAt: userData.createdAt
      },
      createdBy: createdBy.username,
      timestamp: new Date().toISOString()
    });
    
    logger.info(`User created event emitted: ${userData.username} by ${createdBy.username}`);
  }
  
  // Emit user updated event
  emitUserUpdated(userData, updatedBy, changes) {
    this.io.to('admin_room').emit('user:updated', {
      user: {
        id: userData.id,
        username: userData.username,
        role: userData.role,
        status: userData.status,
        updatedAt: userData.updatedAt
      },
      updatedBy: updatedBy.username,
      changes,
      timestamp: new Date().toISOString()
    });
    
    logger.info(`User updated event emitted: ${userData.username} by ${updatedBy.username}`);
  }
  
  // Emit user deleted event
  emitUserDeleted(userData, deletedBy) {
    this.io.to('admin_room').emit('user:deleted', {
      user: {
        id: userData.id,
        username: userData.username,
        role: userData.role
      },
      deletedBy: deletedBy.username,
      timestamp: new Date().toISOString()
    });
    
    logger.info(`User deleted event emitted: ${userData.username} by ${deletedBy.username}`);
  }
  
  // Emit user blocked event
  emitUserBlocked(userData, blockedBy, reason) {
    // Emit to admin room
    this.io.to('admin_room').emit('user:blocked', {
      user: {
        id: userData.id,
        username: userData.username,
        role: userData.role
      },
      blockedBy: blockedBy.username,
      reason: reason || 'No reason provided',
      timestamp: new Date().toISOString()
    });
    
    // Emit to the blocked user if they're connected
    this.io.emit('user:blocked:self', {
      userId: userData.id,
      message: 'Your account has been blocked',
      reason: reason || 'No reason provided',
      timestamp: new Date().toISOString()
    });
    
    logger.info(`User blocked event emitted: ${userData.username} by ${blockedBy.username}`);
  }
  
  // Emit user unblocked event
  emitUserUnblocked(userData, unblockedBy) {
    // Emit to admin room
    this.io.to('admin_room').emit('user:unblocked', {
      user: {
        id: userData.id,
        username: userData.username,
        role: userData.role
      },
      unblockedBy: unblockedBy.username,
      timestamp: new Date().toISOString()
    });
    
    // Emit to the unblocked user if they're connected
    this.io.emit('user:unblocked:self', {
      userId: userData.id,
      message: 'Your account has been unblocked',
      timestamp: new Date().toISOString()
    });
    
    logger.info(`User unblocked event emitted: ${userData.username} by ${unblockedBy.username}`);
  }
  
  // Emit user role changed event
  emitUserRoleChanged(userData, changedBy, oldRole, newRole) {
    this.io.to('admin_room').emit('user:role:changed', {
      user: {
        id: userData.id,
        username: userData.username,
        role: newRole
      },
      changedBy: changedBy.username,
      oldRole,
      newRole,
      timestamp: new Date().toISOString()
    });
    
    // Emit to the user whose role changed
    this.io.emit('user:role:changed:self', {
      userId: userData.id,
      message: `Your role has been changed from ${oldRole} to ${newRole}`,
      oldRole,
      newRole,
      timestamp: new Date().toISOString()
    });
    
    logger.info(`User role changed event emitted: ${userData.username} from ${oldRole} to ${newRole} by ${changedBy.username}`);
  }
  
  // Emit user statistics update
  emitUserStatsUpdate(stats) {
    this.io.to('admin_room').emit('user:stats:update', {
      stats,
      timestamp: new Date().toISOString()
    });
    
    logger.info('User statistics update emitted');
  }
  
  // Emit bulk user operation progress
  emitBulkUserProgress(operationType, progress, total, completed) {
    this.io.to('admin_room').emit('user:bulk:progress', {
      operationType,
      progress: {
        total,
        completed,
        percentage: Math.round((completed / total) * 100)
      },
      timestamp: new Date().toISOString()
    });
  }
  
  // Emit bulk user operation completion
  emitBulkUserComplete(operationType, results) {
    this.io.to('admin_room').emit('user:bulk:complete', {
      operationType,
      results: {
        total: results.total,
        successful: results.successful,
        failed: results.failed,
        errors: results.errors
      },
      timestamp: new Date().toISOString()
    });
    
    logger.info(`Bulk user operation completed: ${operationType}`);
  }
  
  // Force disconnect user (for blocked users)
  forceDisconnectUser(userId) {
    this.io.emit('user:force:disconnect', {
      userId,
      message: 'Your session has been terminated',
      timestamp: new Date().toISOString()
    });
    
    logger.info(`Force disconnect emitted for user: ${userId}`);
  }
  
  // Emit system maintenance notification
  emitMaintenanceNotification(message, scheduledTime) {
    this.io.emit('system:maintenance', {
      message,
      scheduledTime,
      timestamp: new Date().toISOString()
    });
    
    logger.info('System maintenance notification emitted');
  }
}

module.exports = UserSocket;