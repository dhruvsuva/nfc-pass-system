const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const http = require('http');
const socketIo = require('socket.io');
const rateLimit = require('express-rate-limit');
require('dotenv').config();

// Set timezone to Kolkata (Indian Standard Time)
process.env.TZ = 'Asia/Kolkata';

const { connectDB } = require('./config/db');
const { connectRedis } = require('./config/redis');
const logger = require('./utils/logger');

// Import routes
const authRoutes = require('./controllers/auth.controller');
const passRoutes = require('./controllers/pass.controller');
const verifyRoutes = require('./controllers/verify.controller');
const logsRoutes = require('./routes/logs.routes');
const systemLogsRoutes = require('./controllers/system-logs.controller');
const adminRoutes = require('./controllers/admin.controller');
const userRoutes = require('./routes/user.routes');
const categoriesRoutes = require('./routes/categories.routes');
const healthRoutes = require('./controllers/health.controller');

// Import socket handlers
const bulkSocket = require('./sockets/bulk.socket');
const notificationSocket = require('./sockets/notifications.socket');
const systemLogsSocket = require('./sockets/system-logs.socket');
const UserSocket = require('./sockets/user.socket');

const app = express();
const server = http.createServer(app);
const io = socketIo(server, {
  cors: {
    origin: process.env.CORS_ORIGIN || "*",
    methods: ["GET", "POST"]
  }
});

// Middleware
// Configure trust proxy more securely
const trustedProxies = process.env.TRUSTED_PROXIES ? 
  process.env.TRUSTED_PROXIES.split(',').map(ip => ip.trim()) : 
  ['127.0.0.1', '::1']; // Default to localhost only

// Set trust proxy to specific IPs or number of hops instead of true
if (process.env.NODE_ENV === 'production') {
  app.set('trust proxy', trustedProxies);
} else {
  // In development, trust localhost only
  app.set('trust proxy', ['127.0.0.1', '::1']);
}

// Global rate limiting with improved security
const globalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 1000, // limit each IP to 1000 requests per windowMs
  message: 'Too many requests from this IP, please try again later.',
  standardHeaders: true,
  legacyHeaders: false,
  // Secure key generator that validates IP sources
  keyGenerator: (req) => {
    let ip = req.ip;
    
    // Only trust proxy headers if we're behind a trusted proxy
    const isTrustedProxy = trustedProxies.includes(req.connection.remoteAddress) || 
                          trustedProxies.includes(req.socket.remoteAddress);
    
    if (isTrustedProxy) {
      const forwarded = req.headers['x-forwarded-for'];
      const realIp = req.headers['x-real-ip'];
      
      if (forwarded) {
        ip = forwarded.split(',')[0].trim();
      } else if (realIp) {
        ip = realIp;
      }
    }
    
    // Validate IP format using a simple regex
    const ipRegex = /^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$|^([0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}$/;
    
    return ipRegex.test(ip) ? ip : 'unknown';
  },
  // Skip rate limiting for health checks
  skip: (req) => req.path === '/health'
});
app.use(helmet());
app.use(cors());
app.use(globalLimiter);
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// Health and monitoring endpoints
app.use('/', healthRoutes);

// Routes
app.use('/auth', authRoutes);
app.use('/api/pass', passRoutes);
app.use('/api/pass', verifyRoutes);
app.use('/api/logs', logsRoutes);
app.use('/api/system-logs', systemLogsRoutes);
app.use('/api/admin', adminRoutes);

// Admin logs endpoints are now handled by logs routes
app.use('/api/users', userRoutes);
app.use('/api/categories', categoriesRoutes);

// Initialize socket handlers
const userSocket = new UserSocket(io);
let systemLogsSocketHandler = null;

// Make socket handlers available to the app
app.set('io', io);
app.set('userSocket', userSocket);
app.set('getSystemLogsSocket', () => systemLogsSocketHandler);

// Socket.io setup
io.on('connection', (socket) => {
  logger.info(`Client connected: ${socket.id}`);
  
  // Handle bulk operations
  bulkSocket(socket, io);
  
  // Handle notifications
  notificationSocket(socket, io);
  
  // Handle system logs (store the handler for external use)
  systemLogsSocketHandler = systemLogsSocket(socket, io);
  
  socket.on('disconnect', () => {
    logger.info(`Client disconnected: ${socket.id}`);
  });
});

// Error handling middleware
app.use((err, req, res, next) => {
  logger.error('Unhandled error:', err);
  res.status(500).json({ 
    error: 'Internal server error',
    message: process.env.NODE_ENV === 'development' ? err.message : 'Something went wrong'
  });
});

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({ error: 'Route not found' });
});

const PORT = process.env.PORT || 3000;

// Initialize connections and start server
async function startServer() {
  try {
    // Connect to databases
    await connectDB();
    // Conditionally connect to Redis based on env flag
    if (process.env.SKIP_REDIS === 'true') {
      logger.warn('Skipping Redis connection as SKIP_REDIS=true');
    } else {
      try {
        await connectRedis();
      } catch (redisError) {
        logger.warn('Redis connection failed, continuing without Redis:', redisError.message);
      }
    }
    
    // Start server
    server.listen(PORT, '0.0.0.0', () => {
      logger.info(`NFC Pass Backend Server running on port ${PORT}`);
      logger.info(`Environment: ${process.env.NODE_ENV || 'development'}`);
      logger.info(`Server accessible at http://0.0.0.0:${PORT}`);
    });
  } catch (error) {
    logger.error('Failed to start server:', error);
    // Don't exit in Vercel environment
    if (process.env.VERCEL !== '1') {
      process.exit(1);
    }
  }
}

// Graceful shutdown
process.on('SIGTERM', () => {
  logger.info('SIGTERM received, shutting down gracefully');
  server.close(() => {
    logger.info('Process terminated');
    process.exit(0);
  });
});

process.on('SIGINT', () => {
  logger.info('SIGINT received, shutting down gracefully');
  server.close(() => {
    logger.info('Process terminated');
    process.exit(0);
  });
});

// Only start the server automatically when not running tests
if (process.env.NODE_ENV !== 'test') {
  startServer();
}

// Export for Vercel
module.exports = app;

module.exports = { app, server, io, startServer };