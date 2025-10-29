const redis = require('redis');
const logger = require('../utils/logger');

let redisClient;

// Use mock Redis for Vercel deployment
const isVercel = process.env.VERCEL === '1' || process.env.NODE_ENV === 'production';
const useMockRedis = isVercel && (!process.env.REDIS_URL || process.env.REDIS_URL.includes('localhost'));

if (useMockRedis) {
  logger.warn('Using mock Redis for Vercel deployment');
  module.exports = {
    connectRedis: async () => {
      logger.info('Mock Redis connected');
      return mockRedis;
    },
    getRedisClient: () => mockRedis,
    mockRedis
  };
  return;
}

const redisConfig = {
  url: process.env.REDIS_URL || 'redis://localhost:6379',
  password: process.env.REDIS_PASSWORD || undefined,
  socket: {
    reconnectStrategy: (retries) => {
      if (retries > 10) {
        logger.error('Redis reconnection failed after 10 attempts');
        return new Error('Redis reconnection failed');
      }
      return Math.min(retries * 50, 1000);
    },
    connectTimeout: 10000,
    lazyConnect: true
  },
  retry_unfulfilled_commands: true
};

const connectRedis = async () => {
  try {
    redisClient = redis.createClient(redisConfig);
    
    redisClient.on('error', (err) => {
      logger.error('Redis Client Error:', err);
    });
    
    redisClient.on('connect', () => {
      logger.info('Redis Client Connected');
    });
    
    redisClient.on('ready', () => {
      logger.info('Redis Client Ready');
    });
    
    redisClient.on('end', () => {
      logger.info('Redis Client Disconnected');
    });
    
    await redisClient.connect();
    
    // Test the connection
    await redisClient.ping();
    logger.info('Redis connection established successfully');
    
    return redisClient;
  } catch (error) {
    logger.error('Redis connection failed:', error);
    throw error;
  }
};

const getRedisClient = () => {
  if (!redisClient || !redisClient.isOpen) {
    throw new Error('Redis client not initialized or connection closed');
  }
  return redisClient;
};

const disconnectRedis = async () => {
  try {
    if (redisClient && redisClient.isOpen) {
      await redisClient.quit();
      logger.info('Redis connection closed');
    }
  } catch (error) {
    logger.error('Error closing Redis connection:', error);
  }
};

module.exports = {
  connectRedis,
  getRedisClient,
  disconnectRedis
};