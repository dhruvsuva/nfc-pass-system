/**
 * Custom error classes and error handling utilities
 * for the NFC Pass System
 */

class NFCPassError extends Error {
  constructor(message, code, statusCode = 500, details = null) {
    super(message);
    this.name = this.constructor.name;
    this.code = code;
    this.statusCode = statusCode;
    this.details = details;
    this.timestamp = new Date().toISOString();
    
    // Capture stack trace
    Error.captureStackTrace(this, this.constructor);
  }

  toJSON() {
    return {
      error: this.message,
      code: this.code,
      statusCode: this.statusCode,
      details: this.details,
      timestamp: this.timestamp
    };
  }
}

class ValidationError extends NFCPassError {
  constructor(message, details = null) {
    super(message, 'VALIDATION_ERROR', 400, details);
  }
}

class AuthenticationError extends NFCPassError {
  constructor(message = 'Authentication failed') {
    super(message, 'AUTHENTICATION_ERROR', 401);
  }
}

class AuthorizationError extends NFCPassError {
  constructor(message = 'Insufficient permissions') {
    super(message, 'AUTHORIZATION_ERROR', 403);
  }
}

class NotFoundError extends NFCPassError {
  constructor(resource = 'Resource') {
    super(`${resource} not found`, 'NOT_FOUND', 404);
  }
}

class ConflictError extends NFCPassError {
  constructor(message, details = null) {
    super(message, 'CONFLICT_ERROR', 409, details);
  }
}

class RateLimitError extends NFCPassError {
  constructor(message = 'Rate limit exceeded') {
    super(message, 'RATE_LIMIT_EXCEEDED', 429);
  }
}

class DatabaseError extends NFCPassError {
  constructor(message, originalError = null) {
    super(message, 'DATABASE_ERROR', 500, originalError?.message);
    this.originalError = originalError;
  }
}

class RedisError extends NFCPassError {
  constructor(message, originalError = null) {
    super(message, 'REDIS_ERROR', 500, originalError?.message);
    this.originalError = originalError;
  }
}

class PassError extends NFCPassError {
  constructor(message, code, details = null) {
    super(message, code, 400, details);
  }
}

class VerificationError extends NFCPassError {
  constructor(message, code, details = null) {
    super(message, code, 400, details);
  }
}

// Error factory functions
const createPassNotFoundError = (uid) => {
  return new NotFoundError(`Pass with UID ${uid}`);
};

const createUserNotFoundError = (identifier) => {
  return new NotFoundError(`User ${identifier}`);
};

const createDuplicateUIDError = (uid) => {
  return new ConflictError(`Pass with UID ${uid} already exists`, { uid });
};

const createPassAlreadyUsedError = (uid) => {
  return new ConflictError(`Pass ${uid} has already been used`, { uid, status: 'used' });
};

const createPassBlockedError = (uid) => {
  return new ConflictError(`Pass ${uid} is blocked`, { uid, status: 'blocked' });
};

const createPassExpiredError = (uid, expiry) => {
  return new ConflictError(`Pass ${uid} has expired`, { uid, expiry, status: 'expired' });
};

const createInvalidCredentialsError = () => {
  return new AuthenticationError('Invalid username or password');
};

const createTokenExpiredError = () => {
  return new AuthenticationError('Token has expired');
};

const createInvalidTokenError = () => {
  return new AuthenticationError('Invalid token');
};

const createInsufficientPermissionsError = (requiredRole, userRole) => {
  return new AuthorizationError(
    `Insufficient permissions. Required: ${requiredRole}, User: ${userRole}`
  );
};

