const { connectDB, executeQuery } = require('../../config/db');
const logger = require('../../utils/logger');

async function addSyncActionTypes() {
  try {
    // Connect to database
    await connectDB();
    
    logger.info('Adding sync-related action types to logs table...');
    
    // Add new action types to the ENUM
    const alterQuery = `
      ALTER TABLE logs 
      MODIFY COLUMN action_type ENUM(
        'login', 'logout', 'login_failed', 
        'create_pass', 'bulk_create_pass', 'bulk_create_error', 'delete_pass', 
        'block_pass', 'unblock_pass', 'verify_pass', 'session_consume', 
        'reset_single_pass', 'reset_daily_passes', 
        'create_user', 'update_user', 'delete_user', 'block_user', 'unblock_user', 
        'create_category', 'update_category', 'delete_category', 
        'system_error', 'api_error', 'auth_error',
        'sync_start', 'sync_complete', 'sync_error'
      ) NOT NULL
    `;
    
    await executeQuery(alterQuery);
    
    logger.info('Successfully added sync-related action types to logs table');
    logger.info('Migration completed successfully');
    
    process.exit(0);
  } catch (error) {
    logger.error('Migration failed:', error);
    process.exit(1);
  }
}

// Run the migration
addSyncActionTypes();