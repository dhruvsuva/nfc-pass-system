const { connectDB, executeQuery } = require('../../config/db');
const logger = require('../../utils/logger');

/**
 * Migration to add 'unlimited' pass type to support All Access passes
 */
const addUnlimitedPassType = async () => {
  try {
    // Initialize database connection
    await connectDB();
    logger.info('Adding unlimited pass type to passes table...');
    
    // Add 'unlimited' to the pass_type ENUM
    const query = `
      ALTER TABLE passes 
      MODIFY COLUMN pass_type ENUM('daily','seasonal','session','unlimited') NOT NULL
    `;
    
    await executeQuery(query);
    logger.info('Successfully added unlimited pass type to passes table');
    
  } catch (error) {
    logger.error('Failed to add unlimited pass type:', error);
    throw error;
  }
};

// Run migration if called directly
if (require.main === module) {
  addUnlimitedPassType()
    .then(() => {
      logger.info('Migration completed successfully');
      process.exit(0);
    })
    .catch((error) => {
      logger.error('Migration failed:', error);
      process.exit(1);
    });
}

module.exports = addUnlimitedPassType;