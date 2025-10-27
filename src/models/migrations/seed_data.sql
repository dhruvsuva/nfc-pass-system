-- Seeder: Insert default data for production deployment
-- Date: 2025-01-20
-- Description: Insert default categories, settings, and test users for production

USE nfc_pass_system;

-- Insert default categories (if not exists)
INSERT IGNORE INTO categories (name, color_code, description) VALUES 
('All Access', '#FF6B35', 'Unlimited access pass with no validation limits'),
('VIP', '#8E44AD', 'VIP access with premium privileges'),
('General', '#3498DB', 'Standard general admission'),
('Student', '#27AE60', 'Student discount category'),
('Staff', '#E74C3C', 'Staff and employee access'),
('Premium', '#F39C12', 'Premium access with extended privileges'),
('Corporate', '#34495E', 'Corporate event access'),
('Media', '#9B59B6', 'Media and press access');

-- Insert default settings (if not exists)
INSERT IGNORE INTO settings (`key`, `value`) VALUES 
('last_reset_date', '1970-01-01'),
('system_version', '2.0.0'),
('daily_reset_enabled', 'true'),
('verify_rate_limit', '150'),
('bulk_batch_size', '200'),
('session_pass_window_minutes', '15'),
('max_people_per_pass', '10'),
('default_pass_type', 'daily'),
('auto_expire_enabled', 'true'),
('log_retention_days', '90'),
('cache_ttl_seconds', '3600'),
('websocket_enabled', 'true'),
('nfc_timeout_seconds', '30'),
('backup_enabled', 'true'),
('maintenance_mode', 'false');

-- Create default admin user (password: admin123)
INSERT IGNORE INTO users (username, email, password_hash, role, status, created_at) VALUES 
('admin', 'admin@nfcpass.com', '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'admin', 'active', NOW());

-- Create test manager user (password: manager123)
INSERT IGNORE INTO users (username, email, password_hash, role, status, created_by, assigned_category, created_at) VALUES 
('manager', 'manager@nfcpass.com', '$2a$10$CwTycUXWue0Thq9StjUM0uBYkUay4FjMW8XnZN5wltrQerpHhhb4W', 'manager', 'active', 1, 'VIP', NOW());

-- Create test bouncer user (password: bouncer123)
INSERT IGNORE INTO users (username, email, password_hash, role, status, created_by, assigned_category, created_at) VALUES 
('bouncer', 'bouncer@nfcpass.com', '$2a$10$CwTycUXWue0Thq9StjUM0uBYkUay4FjMW8XnZN5wltrQerpHhhb4W', 'bouncer', 'active', 1, 'General', NOW());

-- Create additional test users for different scenarios
INSERT IGNORE INTO users (username, email, password_hash, role, status, created_by, assigned_category, created_at) VALUES 
('gate1_bouncer', 'gate1@nfcpass.com', '$2a$10$CwTycUXWue0Thq9StjUM0uBYkUay4FjMW8XnZN5wltrQerpHhhb4W', 'bouncer', 'active', 1, 'General', NOW()),
('gate2_bouncer', 'gate2@nfcpass.com', '$2a$10$CwTycUXWue0Thq9StjUM0uBYkUay4FjMW8XnZN5wltrQerpHhhb4W', 'bouncer', 'active', 1, 'VIP', NOW()),
('vip_manager', 'vip@nfcpass.com', '$2a$10$CwTycUXWue0Thq9StjUM0uBYkUay4FjMW8XnZN5wltrQerpHhhb4W', 'manager', 'active', 1, 'VIP', NOW()),
('event_manager', 'event@nfcpass.com', '$2a$10$CwTycUXWue0Thq9StjUM0uBYkUay4FjMW8XnZN5wltrQerpHhhb4W', 'manager', 'active', 1, 'All Access', NOW());

-- Insert sample test passes for different categories
INSERT IGNORE INTO passes (uid, pass_id, scan_id, pass_type, category, category_id, people_allowed, status, created_by, max_uses, used_count) VALUES 
('TEST_DAILY_001', UUID(), UUID(), 'daily', 'General', 3, 1, 'active', 1, 1, 0),
('TEST_SESSION_001', UUID(), UUID(), 'session', 'VIP', 2, 5, 'active', 1, 11, 0),
('TEST_UNLIMITED_001', UUID(), UUID(), 'unlimited', 'All Access', 1, 10, 'active', 1, 999, 0),
('TEST_SEASONAL_001', UUID(), UUID(), 'seasonal', 'Premium', 6, 3, 'active', 1, 30, 0);

-- Log the seeding operation
INSERT INTO logs (action_type, user_id, role, details, result, created_at) VALUES 
('system_seed', 1, 'admin', JSON_OBJECT('operation', 'database_seeding', 'tables_seeded', 'categories,settings,users,passes'), 'success', NOW());

SELECT 'Seeding completed: Default data inserted successfully' as result;