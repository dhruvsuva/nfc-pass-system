const { connectDB, executeQuery } = require('../../config/db');
const logger = require('../../utils/logger');

/**
 * Migration to remove valid_from and valid_to fields from passes table
 * Passes should no longer have validity date ranges
 */
const removeValidityFields = async () => {
  try {
    // Initialize database connection
    await connectDB();
    logger.info('Removing validity fields from passes table...');
    
    // Remove valid_from and valid_to columns and their index
    const queries = [
      // Drop the index first
      'ALTER TABLE passes DROP INDEX idx_valid_dates',
      // Remove the columns
      'ALTER TABLE passes DROP COLUMN valid_from',
      'ALTER TABLE passes DROP COLUMN valid_to'
    ];
    
    for (const query of queries) {
      try {
        await executeQuery(query);
        logger.info(`Executed: ${query}`);
      } catch (error) {
        // Log warning but continue if index doesn't exist
        if (error.code === 'ER_CANT_DROP_FIELD_OR_KEY') {
          logger.warn(`Index or column doesn't exist, skipping: ${query}`);
        } else {
          throw error;
        }
      }
    }
    
    logger.info('Successfully removed validity fields from passes table');
    
  } catch (error) {
    logger.error('Failed to remove validity fields:', error);
    throw error;
  }
};

// Run migration if called directly
if (require.main === module) {
  removeValidityFields()
    .then(() => {
      logger.info('Migration completed successfully');
      process.exit(0);
    })
    .catch((error) => {
      logger.error('Migration failed:', error);
      process.exit(1);
    });
}

module.exports = removeValidityFields;