const logger = require('../utils/logger');

module.exports = (socket, io) => {
  // Handle system logs related events
  const handleSystemLogsEvents = () => {
    logger.debug(`System logs handler initialized for socket: ${socket.id}`);
    
    // Join system logs room for real-time updates
    socket.on('join:system-logs', (data) => {
      try {
        // Allow admin, manager, and bouncer roles to join system logs room
        if (socket.user && ['admin', 'manager', 'bouncer'].includes(socket.user.role)) {
          // Join general system logs room
          socket.join('system-logs');
          
          // Join role-specific room for filtered updates
          socket.join(`system-logs:${socket.user.role}`);
          
          logger.info(`User ${socket.user.username} (${socket.user.role}) joined system-logs room`);
          
          socket.emit('system-logs:joined', {
            message: 'Successfully joined system logs updates',
            role: socket.user.role,
            timestamp: new Date().toISOString()
          });
        } else {
          socket.emit('system-logs:error', {
            message: 'Unauthorized to join system logs updates',
            code: 'UNAUTHORIZED',
            timestamp: new Date().toISOString()
          });
        }
      } catch (error) {
        logger.error('Error joining system logs room:', error);
        socket.emit('system-logs:error', {
          message: 'Failed to join system logs updates',
          code: 'JOIN_ERROR',
          timestamp: new Date().toISOString()
        });
      }
    });
    
    // Leave system logs room
    socket.on('leave:system-logs', () => {
      try {
        socket.leave('system-logs');
        if (socket.user) {
          logger.info(`User ${socket.user.username} left system-logs room`);
        }
        
        socket.emit('system-logs:left', {
          message: 'Successfully left system logs updates',
          timestamp: new Date().toISOString()
        });
      } catch (error) {
        logger.error('Error leaving system logs room:', error);
      }
    });
  };

  // Emit new system log with role-based filtering
  const emitNewSystemLog = (logData) => {
    try {
      // Admin sees all logs
      io.to('system-logs:admin').emit('system-logs:new', {
        log: logData,
        timestamp: new Date().toISOString()
      });
      
      // Manager and Bouncer see only relevant logs based on action type
      const relevantForManagerBouncer = [
        'login', 'logout', 'token_refresh',
        'pass_create', 'pass_verify', 'pass_reset', 'pass_bulk_create', 
        'pass_delete', 'pass_block', 'pass_unblock',
        'reset_single_pass', 'reset_daily_passes',
        'sync_start', 'sync_complete',
        'unauthorized_attempt'
      ];
      
      if (relevantForManagerBouncer.includes(logData.action_type)) {
        // Manager sees pass-related and user activity logs
        io.to('system-logs:manager').emit('system-logs:new', {
          log: logData,
          timestamp: new Date().toISOString()
        });
        
        // Bouncer sees only pass verification and basic activity logs
        const relevantForBouncer = [
          'login', 'logout', 'pass_verify', 'pass_reset',
          'unauthorized_attempt'
        ];
        
        if (relevantForBouncer.includes(logData.action_type)) {
          io.to('system-logs:bouncer').emit('system-logs:new', {
            log: logData,
            timestamp: new Date().toISOString()
          });
        }
      }
      
      // Also emit to general role-based rooms for backward compatibility
      io.to('role:admin').emit('system-logs:new', {
        log: logData,
        timestamp: new Date().toISOString()
      });
      
      logger.debug(`New system log emitted: ${logData.action_type} by user ${logData.user_id || 'system'}`);
    } catch (error) {
      logger.error('Error emitting new system log:', error);
    }
  };

  // Emit system log update with role-based filtering
  const emitSystemLogUpdate = (logData) => {
    try {
      // Admin sees all log updates
      io.to('system-logs:admin').emit('system-logs:updated', {
        log: logData,
        timestamp: new Date().toISOString()
      });
      
      // Apply same filtering logic as new logs
      const relevantForManagerBouncer = [
        'login', 'logout', 'token_refresh',
        'pass_create', 'pass_verify', 'pass_reset', 'pass_bulk_create', 
        'pass_delete', 'pass_block', 'pass_unblock',
        'reset_single_pass', 'reset_daily_passes',
        'sync_start', 'sync_complete',
        'unauthorized_attempt'
      ];
      
      if (relevantForManagerBouncer.includes(logData.action_type)) {
        io.to('system-logs:manager').emit('system-logs:updated', {
          log: logData,
          timestamp: new Date().toISOString()
        });
        
        const relevantForBouncer = [
          'login', 'logout', 'pass_verify', 'pass_reset',
          'unauthorized_attempt'
        ];
        
        if (relevantForBouncer.includes(logData.action_type)) {
          io.to('system-logs:bouncer').emit('system-logs:updated', {
            log: logData,
            timestamp: new Date().toISOString()
          });
        }
      }
      
      // Backward compatibility
      io.to('role:admin').emit('system-logs:updated', {
        log: logData,
        timestamp: new Date().toISOString()
      });
      
      logger.debug(`System log update emitted: ID ${logData.id}`);
    } catch (error) {
      logger.error('Error emitting system log update:', error);
    }
  };

  // Emit system logs statistics update with role-based filtering
  const emitSystemLogsStats = (statsData) => {
    try {
      // Admin gets full stats
      io.to('system-logs:admin').emit('system-logs:stats', {
        stats: statsData,
        timestamp: new Date().toISOString()
      });
      
      // Manager gets filtered stats (no user management stats)
      const managerStats = { ...statsData };
      if (managerStats.user_management) {
        delete managerStats.user_management;
      }
      if (managerStats.category_management) {
        delete managerStats.category_management;
      }
      
      io.to('system-logs:manager').emit('system-logs:stats', {
        stats: managerStats,
        timestamp: new Date().toISOString()
      });
      
      // Bouncer gets minimal stats (only pass-related)
      const bouncerStats = {
        pass_operations: statsData.pass_operations || {},
        login_activity: statsData.login_activity || {},
        total_logs: statsData.total_logs || 0
      };
      
      io.to('system-logs:bouncer').emit('system-logs:stats', {
        stats: bouncerStats,
        timestamp: new Date().toISOString()
      });
      
      // Backward compatibility
      io.to('role:admin').emit('system-logs:stats', {
        stats: statsData,
        timestamp: new Date().toISOString()
      });
      
      logger.debug('System logs stats emitted with role-based filtering');
    } catch (error) {
      logger.error('Error emitting system logs stats:', error);
    }
  };

  // Initialize the handler
  handleSystemLogsEvents();

  // Return methods for external use
  return {
    emitNewSystemLog,
    emitSystemLogUpdate,
    emitSystemLogsStats
  };
};