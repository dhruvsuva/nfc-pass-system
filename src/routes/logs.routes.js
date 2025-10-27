const express = require('express');
const logsController = require('../controllers/logs.controller');
const { authenticateToken, authorizeRoles } = require('../utils/auth.middleware');

const router = express.Router();

// Admin-only logs endpoints
router.get('/system', authenticateToken, authorizeRoles('admin'), logsController.getSystemLogs);
router.get('/daily', authenticateToken, authorizeRoles('admin'), logsController.getDailyLogs);
router.get('/combined', authenticateToken, authorizeRoles('admin'), logsController.getCombinedLogs);
router.get('/stats', authenticateToken, authorizeRoles('admin'), logsController.getLogStats);

module.exports = router;
