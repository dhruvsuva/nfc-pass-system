const JWTService = require('../config/jwt');
const UserModel = require('../models/user.model');
const logger = require('./logger');
const LoggingService = require('../services/logging.service');

// Utility function to check token expiry
const checkTokenExpiry = (token) => {
  try {
    if (!token || typeof token !== 'string') {
      return { valid: false, expired: false, error: 'Invalid token format' };
    }

    const tokenParts = token.split('.');
    if (tokenParts.length !== 3) {
      return { valid: false, expired: false, error: 'Invalid JWT format' };
    }

    // Decode payload without verification to check expiry
    const payload = JSON.parse(Buffer.from(tokenParts[1], 'base64').toString());
    const currentTime = Math.floor(Date.now() / 1000);
    
    if (payload.exp && payload.exp < currentTime) {
      return { valid: false, expired: true, error: 'Token expired' };
    }

    // Now verify the token properly
    const decoded = JWTService.verifyAccessToken(token);
    return { valid: true, expired: false, decoded };
  } catch (error) {
    if (error.name === 'TokenExpiredError') {
      return { valid: false, expired: true, error: 'Token expired' };
    }
    return { valid: false, expired: false, error: error.message };
  }
};

// Middleware to check token status
const checkTokenStatus = async (req, res, next) => {
  try {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];

    if (!token) {
      return res.status(200).json({
        tokenStatus: 'missing',
        valid: false,
        expired: false,
        message: 'No token provided'
      });
    }

    const tokenCheck = checkTokenExpiry(token);
    
    if (tokenCheck.expired) {
      return res.status(200).json({
        tokenStatus: 'expired',
        valid: false,
        expired: true,
        message: 'Token has expired'
      });
    }

    if (!tokenCheck.valid) {
      return res.status(200).json({
        tokenStatus: 'invalid',
        valid: false,
        expired: false,
        message: tokenCheck.error
      });
    }

    // Check if user still exists
    const user = await UserModel.findById(tokenCheck.decoded.userId);
    if (!user) {
      return res.status(200).json({
        tokenStatus: 'user_not_found',
        valid: false,
        expired: false,
        message: 'User not found'
      });
    }

    if (user.status !== 'active') {
      return res.status(200).json({
        tokenStatus: 'user_inactive',
        valid: false,
        expired: false,
        message: `User status: ${user.status}`,
        userStatus: user.status
      });
    }

    return res.status(200).json({
      tokenStatus: 'valid',
      valid: true,
      expired: false,
      message: 'Token is valid',
      user: {
        id: user.id,
        username: user.username,
        role: user.role,
        status: user.status
      }
    });
  } catch (error) {
    logger.error('Token status check error:', error);
    return res.status(500).json({
      tokenStatus: 'error',
      valid: false,
      expired: false,
      message: 'Error checking token status'
    });
  }
};

// Simple in-memory rate limiting for invalid tokens
const invalidTokenAttempts = new Map();
const INVALID_TOKEN_LIMIT = 10; // Max 10 invalid token attempts per IP per minute
const INVALID_TOKEN_WINDOW = 60 * 1000; // 1 minute

const checkInvalidTokenRateLimit = (ip) => {
  const now = Date.now();
  const attempts = invalidTokenAttempts.get(ip) || { count: 0, resetTime: now + INVALID_TOKEN_WINDOW };
  
  if (now > attempts.resetTime) {
    // Reset the counter
    attempts.count = 1;
    attempts.resetTime = now + INVALID_TOKEN_WINDOW;
  } else {
    attempts.count++;
  }
  
  invalidTokenAttempts.set(ip, attempts);
  
  return attempts.count <= INVALID_TOKEN_LIMIT;
};

