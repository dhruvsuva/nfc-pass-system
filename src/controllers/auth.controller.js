const express = require('express');
const { body, validationResult } = require('express-validator');
const rateLimit = require('express-rate-limit');
const UserModel = require('../models/user.model');
const JWTService = require('../config/jwt');
const logger = require('../utils/logger');
const { auditLog, checkTokenStatus } = require('../utils/auth.middleware');
const LoggingService = require('../services/logging.service');

const router = express.Router();

// Rate limiting for auth endpoints
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // limit each IP to 100 requests per windowMs (increased for testing)
  message: {
    error: 'Too many authentication attempts, please try again later.',
    code: 'RATE_LIMIT_EXCEEDED'
  },
  standardHeaders: true,
  legacyHeaders: false
  // trustProxy setting removed - will inherit from Express app configuration
});

// Validation rules
const loginValidation = [
  body('username')
    .trim()
    .isLength({ min: 3, max: 255 })
    .withMessage('Username must be between 3 and 255 characters'),
  body('password')
    .isLength({ min: 6 })
    .withMessage('Password must be at least 6 characters long')
];

const refreshValidation = [
  body('refreshToken')
    .notEmpty()
    .withMessage('Refresh token is required')
];

// Helper function to handle validation errors
const handleValidationErrors = (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({
      error: 'Validation failed',
      code: 'VALIDATION_ERROR',
      details: errors.array()
    });
  }
  next();
};

// POST /auth/login
router.post('/login', 
  authLimiter,
  loginValidation,
  handleValidationErrors,
  auditLog('USER_LOGIN_ATTEMPT'),
  async (req, res) => {
    try {
      const { username, password } = req.body;

      // Find user by username
      logger.info(`Attempting to find user by username: ${username}`);
      const user = await UserModel.findByUsername(username);
      logger.info(`UserModel.findByUsername result: ${user ? 'USER_FOUND' : 'USER_NOT_FOUND'}`);
      
      if (user) {
        logger.info(`Found user details - ID: ${user.id}, Role: ${user.role}, Status: ${user.status}`);
      }
      
      if (!user) {
        logger.warn(`Login attempt with invalid username: ${username}`);
        
        // Log failed login attempt
        await LoggingService.logLogin({ id: null, username, role: null }, req, false);
        
        return res.status(401).json({
          error: 'Invalid credentials',
          code: 'INVALID_CREDENTIALS'
        });
      }

      // Check if user is active
      if (user.status !== 'active') {
        logger.warn(`Login attempt for disabled user: ${username}`);
        
        // Log failed login attempt for disabled user
        await LoggingService.logLogin(user, req, false);
        
        return res.status(401).json({
          error: 'Account is disabled',
          code: 'ACCOUNT_DISABLED'
        });
      }

      // Verify password
      logger.info(`Verifying password for user: ${username}`);
      logger.info(`Password provided: ${password ? 'YES' : 'NO'}`);
      logger.info(`Password hash exists: ${user.password_hash ? 'YES' : 'NO'}`);
      
      const isPasswordValid = await UserModel.verifyPassword(password, user.password_hash);
      logger.info(`Password verification result for ${username}: ${isPasswordValid}`);
      
      if (!isPasswordValid) {
        logger.warn(`Login attempt with invalid password for user: ${username}`);
        
        // Log failed login attempt
        await LoggingService.logLogin(user, req, false);
        
        return res.status(401).json({
          error: 'Invalid credentials',
          code: 'INVALID_CREDENTIALS'
        });
      }

      // Generate tokens
      const tokens = JWTService.generateTokenPair(user);

      // Log successful login
      await LoggingService.logLogin(user, req, true);

      logger.info(`User logged in successfully: ${username}`);

      res.status(200).json({
        message: 'Login successful',
        user: {
          id: user.id,
          username: user.username,
          role: user.role,
          status: user.status,
          assigned_category: user.assigned_category
        },
        ...tokens
      });
    } catch (error) {
      logger.error('Login error:', error);
      
      // Log system error
      await LoggingService.logError('auth_error', error, null, req, {
        action: 'login',
        username: req.body.username
      });
      
      res.status(500).json({
        error: 'Internal server error',
        code: 'INTERNAL_ERROR'
      });
    }
  }
);

