const { body, query, param, validationResult } = require('express-validator');
const moment = require('moment');

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

// Custom validators
const isValidDate = (value) => {
  if (!value) return true; // Allow null/undefined for optional fields
  return moment(value, 'YYYY-MM-DD HH:mm:ss', true).isValid() || 
         moment(value, 'YYYY-MM-DD', true).isValid() ||
         moment(value).isValid();
};

const isValidUID = (value) => {
  // UID should be alphanumeric and between 4-128 characters
  return /^[a-zA-Z0-9]{4,128}$/.test(value);
};

// Pass validation rules
const createPassValidation = [
  body('uid')
    .trim()
    .isLength({ min: 4, max: 128 })
    .withMessage('UID must be between 4 and 128 characters')
    .custom(isValidUID)
    .withMessage('UID must contain only alphanumeric characters'),
  body('pass_type')
    .isIn(['daily', 'seasonal', 'unlimited'])
    .withMessage('Pass type must be daily, seasonal, or unlimited'),
  body('category')
    .trim()
    .isLength({ min: 1, max: 100 })
    .withMessage('Category must be between 1 and 100 characters'),
  body('people_allowed')
    .isInt({ min: 1, max: 100 })
    .withMessage('People allowed must be between 1 and 100'),
  body('valid_from')
    .optional({ nullable: true })
    .custom(isValidDate)
    .withMessage('Valid from must be a valid date'),
  body('valid_to')
    .optional({ nullable: true })
    .custom(isValidDate)
    .withMessage('Valid to must be a valid date')
];

const bulkCreatePassValidation = [
  body('uids')
    .isArray({ min: 1, max: 1000 })
    .withMessage('UIDs must be an array with 1-1000 items'),
  body('uids.*')
    .trim()
    .isLength({ min: 4, max: 128 })
    .withMessage('Each UID must be between 4 and 128 characters')
    .custom(isValidUID)
    .withMessage('Each UID must contain only alphanumeric characters'),
  body('pass_type')
    .isIn(['daily', 'seasonal', 'unlimited'])
    .withMessage('Pass type must be daily, seasonal, or unlimited'),
  body('category')
    .trim()
    .isLength({ min: 1, max: 100 })
    .withMessage('Category must be between 1 and 100 characters'),
  body('people_allowed')
    .isInt({ min: 1, max: 100 })
    .withMessage('People allowed must be between 1 and 100'),
  body('max_uses')
    .optional()
    .custom((value, { req }) => {
      const maxUses = parseInt(value);
      const passType = req.body.pass_type;
      
      if (isNaN(maxUses) || maxUses < 1) {
        throw new Error('Max uses must be a positive integer');
      }
      
      // For unlimited pass type, allow up to 999999
      if (passType === 'unlimited') {
        if (maxUses > 999999) {
          throw new Error('Max uses for unlimited passes must not exceed 999999');
        }
      } else {
        // For other pass types, maintain the original limit of 100
        if (maxUses > 100) {
          throw new Error('Max uses must be between 1 and 100 for this pass type');
        }
      }
      
      return true;
    })
];

// Verification validation rules
const verifyPassValidation = [
  body('uid')
    .trim()
    .isLength({ min: 4, max: 128 })
    .withMessage('UID must be between 4 and 128 characters')
    .custom(isValidUID)
    .withMessage('UID must contain only alphanumeric characters'),
  body('scanned_by')
    .isInt({ min: 1 })
    .withMessage('Scanned by must be a valid user ID'),
  body('device_local_id')
    .optional()
    .trim()
    .isLength({ max: 128 })
    .withMessage('Device local ID must be less than 128 characters')
];

const syncLogsValidation = [
  body('logs')
    .isArray({ min: 1, max: 1000 })
    .withMessage('Logs must be an array with 1-1000 items'),
  body('logs.*.uid')
    .trim()
    .isLength({ min: 4, max: 128 })
    .withMessage('Each UID must be between 4 and 128 characters'),
  body('logs.*.scanned_by')
    .isInt({ min: 1 })
    .withMessage('Each scanned_by must be a valid user ID'),
  body('logs.*.result')
    .isIn(['valid', 'invalid', 'blocked', 'duplicate'])
    .withMessage('Each result must be valid, invalid, blocked, or duplicate'),
  body('logs.*.scanned_at')
    .custom(isValidDate)
    .withMessage('Each scanned_at must be a valid date')
];

// Query validation rules
const logsQueryValidation = [
  query('date')
    .matches(/^\d{4}-\d{2}-\d{2}$/)
    .withMessage('Date must be in YYYY-MM-DD format'),
  query('uid')
    .optional()
    .trim()
    .isLength({ min: 4, max: 128 })
    .withMessage('UID must be between 4 and 128 characters'),
  query('pass_id')
    .optional()
    .isUUID(4)
    .withMessage('Pass ID must be a valid UUID'),
  query('scanned_by')
    .optional()
    .isInt({ min: 1 })
    .withMessage('Scanned by must be a valid user ID'),
  query('result')
    .optional()
    .isIn(['valid', 'invalid', 'blocked', 'duplicate'])
    .withMessage('Result must be valid, invalid, blocked, or duplicate'),
  query('page')
    .optional()
    .isInt({ min: 1 })
    .withMessage('Page must be a positive integer'),
  query('limit')
    .optional()
    .isInt({ min: 1, max: 1000 })
    .withMessage('Limit must be between 1 and 1000')
];

