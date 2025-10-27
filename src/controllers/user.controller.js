const bcrypt = require('bcryptjs');
const UserModel = require('../models/user.model');
const { validateUser, validateUserUpdate } = require('../utils/validators');
const logger = require('../utils/logger');
const LoggingService = require('../services/logging.service');

/**
 * Create a new user (Admin only)
 * POST /api/users
 */
const createUser = async (req, res) => {
  try {
    const { username, password, role = 'bouncer', status = 'active', assigned_category } = req.body;
    
    // Validate input
    const validation = validateUser({ username, password, role, status });
    if (!validation.isValid) {
      return res.status(400).json({
        success: false,
        message: 'Validation failed',
        errors: validation.errors
      });
    }

    
    // Check if user already exists
    const existingUser = await UserModel.findByUsername(username);
    if (existingUser) {
      return res.status(409).json({
        success: false,
        message: 'Username already exists'
      });
    }
    
    // Create user
    const user = await UserModel.create({
      username,
      password,
      role,
      status,
      assigned_category: role === 'bouncer' ? assigned_category : null,
      createdBy: req.user.id
    });
    
    logger.info(`User created: ${user.username} by ${req.user.role} ${req.user.username}`);
    
    // Log user creation
    await LoggingService.logCreateUser(user, req.user, req);
    
    res.status(201).json({
      success: true,
      message: 'User created successfully',
      data: {
        id: user.id,
        username: user.username,
        role: user.role,
        status: user.status,
        createdAt: user.createdAt,
        updatedAt: user.updatedAt
      }
    });
    
  } catch (error) {
    logger.error('Create user error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
};

/**
 * Get all users with search, filter, and pagination
 * GET /api/users
 */
const getUsers = async (req, res) => {
  try {
    const {
      page = 1,
      limit = 20,
      search,
      role,
      status,
      sortBy = 'created_at',
      sortOrder = 'DESC'
    } = req.query;
    
    // Validate pagination parameters
    const validPage = Math.max(1, parseInt(page) || 1);
    const validLimit = Math.max(1, Math.min(100, parseInt(limit) || 20));
    
    // Build filters
    const filters = {};
    if (search) filters.search = search;
    if (role) filters.role = role;
    if (status) filters.status = status;
    
    // Get users with pagination
    const result = await UserModel.findAllWithPagination({
      page: validPage,
      limit: validLimit,
      filters,
      sortBy,
      sortOrder
    });
    
    res.json({
      success: true,
      data: {
        users: result.users,
        pagination: {
          currentPage: validPage,
          totalPages: result.totalPages,
          totalUsers: result.totalCount,
          hasNextPage: validPage < result.totalPages,
          hasPrevPage: validPage > 1,
          limit: validLimit
        }
      }
    });
    
  } catch (error) {
    logger.error('Get users error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
};

/**
 * Get single user by ID
 * GET /api/users/:id
 */
const getUserById = async (req, res) => {
  try {
    const { id } = req.params;
    
    const user = await UserModel.findById(id);
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      });
    }
    
    res.json({
      success: true,
      data: { user }
    });
    
  } catch (error) {
    logger.error('Get user by ID error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
};

/**
 * Update user details
 * PATCH /api/users/:id
 */
const updateUser = async (req, res) => {
  try {
    const { id } = req.params;
    const { username, role, status, assigned_category } = req.body;
    
    // Find user
    const user = await UserModel.findByIdIncludeInactive(id);
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      });
    }
    
    // Prevent admin from updating their own role
    if (user.id === req.user.id && role && role !== user.role) {
      return res.status(403).json({
        success: false,
        message: 'Cannot change your own role'
      });
    }

    
    // Check for duplicate username
    if (username && username !== user.username) {
      const existingUser = await UserModel.findByUsername(username);
      if (existingUser && existingUser.id !== parseInt(id)) {
        return res.status(409).json({
          success: false,
          message: 'Username already exists'
        });
      }
    }
    
    // Prepare update data
    const newRole = role || user.role;
    const updateData = {
      username: username || user.username,
      role: newRole,
      status: status || user.status,
      // Clear assigned_category if role changes from bouncer to something else
      assigned_category: newRole === 'bouncer' 
        ? (assigned_category !== undefined ? assigned_category : user.assigned_category)
        : null
    };

    
    // Update user
    const updatedUser = await UserModel.update(id, updateData);
    
    logger.info(`User updated: ${updatedUser.username} by ${req.user.role} ${req.user.username}`);
    
    // Log user update
    const changes = {};
    if (username && username !== user.username) changes.username = { from: user.username, to: username };
    if (role && role !== user.role) changes.role = { from: user.role, to: role };
    if (status && status !== user.status) changes.status = { from: user.status, to: status };
    if (assigned_category !== undefined && assigned_category !== user.assigned_category) changes.assigned_category = { from: user.assigned_category, to: assigned_category };
    await LoggingService.logUpdateUser(updatedUser, req.user, req, changes);
    
    res.json({
      success: true,
      message: 'User updated successfully',
      data: { user: updatedUser }
    });
    
  } catch (error) {
    logger.error('Update user error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
};

/**
 * Change user password
 * PATCH /api/users/:id/password
 */
const changePassword = async (req, res) => {
  try {
    const { id } = req.params;
    const { password } = req.body;
    
    if (!password || password.length < 6) {
      return res.status(400).json({
        success: false,
        message: 'Password must be at least 6 characters long'
      });
    }
    
    // Find user
    const user = await UserModel.findById(id);
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      });
    }
    
    // Update password
    await UserModel.updatePassword(id, password);
    
    logger.info(`Password changed for user: ${user.username} by ${req.user.role} ${req.user.username}`);
    
    // Log password change action
    await LoggingService.logChangePassword(user, req.user, req);
    
    res.json({
      success: true,
      message: 'Password changed successfully'
    });
    
  } catch (error) {
    logger.error('Change password error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
};

/**
 * Assign category to user
 * PATCH /api/users/:id/assign-category
 */
const assignCategory = async (req, res) => {
  try {
    const { id } = req.params;
    const { category } = req.body;
    
    if (!category) {
      return res.status(400).json({
        success: false,
        message: 'Category is required'
      });
    }
    
    // Find user
    const user = await UserModel.findById(id);
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      });
    }
    
    // Only assign categories to bouncers
    if (user.role !== 'bouncer') {
      return res.status(400).json({
        success: false,
        message: 'Categories can only be assigned to bouncers'
      });
    }
    
    // Assign category
    await UserModel.assignCategory(id, category);
    
    logger.info(`Category ${category} assigned to user: ${user.username} by ${req.user.role} ${req.user.username}`);
    
    // Log category assignment
    await LoggingService.logAssignCategory(user, category, req.user, req);
    
    res.json({
      success: true,
      message: 'Category assigned successfully',
      data: {
        userId: user.id,
        username: user.username,
        assignedCategory: category
      }
    });
    
  } catch (error) {
    logger.error('Assign category error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
};

/**
 * Block user
 * PATCH /api/users/:id/block
 */
const blockUser = async (req, res) => {
  try {
    const { id } = req.params;
    const { reason = 'Blocked by admin' } = req.body;
    
    // Find user
    const user = await UserModel.findById(id);
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      });
    }
    
    // Prevent blocking admin users
    if (user.role === 'admin') {
      return res.status(403).json({
        success: false,
        message: 'Cannot block admin users'
      });
    }
    
    // Prevent admin from blocking themselves
    if (user.id === req.user.id) {
      return res.status(403).json({
        success: false,
        message: 'Cannot block your own account'
      });
    }
    
    // Block user
    await UserModel.blockUser(id, req.user.id, reason);
    
    logger.info(`User blocked: ${user.username} by ${req.user.role} ${req.user.username}`);
    
    // Log user block action
    await LoggingService.logBlockUnblockUser(user, 'block', req.user, req, reason);
    
    res.json({
      success: true,
      message: 'User blocked successfully'
    });
    
  } catch (error) {
    logger.error('Block user error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
};

/**
 * Unblock user
 * PATCH /api/users/:id/unblock
 */
const unblockUser = async (req, res) => {
  try {
    const { id } = req.params;
    
    // Find user
    const user = await UserModel.findById(id);
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      });
    }
    
    // Unblock user
    await UserModel.unblockUser(id, req.user.id);
    
    logger.info(`User unblocked: ${user.username} by ${req.user.role} ${req.user.username}`);
    
    // Log user unblock action
    await LoggingService.logBlockUnblockUser(user, 'unblock', req.user, req);
    
    res.json({
      success: true,
      message: 'User unblocked successfully'
    });
    
  } catch (error) {
    logger.error('Unblock user error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
};

/**
 * Delete single user
 * DELETE /api/users/:id
 */
const deleteUser = async (req, res) => {
  try {
    const { id } = req.params;
    
    // Find user
    const user = await UserModel.findById(id);
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      });
    }
    
    // Prevent deleting admin users
    if (user.role === 'admin') {
      return res.status(403).json({
        success: false,
        message: 'Cannot delete admin users'
      });
    }
    
    // Prevent admin from deleting themselves
    if (user.id === req.user.id) {
      return res.status(403).json({
        success: false,
        message: 'Cannot delete your own account'
      });
    }
    
    // Hard delete user completely
    await UserModel.delete(id);
    
    logger.info(`User deleted: ${user.username} by ${req.user.role} ${req.user.username}`);
    
    // Log user deletion
    await LoggingService.logDeleteUser(user, req.user, req);
    
    res.json({
      success: true,
      message: 'User deleted successfully'
    });
    
  } catch (error) {
    logger.error('Delete user error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
};

/**
 * Delete all users except admins
 * DELETE /api/users
 */
const deleteAllUsers = async (req, res) => {
  try {
    // Bulk hard delete all non-admin users
    const deletedCount = await UserModel.bulkDelete(
      { role: ['manager', 'bouncer'] }
    );
    
    logger.info(`Bulk deleted ${deletedCount} non-admin users by ${req.user.role} ${req.user.username}`);
    
    res.json({
      success: true,
      message: `Successfully deleted ${deletedCount} users (admins protected)`,
      deletedCount
    });
    
  } catch (error) {
    logger.error('Delete all users error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
};

/**
 * Get user statistics
 * GET /api/users/stats
 */
const getUserStats = async (req, res) => {
  try {
    const stats = await UserModel.getUserStats();
    
    res.json({
      success: true,
      data: { stats }
    });
    
  } catch (error) {
    logger.error('Get user stats error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
};

module.exports = {
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
};