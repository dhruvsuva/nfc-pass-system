const logger = require('../utils/logger');

module.exports = (socket, io) => {
  // Handle pass-related notifications
  const handlePassNotifications = () => {
    // These events are typically emitted from controllers/services
    // This module sets up the infrastructure for handling them
    
    logger.debug(`Notifications handler initialized for socket: ${socket.id}`);
  };

  // Emit pass blocked notification
  const emitPassBlocked = (data) => {
    try {
      // Emit to all connected admin and manager users
      io.to('role:admin').emit('pass:blocked', {
        ...data,
        timestamp: new Date().toISOString()
      });
      
      io.to('role:manager').emit('pass:blocked', {
        ...data,
        timestamp: new Date().toISOString()
      });
      
      // Also emit to general notifications room
      io.to('notifications').emit('pass:blocked', {
        ...data,
        timestamp: new Date().toISOString()
      });
      
      logger.info(`Pass blocked notification sent: UID=${data.uid}`);
    } catch (error) {
      logger.error('Error emitting pass blocked notification:', error);
    }
  };

  // Emit pass unblocked notification
  const emitPassUnblocked = (data) => {
    try {
      // Emit to all connected admin and manager users
      io.to('role:admin').emit('pass:unblocked', {
        ...data,
        timestamp: new Date().toISOString()
      });
      
      io.to('role:manager').emit('pass:unblocked', {
        ...data,
        timestamp: new Date().toISOString()
      });
      
      // Also emit to general notifications room
      io.to('notifications').emit('pass:unblocked', {
        ...data,
        timestamp: new Date().toISOString()
      });
      
      logger.info(`Pass unblocked notification sent: UID=${data.uid}`);
    } catch (error) {
      logger.error('Error emitting pass unblocked notification:', error);
    }
  };

  // Emit pass reset notification
  const emitPassReset = (data) => {
    try {
      // Emit to all connected admin and manager users
      io.to('role:admin').emit('pass:reset', {
        ...data,
        timestamp: new Date().toISOString()
      });
      
      io.to('role:manager').emit('pass:reset', {
        ...data,
        timestamp: new Date().toISOString()
      });
      
      // Also emit to general notifications room
      io.to('notifications').emit('pass:reset', {
        ...data,
        timestamp: new Date().toISOString()
      });
      
      logger.info(`Pass reset notification sent: UID=${data.uid}`);
    } catch (error) {
      logger.error('Error emitting pass reset notification:', error);
    }
  };

  // Emit daily reset notification
  const emitDailyReset = (data) => {
    try {
      // Emit to all connected admin users
      io.to('role:admin').emit('daily:reset', {
        ...data,
        timestamp: new Date().toISOString()
      });
      
      // Emit to manager users
      io.to('role:manager').emit('daily:reset', {
        ...data,
        timestamp: new Date().toISOString()
      });
      
      // Also emit to admin notifications room
      io.to('admin:notifications').emit('daily:reset', {
        ...data,
        timestamp: new Date().toISOString()
      });
      
      logger.info(`Daily reset notification sent: date=${data.date}, resetCount=${data.resetCount}`);
    } catch (error) {
      logger.error('Error emitting daily reset notification:', error);
    }
  };

  // Emit system alert notification
  const emitSystemAlert = (data) => {
    try {
      const alertData = {
        ...data,
        timestamp: new Date().toISOString(),
        id: require('uuid').v4()
      };
      
      // Emit to admin users for critical alerts
      if (data.level === 'critical' || data.level === 'error') {
        io.to('role:admin').emit('system:alert', alertData);
      }
      
      // Emit to manager users for warnings and above
      if (['critical', 'error', 'warning'].includes(data.level)) {
        io.to('role:manager').emit('system:alert', alertData);
      }
      
      // Emit to admin notifications room
      io.to('admin:notifications').emit('system:alert', alertData);
      
      logger.info(`System alert notification sent: level=${data.level}, message=${data.message}`);
    } catch (error) {
      logger.error('Error emitting system alert notification:', error);
    }
  };

  // Emit cache rebuild notification
  const emitCacheRebuilt = (data) => {
    try {
      const cacheData = {
        ...data,
        timestamp: new Date().toISOString()
      };
      
      // Emit to admin users
      io.to('role:admin').emit('cache:rebuilt', cacheData);
      
      // Emit to admin notifications room
      io.to('admin:notifications').emit('cache:rebuilt', cacheData);
      
      logger.info(`Cache rebuilt notification sent: activeCount=${data.activeCount}, blockedCount=${data.blockedCount}`);
    } catch (error) {
      logger.error('Error emitting cache rebuilt notification:', error);
    }
  };

  // Emit verification stats update
  const emitVerificationStats = (data) => {
    try {
      const statsData = {
        ...data,
        timestamp: new Date().toISOString()
      };
      
      // Emit to admin and manager users
      io.to('role:admin').emit('verification:stats', statsData);
      io.to('role:manager').emit('verification:stats', statsData);
      
      logger.debug('Verification stats notification sent');
    } catch (error) {
      logger.error('Error emitting verification stats notification:', error);
    }
  };

  // Handle real-time verification updates (for monitoring dashboards)
  const emitVerificationUpdate = (data) => {
    try {
      const verificationData = {
        uid: data.uid,
        result: data.result,
        scanned_by: data.scanned_by,
        timestamp: data.timestamp || new Date().toISOString()
      };
      
      // Emit to admin and manager users for monitoring
      io.to('role:admin').emit('verification:update', verificationData);
      io.to('role:manager').emit('verification:update', verificationData);
      
      logger.debug(`Verification update sent: UID=${data.uid}, Result=${data.result}`);
    } catch (error) {
      logger.error('Error emitting verification update:', error);
    }
  };

  // Handle user activity notifications
  const emitUserActivity = (data) => {
    try {
      const activityData = {
        ...data,
        timestamp: new Date().toISOString()
      };
      
      // Emit to admin users for user activity monitoring
      io.to('role:admin').emit('user:activity', activityData);
      
      logger.debug(`User activity notification sent: ${data.action} by ${data.username}`);
    } catch (error) {
      logger.error('Error emitting user activity notification:', error);
    }
  };

  // Gate subscription functionality removed as gates are no longer used

  // Get current notification settings
  socket.on('notifications:settings', (data) => {
    try {
      if (!socket.user) {
        socket.emit('error', { error: 'Authentication required' });
        return;
      }
      
      // Return user's notification preferences
      const settings = {
        pass_updates: true,
        verification_updates: socket.user.role !== 'bouncer',
        system_alerts: ['admin', 'manager'].includes(socket.user.role),
        daily_reset: socket.user.role === 'admin',
        bulk_operations: ['admin', 'manager'].includes(socket.user.role)
      };
      
      socket.emit('notifications:settings:response', settings);
      
    } catch (error) {
      logger.error('Notification settings error:', error);
      socket.emit('notifications:settings:error', { error: 'Failed to get notification settings' });
    }
  });

  // Initialize notifications handler
  handlePassNotifications();

  // Expose notification emitters for use by other modules
  socket.notificationEmitters = {
    emitPassBlocked,
    emitPassUnblocked,
    emitPassReset,
    emitDailyReset,
    emitSystemAlert,
    emitCacheRebuilt,
    emitVerificationStats,
    emitVerificationUpdate,
    emitUserActivity
  };

  // Store reference to io for global notifications
  socket.io = io;
};