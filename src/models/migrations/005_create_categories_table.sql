-- Create categories table for dynamic category management
CREATE TABLE IF NOT EXISTS categories (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(100) NOT NULL UNIQUE,
    color_code VARCHAR(7) NOT NULL DEFAULT '#007bff', -- Hex color code
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    -- Indexes for performance
    INDEX idx_categories_name (name),
    INDEX idx_categories_created_at (created_at)
);

-- Insert default categories including the special "All Access" category
INSERT INTO categories (name, color_code, description) VALUES
('General', '#007bff', 'General admission pass'),
('VIP', '#ffc107', 'VIP access with premium benefits'),
('Staff', '#28a745', 'Staff access for event personnel'),
('All Access', '#dc3545', 'Unlimited access pass with no usage restrictions'),
('Premium', '#6f42c1', 'Premium tier access'),
('Student', '#17a2b8', 'Student discount category');

-- Add category_id column to passes table if it doesn't exist
ALTER TABLE passes 
ADD COLUMN IF NOT EXISTS category_id BIGINT,
ADD CONSTRAINT fk_passes_category 
    FOREIGN KEY (category_id) REFERENCES categories(id) 
    ON DELETE SET NULL ON UPDATE CASCADE;

-- Create index on category_id for better performance
CREATE INDEX IF NOT EXISTS idx_passes_category_id ON passes(category_id);

-- Update existing passes to have a default category (General)
UPDATE passes 
SET category_id = (SELECT id FROM categories WHERE name = 'General' LIMIT 1)
WHERE category_id IS NULL;