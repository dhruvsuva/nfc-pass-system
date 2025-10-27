const { executeQuery } = require('../config/db');
const logger = require('../utils/logger');

class CategoriesModel {
  /**
   * Create a new category
   * @param {Object} categoryData - Category data
   * @param {string} categoryData.name - Category name
   * @param {string} categoryData.color_code - Hex color code
   * @param {string} categoryData.description - Category description
   * @returns {Promise<Object>} Created category
   */
  static async create(categoryData) {
    const { name, color_code, description } = categoryData;
    
    try {
      const query = `
        INSERT INTO categories (name, color_code, description)
        VALUES (?, ?, ?)
      `;
      
      // Convert undefined to null for SQL compatibility
      const params = [
        name || null,
        color_code || null,
        description === undefined ? null : description
      ];
      
      const result = await executeQuery(query, params);
      
      logger.info(`Category created: ${name} (ID: ${result.insertId})`);
      
      // Return the created category
      return await this.findById(result.insertId);
    } catch (error) {
      logger.error('Error creating category:', error);
      throw error;
    }
  }

  /**
   * Get all categories
   * @returns {Promise<Array>} List of categories
   */
  static async findAll() {
    try {
      const query = `
        SELECT id, name, color_code, description, created_at, updated_at
        FROM categories
        ORDER BY name ASC
      `;
      
      const rows = await executeQuery(query);
      return rows;
    } catch (error) {
      logger.error('Error fetching categories:', error);
      throw error;
    }
  }

  /**
   * Get category by ID
   * @param {number} id - Category ID
   * @returns {Promise<Object|null>} Category or null if not found
   */
  static async findById(id) {
    try {
      const query = `
        SELECT id, name, color_code, description, created_at, updated_at
        FROM categories
        WHERE id = ?
      `;
      
      const rows = await executeQuery(query, [id]);
      return rows[0] || null;
    } catch (error) {
      logger.error('Error fetching category by ID:', error);
      throw error;
    }
  }

  /**
   * Get category by name
   * @param {string} name - Category name
   * @returns {Promise<Object|null>} Category or null if not found
   */
  static async findByName(name) {
    try {
      const query = `
        SELECT id, name, color_code, description, created_at, updated_at
        FROM categories
        WHERE name = ?
      `;
      
      const rows = await executeQuery(query, [name]);
      return rows[0] || null;
    } catch (error) {
      logger.error('Error fetching category by name:', error);
      throw error;
    }
  }

  /**
   * Update category
   * @param {number} id - Category ID
   * @param {Object} updateData - Data to update
   * @returns {Promise<Object|null>} Updated category or null if not found
   */
  static async update(id, updateData) {
    try {
      const allowedFields = ['name', 'color_code', 'description'];
      const updates = [];
      const values = [];

      // Build dynamic update query
      Object.keys(updateData).forEach(key => {
        if (allowedFields.includes(key) && updateData[key] !== undefined) {
          updates.push(`${key} = ?`);
          values.push(updateData[key]);
        }
      });

      if (updates.length === 0) {
        throw new Error('No valid fields to update');
      }

      values.push(id);

      const query = `
        UPDATE categories 
        SET ${updates.join(', ')}, updated_at = CURRENT_TIMESTAMP
        WHERE id = ?
      `;

      const result = await executeQuery(query, values);

      if (result.affectedRows === 0) {
        return null;
      }

      logger.info(`Category updated: ID ${id}`);
      return await this.findById(id);
    } catch (error) {
      logger.error('Error updating category:', error);
      throw error;
    }
  }

  /**
   * Delete category
   * @param {number} id - Category ID
   * @returns {Promise<boolean>} True if deleted, false if not found
   */
  static async delete(id) {
    try {
      // Check if category exists
      const category = await this.findById(id);
      if (!category) {
        return false;
      }

      // Check if category is being used by any active passes
      const passCountQuery = `
        SELECT COUNT(*) as count
        FROM passes
        WHERE category = ? AND status != 'deleted'
      `;
      
      const passCountResult = await executeQuery(passCountQuery, [category.name]);
      const passCount = passCountResult[0].count;

      if (passCount > 0) {
        throw new Error(`Cannot delete category. It is being used by ${passCount} pass(es)`);
      }

      const query = `DELETE FROM categories WHERE id = ?`;
      const result = await executeQuery(query, [id]);

      logger.info(`Category deleted: ${category.name} (ID: ${id})`);
      return result.affectedRows > 0;
    } catch (error) {
      logger.error('Error deleting category:', error);
      throw error;
    }
  }

  /**
   * Check if category exists
   * @param {number} id - Category ID
   * @returns {Promise<boolean>} True if exists, false otherwise
   */
  static async exists(id) {
    try {
      const category = await this.findById(id);
      return category !== null;
    } catch (error) {
      logger.error('Error checking category existence:', error);
      throw error;
    }
  }

  /**
   * Check if category is "All Access" type (deprecated - All Access removed)
   * @param {number} id - Category ID
   * @returns {Promise<boolean>} Always returns false as All Access is removed
   */
  static async isAllAccess(id) {
    // Always return false as All Access category is no longer special
    return false;
  }

  /**
   * Get All Access category (deprecated - All Access is no longer special)
   * @returns {Promise<Object|null>} All Access category or null if not found
   */
  static async getAllAccessCategory() {
    try {
      return await this.findByName('All Access');
    } catch (error) {
      logger.error('Error in getAllAccessCategory:', error);
      throw error;
    }
  }

  /**
   * Get categories with pass count
   * @returns {Promise<Array>} Categories with pass counts
   */
  static async findAllWithPassCount() {
    try {
      const query = `
        SELECT 
          c.id,
          c.name,
          c.color_code,
          c.description,
          c.created_at,
          c.updated_at,
          COUNT(p.id) as pass_count
        FROM categories c
        LEFT JOIN passes p ON c.name = p.category
        GROUP BY c.id, c.name, c.color_code, c.description, c.created_at, c.updated_at
        ORDER BY c.name ASC
      `;
      
      const rows = await executeQuery(query);
      return rows;
    } catch (error) {
      logger.error('Error fetching categories with pass count:', error);
      throw error;
    }
  }

  /**
   * Validate category data
   * @param {Object} categoryData - Category data to validate
   * @returns {Object} Validation result
   */
  static validateCategoryData(categoryData) {
    const errors = [];
    const { name, color_code, description } = categoryData;

    // Validate name
    if (!name || typeof name !== 'string') {
      errors.push('Name is required and must be a string');
    } else if (name.length < 2 || name.length > 100) {
      errors.push('Name must be between 2 and 100 characters');
    }

    // Validate color_code
    if (!color_code || typeof color_code !== 'string') {
      errors.push('Color code is required and must be a string');
    } else if (!/^#[0-9A-Fa-f]{6}$/.test(color_code)) {
      errors.push('Color code must be a valid hex color (e.g., #FF0000)');
    }

    // Validate description (optional)
    if (description !== undefined && description !== null) {
      if (typeof description !== 'string') {
        errors.push('Description must be a string');
      } else if (description.length > 500) {
        errors.push('Description must not exceed 500 characters');
      }
    }

    return {
      isValid: errors.length === 0,
      errors
    };
  }
}

module.exports = CategoriesModel;