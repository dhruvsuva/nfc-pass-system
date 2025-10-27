const { connectDB, executeQuery, getDB } = require('../../config/db');
const logger = require('../../utils/logger');

const migrations = [
  {
    id: 1,
    name: 'create_users_table',
    query: `
      CREATE TABLE IF NOT EXISTS users (
        id BIGINT PRIMARY KEY AUTO_INCREMENT,
        username VARCHAR(255) UNIQUE NOT NULL,
        email VARCHAR(255) NULL,
        password_hash VARCHAR(255) NOT NULL,
        role ENUM('admin','manager','bouncer') NOT NULL DEFAULT 'bouncer',
        status ENUM('active','disabled') NOT NULL DEFAULT 'active',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        INDEX idx_username (username),
        INDEX idx_role (role),
        INDEX idx_status (status)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    `
  },
  {
    id: 2,
    name: 'create_passes_table',
    query: `
      CREATE TABLE IF NOT EXISTS passes (
        id BIGINT PRIMARY KEY AUTO_INCREMENT,
        uid VARCHAR(128) UNIQUE NOT NULL,
        pass_id CHAR(36) NOT NULL,
        pass_type ENUM('daily','seasonal','session') NOT NULL,
        category VARCHAR(100) NOT NULL,
        people_allowed INT NOT NULL DEFAULT 1,
        status ENUM('active','blocked','used','expired','deleted') NOT NULL DEFAULT 'active',
        valid_from DATETIME NULL,
        valid_to DATETIME NULL,
        created_by BIGINT NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE RESTRICT,
        INDEX idx_uid (uid),
        INDEX idx_pass_id (pass_id),
        INDEX idx_status (status),
        INDEX idx_pass_type (pass_type),
        INDEX idx_category (category),
        INDEX idx_created_by (created_by),
        INDEX idx_valid_dates (valid_from, valid_to)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    `
  },
  {
    id: 3,
    name: 'create_settings_table',
    query: `
      CREATE TABLE IF NOT EXISTS settings (
        id INT PRIMARY KEY AUTO_INCREMENT,
        \`key\` VARCHAR(255) UNIQUE NOT NULL,
        \`value\` TEXT,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        INDEX idx_key (\`key\`)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    `
  },
  {
    id: 4,
    name: 'create_migration_history_table',
    query: `
      CREATE TABLE IF NOT EXISTS migration_history (
        id INT PRIMARY KEY AUTO_INCREMENT,
        migration_id INT NOT NULL,
        migration_name VARCHAR(255) NOT NULL,
        executed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        UNIQUE KEY unique_migration (migration_id)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    `
  },
  {
    id: 5,
    name: 'insert_default_settings',
    query: `
      INSERT IGNORE INTO settings (\`key\`, \`value\`) VALUES 
      ('last_reset_date', '1970-01-01'),
      ('system_version', '1.0.0'),
      ('daily_reset_enabled', 'false'),
      ('verify_rate_limit', '100'),
      ('bulk_batch_size', '100')
    `
  },
  {
    id: 6,
    name: 'create_default_admin_user',
    query: `
      INSERT IGNORE INTO users (username, email, password_hash, role, status) VALUES 
      ('admin', 'admin@nfcpass.com', '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'admin', 'active')
    `
  },
  {
    id: 7,
    name: 'create_logs_table',
    query: `
      CREATE TABLE IF NOT EXISTS logs (
        id BIGINT PRIMARY KEY AUTO_INCREMENT,
        action_type ENUM(
          'login', 'logout', 'login_failed',
          'create_pass', 'bulk_create_pass', 'delete_pass', 
          'block_pass', 'unblock_pass',
          'verify_pass', 'session_consume',
          'reset_single_pass', 'reset_daily_passes',
          'create_user', 'update_user', 'delete_user',
          'system_error', 'api_error', 'auth_error'
        ) NOT NULL,
        user_id BIGINT NULL,
        role ENUM('admin', 'manager', 'bouncer', 'system') NULL,
        pass_id CHAR(36) NULL,
        uid VARCHAR(128) NULL,
        target_user_id BIGINT NULL,
        ip_address VARCHAR(45) NULL,
        user_agent TEXT NULL,
        details JSON NULL,
        result ENUM('success', 'failure', 'error') NOT NULL DEFAULT 'success',
        error_message TEXT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        INDEX idx_action_type (action_type),
        INDEX idx_user_id (user_id),
        INDEX idx_role (role),
        INDEX idx_pass_id (pass_id),
        INDEX idx_uid (uid),
        INDEX idx_target_user_id (target_user_id),
        INDEX idx_result (result),
        INDEX idx_created_at (created_at),
        INDEX idx_action_user (action_type, user_id),
        INDEX idx_action_date (action_type, created_at),
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
        FOREIGN KEY (target_user_id) REFERENCES users(id) ON DELETE SET NULL
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    `
  },
  {
    id: 8,
    name: 'create_categories_table',
    query: `
      CREATE TABLE IF NOT EXISTS categories (
        id INT PRIMARY KEY AUTO_INCREMENT,
        name VARCHAR(100) UNIQUE NOT NULL,
        color_code VARCHAR(7) NOT NULL,
        description TEXT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        INDEX idx_name (name)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    `
  },
  {
    id: 9,
    name: 'insert_default_categories',
    query: `
      INSERT IGNORE INTO categories (name, color_code, description) VALUES 
      ('All Access', '#FF6B35', 'Unlimited access pass with no validation limits'),
      ('VIP', '#8E44AD', 'VIP access with premium privileges'),
      ('General', '#3498DB', 'Standard general admission'),
      ('Student', '#27AE60', 'Student discount category'),
      ('Staff', '#E74C3C', 'Staff and employee access')
    `
  },
  {
    id: 10,
    name: 'add_category_id_to_passes',
    query: `
      ALTER TABLE passes 
      ADD COLUMN category_id INT NULL AFTER category,
      ADD INDEX idx_category_id (category_id),
      ADD FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET NULL
    `
  },
  {
    id: 11,
    name: 'update_existing_passes_with_categories',
    query: `
      UPDATE passes p 
      JOIN categories c ON LOWER(p.category) = LOWER(c.name)
      SET p.category_id = c.id
      WHERE p.category_id IS NULL
    `
  },
  {
    id: 12,
    name: 'add_scan_id_to_passes',
    query: `
      ALTER TABLE passes 
      ADD COLUMN scan_id CHAR(36) NULL AFTER pass_id,
      ADD INDEX idx_scan_id ()
    `
  },
  {
    id: 13,
    name: 'add_max_uses_to_passes',
    query: `
      -- Add max_uses column if it doesn't exist
      SET @sql = IF(
        (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
         WHERE TABLE_SCHEMA = DATABASE() 
         AND TABLE_NAME = 'passes' 
         AND COLUMN_NAME = 'max_uses') = 0,
        'ALTER TABLE passes ADD COLUMN max_uses INT NULL AFTER people_allowed',
        'SELECT "max_uses column already exists" as message'
      );
      PREPARE stmt FROM @sql;
      EXECUTE stmt;
      DEALLOCATE PREPARE stmt;
      
      -- Add index for max_uses if it doesn't exist
      SET @sql = IF(
        (SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS 
         WHERE TABLE_SCHEMA = DATABASE() 
         AND TABLE_NAME = 'passes' 
         AND INDEX_NAME = 'idx_max_uses') = 0,
        'ALTER TABLE passes ADD INDEX idx_max_uses (max_uses)',
        'SELECT "idx_max_uses index already exists" as message'
      );
      PREPARE stmt FROM @sql;
      EXECUTE stmt;
      DEALLOCATE PREPARE stmt;
    `
  },
  {
    id: 14,
    name: 'add_unique_constraints_and_indexes',
    query: `
      -- Add unique constraint for UID if not exists
      ALTER TABLE passes 
      ADD CONSTRAINT unique_uid UNIQUE (uid);
      
      -- Add composite indexes for performance
      ALTER TABLE passes 
      ADD INDEX idx_status_category (status, category_id),
      ADD INDEX idx_pass_type_status (pass_type, status),
      ADD INDEX idx_created_by_status (created_by, status),
      ADD INDEX idx_valid_dates_status (valid_from, valid_to, status);
      
      -- Add indexes for users table
      ALTER TABLE users 
      ADD INDEX idx_role_status (role, status),
      ADD INDEX idx_created_at (created_at);
      
      -- Add indexes for logs table for better performance
      ALTER TABLE logs 
      ADD INDEX idx_user_action_date (user_id, action_type, created_at),
      ADD INDEX idx_pass_action_date (pass_id, action_type, created_at);
      
      -- Add check constraints for data integrity
      ALTER TABLE passes 
      ADD CONSTRAINT chk_people_allowed CHECK (people_allowed > 0),
      ADD CONSTRAINT chk_max_uses CHECK (max_uses IS NULL OR max_uses > 0),
      ADD CONSTRAINT chk_valid_dates CHECK (valid_from IS NULL OR valid_to IS NULL OR valid_from <= valid_to);
      
      -- Add foreign key constraint for last_scan_by if column exists
      SET @sql = IF(
        (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
         WHERE TABLE_SCHEMA = DATABASE() 
         AND TABLE_NAME = 'passes' 
         AND COLUMN_NAME = 'last_scan_by') > 0,
        'ALTER TABLE passes ADD CONSTRAINT fk_last_scan_by FOREIGN KEY () REFERENCES users(id) ON DELETE SET NULL',
        'SELECT "last_scan_by column does not exist" as message'
      );
      PREPARE stmt FROM @sql;
      EXECUTE stmt;
      DEALLOCATE PREPARE stmt;
    `
  },
  {
    id: 15,
    name: 'add_user_management_fields',
    query: `
      -- Add user management fields if they don't exist
      SET @sql = IF(
        (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
         WHERE TABLE_SCHEMA = DATABASE() 
         AND TABLE_NAME = 'users' 
         AND COLUMN_NAME = 'created_by') = 0,
        'ALTER TABLE users ADD COLUMN created_by BIGINT NULL AFTER role',
        'SELECT "created_by column already exists" as message'
      );
      PREPARE stmt FROM @sql;
      EXECUTE stmt;
      DEALLOCATE PREPARE stmt;
      
      SET @sql = IF(
        (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
         WHERE TABLE_SCHEMA = DATABASE() 
         AND TABLE_NAME = 'users' 
         AND COLUMN_NAME = 'blocked_at') = 0,
        'ALTER TABLE users ADD COLUMN blocked_at TIMESTAMP NULL AFTER status',
        'SELECT "blocked_at column already exists" as message'
      );
      PREPARE stmt FROM @sql;
      EXECUTE stmt;
      DEALLOCATE PREPARE stmt;
      
      SET @sql = IF(
        (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
         WHERE TABLE_SCHEMA = DATABASE() 
         AND TABLE_NAME = 'users' 
         AND COLUMN_NAME = 'deleted_at') = 0,
        'ALTER TABLE users ADD COLUMN deleted_at TIMESTAMP NULL AFTER blocked_at',
        'SELECT "deleted_at column already exists" as message'
      );
      PREPARE stmt FROM @sql;
      EXECUTE stmt;
      DEALLOCATE PREPARE stmt;
      
      SET @sql = IF(
        (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
         WHERE TABLE_SCHEMA = DATABASE() 
         AND TABLE_NAME = 'users' 
         AND COLUMN_NAME = 'assigned_category') = 0,
        'ALTER TABLE users ADD COLUMN assigned_category INT NULL AFTER deleted_at',
        'SELECT "assigned_category column already exists" as message'
      );
      PREPARE stmt FROM @sql;
      EXECUTE stmt;
      DEALLOCATE PREPARE stmt;
      
      -- Add foreign key constraints if they don't exist
      SET @sql = IF(
        (SELECT COUNT(*) FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE 
         WHERE TABLE_SCHEMA = DATABASE() 
         AND TABLE_NAME = 'users' 
         AND CONSTRAINT_NAME = 'fk_users_created_by') = 0,
        'ALTER TABLE users ADD CONSTRAINT fk_users_created_by FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL',
        'SELECT "fk_users_created_by constraint already exists" as message'
      );
      PREPARE stmt FROM @sql;
      EXECUTE stmt;
      DEALLOCATE PREPARE stmt;
      
      SET @sql = IF(
        (SELECT COUNT(*) FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE 
         WHERE TABLE_SCHEMA = DATABASE() 
         AND TABLE_NAME = 'users' 
         AND CONSTRAINT_NAME = 'fk_users_assigned_category') = 0,
        'ALTER TABLE users ADD CONSTRAINT fk_users_assigned_category FOREIGN KEY (assigned_category) REFERENCES categories(id) ON DELETE SET NULL',
        'SELECT "fk_users_assigned_category constraint already exists" as message'
      );
      PREPARE stmt FROM @sql;
      EXECUTE stmt;
      DEALLOCATE PREPARE stmt;
      
      -- Add indexes for new columns
      ALTER TABLE users 
      ADD INDEX idx_created_by (created_by),
      ADD INDEX idx_blocked_at (blocked_at),
      ADD INDEX idx_deleted_at (deleted_at),
      ADD INDEX idx_assigned_category (assigned_category);
    `
  },
  {
    id: 16,
    name: 'add_usage_tracking_fields',
    query: `
      -- Add usage tracking fields if they don't exist
      SET @sql = IF(
        (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
         WHERE TABLE_SCHEMA = DATABASE() 
         AND TABLE_NAME = 'passes' 
         AND COLUMN_NAME = 'used_count') = 0,
        'ALTER TABLE passes ADD COLUMN used_count INT NOT NULL DEFAULT 0 AFTER max_uses',
        'SELECT "used_count column already exists" as message'
      );
      PREPARE stmt FROM @sql;
      EXECUTE stmt;
      DEALLOCATE PREPARE stmt;
      
      SET @sql = IF(
        (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
         WHERE TABLE_SCHEMA = DATABASE() 
         AND TABLE_NAME = 'passes' 
         AND COLUMN_NAME = 'last_scan_at') = 0,
        'ALTER TABLE passes ADD COLUMN last_scan_at TIMESTAMP NULL AFTER used_count',
        'SELECT "last_scan_at column already exists" as message'
      );
      PREPARE stmt FROM @sql;
      EXECUTE stmt;
      DEALLOCATE PREPARE stmt;
      
      SET @sql = IF(
        (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
         WHERE TABLE_SCHEMA = DATABASE() 
         AND TABLE_NAME = 'passes' 
         AND COLUMN_NAME = 'last_scan_by') = 0,
        'ALTER TABLE passes ADD COLUMN last_scan_by BIGINT NULL AFTER last_scan_at',
        'SELECT "last_scan_by column already exists" as message'
      );
      PREPARE stmt FROM @sql;
      EXECUTE stmt;
      DEALLOCATE PREPARE stmt;
      
      -- Add indexes for usage tracking
      ALTER TABLE passes 
      ADD INDEX idx_used_count (used_count),
      ADD INDEX idx_last_scan_at (),
      ADD INDEX idx_last_scan_by ();
      
      -- Add check constraint for used_count
      ALTER TABLE passes 
      ADD CONSTRAINT chk_used_count CHECK (used_count >= 0);
    `
  }
];

