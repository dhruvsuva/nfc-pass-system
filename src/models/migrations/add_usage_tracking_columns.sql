-- Migration: Add usage tracking columns to passes table
-- Date: 2025-09-17
-- Description: Add max_uses, used_count, last_scan_at, last_scan_by columns for session pass support

USE nfc_pass_system;

-- Add new columns for usage tracking
ALTER TABLE passes 
ADD COLUMN max_uses INT NOT NULL DEFAULT 1 COMMENT 'Total allowed uses (11 for session passes)',
ADD COLUMN used_count INT NOT NULL DEFAULT 0 COMMENT 'Total times consumed so far',
ADD COLUMN last_scan_at DATETIME NULL COMMENT 'Last time scanned',
ADD COLUMN last_scan_by BIGINT NULL COMMENT 'User ID who last scanned (bouncer)',
ADD INDEX idx_passes_last_scan_at (last_scan_at),
ADD INDEX idx_passes_used_count (used_count),
ADD FOREIGN KEY fk_passes_last_scan_by (last_scan_by) REFERENCES users(id) ON DELETE SET NULL;

-- Update existing passes to have proper max_uses based on pass_type
UPDATE passes 
SET max_uses = CASE 
    WHEN pass_type = 'session' THEN 11
    WHEN pass_type = 'daily' THEN 1
    WHEN pass_type = 'seasonal' THEN 30
    ELSE 1
END
WHERE max_uses = 1;

-- Update used_count based on current status
UPDATE passes 
SET used_count = CASE 
    WHEN status = 'used' THEN max_uses
    ELSE 0
END
WHERE used_count = 0;

SELECT 'Migration completed: Added usage tracking columns to passes table' as result;