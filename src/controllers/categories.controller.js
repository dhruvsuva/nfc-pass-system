const CategoriesModel = require('../models/categories.model');
const logger = require('../utils/logger');
const LoggingService = require('../services/logging.service');

class CategoriesController {
  /**
   * Create a new category
   * POST /api/categories
   */
  static async createCategory(req, res) {
    try {
      const { name, color_code, description } = req.body;

      // Validate input data
      const validation = CategoriesModel.validateCategoryData({ name, color_code, description });
      if (!validation.isValid) {
        return res.status(400).json({
          success: false,
          message: 'Validation failed',
          errors: validation.errors
        });
      }

      // Check if category with same name already exists
      const existingCategory = await CategoriesModel.findByName(name);
      if (existingCategory) {
        return res.status(409).json({
          success: false,
          message: 'Category with this name already exists'
        });
      }

      // Create category
      const category = await CategoriesModel.create({ name, color_code, description });

      logger.info(`Category created by user ${req.user.id}: ${name}`);
      
      // Log the category creation action
      await LoggingService.logCreateCategory(category, req.user, req);

      res.status(201).json({
        success: true,
        message: 'Category created successfully',
        data: category
      });
    } catch (error) {
      logger.error('Error creating category:', error);
      res.status(500).json({
        success: false,
        message: 'Internal server error',
        error: process.env.NODE_ENV === 'development' ? error.message : undefined
      });
    }
  }

  /**
   * Get all categories
   * GET /api/categories
   */
  static async getCategories(req, res) {
    try {
      const includePassCount = req.query.include_pass_count === 'true';
      
      // Debug logs
      logger.info(`Categories API called - includePassCount: ${includePassCount}`);
      logger.info(`Request user: ${JSON.stringify(req.user)}`);
      
      let categories;
      if (includePassCount) {
        logger.info('Calling findAllWithPassCount...');
        categories = await CategoriesModel.findAllWithPassCount();
        logger.info(`findAllWithPassCount returned ${categories.length} categories`);
      } else {
        logger.info('Calling findAll...');
        categories = await CategoriesModel.findAll();
        logger.info(`findAll returned ${categories.length} categories`);
      }

      logger.info(`Final categories count: ${categories.length}`);
      logger.info(`Categories data: ${JSON.stringify(categories.map(c => ({ id: c.id, name: c.name })))}`);

      res.json({
        success: true,
        message: 'Categories retrieved successfully',
        data: categories,
        count: categories.length
      });
    } catch (error) {
      logger.error('Error fetching categories:', error);
      res.status(500).json({
        success: false,
        message: 'Internal server error',
        error: process.env.NODE_ENV === 'development' ? error.message : undefined
      });
    }
  }

  /**
   * Get category by ID
   * GET /api/categories/:id
   */
  static async getCategoryById(req, res) {
    try {
      const { id } = req.params;

      // Validate ID
      if (!id || isNaN(parseInt(id))) {
        return res.status(400).json({
          success: false,
          message: 'Invalid category ID'
        });
      }

      const category = await CategoriesModel.findById(parseInt(id));

      if (!category) {
        return res.status(404).json({
          success: false,
          message: 'Category not found'
        });
      }

      res.json({
        success: true,
        message: 'Category retrieved successfully',
        data: category
      });
    } catch (error) {
      logger.error('Error fetching category:', error);
      res.status(500).json({
        success: false,
        message: 'Internal server error',
        error: process.env.NODE_ENV === 'development' ? error.message : undefined
      });
    }
  }

  /**
   * DEBUG endpoint - Direct SQL query test
   * GET /api/categories/debug/sql
   */
  static async debugSqlQuery(req, res) {
    try {
      const { executeQuery } = require('../config/db');
      
      logger.info('Debug SQL query called');
      
      // Test direct SQL query
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
      
      logger.info('Executing direct SQL query...');
      const directResults = await executeQuery(query);
      logger.info(`Direct SQL query returned ${directResults.length} categories`);
      
      // Test model method
      logger.info('Calling CategoriesModel.findAllWithPassCount...');
      const modelResults = await CategoriesModel.findAllWithPassCount();
      logger.info(`Model method returned ${modelResults.length} categories`);
      
      res.status(200).json({
        success: true,
        message: 'Debug query executed',
        data: {
          directSql: {
            count: directResults.length,
            results: directResults
          },
          modelMethod: {
            count: modelResults.length,
            results: modelResults
          }
        }
      });
    } catch (error) {
      logger.error('Error in debug SQL query:', error);
      res.status(500).json({
        success: false,
        message: 'Internal server error',
        error: process.env.NODE_ENV === 'development' ? error.message : undefined
      });
    }
  }

