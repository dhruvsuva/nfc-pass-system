-- Migration: Create comprehensive logs table for tracking all system actions
-- Version: 004
-- Description: Creates logs table with comprehensive schema for authentication, pass management, verification, and system logs

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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;