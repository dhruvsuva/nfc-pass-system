const mysql = require('mysql2/promise');
const logger = require('../utils/logger');

let pool;

// Use mock database for Vercel deployment
const isVercel = process.env.VERCEL === '1' || process.env.NODE_ENV === 'production';
const useMockDB = isVercel && (!process.env.DB_HOST || process.env.DB_HOST === 'localhost');

if (useMockDB) {
  logger.warn('Using mock database for Vercel deployment');
  module.exports = require('./mock-db');
  return;
}

const dbConfig = {
  host: process.env.DB_HOST || 'localhost',
  port: process.env.DB_PORT || 3306,
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASS || '',
  database: process.env.DB_NAME || 'nfc_pass_system',
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
  charset: 'utf8mb4',
  timezone: '+05:30', // Indian Standard Time (Kolkata timezone)
  // MySQL2 compatible options only
  supportBigNumbers: true,
  bigNumberStrings: true,
  dateStrings: true,
  debug: false,
  trace: false,
  // SSL configuration for production
  ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false
};

const connectDB = async () => {
  try {
    // Create connection pool
    pool = mysql.createPool(dbConfig);
    
    // Test the connection
    const connection = await pool.getConnection();
    logger.info('MySQL Database connected successfully');
    connection.release();
    
    return pool;
  } catch (error) {
    logger.error('Database connection failed:', error);
    throw error;
  }
};

const getDB = () => {
  if (!pool) {
    throw new Error('Database not initialized. Call connectDB first.');
  }
  return pool;
};

// Helper function to execute queries
const executeQuery = async (query, params = []) => {
  try {
    const db = getDB();
    const [results] = await db.execute(query, params);
    return results;
  } catch (error) {
    logger.error('Query execution failed:', { query, params, error: error.message });
    throw error;
  }
};

// Helper function for transactions
const executeTransaction = async (queries) => {
  const connection = await getDB().getConnection();
  try {
    await connection.beginTransaction();
    
    const results = [];
    for (const { query, params } of queries) {
      const [result] = await connection.execute(query, params || []);
      results.push(result);
    }
    
    await connection.commit();
    return results;
  } catch (error) {
    await connection.rollback();
    logger.error('Transaction failed:', error);
    throw error;
  } finally {
    connection.release();
  }
};

// Helper function to create daily log table
const createDailyLogTable = async (date) => {
  const tableName = getDailyLogTableName(date);
  
  const query = `
    CREATE TABLE IF NOT EXISTS ${tableName} (
      id BIGINT PRIMARY KEY AUTO_INCREMENT,
      pass_id CHAR(36),
      uid VARCHAR(128),
      scanned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      scanned_by BIGINT,
      result ENUM('valid','invalid','blocked','used','error') VARCHAR(128),
      remaining_uses INT NULL COMMENT 'Remaining uses after this verification',
      consumed_count INT NOT NULL DEFAULT 1 COMMENT 'Number of entries consumed in this verification',
      prompt_consumption BOOLEAN NOT NULL DEFAULT FALSE COMMENT 'Whether this was consumed via prompt token',
      offline_sync BOOLEAN NOT NULL DEFAULT FALSE COMMENT 'Whether this was synced from offline logs' BOOLEAN DEFAULT FALSE,
      category VARCHAR(100) NULL COMMENT 'Pass category from passes table',
      pass_type VARCHAR(100) NULL COMMENT 'Pass type from passes table',
      INDEX idx_uid (uid),
      INDEX idx_scanned_at (scanned_at),
      INDEX idx_result (result),
      INDEX idx_scanned_by (scanned_by),
      INDEX idx_category (category),
      INDEX idx_pass_type (pass_type)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  `;
  
  try {
    await executeQuery(query);
    logger.info(`Daily log table created: ${tableName}`);
    return tableName;
  } catch (error) {
    logger.error(`Failed to create daily log table ${tableName}:`, error);
    throw error;
  }
};

// Helper function to get daily log table name
const getDailyLogTableName = (date) => {
  return `daily_logs_${date.replace(/-/g, '_')}`;
};

// Helper function to check if table exists
const tableExists = async (tableName) => {
  try {
    const query = `
      SELECT COUNT(*) as count 
      FROM information_schema.tables 
      WHERE table_schema = ? AND table_name = ?
    `;
    const result = await executeQuery(query, [process.env.DB_NAME, tableName]);
    return result[0].count > 0;
  } catch (error) {
    logger.error(`Failed to check if table ${tableName} exists:`, error);
    return false;
  }
};

module.exports = {
  connectDB,
  getDB,
  executeQuery,
  executeTransaction,
  createDailyLogTable,
  getDailyLogTableName,
  tableExists
};