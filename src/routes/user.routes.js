const express = require('express');
const router = express.Router();
const {
  createUser,
  getUsers,
  getUserById,
  updateUser,
  changePassword,
  assignCategory,
  blockUser,
  unblockUser,
  deleteUser,
  deleteAllUsers,
  getUserStats
} = require('../controllers/user.controller');
const { authenticateToken, authorizeRoles, adminOrManager } = require('../utils/auth.middleware');

// User management routes require admin or manager role
const requireAdminOrManager = adminOrManager;

/**
 * @route   POST /api/users
 * @desc    Create a new user (Admin/Manager)
 * @access  Private (Admin/Manager)
 */
router.post('/', authenticateToken, requireAdminOrManager, createUser);

/**
 * @route   GET /api/users/stats
 * @desc    Get user statistics (Admin/Manager)
 * @access  Private (Admin/Manager)
 */
router.get('/stats', authenticateToken, requireAdminOrManager, getUserStats);

/**
 * @route   GET /api/users
 * @desc    Get all users with search, filter, and pagination (Admin/Manager)
 * @access  Private (Admin/Manager)
 * @query   page, limit, search, role, status, sortBy, sortOrder
 */
router.get('/', authenticateToken, requireAdminOrManager, getUsers);

/**
 * @route   GET /api/users/:id
 * @desc    Get single user by ID (Admin/Manager)
 * @access  Private (Admin/Manager)
 */
router.get('/:id', authenticateToken, requireAdminOrManager, getUserById);

/**
 * @route   PATCH /api/users/:id
 * @desc    Update user details (Admin/Manager)
 * @access  Private (Admin/Manager)
 */
router.patch('/:id', authenticateToken, requireAdminOrManager, updateUser);

/**
 * @route   PATCH /api/users/:id/password
 * @desc    Change user password (Admin/Manager)
 * @access  Private (Admin/Manager)
 */
router.patch('/:id/password', authenticateToken, requireAdminOrManager, changePassword);

/**
 * @route   PATCH /api/users/:id/assign-category
 * @desc    Assign category to bouncer (Admin/Manager)
 * @access  Private (Admin/Manager)
 */
router.patch('/:id/assign-category', authenticateToken, requireAdminOrManager, assignCategory);

/**
 * @route   PATCH /api/users/:id/block
 * @desc    Block user (Admin/Manager)
 * @access  Private (Admin/Manager)
 */
router.patch('/:id/block', authenticateToken, requireAdminOrManager, blockUser);

/**
 * @route   PATCH /api/users/:id/unblock
 * @desc    Unblock user (Admin/Manager)
 * @access  Private (Admin/Manager)
 */
router.patch('/:id/unblock', authenticateToken, requireAdminOrManager, unblockUser);

/**
 * @route   DELETE /api/users/:id
 * @desc    Delete single user (Admin/Manager)
 * @access  Private (Admin/Manager)
 */
router.delete('/:id', authenticateToken, requireAdminOrManager, deleteUser);

/**
 * @route   DELETE /api/users
 * @desc    Delete all users except admins (Admin/Manager)
 * @access  Private (Admin/Manager)
 */
router.delete('/', authenticateToken, requireAdminOrManager, deleteAllUsers);

module.exports = router;