const statsQueryValidation = [
  query('from')
    .matches(/^\d{4}-\d{2}-\d{2}$/)
    .withMessage('From date must be in YYYY-MM-DD format'),
  query('to')
    .matches(/^\d{4}-\d{2}-\d{2}$/)
    .withMessage('To date must be in YYYY-MM-DD format'),
  query('category')
    .optional()
    .trim()
    .isLength({ min: 1, max: 100 })
    .withMessage('Category must be between 1 and 100 characters')
];

// Parameter validation rules
const passIdValidation = [
  param('id')
    .isInt({ min: 1 })
    .withMessage('Pass ID must be a positive integer')
];

const resetPassValidation = [
  body('reason')
    .optional()
    .trim()
    .isLength({ max: 255 })
    .withMessage('Reason must be less than 255 characters'),
  body('reset_by')
    .optional()
    .isInt({ min: 1 })
    .withMessage('Reset by must be a valid user ID')
];

// Daily reset validation
const dailyResetValidation = [
  body('date')
    .optional()
    .matches(/^\d{4}-\d{2}-\d{2}$/)
    .withMessage('Date must be in YYYY-MM-DD format'),
  body('confirm')
    .equals('true')
    .withMessage('Confirmation required for daily reset')
];

// User validation rules
const createUserValidation = [
  body('username')
    .trim()
    .isLength({ min: 3, max: 50 })
    .withMessage('Username must be between 3 and 50 characters')
    .matches(/^[a-zA-Z0-9_-]+$/)
    .withMessage('Username can only contain letters, numbers, hyphens, and underscores'),
  body('password')
    .isLength({ min: 6, max: 128 })
    .withMessage('Password must be between 6 and 128 characters'),
  body('role')
    .isIn(['admin', 'manager', 'bouncer'])
    .withMessage('Role must be admin, manager, or bouncer'),
  body('status')
    .optional()
    .isIn(['active', 'blocked', 'deleted'])
    .withMessage('Status must be active, blocked, or deleted')
];

const updateUserValidation = [
  body('username')
    .optional()
    .trim()
    .isLength({ min: 3, max: 50 })
    .withMessage('Username must be between 3 and 50 characters')
    .matches(/^[a-zA-Z0-9_-]+$/)
    .withMessage('Username can only contain letters, numbers, hyphens, and underscores'),
  body('password')
    .optional()
    .isLength({ min: 6, max: 128 })
    .withMessage('Password must be between 6 and 128 characters'),
  body('role')
    .optional()
    .isIn(['admin', 'manager', 'bouncer'])
    .withMessage('Role must be admin, manager, or bouncer'),
  body('status')
    .optional()
    .isIn(['active', 'blocked', 'deleted'])
    .withMessage('Status must be active, blocked, or deleted')
];

const userIdValidation = [
  param('id')
    .isInt({ min: 1 })
    .withMessage('User ID must be a positive integer')
];

const blockUserValidation = [
  body('reason')
    .optional()
    .trim()
    .isLength({ max: 255 })
    .withMessage('Block reason must be less than 255 characters')
];

// Helper functions for user validation
const validateUser = (userData) => {
  const errors = [];
  
  if (!userData.username || userData.username.trim().length < 3) {
    errors.push('Username must be at least 3 characters long');
  }
  
  if (!userData.password || userData.password.length < 6) {
    errors.push('Password must be at least 6 characters long');
  }
  
  if (!userData.role || !['admin', 'manager', 'bouncer'].includes(userData.role)) {
    errors.push('Role must be admin, manager, or bouncer');
  }
  
  if (userData.status && !['active', 'blocked', 'deleted'].includes(userData.status)) {
    errors.push('Status must be active, blocked, or deleted');
  }
  
  return {
    isValid: errors.length === 0,
    errors
  };
};

const validateUserUpdate = (userData) => {
  const errors = [];
  
  if (userData.username && userData.username.trim().length < 3) {
    errors.push('Username must be at least 3 characters long');
  }
  
  if (userData.password && userData.password.length < 6) {
    errors.push('Password must be at least 6 characters long');
  }
  
  if (userData.role && !['admin', 'manager', 'bouncer'].includes(userData.role)) {
    errors.push('Role must be admin, manager, or bouncer');
  }
  
  if (userData.status && !['active', 'blocked', 'deleted'].includes(userData.status)) {
    errors.push('Status must be active, blocked, or deleted');
  }
  
  return {
    isValid: errors.length === 0,
    errors
  };
};

// Pagination helpers
const getPaginationParams = (req) => {
  const page = parseInt(req.query.page) || 1;
  const limit = parseInt(req.query.limit) || 50;
  const offset = (page - 1) * limit;
  
  return { page, limit, offset };
};

// Date helpers
const formatDateForDB = (dateString) => {
  if (!dateString) return null;
  return moment(dateString).format('YYYY-MM-DD HH:mm:ss');
};

const getCurrentDate = () => {
  return moment().format('YYYY-MM-DD');
};

const getCurrentDateTime = () => {
  return moment().format('YYYY-MM-DD HH:mm:ss');
};

module.exports = {
  handleValidationErrors,
  createPassValidation,
  bulkCreatePassValidation,
  verifyPassValidation,
  syncLogsValidation,
  logsQueryValidation,
  statsQueryValidation,
  passIdValidation,
  resetPassValidation,
  dailyResetValidation,
  createUserValidation,
  updateUserValidation,
  userIdValidation,
  blockUserValidation,
  validateUser,
  validateUserUpdate,
  getPaginationParams,
  formatDateForDB,
  getCurrentDate,
  getCurrentDateTime,
  isValidDate,
  isValidUID
};