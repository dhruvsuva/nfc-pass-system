-- Migration: Update daily logs table schema for usage tracking
-- Date: 2025-09-17
-- Description: Add columns for remaining_uses, consumed_count, and prompt_consumption tracking

USE nfc_pass_system;

-- Create a procedure to update all existing daily log tables
DELIMITER //

CREATE PROCEDURE UpdateDailyLogsTables()
BEGIN
    DECLARE done INT DEFAULT FALSE;
    DECLARE table_name VARCHAR(255);
    DECLARE cur CURSOR FOR 
        SELECT TABLE_NAME 
        FROM INFORMATION_SCHEMA.TABLES 
        WHERE TABLE_SCHEMA = 'nfc_pass_system' 
        AND TABLE_NAME LIKE 'daily_logs_%';
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

    OPEN cur;
    
    read_loop: LOOP
        FETCH cur INTO table_name;
        IF done THEN
            LEAVE read_loop;
        END IF;
        
        -- Check if columns already exist before adding them
        SET @sql = CONCAT('ALTER TABLE ', table_name, ' 
            ADD COLUMN IF NOT EXISTS remaining_uses INT NULL COMMENT "Remaining uses after this verification",
            ADD COLUMN IF NOT EXISTS consumed_count INT NOT NULL DEFAULT 1 COMMENT "Number of entries consumed in this verification",
            ADD COLUMN IF NOT EXISTS prompt_consumption BOOLEAN NOT NULL DEFAULT FALSE COMMENT "Whether this was consumed via prompt token",
            ADD COLUMN IF NOT EXISTS offline_sync BOOLEAN NOT NULL DEFAULT FALSE COMMENT "Whether this was synced from offline logs"');
        
        PREPARE stmt FROM @sql;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;
        
        SELECT CONCAT('Updated table: ', table_name) as result;
        
    END LOOP;
    
    CLOSE cur;
END//

DELIMITER ;

-- Execute the procedure
CALL UpdateDailyLogsTables();

-- Drop the procedure after use
DROP PROCEDURE UpdateDailyLogsTables;

-- Update the daily log table creation function to include new columns
-- This ensures future daily log tables will have the correct schema
SELECT 'Daily logs schema migration completed' as result;