const { connectDB, executeQuery } = require('../../config/db');
const logger = require('../../utils/logger');

/**
 * Migration to add bouncer category restrictions
 * 1. Add assigned_category column to users table
 * 2. Update categories with fixed themes
 */
const addBouncerCategoryRestrictions = async () => {
  try {
    // Initialize database connection
    await connectDB();
    logger.info('Adding bouncer category restrictions...');
    
    // Step 1: Add assigned_category column to users table
    logger.info('Adding assigned_category column to users table...');
    const addColumnQuery = `
      ALTER TABLE users 
      ADD COLUMN assigned_category VARCHAR(100) NULL COMMENT 'Category assigned to bouncer for verification restrictions'
    `;
    
    await executeQuery(addColumnQuery);
    logger.info('Successfully added assigned_category column to users table');
    
    // Step 2: Update categories with fixed themes
    logger.info('Updating categories with fixed themes...');
    
    // First, clear existing categories (except All Access)
    const clearCategoriesQuery = `
      DELETE FROM categories WHERE name != 'All Access'
    `;
    await executeQuery(clearCategoriesQuery);
    
    // Insert new categories with fixed themes
    const insertCategoriesQuery = `
      INSERT INTO categories (name, color_code, description) VALUES 
      ('Platinum A', '#bcbabb', 'Platinum A access category'),
      ('Platinum B', '#9ad3a6', 'Platinum B access category'),
      ('Diamond', '#79b7de', 'Diamond access category'),
      ('Gold A', '#eac23c', 'Gold A access category'),
      ('Gold B', '#cc802a', 'Gold B access category'),
      ('Silver', '#ebebeb', 'Silver access category')
      ON DUPLICATE KEY UPDATE 
      color_code = VALUES(color_code),
      description = VALUES(description)
    `;
    
    await executeQuery(insertCategoriesQuery);
    logger.info('Successfully updated categories with fixed themes');
    
    // Step 3: Add index for assigned_category for better performance
    logger.info('Adding index for assigned_category...');
    const addIndexQuery = `
      ALTER TABLE users 
      ADD INDEX idx_assigned_category (assigned_category)
    `;
    
    await executeQuery(addIndexQuery);
    logger.info('Successfully added index for assigned_category');
    
    logger.info('Bouncer category restrictions migration completed successfully');
    
  } catch (error) {
    logger.error('Failed to add bouncer category restrictions:', error);
    throw error;
  }
};

// Run migration if called directly
if (require.main === module) {
  addBouncerCategoryRestrictions()
    .then(() => {
      logger.info('Migration completed successfully');
      process.exit(0);
    })
    .catch((error) => {
      logger.error('Migration failed:', error);
      process.exit(1);
    });
}

module.exports = addBouncerCategoryRestrictions;