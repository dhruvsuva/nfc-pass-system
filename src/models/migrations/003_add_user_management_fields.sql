-- Migration: Add user management fields to users table
-- Date: 2024-01-15
-- Description: Add fields for user management functionality including blocking, deletion tracking, and audit fields

-- Add new columns for user management
ALTER TABLE users 
ADD COLUMN created_by INT NULL,
ADD COLUMN blocked_at TIMESTAMP NULL,
ADD COLUMN blocked_by INT NULL,
ADD COLUMN block_reason TEXT NULL,
ADD COLUMN unblocked_at TIMESTAMP NULL,
ADD COLUMN unblocked_by INT NULL,
ADD COLUMN deleted_at TIMESTAMP NULL,
ADD COLUMN deleted_by INT NULL;

-- Add foreign key constraints
ALTER TABLE users 
ADD CONSTRAINT fk_users_created_by 
  FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL,
ADD CONSTRAINT fk_users_blocked_by 
  FOREIGN KEY (blocked_by) REFERENCES users(id) ON DELETE SET NULL,
ADD CONSTRAINT fk_users_unblocked_by 
  FOREIGN KEY (unblocked_by) REFERENCES users(id) ON DELETE SET NULL,
ADD CONSTRAINT fk_users_deleted_by 
  FOREIGN KEY (deleted_by) REFERENCES users(id) ON DELETE SET NULL;

-- Add indexes for better performance
CREATE INDEX idx_users_status ON users(status);
CREATE INDEX idx_users_role ON users(role);
CREATE INDEX idx_users_created_by ON users(created_by);
CREATE INDEX idx_users_blocked_at ON users(blocked_at);
CREATE INDEX idx_users_deleted_at ON users(deleted_at);

-- Update existing users to have proper timestamps if they don't exist
UPDATE users 
SET created_at = COALESCE(created_at, NOW()),
    updated_at = COALESCE(updated_at, NOW())
WHERE created_at IS NULL OR updated_at IS NULL;

-- Ensure all existing users have active status if not set
UPDATE users 
SET status = 'active' 
WHERE status IS NULL OR status = '';

-- Add check constraints for valid status values
ALTER TABLE users 
ADD CONSTRAINT chk_users_status 
  CHECK (status IN ('active', 'blocked', 'deleted'));

-- Add check constraints for valid role values
ALTER TABLE users 
ADD CONSTRAINT chk_users_role 
  CHECK (role IN ('admin', 'manager', 'bouncer'));

-- Create a view for active users (excluding deleted)
CREATE OR REPLACE VIEW active_users AS
SELECT 
  id,
  username,
  email,
  role,
  status,
  created_at,
  updated_at,
  created_by,
  blocked_at,
  blocked_by,
  block_reason,
  unblocked_at,
  unblocked_by
FROM users 
WHERE status != 'deleted';

-- Create a view for user statistics
CREATE OR REPLACE VIEW user_stats AS
SELECT 
  role,
  status,
  COUNT(*) as count
FROM users 
GROUP BY role, status;

-- Insert audit log for migration
INSERT INTO system_logs (action, details, created_at) 
VALUES ('MIGRATION', 'Added user management fields to users table', NOW());