// Authentication middleware - verifies JWT token
const authenticateToken = async (req, res, next) => {
  try {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1]; // Bearer TOKEN

    if (!token) {
      // Only log if it's not a preflight request or health check
      const shouldLog = !req.method === 'OPTIONS' && !req.path.includes('/health');
      if (shouldLog) {
        try {
          await LoggingService.logUnauthorizedAttempt(req, 'TOKEN_MISSING', { details: 'No token provided' });
        } catch (logError) {
          logger.error('Failed to log unauthorized attempt:', logError);
        }
      }
      
      return res.status(401).json({ 
        error: 'Access token required',
        code: 'TOKEN_MISSING'
      });
    }

    // Basic token format validation
    if (typeof token !== 'string' || token.trim() === '') {
      // Reduce logging frequency for invalid string tokens
      if (Math.random() < 0.1) { // Log only 10% of these errors
        logger.warn('Invalid token format: token is not a valid string');
      }
      
      return res.status(401).json({ 
        error: 'Invalid token format',
        code: 'TOKEN_INVALID'
      });
    }

    // Check if token has the basic JWT structure (three parts separated by dots)
    const tokenParts = token.split('.');
    if (tokenParts.length !== 3) {
      // Check rate limit for invalid tokens
      const clientIP = req.ip || req.connection.remoteAddress || 'unknown';
      if (!checkInvalidTokenRateLimit(clientIP)) {
        return res.status(429).json({ 
          error: 'Too many invalid token attempts',
          code: 'RATE_LIMIT_EXCEEDED'
        });
      }

      // Reduce logging frequency for malformed tokens to prevent spam
      if (Math.random() < 0.05) { // Log only 5% of these errors
        logger.warn(`Invalid token format: JWT must have 3 parts separated by dots. Received ${tokenParts.length} parts`);
        try {
          await LoggingService.logUnauthorizedAttempt(req, 'TOKEN_INVALID', { 
            details: `JWT must have 3 parts separated by dots. Received ${tokenParts.length} parts`,
            tokenLength: token.length,
            userAgent: req.headers['user-agent']
          });
        } catch (logError) {
          logger.error('Failed to log unauthorized attempt:', logError);
        }
      }
      
      return res.status(401).json({ 
        error: 'Invalid token format',
        code: 'TOKEN_INVALID'
      });
    }

    // Additional validation: check if each part is base64-like
    const isValidBase64Part = (part) => {
      return part && part.length > 0 && /^[A-Za-z0-9_-]+$/.test(part);
    };

    if (!isValidBase64Part(tokenParts[0]) || !isValidBase64Part(tokenParts[1]) || !isValidBase64Part(tokenParts[2])) {
      // Check rate limit for invalid tokens
      const clientIP = req.ip || req.connection.remoteAddress || 'unknown';
      if (!checkInvalidTokenRateLimit(clientIP)) {
        return res.status(429).json({ 
          error: 'Too many invalid token attempts',
          code: 'RATE_LIMIT_EXCEEDED'
        });
      }

      // This is likely a malformed or fake token
      return res.status(401).json({ 
        error: 'Invalid token format',
        code: 'TOKEN_INVALID'
      });
    }

    // Check if token is blacklisted
    try {
      const redisService = require('../services/redis.service');
      const isBlacklisted = await redisService.isTokenBlacklisted(token);
      if (isBlacklisted) {
        logger.info('Blacklisted token used for authentication attempt');
        try {
          await LoggingService.logUnauthorizedAttempt(req, 'TOKEN_BLACKLISTED', { details: 'Token has been blacklisted' });
        } catch (logError) {
          logger.error('Failed to log unauthorized attempt:', logError);
        }
        
        return res.status(401).json({ 
          error: 'Token has been revoked',
          code: 'TOKEN_BLACKLISTED'
        });
      }
    } catch (blacklistError) {
      logger.error('Error checking token blacklist:', blacklistError);
      // Continue with normal verification if blacklist check fails
    }

    // Wrap JWT verification in try-catch to handle malformed tokens
    let decoded;
    try {
      decoded = JWTService.verifyAccessToken(token);
    } catch (jwtError) {
      // Reduce logging frequency for JWT errors to prevent spam
      const shouldLogError = Math.random() < 0.2; // Log only 20% of JWT errors
      
      if (jwtError.name === 'TokenExpiredError') {
        if (shouldLogError) {
          logger.info('JWT token expired for user request');
          try {
            await LoggingService.logUnauthorizedAttempt(req, 'TOKEN_EXPIRED', { details: 'JWT token expired' });
          } catch (logError) {
            logger.error('Failed to log unauthorized attempt:', logError);
          }
        }
        
        // Set special headers for auto logout
        res.set({
          'X-Auth-Status': 'TOKEN_EXPIRED',
          'X-Auto-Logout': 'true',
          'X-Logout-Reason': 'Token has expired'
        });
        
        return res.status(401).json({ 
          error: 'Token expired',
          code: 'TOKEN_EXPIRED',
          autoLogout: true,
          message: 'Your session has expired. Please login again.',
          timestamp: new Date().toISOString()
        });
      }
      
      if (jwtError.name === 'JsonWebTokenError') {
        if (shouldLogError) {
          logger.warn(`JWT verification failed: ${jwtError.message}`);
          try {
            await LoggingService.logUnauthorizedAttempt(req, 'TOKEN_INVALID', { 
              details: `Invalid JWT token: ${jwtError.message}`,
              userAgent: req.headers['user-agent']
            });
          } catch (logError) {
            logger.error('Failed to log unauthorized attempt:', logError);
          }
        }
        
        return res.status(401).json({ 
          error: 'Invalid token',
          code: 'TOKEN_INVALID'
        });
      }
      
      // For any other JWT errors
      if (shouldLogError) {
        logger.error('JWT verification failed:', jwtError);
        try {
          await LoggingService.logUnauthorizedAttempt(req, 'TOKEN_ERROR', { 
            details: `JWT error: ${jwtError.message}`,
            errorType: jwtError.name
          });
        } catch (logError) {
          logger.error('Failed to log unauthorized attempt:', logError);
        }
      }
      
      return res.status(401).json({ 
        error: 'Token verification failed',
        code: 'TOKEN_ERROR'
      });
    }
    
    // Verify user still exists and is active
    const user = await UserModel.findById(decoded.userId);
    if (!user) {
      // Log unauthorized attempt for non-existent user
      try {
        await LoggingService.logUnauthorizedAttempt(req, 'USER_NOT_FOUND', { details: `User ID ${decoded.userId} not found` });
      } catch (logError) {
        logger.error('Failed to log unauthorized attempt:', logError);
      }
      
      return res.status(401).json({ 
        error: 'User not found',
        code: 'USER_NOT_FOUND'
      });
    }
    
    // Check if user is blocked - return 403 Forbidden
    if (user.status === 'blocked') {
      logger.warn(`Blocked user ${user.username} (ID: ${user.id}) attempted access`);
      
      // Log unauthorized attempt for blocked user
      try {
        await LoggingService.logUnauthorizedAttempt(req, 'USER_BLOCKED', { 
          details: `User is blocked. Reason: ${user.block_reason || 'No reason provided'}`,
          user_id: user.id,
          username: user.username
        });
      } catch (logError) {
        logger.error('Failed to log unauthorized attempt:', logError);
      }
      
      return res.status(403).json({ 
        error: 'Your account has been blocked by Admin',
        code: 'USER_BLOCKED',
        userStatus: user.status,
        blockReason: user.block_reason,
        blockedAt: user.blocked_at,
        blockedBy: user.blocked_by
      });
    }
    
    // Check if user is active
    if (user.status !== 'active') {
      logger.warn(`User ${user.username} (ID: ${user.id}) has status: ${user.status}`);
      
      // Log unauthorized attempt for inactive user
      try {
        await LoggingService.logUnauthorizedAttempt(req, 'USER_INACTIVE', { 
          details: `User status: ${user.status}`,
          user_id: user.id,
          username: user.username
        });
      } catch (logError) {
        logger.error('Failed to log unauthorized attempt:', logError);
      }
      
      return res.status(401).json({ 
        error: 'User account is not active',
        code: 'USER_INACTIVE',
        userStatus: user.status
      });
    }

    // Add user info to request
    req.user = {
      id: user.id,
      username: user.username,
      role: user.role,
      status: user.status,
      assigned_category: user.assigned_category,
    };

    next();
  } catch (error) {
    logger.error('Authentication error:', error);
    
    // Log API error for authentication failure
    try {
      await LoggingService.logApiError(null, req, error, 'authentication');
    } catch (logError) {
      logger.error('Failed to log API error:', logError);
    }

    return res.status(500).json({ 
      error: 'Authentication failed',
      code: 'AUTH_ERROR'
    });
  }
};