// Error handling middleware
const errorHandler = (err, req, res, next) => {
  const logger = require('./logger');
  
  // Log the error
  logger.error('Error occurred:', {
    error: err.message,
    code: err.code,
    stack: err.stack,
    url: req.originalUrl,
    method: req.method,
    ip: req.ip,
    userAgent: req.get('User-Agent'),
    user: req.user ? {
      id: req.user.id,
      username: req.user.username,
      role: req.user.role
    } : null
  });
  
  // Handle known error types
  if (err instanceof NFCPassError) {
    return res.status(err.statusCode).json(err.toJSON());
  }
  
  // Handle specific error types
  if (err.name === 'ValidationError') {
    return res.status(400).json({
      error: 'Validation failed',
      code: 'VALIDATION_ERROR',
      details: err.details || err.message
    });
  }
  
  if (err.name === 'JsonWebTokenError') {
    return res.status(401).json({
      error: 'Invalid token',
      code: 'INVALID_TOKEN'
    });
  }
  
  if (err.name === 'TokenExpiredError') {
    return res.status(401).json({
      error: 'Token expired',
      code: 'TOKEN_EXPIRED'
    });
  }
  
  if (err.code === 'ER_DUP_ENTRY') {
    return res.status(409).json({
      error: 'Duplicate entry',
      code: 'DUPLICATE_ENTRY',
      details: err.message
    });
  }
  
  if (err.code === 'ECONNREFUSED') {
    return res.status(503).json({
      error: 'Service unavailable',
      code: 'SERVICE_UNAVAILABLE',
      details: 'Database connection failed'
    });
  }
  
  // Handle rate limiting errors
  if (err.status === 429) {
    return res.status(429).json({
      error: 'Too many requests',
      code: 'RATE_LIMIT_EXCEEDED',
      retryAfter: err.retryAfter
    });
  }
  
  // Default error response
  const isDevelopment = process.env.NODE_ENV === 'development';
  
  res.status(500).json({
    error: 'Internal server error',
    code: 'INTERNAL_ERROR',
    message: isDevelopment ? err.message : 'Something went wrong',
    stack: isDevelopment ? err.stack : undefined
  });
};

// Async error wrapper
const asyncHandler = (fn) => {
  return (req, res, next) => {
    Promise.resolve(fn(req, res, next)).catch(next);
  };
};

// Error response helper
const sendErrorResponse = (res, error, statusCode = 500) => {
  if (error instanceof NFCPassError) {
    return res.status(error.statusCode).json(error.toJSON());
  }
  
  return res.status(statusCode).json({
    error: error.message || 'An error occurred',
    code: error.code || 'UNKNOWN_ERROR',
    timestamp: new Date().toISOString()
  });
};

// Validation error helper
const createValidationError = (errors) => {
  const details = Array.isArray(errors) ? errors : [errors];
  return new ValidationError('Validation failed', details);
};

// Database error helper
const handleDatabaseError = (error, operation = 'Database operation') => {
  const logger = require('./logger');
  logger.error(`${operation} failed:`, error);
  
  if (error.code === 'ER_DUP_ENTRY') {
    throw new ConflictError('Duplicate entry detected');
  }
  
  if (error.code === 'ER_NO_REFERENCED_ROW_2') {
    throw new ValidationError('Referenced record does not exist');
  }
  
  if (error.code === 'ECONNREFUSED') {
    throw new DatabaseError('Database connection failed');
  }
  
  throw new DatabaseError(`${operation} failed`, error);
};

// Redis error helper
const handleRedisError = (error, operation = 'Redis operation') => {
  const logger = require('./logger');
  logger.error(`${operation} failed:`, error);
  
  if (error.code === 'ECONNREFUSED') {
    throw new RedisError('Redis connection failed');
  }
  
  throw new RedisError(`${operation} failed`, error);
};

module.exports = {
  // Error classes
  NFCPassError,
  ValidationError,
  AuthenticationError,
  AuthorizationError,
  NotFoundError,
  ConflictError,
  RateLimitError,
  DatabaseError,
  RedisError,
  PassError,
  VerificationError,
  
  // Error factory functions
  createPassNotFoundError,
  createUserNotFoundError,
  createDuplicateUIDError,
  createPassAlreadyUsedError,
  createPassBlockedError,
  createPassExpiredError,
  createInvalidCredentialsError,
  createTokenExpiredError,
  createInvalidTokenError,
  createInsufficientPermissionsError,
  createValidationError,
  
  // Error handling utilities
  errorHandler,
  asyncHandler,
  sendErrorResponse,
  handleDatabaseError,
  handleRedisError
};