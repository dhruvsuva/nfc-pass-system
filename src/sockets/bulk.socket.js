const bulkService = require('../services/bulk.service');
const JWTService = require('../config/jwt');
const UserModel = require('../models/user.model');
const logger = require('../utils/logger');

module.exports = (socket, io) => {
  // Authenticate socket connection
  socket.on('authenticate', async (data) => {
    try {
      const { token } = data;
      
      if (!token) {
        socket.emit('auth:error', { error: 'Token required' });
        return;
      }

      const decoded = JWTService.verifyAccessToken(token);
      const user = await UserModel.findById(decoded.userId);
      
      if (!user) {
        socket.emit('auth:error', { error: 'User not found' });
        return;
      }

      // Store user info in socket
      socket.user = {
        id: user.id,
        username: user.username,
        role: user.role,
        status: user.status
      };

      // Join role-based rooms
      socket.join(`role:${user.role}`);
      socket.join(`user:${user.id}`);

      socket.emit('auth:success', {
        user: socket.user,
        rooms: [`role:${user.role}`, `user:${user.id}`]
      });

      logger.info(`Socket authenticated: ${user.username} (${socket.id})`);
      
    } catch (error) {
      logger.error('Socket authentication error:', error);
      socket.emit('auth:error', { error: 'Authentication failed' });
    }
  });

  // Check authentication middleware
  const requireAuth = (callback) => {
    return (...args) => {
      if (!socket.user) {
        socket.emit('error', { error: 'Authentication required' });
        return;
      }
      callback(...args);
    };
  };

  // Check role permissions
  const requireRole = (allowedRoles) => {
    return (callback) => {
      return (...args) => {
        if (!socket.user) {
          socket.emit('error', { error: 'Authentication required' });
          return;
        }
        
        if (!allowedRoles.includes(socket.user.role)) {
          socket.emit('error', { 
            error: 'Insufficient permissions',
            requiredRoles: allowedRoles,
            userRole: socket.user.role
          });
          return;
        }
        
        callback(...args);
      };
    };
  };

  // Bulk pass creation via WebSocket
  socket.on('bulk:create:start', requireAuth(requireRole(['admin', 'manager'])(async (data) => {
    try {
      const { passes } = data;
      
      if (!passes || !Array.isArray(passes)) {
        socket.emit('bulk:create:error', {
          error: 'Invalid passes data - must be an array'
        });
        return;
      }

      if (passes.length === 0) {
        socket.emit('bulk:create:error', {
          error: 'No passes provided'
        });
        return;
      }

      if (passes.length > 10000) {
        socket.emit('bulk:create:error', {
          error: 'Too many passes - maximum 10,000 per bulk operation'
        });
        return;
      }

      // Check if we can start a new bulk operation
      const canStart = await bulkService.canStartNewBulkOperation();
      if (!canStart) {
        socket.emit('bulk:create:error', {
          error: 'Maximum concurrent bulk operations reached. Please try again later.'
        });
        return;
      }

      logger.info(`Starting WebSocket bulk creation: ${passes.length} passes from ${socket.user.username}`);
      
      // Start bulk creation
      const result = await bulkService.createBulkPassesWebSocket(
        socket,
        passes,
        socket.user.id
      );
      
      logger.info(`WebSocket bulk creation completed: bulkId=${result.bulkId}`);
      
    } catch (error) {
      logger.error('Bulk creation WebSocket error:', error);
      socket.emit('bulk:create:error', {
        error: error.message || 'Bulk creation failed'
      });
    }
  })));

  // Get bulk operation status
  socket.on('bulk:status', requireAuth((data) => {
    try {
      const { bulkId } = data;
      
      if (!bulkId) {
        socket.emit('bulk:status:error', { error: 'Bulk ID required' });
        return;
      }

      const operation = bulkService.getBulkOperationStatus(bulkId);
      
      if (!operation) {
        socket.emit('bulk:status:error', { error: 'Bulk operation not found' });
        return;
      }

      socket.emit('bulk:status:response', {
        bulkId,
        status: operation.status,
        total: operation.total,
        processed: operation.processed,
        created: operation.created,
        duplicates: operation.duplicates,
        errorCount: operation.errors.length,
        progressPercent: Math.round((operation.processed / operation.total) * 100),
        duration: operation.endTime ? 
          operation.endTime - operation.startTime : 
          Date.now() - operation.startTime
      });
      
    } catch (error) {
      logger.error('Bulk status error:', error);
      socket.emit('bulk:status:error', { error: 'Failed to get bulk status' });
    }
  }));

  // Cancel bulk operation
  socket.on('bulk:cancel', requireAuth(requireRole(['admin', 'manager'])(async (data) => {
    try {
      const { bulkId } = data;
      
      if (!bulkId) {
        socket.emit('bulk:cancel:error', { error: 'Bulk ID required' });
        return;
      }

      const cancelled = bulkService.cancelBulkOperation(bulkId);
      
      if (cancelled) {
        socket.emit('bulk:cancel:success', { bulkId });
        logger.info(`Bulk operation cancelled: ${bulkId} by ${socket.user.username}`);
      } else {
        socket.emit('bulk:cancel:error', { 
          error: 'Bulk operation not found or cannot be cancelled' 
        });
      }
      
    } catch (error) {
      logger.error('Bulk cancel error:', error);
      socket.emit('bulk:cancel:error', { error: 'Failed to cancel bulk operation' });
    }
  })));

  // Get all active bulk operations (admin/manager only)
  socket.on('bulk:list', requireAuth(requireRole(['admin', 'manager'])(() => {
    try {
      const operations = bulkService.getAllActiveBulkOperations();
      
      socket.emit('bulk:list:response', {
        operations,
        count: operations.length
      });
      
    } catch (error) {
      logger.error('Bulk list error:', error);
      socket.emit('bulk:list:error', { error: 'Failed to get bulk operations list' });
    }
  })));

  // Join specific rooms for targeted notifications
  socket.on('join:room', requireAuth((data) => {
    try {
      const { room } = data;
      
      // Validate room name and permissions
      const allowedRooms = [
        'notifications',
        'pass:updates',
        'admin:notifications',
        'manager:notifications'
      ];
      
      if (!allowedRooms.includes(room)) {
        socket.emit('join:room:error', { error: 'Invalid room name' });
        return;
      }
      
      // Check permissions for admin/manager rooms
      if (room.includes('admin') && socket.user.role !== 'admin') {
        socket.emit('join:room:error', { error: 'Admin permissions required' });
        return;
      }
      
      if (room.includes('manager') && !['admin', 'manager'].includes(socket.user.role)) {
        socket.emit('join:room:error', { error: 'Manager permissions required' });
        return;
      }
      
      socket.join(room);
      socket.emit('join:room:success', { room });
      
      logger.debug(`Socket ${socket.id} joined room: ${room}`);
      
    } catch (error) {
      logger.error('Join room error:', error);
      socket.emit('join:room:error', { error: 'Failed to join room' });
    }
  }));

  // Leave room
  socket.on('leave:room', requireAuth((data) => {
    try {
      const { room } = data;
      
      socket.leave(room);
      socket.emit('leave:room:success', { room });
      
      logger.debug(`Socket ${socket.id} left room: ${room}`);
      
    } catch (error) {
      logger.error('Leave room error:', error);
      socket.emit('leave:room:error', { error: 'Failed to leave room' });
    }
  }));

  // Handle disconnection
  socket.on('disconnect', () => {
    if (socket.user) {
      logger.info(`Socket disconnected: ${socket.user.username} (${socket.id})`);
    } else {
      logger.debug(`Unauthenticated socket disconnected: ${socket.id}`);
    }
  });

  // Handle connection errors
  socket.on('error', (error) => {
    logger.error('Socket error:', error);
  });

  // Send welcome message
  socket.emit('connected', {
    message: 'Connected to NFC Pass System',
    socketId: socket.id,
    timestamp: new Date().toISOString()
  });
};