  /**
   * Update category
   * PATCH /api/categories/:id
   */
  static async updateCategory(req, res) {
    try {
      const { id } = req.params;
      const updateData = req.body;

      // Validate ID
      if (!id || isNaN(parseInt(id))) {
        return res.status(400).json({
          success: false,
          message: 'Invalid category ID'
        });
      }

      // Check if category exists
      const existingCategory = await CategoriesModel.findById(parseInt(id));
      if (!existingCategory) {
        return res.status(404).json({
          success: false,
          message: 'Category not found'
        });
      }

      // Validate update data
      const validation = CategoriesModel.validateCategoryData(updateData);
      if (!validation.isValid) {
        return res.status(400).json({
          success: false,
          message: 'Validation failed',
          errors: validation.errors
        });
      }

      // Check if name is being updated and if it conflicts with existing category
      if (updateData.name && updateData.name !== existingCategory.name) {
        const nameConflict = await CategoriesModel.findByName(updateData.name);
        if (nameConflict) {
          return res.status(409).json({
            success: false,
            message: 'Category with this name already exists'
          });
        }
      }

      // Update category
      const updatedCategory = await CategoriesModel.update(parseInt(id), updateData);

      logger.info(`Category updated by user ${req.user.id}: ${existingCategory.name} (ID: ${id})`);
      
      // Log the category update action
      await LoggingService.logUpdateCategory(updatedCategory, existingCategory, req.user, req, updateData);

      res.json({
        success: true,
        message: 'Category updated successfully',
        data: updatedCategory
      });
    } catch (error) {
      logger.error('Error updating category:', error);
      res.status(500).json({
        success: false,
        message: 'Internal server error',
        error: process.env.NODE_ENV === 'development' ? error.message : undefined
      });
    }
  }

  /**
   * Delete category
   * DELETE /api/categories/:id
   */
  static async deleteCategory(req, res) {
    try {
      const { id } = req.params;

      // Validate ID
      if (!id || isNaN(parseInt(id))) {
        return res.status(400).json({
          success: false,
          message: 'Invalid category ID'
        });
      }

      // Check if category exists
      const existingCategory = await CategoriesModel.findById(parseInt(id));
      if (!existingCategory) {
        return res.status(404).json({
          success: false,
          message: 'Category not found'
        });
      }

      // Note: All categories can now be deleted as we only use fixed categories

      // Delete category
      const deleted = await CategoriesModel.delete(parseInt(id));

      if (!deleted) {
        return res.status(404).json({
          success: false,
          message: 'Category not found'
        });
      }

      logger.info(`Category deleted by user ${req.user.id}: ${existingCategory.name} (ID: ${id})`);
      
      // Log the category deletion action
      await LoggingService.logDeleteCategory(existingCategory, req.user, req);

      res.json({
        success: true,
        message: 'Category deleted successfully'
      });
    } catch (error) {
      logger.error('Error deleting category:', error);
      
      // Handle specific error for categories in use
      if (error.message.includes('Cannot delete category')) {
        return res.status(409).json({
          success: false,
          message: error.message
        });
      }

      res.status(500).json({
        success: false,
        message: 'Internal server error',
        error: process.env.NODE_ENV === 'development' ? error.message : undefined
      });
    }
  }

  /**
   * Get All Access category
   * GET /api/categories/all-access
   */
  static async getAllAccessCategory(req, res) {
    try {
      const allAccessCategory = await CategoriesModel.findByName('All Access');
      
      if (!allAccessCategory) {
        return res.status(404).json({
          success: false,
          message: 'All Access category not found in database'
        });
      }

      res.json({
        success: true,
        message: 'All Access category retrieved successfully',
        data: allAccessCategory
      });
    } catch (error) {
      logger.error('Error in getAllAccessCategory:', error);
      res.status(500).json({
        success: false,
        message: 'Internal server error',
        error: process.env.NODE_ENV === 'development' ? error.message : undefined
      });
    }
  }
}

module.exports = CategoriesController;