// Authorization middleware - checks user roles
const authorizeRoles = (...allowedRoles) => {
  return async (req, res, next) => {
    try {
      if (!req.user) {
        return res.status(401).json({ 
          error: 'Authentication required',
          code: 'AUTH_REQUIRED'
        });
      }

      if (!allowedRoles.includes(req.user.role)) {
        logger.warn(`Access denied for user ${req.user.username} with role ${req.user.role}. Required roles: ${allowedRoles.join(', ')}`);
        
        // Log unauthorized attempt for insufficient permissions
        await LoggingService.logUnauthorizedAttempt(
          req.user, 
          req, 
          'INSUFFICIENT_PERMISSIONS', 
          `User role '${req.user.role}' not in allowed roles: ${allowedRoles.join(', ')}`
        );
        
        return res.status(403).json({ 
          error: 'Insufficient permissions',
          code: 'INSUFFICIENT_PERMISSIONS',
          requiredRoles: allowedRoles,
          userRole: req.user.role
        });
      }

      next();
    } catch (error) {
      logger.error('Authorization error:', error);
      
      // Log API error for authorization failure
      await LoggingService.logApiError(req.user || null, req, error, 'authorization');
      
      return res.status(500).json({ 
        error: 'Authorization failed',
        code: 'AUTH_ERROR'
      });
    }
  };
};

