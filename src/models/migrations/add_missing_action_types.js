const { connectDB, executeQuery } = require('../../config/db');
const logger = require('../../utils/logger');

/**
 * Migration to add missing action types to logs table
 * This adds category management and user management action types
 */
const addMissingActionTypes = async () => {
  try {
    // Initialize database connection
    await connectDB();
    logger.info('Adding missing action types to logs table...');
    
    // Add the missing action types to the ENUM
    const query = `
      ALTER TABLE logs 
      MODIFY COLUMN action_type ENUM(
        'login', 'logout', 'login_failed',
        'create_pass', 'bulk_create_pass', 'bulk_create_error', 'delete_pass', 
        'block_pass', 'unblock_pass',
        'verify_pass', 'session_consume',
        'reset_single_pass', 'reset_daily_passes',
        'create_user', 'update_user', 'delete_user',
        'block_user', 'unblock_user',
        'create_category', 'update_category', 'delete_category',
        'system_error', 'api_error', 'auth_error'
      ) NOT NULL
    `;
    
    await executeQuery(query);
    logger.info('Successfully added missing action types to logs table');
    
  } catch (error) {
    logger.error('Failed to add missing action types:', error);
    throw error;
  }
};

// Run migration if called directly
if (require.main === module) {
  addMissingActionTypes()
    .then(() => {
      logger.info('Migration completed successfully');
      process.exit(0);
    })
    .catch((error) => {
      logger.error('Migration failed:', error);
      process.exit(1);
    });
}

module.exports = addMissingActionTypes;