// POST /auth/refresh
router.post('/refresh',
  authLimiter,
  refreshValidation,
  handleValidationErrors,
  auditLog('TOKEN_REFRESH_ATTEMPT'),
  async (req, res) => {
    try {
      const { refreshToken } = req.body;

      // Verify refresh token
      let decoded;
      try {
        decoded = JWTService.verifyRefreshToken(refreshToken);
      } catch (error) {
        logger.warn('Invalid refresh token provided');
        
        // Log failed token refresh
        await LoggingService.logTokenRefresh(null, req, false, 'Invalid refresh token');
        
        return res.status(401).json({
          error: 'Invalid refresh token',
          code: 'INVALID_REFRESH_TOKEN'
        });
      }

      // Find user
      const user = await UserModel.findById(decoded.userId);
      if (!user) {
        logger.warn(`Refresh token for non-existent user: ${decoded.userId}`);
        
        // Log failed token refresh
        await LoggingService.logTokenRefresh(null, req, false, 'User not found');
        
        return res.status(401).json({
          error: 'User not found',
          code: 'USER_NOT_FOUND'
        });
      }

      // Check if user is still active
      if (user.status !== 'active') {
        logger.warn(`Refresh token for disabled user: ${user.username}`);
        
        // Log failed token refresh
        await LoggingService.logTokenRefresh(user, req, false, 'Account is disabled');
        
        return res.status(401).json({
          error: 'Account is disabled',
          code: 'ACCOUNT_DISABLED'
        });
      }

      // Generate new access token
      const newAccessToken = JWTService.generateAccessToken({
        userId: user.id,
        username: user.username,
        role: user.role,
        status: user.status
      });

      // Log successful token refresh
      await LoggingService.logTokenRefresh(user, req, true);

      logger.info(`Token refreshed for user: ${user.username}`);

      res.status(200).json({
        message: 'Token refreshed successfully',
        accessToken: newAccessToken,
        expiresIn: process.env.JWT_EXPIRY || '8h'
      });
    } catch (error) {
      logger.error('Token refresh error:', error);
      
      // Log system error
      await LoggingService.logError('auth_error', error, null, req, {
        action: 'token_refresh'
      });
      
      res.status(500).json({
        error: 'Internal server error',
        code: 'INTERNAL_ERROR'
      });
    }
  }
);

// POST /auth/logout (optional - for audit logging)
router.post('/logout',
  require('../utils/auth.middleware').authenticateToken,
  auditLog('USER_LOGOUT'),
  async (req, res) => {
    try {
      // Get the token from the Authorization header
      const authHeader = req.headers.authorization;
      const token = authHeader && authHeader.split(' ')[1];
      
      if (token) {
        // Add token to blacklist
        const redisService = require('../services/redis.service');
        const jwt = require('jsonwebtoken');
        
        try {
          // Decode token to get expiration time
          const decoded = jwt.decode(token);
          if (decoded && decoded.exp) {
            const expiresAt = decoded.exp * 1000; // Convert to milliseconds
            await redisService.addToTokenBlacklist(token, expiresAt);
            logger.info(`Token blacklisted for user: ${req.user.username}`);
          }
        } catch (blacklistError) {
          logger.error('Error blacklisting token:', blacklistError);
          // Continue with logout even if blacklisting fails
        }
      }
      
      // Log logout action
      await LoggingService.logLogout(req.user, req);
      
      res.status(200).json({
        message: 'Logout successful'
      });
    } catch (error) {
      logger.error('Logout logging error:', error);
      // Still return success even if logging fails
      res.status(200).json({
        message: 'Logout successful'
      });
    }
  }
);

// GET /auth/me (get current user info)
router.get('/me',
  require('../utils/auth.middleware').authenticateToken,
  (req, res) => {
    res.status(200).json({
      user: {
        id: req.user.id,
        username: req.user.username,
        role: req.user.role,
        status: req.user.status
      }
    });
  }
);

// GET /auth/verify (verify token validity)
router.get('/verify',
  require('../utils/auth.middleware').authenticateToken,
  (req, res) => {
    res.status(200).json({
      valid: true,
      user: {
        id: req.user.id,
        username: req.user.username,
        role: req.user.role,
        status: req.user.status
      }
    });
  }
);

// Token status check endpoint for auto logout support
router.get('/token-status', checkTokenStatus);

module.exports = router;