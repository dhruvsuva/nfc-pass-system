-- Migration: Add unique constraints and proper indexes for production
-- Date: 2025-01-20
-- Description: Add unique UID constraint, proper indexes, and constraints for production readiness

USE nfc_pass_system;

-- Ensure UID is unique (should already be, but adding explicit constraint)
-- First check if constraint already exists
SET @constraint_exists = (
    SELECT COUNT(*)
    FROM information_schema.TABLE_CONSTRAINTS 
    WHERE CONSTRAINT_SCHEMA = 'nfc_pass_system' 
    AND TABLE_NAME = 'passes' 
    AND CONSTRAINT_NAME = 'unique_uid'
);

-- Add unique constraint if it doesn't exist
SET @sql = IF(@constraint_exists = 0, 
    'ALTER TABLE passes ADD CONSTRAINT unique_uid UNIQUE (uid)',
    'SELECT "UID unique constraint already exists" as message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Add composite indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_passes_status_type ON passes(status, pass_type);
CREATE INDEX IF NOT EXISTS idx_passes_category_status ON passes(category, status);
CREATE INDEX IF NOT EXISTS idx_passes_created_date ON passes(created_at);
CREATE INDEX IF NOT EXISTS idx_passes_usage_tracking ON passes(used_count, max_uses);

-- Add indexes for users table
CREATE INDEX IF NOT EXISTS idx_users_role_status ON users(role, status);
CREATE INDEX IF NOT EXISTS idx_users_created_date ON users(created_at);

-- Add indexes for logs table for better performance
CREATE INDEX IF NOT EXISTS idx_logs_date_action ON logs(created_at, action_type);
CREATE INDEX IF NOT EXISTS idx_logs_user_date ON logs(user_id, created_at);

-- Add check constraints for data integrity
ALTER TABLE passes 
ADD CONSTRAINT chk_passes_people_allowed 
  CHECK (people_allowed > 0 AND people_allowed <= 100);

ALTER TABLE passes 
ADD CONSTRAINT chk_passes_max_uses 
  CHECK (max_uses > 0 AND max_uses <= 100);

ALTER TABLE passes 
ADD CONSTRAINT chk_passes_used_count 
  CHECK (used_count >= 0 AND used_count <= max_uses);

-- Ensure categories have valid color codes
ALTER TABLE categories 
ADD CONSTRAINT chk_categories_color_code 
  CHECK (color_code REGEXP '^#[0-9A-Fa-f]{6}$');

-- Add foreign key constraint for passes.last_scan_by if not exists
SET @fk_exists = (
    SELECT COUNT(*)
    FROM information_schema.KEY_COLUMN_USAGE 
    WHERE CONSTRAINT_SCHEMA = 'nfc_pass_system' 
    AND TABLE_NAME = 'passes' 
    AND CONSTRAINT_NAME = 'fk_passes_last_scan_by'
);

SET @sql = IF(@fk_exists = 0, 
    'ALTER TABLE passes ADD CONSTRAINT fk_passes_last_scan_by FOREIGN KEY (last_scan_by) REFERENCES users(id) ON DELETE SET NULL',
    'SELECT "Foreign key constraint already exists" as message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SELECT 'Migration completed: Added unique constraints and indexes for production' as result;