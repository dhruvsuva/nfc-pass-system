const express = require('express');
const { executeQuery } = require('../config/db');
const redisService = require('../services/redis.service');
const logger = require('../utils/logger');
const os = require('os');
const process = require('process');

const router = express.Router();

/**
 * Basic health check endpoint
 * Returns simple health status for load balancers
 */
router.get('/health', async (req, res) => {
  try {
    const health = {
      status: 'healthy',
      timestamp: new Date().toISOString(),
      uptime: Math.floor(process.uptime()),
      environment: process.env.NODE_ENV || 'development'
    };

    // Quick database check
    try {
      await executeQuery('SELECT 1 as test');
      health.database = 'connected';
    } catch (error) {
      health.database = 'disconnected';
      health.status = 'unhealthy';
      logger.error('Database health check failed:', error);
    }

    // Quick cache check (if Redis is configured)
    try {
      if (redisService && redisService.ping) {
        await redisService.ping();
        health.cache = 'connected';
      } else {
        health.cache = 'not_configured';
      }
    } catch (error) {
      health.cache = 'disconnected';
      health.status = 'degraded';
      logger.warn('Cache health check failed:', error);
    }

    const statusCode = health.status === 'healthy' ? 200 : 503;
    res.status(statusCode).json(health);

  } catch (error) {
    logger.error('Health check failed:', error);
    res.status(503).json({
      status: 'unhealthy',
      timestamp: new Date().toISOString(),
      error: 'Health check failed'
    });
  }
});

/**
 * Detailed health check with comprehensive system information
 */
router.get('/health/detailed', async (req, res) => {
  try {
    const startTime = Date.now();
    
    const health = {
      status: 'healthy',
      timestamp: new Date().toISOString(),
      uptime: Math.floor(process.uptime()),
      environment: process.env.NODE_ENV || 'development',
      version: process.env.npm_package_version || '1.0.0',
      checks: {}
    };

    // Database health check with timing
    try {
      const dbStart = Date.now();
      const result = await executeQuery('SELECT 1 as test, NOW() as db_time');
      const dbTime = Date.now() - dbStart;
      
      health.checks.database = {
        status: 'healthy',
        response_time_ms: dbTime,
        server_time: result[0].db_time
      };
    } catch (error) {
      health.checks.database = {
        status: 'unhealthy',
        error: error.message
      };
      health.status = 'unhealthy';
    }

    // Cache health check with timing
    try {
      if (redisService && redisService.ping) {
        const cacheStart = Date.now();
        await redisService.ping();
        const cacheTime = Date.now() - cacheStart;
        
        health.checks.cache = {
          status: 'healthy',
          response_time_ms: cacheTime
        };
      } else {
        health.checks.cache = {
          status: 'not_configured'
        };
      }
    } catch (error) {
      health.checks.cache = {
        status: 'unhealthy',
        error: error.message
      };
      if (health.status === 'healthy') {
        health.status = 'degraded';
      }
    }

    // System resources
    health.system = {
      memory: {
        used: Math.round(process.memoryUsage().heapUsed / 1024 / 1024),
        total: Math.round(process.memoryUsage().heapTotal / 1024 / 1024),
        external: Math.round(process.memoryUsage().external / 1024 / 1024),
        system_free: Math.round(os.freemem() / 1024 / 1024),
        system_total: Math.round(os.totalmem() / 1024 / 1024)
      },
      cpu: {
        load_average: os.loadavg(),
        cpu_count: os.cpus().length
      },
      platform: {
        type: os.type(),
        platform: os.platform(),
        arch: os.arch(),
        hostname: os.hostname()
      }
    };

    // Application metrics
    health.application = {
      node_version: process.version,
      pid: process.pid,
      uptime_seconds: Math.floor(process.uptime()),
      environment: process.env.NODE_ENV || 'development'
    };

    health.response_time_ms = Date.now() - startTime;

    const statusCode = health.status === 'healthy' ? 200 : 
                      health.status === 'degraded' ? 200 : 503;
    
    res.status(statusCode).json(health);

  } catch (error) {
    logger.error('Detailed health check failed:', error);
    res.status(503).json({
      status: 'unhealthy',
      timestamp: new Date().toISOString(),
      error: 'Detailed health check failed',
      message: error.message
    });
  }
});

/**
 * Readiness probe - checks if application is ready to serve traffic
 */
router.get('/ready', async (req, res) => {
  try {
    const checks = [];
    let ready = true;

    // Check database connectivity
    try {
      await executeQuery('SELECT 1');
      checks.push({ name: 'database', status: 'ready' });
    } catch (error) {
      checks.push({ name: 'database', status: 'not_ready', error: error.message });
      ready = false;
    }

    // Check if critical tables exist
    try {
      await executeQuery('SELECT COUNT(*) FROM users LIMIT 1');
      await executeQuery('SELECT COUNT(*) FROM passes LIMIT 1');
      checks.push({ name: 'database_schema', status: 'ready' });
    } catch (error) {
      checks.push({ name: 'database_schema', status: 'not_ready', error: error.message });
      ready = false;
    }

    // Check cache (optional)
    try {
      if (redisService && redisService.ping) {
        await redisService.ping();
        checks.push({ name: 'cache', status: 'ready' });
      } else {
        checks.push({ name: 'cache', status: 'not_configured' });
      }
    } catch (error) {
      checks.push({ name: 'cache', status: 'not_ready', error: error.message });
      // Cache failure doesn't make app not ready, just degraded
    }

    const response = {
      ready,
      timestamp: new Date().toISOString(),
      checks
    };

    res.status(ready ? 200 : 503).json(response);

  } catch (error) {
    logger.error('Readiness check failed:', error);
    res.status(503).json({
      ready: false,
      timestamp: new Date().toISOString(),
      error: 'Readiness check failed'
    });
  }
});

