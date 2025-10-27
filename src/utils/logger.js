const winston = require('winston');

// Check if we're in a serverless environment (Vercel, AWS Lambda, etc.)
const isServerless = process.env.VERCEL || process.env.AWS_LAMBDA_FUNCTION_NAME || process.env.NODE_ENV === 'production';

const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    winston.format.timestamp({
      format: 'YYYY-MM-DD HH:mm:ss'
    }),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  defaultMeta: { service: 'nfc-pass-backend' },
  transports: []
});

// Add transports based on environment
if (isServerless) {
  // In serverless environments, only use console logging
  logger.add(new winston.transports.Console({
    format: winston.format.combine(
      winston.format.colorize(),
      winston.format.simple()
    )
  }));
} else {
  // In non-serverless environments, use file logging
  const path = require('path');
  const fs = require('fs');
  const logDir = path.join(__dirname, '../../logs');
  
  // Create logs directory if it doesn't exist
  if (!fs.existsSync(logDir)) {
    fs.mkdirSync(logDir, { recursive: true });
  }
  
  // Write all logs with level 'error' and below to error.log
  logger.add(new winston.transports.File({ 
    filename: path.join(logDir, 'error.log'), 
    level: 'error' 
  }));
  
  // Write all logs to combined.log
  logger.add(new winston.transports.File({ 
    filename: path.join(logDir, 'combined.log') 
  }));
  
  // Also log to console in development
  logger.add(new winston.transports.Console({
    format: winston.format.combine(
      winston.format.colorize(),
      winston.format.simple()
    )
  }));
}

module.exports = logger;