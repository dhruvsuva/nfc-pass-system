-- Production Ready Schema Migration
-- This migration adds all necessary constraints, indexes, and fields for production deployment

-- Add unique constraint for UID (ignore if exists)
ALTER TABLE passes ADD CONSTRAINT unique_uid UNIQUE (uid);

-- Add composite indexes for performance
ALTER TABLE passes ADD INDEX idx_status_category (status, category_id);
ALTER TABLE passes ADD INDEX idx_pass_type_status (pass_type, status);
ALTER TABLE passes ADD INDEX idx_created_by_status (created_by, status);
ALTER TABLE passes ADD INDEX idx_valid_dates_status (valid_from, valid_to, status);

-- Add indexes for users table
ALTER TABLE users ADD INDEX idx_role_status (role, status);
ALTER TABLE users ADD INDEX idx_created_at (created_at);

-- Add indexes for logs table for better performance
ALTER TABLE logs ADD INDEX idx_user_action_date (user_id, action_type, created_at);
ALTER TABLE logs ADD INDEX idx_pass_action_date (pass_id, action_type, created_at);

-- Add check constraints for data integrity
ALTER TABLE passes ADD CONSTRAINT chk_people_allowed CHECK (people_allowed > 0);
ALTER TABLE passes ADD CONSTRAINT chk_max_uses CHECK (max_uses IS NULL OR max_uses > 0);
ALTER TABLE passes ADD CONSTRAINT chk_valid_dates CHECK (valid_from IS NULL OR valid_to IS NULL OR valid_from <= valid_to);
ALTER TABLE passes ADD CONSTRAINT chk_used_count CHECK (used_count >= 0);

-- Add user management fields
ALTER TABLE users ADD COLUMN created_by BIGINT NULL AFTER role;
ALTER TABLE users ADD COLUMN blocked_at TIMESTAMP NULL AFTER status;
ALTER TABLE users ADD COLUMN deleted_at TIMESTAMP NULL AFTER blocked_at;
ALTER TABLE users ADD COLUMN assigned_category INT NULL AFTER deleted_at;

-- Add usage tracking fields
ALTER TABLE passes ADD COLUMN used_count INT NOT NULL DEFAULT 0 AFTER max_uses;
ALTER TABLE passes ADD COLUMN last_scan_at TIMESTAMP NULL AFTER used_count;
ALTER TABLE passes ADD COLUMN last_scan_by BIGINT NULL AFTER last_scan_at;

-- Add foreign key constraints
ALTER TABLE users ADD CONSTRAINT fk_users_created_by FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL;
ALTER TABLE users ADD CONSTRAINT fk_users_assigned_category FOREIGN KEY (assigned_category) REFERENCES categories(id) ON DELETE SET NULL;
ALTER TABLE passes ADD CONSTRAINT fk_last_scan_by FOREIGN KEY (last_scan_by) REFERENCES users(id) ON DELETE SET NULL;

-- Add indexes for new columns
ALTER TABLE users ADD INDEX idx_created_by (created_by);
ALTER TABLE users ADD INDEX idx_blocked_at (blocked_at);
ALTER TABLE users ADD INDEX idx_deleted_at (deleted_at);
ALTER TABLE users ADD INDEX idx_assigned_category (assigned_category);

ALTER TABLE passes ADD INDEX idx_used_count (used_count);
ALTER TABLE passes ADD INDEX idx_last_scan_at (last_scan_at);
ALTER TABLE passes ADD INDEX idx_last_scan_by (last_scan_by);