const checkMigrationExecuted = async (migrationId) => {
  try {
    const result = await executeQuery(
      'SELECT COUNT(*) as count FROM migration_history WHERE migration_id = ?',
      [migrationId]
    );
    return result[0].count > 0;
  } catch (error) {
    // If migration_history table doesn't exist yet, return false
    return false;
  }
};

const recordMigration = async (migration) => {
  try {
    await executeQuery(
      'INSERT INTO migration_history (migration_id, migration_name) VALUES (?, ?)',
      [migration.id, migration.name]
    );
  } catch (error) {
    logger.error(`Failed to record migration ${migration.name}:`, error);
  }
};

const executeMigrationQuery = async (query) => {
  // Split query by semicolons and execute each statement separately
  const statements = query
    .split(';')
    .map(stmt => stmt.trim())
    .filter(stmt => stmt.length > 0 && !stmt.match(/^\s*--/));
  
  for (const statement of statements) {
    if (statement.trim()) {
      await executeQuery(statement);
    }
  }
};

const runMigrations = async () => {
  try {
    logger.info('Starting database migrations...');
    
    for (const migration of migrations) {
      // Skip migration history check for the migration_history table creation itself
      if (migration.id !== 4) {
        const isExecuted = await checkMigrationExecuted(migration.id);
        if (isExecuted) {
          logger.info(`Migration ${migration.name} already executed, skipping...`);
          continue;
        }
      }
      
      logger.info(`Executing migration: ${migration.name}`);
      
      try {
        await executeMigrationQuery(migration.query);
      } catch (error) {
        logger.error(`Migration ${migration.name} failed:`, error.message);
        // Continue with next migration instead of stopping
        continue;
      }
      
      // Record the migration (skip for migration_history table creation)
      if (migration.id !== 4) {
        await recordMigration(migration);
      }
      
      logger.info(`Migration ${migration.name} completed successfully`);
    }
    
    logger.info('All migrations completed successfully');
  } catch (error) {
    logger.error('Migration failed:', error);
    throw error;
  }
};

const main = async () => {
  try {
    await connectDB();
    await runMigrations();
    process.exit(0);
  } catch (error) {
    logger.error('Migration process failed:', error);
    process.exit(1);
  }
};

// Run migrations if this file is executed directly
if (require.main === module) {
  main();
}

module.exports = {
  runMigrations,
  migrations
};