/**
 * Liveness probe - checks if application is alive
 */
router.get('/live', (req, res) => {
  // Simple liveness check - if we can respond, we're alive
  res.status(200).json({
    alive: true,
    timestamp: new Date().toISOString(),
    uptime: Math.floor(process.uptime()),
    pid: process.pid
  });
});

/**
 * Application metrics endpoint
 */
router.get('/metrics', async (req, res) => {
  try {
    const metrics = {
      timestamp: new Date().toISOString(),
      uptime_seconds: Math.floor(process.uptime()),
      
      // Memory metrics
      memory: {
        heap_used_bytes: process.memoryUsage().heapUsed,
        heap_total_bytes: process.memoryUsage().heapTotal,
        external_bytes: process.memoryUsage().external,
        rss_bytes: process.memoryUsage().rss,
        system_free_bytes: os.freemem(),
        system_total_bytes: os.totalmem()
      },

      // CPU metrics
      cpu: {
        load_average_1m: os.loadavg()[0],
        load_average_5m: os.loadavg()[1],
        load_average_15m: os.loadavg()[2],
        cpu_count: os.cpus().length
      },

      // Process metrics
      process: {
        pid: process.pid,
        node_version: process.version,
        platform: process.platform,
        arch: process.arch
      }
    };

    // Database metrics
    try {
      const dbMetrics = await executeQuery(`
        SELECT 
          (SELECT COUNT(*) FROM users) as total_users,
          (SELECT COUNT(*) FROM users WHERE status = 'active') as active_users,
          (SELECT COUNT(*) FROM passes) as total_passes,
          (SELECT COUNT(*) FROM passes WHERE status = 'active') as active_passes,
          (SELECT COUNT(*) FROM passes WHERE status = 'blocked') as blocked_passes,
          (SELECT COUNT(*) FROM logs WHERE DATE(timestamp) = CURDATE()) as today_logs
      `);
      
      metrics.database = {
        total_users: parseInt(dbMetrics[0].total_users),
        active_users: parseInt(dbMetrics[0].active_users),
        total_passes: parseInt(dbMetrics[0].total_passes),
        active_passes: parseInt(dbMetrics[0].active_passes),
        blocked_passes: parseInt(dbMetrics[0].blocked_passes),
        today_logs: parseInt(dbMetrics[0].today_logs)
      };
    } catch (error) {
      metrics.database = { error: 'Failed to fetch database metrics' };
    }

    // Cache metrics (if available)
    try {
      if (redisService && redisService.getStats) {
        metrics.cache = await redisService.getStats();
      } else {
        metrics.cache = { status: 'not_configured' };
      }
    } catch (error) {
      metrics.cache = { error: 'Failed to fetch cache metrics' };
    }

    res.json(metrics);

  } catch (error) {
    logger.error('Metrics collection failed:', error);
    res.status(500).json({
      error: 'Failed to collect metrics',
      timestamp: new Date().toISOString()
    });
  }
});

/**
 * Prometheus-style metrics endpoint
 */
router.get('/metrics/prometheus', async (req, res) => {
  try {
    let prometheusMetrics = '';
    
    // Memory metrics
    const memory = process.memoryUsage();
    prometheusMetrics += `# HELP nodejs_heap_size_used_bytes Process heap space used\n`;
    prometheusMetrics += `# TYPE nodejs_heap_size_used_bytes gauge\n`;
    prometheusMetrics += `nodejs_heap_size_used_bytes ${memory.heapUsed}\n\n`;
    
    prometheusMetrics += `# HELP nodejs_heap_size_total_bytes Process heap space total\n`;
    prometheusMetrics += `# TYPE nodejs_heap_size_total_bytes gauge\n`;
    prometheusMetrics += `nodejs_heap_size_total_bytes ${memory.heapTotal}\n\n`;
    
    // Uptime
    prometheusMetrics += `# HELP nodejs_process_uptime_seconds Process uptime\n`;
    prometheusMetrics += `# TYPE nodejs_process_uptime_seconds counter\n`;
    prometheusMetrics += `nodejs_process_uptime_seconds ${Math.floor(process.uptime())}\n\n`;
    
    // Database metrics
    try {
      const dbMetrics = await executeQuery(`
        SELECT 
          (SELECT COUNT(*) FROM users WHERE status = 'active') as active_users,
          (SELECT COUNT(*) FROM passes WHERE status = 'active') as active_passes,
          (SELECT COUNT(*) FROM passes WHERE status = 'blocked') as blocked_passes
      `);
      
      prometheusMetrics += `# HELP app_users_active_total Number of active users\n`;
      prometheusMetrics += `# TYPE app_users_active_total gauge\n`;
      prometheusMetrics += `app_users_active_total ${dbMetrics[0].active_users}\n\n`;
      
      prometheusMetrics += `# HELP app_passes_active_total Number of active passes\n`;
      prometheusMetrics += `# TYPE app_passes_active_total gauge\n`;
      prometheusMetrics += `app_passes_active_total ${dbMetrics[0].active_passes}\n\n`;
      
      prometheusMetrics += `# HELP app_passes_blocked_total Number of blocked passes\n`;
      prometheusMetrics += `# TYPE app_passes_blocked_total gauge\n`;
      prometheusMetrics += `app_passes_blocked_total ${dbMetrics[0].blocked_passes}\n\n`;
      
    } catch (error) {
      logger.warn('Failed to fetch database metrics for Prometheus:', error);
    }
    
    res.set('Content-Type', 'text/plain');
    res.send(prometheusMetrics);
    
  } catch (error) {
    logger.error('Prometheus metrics collection failed:', error);
    res.status(500).send('# Error collecting metrics\n');
  }
});

module.exports = router;