// Admin only middleware
const adminOnly = authorizeRoles('admin');

// Admin and Manager middleware
const adminOrManager = authorizeRoles('admin', 'manager');

// All authenticated users (admin, manager, bouncer)
const allRoles = authorizeRoles('admin', 'manager', 'bouncer');

// Optional authentication - doesn't fail if no token provided
const optionalAuth = async (req, res, next) => {
  try {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];

    if (!token) {
      req.user = null;
      return next();
    }

    const decoded = JWTService.verifyAccessToken(token);
    const user = await UserModel.findById(decoded.userId);
    
    if (user) {
      req.user = {
        id: user.id,
        username: user.username,
        role: user.role,
        status: user.status
      };
    } else {
      req.user = null;
    }

    next();
  } catch (error) {
    // For optional auth, we don't fail on token errors
    req.user = null;
    next();
  }
};

// Middleware to check if user can access specific resource
const checkResourceAccess = (resourceType) => {
  return async (req, res, next) => {
    try {
      const user = req.user;
      
      if (!user) {
        return res.status(401).json({ 
          error: 'Authentication required',
          code: 'AUTH_REQUIRED'
        });
      }

      // Admin can access everything
      if (user.role === 'admin') {
        return next();
      }

      // Manager can access most resources
      if (user.role === 'manager') {
        // Managers cannot access user management or system settings
        if (resourceType === 'user_management' || resourceType === 'system_settings') {
          return res.status(403).json({ 
            error: 'Insufficient permissions for this resource',
            code: 'INSUFFICIENT_PERMISSIONS'
          });
        }
        return next();
      }

      // Bouncer can only access verification and logs
      if (user.role === 'bouncer') {
        if (resourceType === 'verification' || resourceType === 'logs_read') {
          return next();
        }
        return res.status(403).json({ 
          error: 'Insufficient permissions for this resource',
          code: 'INSUFFICIENT_PERMISSIONS'
        });
      }

      return res.status(403).json({ 
        error: 'Unknown role',
        code: 'UNKNOWN_ROLE'
      });
    } catch (error) {
      logger.error('Resource access check error:', error);
      return res.status(500).json({ 
        error: 'Authorization failed',
        code: 'AUTH_ERROR'
      });
    }
  };
};

// Audit logging middleware
const auditLog = (action) => {
  return (req, res, next) => {
    const originalSend = res.send;
    
    res.send = function(data) {
      // Log the action after response is sent
      setImmediate(() => {
        logger.info('Audit Log', {
          action,
          user: req.user ? {
            id: req.user.id,
            username: req.user.username,
            role: req.user.role
          } : null,
          method: req.method,
          url: req.originalUrl,
          ip: req.ip,
          userAgent: req.get('User-Agent'),
          statusCode: res.statusCode,
          timestamp: new Date().toISOString()
        });
      });
      
      originalSend.call(this, data);
    };
    
    next();
  };
};

module.exports = {
  authenticateToken,
  authorizeRoles,
  adminOnly,
  adminOrManager,
  allRoles,
  optionalAuth,
  checkResourceAccess,
  auditLog,
  checkTokenExpiry,
  checkTokenStatus
};