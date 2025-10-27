const express = require('express');
const router = express.Router();
const categoriesController = require('../controllers/categories.controller');
const { authenticateToken, authorizeRoles } = require('../utils/auth.middleware');

// All category management routes require admin role
const requireAdmin = authorizeRoles('admin');

// Apply authentication to all routes
router.use(authenticateToken);

/**
 * @route   GET /api/categories
 * @desc    Get all categories
 * @access  Private (Authenticated users)
 * @query   include_pass_count - Include pass count for each category
 */
router.get('/', categoriesController.getCategories);

/**
 * @route   GET /api/categories/debug/sql
 * @desc    Debug SQL query comparison
 * @access  Private (Admin only)
 */
router.get('/debug/sql', requireAdmin, categoriesController.debugSqlQuery);

/**
 * @route   GET /api/categories/all-access
 * @desc    Get All Access category
 * @access  Private (Authenticated users)
 */
router.get('/all-access', categoriesController.getAllAccessCategory);

/**
 * @route   GET /api/categories/:id
 * @desc    Get category by ID
 * @access  Private (Authenticated users)
 */
router.get('/:id', categoriesController.getCategoryById);

/**
 * @route   POST /api/categories
 * @desc    Create a new category
 * @access  Private (Admin only)
 */
router.post('/', requireAdmin, categoriesController.createCategory);

/**
 * @route   PATCH /api/categories/:id
 * @desc    Update category
 * @access  Private (Admin only)
 */
router.patch('/:id', requireAdmin, categoriesController.updateCategory);

/**
 * @route   DELETE /api/categories/:id
 * @desc    Delete category
 * @access  Private (Admin only)
 */
router.delete('/:id', requireAdmin, categoriesController.deleteCategory);

module.exports = router;