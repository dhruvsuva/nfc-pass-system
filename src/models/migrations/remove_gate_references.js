require('dotenv').config();
const { executeQuery, getDailyLogTableName, tableExists, connectDB } = require('../../config/db');
const logger = require('../../utils/logger');

/**
 * Migration to remove all gate references from the database
 * This includes:
 * 1. Removing gate_id columns from daily log tables
 * 2. Updating the daily log table creation function
 * 3. Cleaning up any gate-related indexes
 */

const removeGateReferences = async () => {
  try {
    // Connect to database first
    await connectDB();
    logger.info('Starting gate references removal migration...');

    // Get list of existing daily log tables
    const query = `
      SELECT table_name 
      FROM information_schema.tables 
      WHERE table_schema = ? 
      AND table_name LIKE 'daily_logs_%'
    `;
    
    const tables = await executeQuery(query, [process.env.DB_NAME]);
    
    logger.info(`Found ${tables.length} daily log tables to update`);

    // Remove gate_id column from each daily log table
    for (const table of tables) {
      const tableName = table.table_name;
      
      try {
        // Check if gate_id column exists
        const columnCheck = `
          SELECT COLUMN_NAME 
          FROM information_schema.COLUMNS 
          WHERE TABLE_SCHEMA = ? 
          AND TABLE_NAME = ? 
          AND COLUMN_NAME = 'gate_id'
        `;
        
        const columnExists = await executeQuery(columnCheck, [process.env.DB_NAME, tableName]);
        
        if (columnExists.length > 0) {
          // Drop the gate_id column and its index
          const dropColumnQuery = `
            ALTER TABLE ${tableName} 
            DROP INDEX IF EXISTS idx_gate_id,
            DROP COLUMN gate_id
          `;
          
          await executeQuery(dropColumnQuery);
          logger.info(`Removed gate_id column from ${tableName}`);
        } else {
          logger.info(`gate_id column not found in ${tableName}, skipping`);
        }
      } catch (error) {
        logger.error(`Error updating table ${tableName}:`, error);
        // Continue with other tables even if one fails
      }
    }

    logger.info('Gate references removal migration completed successfully');
    return true;
  } catch (error) {
    logger.error('Gate references removal migration failed:', error);
    throw error;
  }
};

// Run migration if called directly
if (require.main === module) {
  removeGateReferences()
    .then(() => {
      logger.info('Migration completed successfully');
      process.exit(0);
    })
    .catch((error) => {
      logger.error('Migration failed:', error);
      process.exit(1);
    });
}

module.exports = {
  removeGateReferences
};