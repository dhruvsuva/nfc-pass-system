const { getRedisClient } = require('../config/redis');
const logger = require('../utils/logger');
const PassModel = require('../models/pass.model');

class RedisService {
  constructor() {
    this.ACTIVE_PASSES_KEY = 'active:passes';
    this.BLOCKED_PASSES_KEY = 'blocked:passes';
    this.VERIFY_LOCK_PREFIX = 'lock:verify:';
    this.TOKEN_BLACKLIST_KEY = 'blacklist:tokens';
    this.CACHE_TTL = parseInt(process.env.CACHE_TTL) || 3600; // 1 hour
    this.LOCK_TTL = 10; // 10 seconds for verification locks
  }

  async addActivePass(uid, passData) {
    try {
      const client = getRedisClient();
      const passInfo = {
        pass_id: passData.pass_id,
        pass_db_id: passData.id,
        status: passData.status,
        people_allowed: passData.people_allowed,
        pass_type: passData.pass_type,
        category: passData.category,
        max_uses: passData.max_uses
      };
      
      await client.hSet(this.ACTIVE_PASSES_KEY, uid, JSON.stringify(passInfo));
      logger.debug(`Added active pass to cache: ${uid}`);
    } catch (error) {
      logger.error('Error adding active pass to cache:', error);
      throw error;
    }
  }

  async getActivePass(uid) {
    try {
      const client = getRedisClient();
      const passData = await client.hGet(this.ACTIVE_PASSES_KEY, uid);
      
      if (passData) {
        return JSON.parse(passData);
      }
      return null;
    } catch (error) {
      logger.error('Error getting active pass from cache:', error);
      throw error;
    }
  }

  async removeActivePass(uid) {
    try {
      const client = getRedisClient();
      await client.hDel(this.ACTIVE_PASSES_KEY, uid);
      logger.debug(`Removed active pass from cache: ${uid}`);
    } catch (error) {
      logger.error('Error removing active pass from cache:', error);
      throw error;
    }
  }

  async addBlockedPass(uid) {
    try {
      const client = getRedisClient();
      await client.sAdd(this.BLOCKED_PASSES_KEY, uid);
      logger.debug(`Added blocked pass to cache: ${uid}`);
    } catch (error) {
      logger.error('Error adding blocked pass to cache:', error);
      throw error;
    }
  }

  async removeBlockedPass(uid) {
    try {
      const client = getRedisClient();
      await client.sRem(this.BLOCKED_PASSES_KEY, uid);
      logger.debug(`Removed blocked pass from cache: ${uid}`);
    } catch (error) {
      logger.error('Error removing blocked pass from cache:', error);
      throw error;
    }
  }

  async isPassBlocked(uid) {
    try {
      const client = getRedisClient();
      return await client.sIsMember(this.BLOCKED_PASSES_KEY, uid);
    } catch (error) {
      logger.warn('Redis not available for blocked pass check, falling back to database:', error.message);
      
      // Fallback to database check
      try {
        const PassModel = require('../models/pass.model');
        const pass = await PassModel.findByUid(uid);
        // If pass exists and status is 'blocked', return true
        return pass && pass.status === 'blocked';
      } catch (dbError) {
        logger.error('Database fallback failed for blocked pass check:', dbError);
        // If both Redis and DB fail, assume pass is not blocked to allow verification
        return false;
      }
    }
  }

  async getAllBlockedPasses() {
    try {
      const client = getRedisClient();
      return await client.sMembers(this.BLOCKED_PASSES_KEY);
    } catch (error) {
      logger.error('Error getting all blocked passes:', error);
      throw error;
    }
  }

  async setVerifyLock(uid, ttl = this.LOCK_TTL) {
    try {
      const client = getRedisClient();
      const lockKey = `${this.VERIFY_LOCK_PREFIX}${uid}`;
      const result = await client.set(lockKey, '1', {
        EX: ttl,
        NX: true
      });
      return result === 'OK';
    } catch (error) {
      logger.error('Error setting verify lock:', error);
      throw error;
    }
  }

  async releaseVerifyLock(uid) {
    try {
      const client = getRedisClient();
      const lockKey = `${this.VERIFY_LOCK_PREFIX}${uid}`;
      await client.del(lockKey);
    } catch (error) {
      logger.error('Error releasing verify lock:', error);
      throw error;
    }
  }

  async markPassAsUsed(uid) {
    try {
      const client = getRedisClient();
      const passData = await this.getActivePass(uid);
      
      if (passData) {
        passData.status = 'used';
        await client.hSet(this.ACTIVE_PASSES_KEY, uid, JSON.stringify(passData));
        logger.debug(`Marked pass as used in cache: ${uid}`);
        return true;
      }
      return false;
    } catch (error) {
      logger.error('Error marking pass as used:', error);
      throw error;
    }
  }

  async rebuildActivePassesCache() {
    try {
      const client = getRedisClient();
      
      // Clear existing cache
      await client.del(this.ACTIVE_PASSES_KEY);
      
      // Get all active passes from database
      const activePasses = await PassModel.getActivePasses();
      
      if (activePasses.length > 0) {
        const pipeline = client.multi();
        
        for (const pass of activePasses) {
          const passInfo = {
            pass_id: pass.pass_id,
            pass_db_id: pass.pass_db_id,
            status: pass.status,
            people_allowed: pass.people_allowed,
            pass_type: pass.pass_type,
            category: pass.category,
            max_uses: pass.max_uses
          };
          
          pipeline.hSet(this.ACTIVE_PASSES_KEY, pass.uid, JSON.stringify(passInfo));
        }
        
        await pipeline.exec();
      }
      
      logger.info(`Rebuilt active passes cache with ${activePasses.length} passes`);
      return activePasses.length;
    } catch (error) {
      logger.error('Error rebuilding active passes cache:', error);
      throw error;
    }
  }

  async rebuildBlockedPassesCache() {
    try {
      const client = getRedisClient();
      
      // Clear existing cache
      await client.del(this.BLOCKED_PASSES_KEY);
      
      // Get all blocked passes from database
      const blockedPasses = await PassModel.getBlockedPasses();
      
      if (blockedPasses.length > 0) {
        await client.sAdd(this.BLOCKED_PASSES_KEY, blockedPasses);
      }
      
      logger.info(`Rebuilt blocked passes cache with ${blockedPasses.length} passes`);
      return blockedPasses.length;
    } catch (error) {
      logger.error('Error rebuilding blocked passes cache:', error);
      throw error;
    }
  }

  async rebuildAllCaches() {
    try {
      const activeCount = await this.rebuildActivePassesCache();
      const blockedCount = await this.rebuildBlockedPassesCache();
      
      logger.info(`Cache rebuild completed - Active: ${activeCount}, Blocked: ${blockedCount}`);
      return { activeCount, blockedCount };
    } catch (error) {
      logger.error('Error rebuilding all caches:', error);
      throw error;
    }
  }

  async clearAllCaches() {
    try {
      const client = getRedisClient();
      await client.del(this.ACTIVE_PASSES_KEY, this.BLOCKED_PASSES_KEY);
      logger.info('All caches cleared');
    } catch (error) {
      logger.error('Error clearing all caches:', error);
      throw error;
    }
  }

  async getCacheStats() {
    try {
      const client = getRedisClient();
      const activeCount = await client.hLen(this.ACTIVE_PASSES_KEY);
      const blockedCount = await client.sCard(this.BLOCKED_PASSES_KEY);
      
      return {
        activePassesCount: activeCount,
        blockedPassesCount: blockedCount,
        timestamp: new Date().toISOString()
      };
    } catch (error) {
      logger.error('Error getting cache stats:', error);
      throw error;
    }
  }

  async getActivePassesCount() {
    try {
      const client = getRedisClient();
      return await client.hLen(this.ACTIVE_PASSES_KEY);
    } catch (error) {
      logger.error('Error getting active passes count:', error);
      throw error;
    }
  }

  async getBlockedPassesCount() {
    try {
      const client = getRedisClient();
      return await client.sCard(this.BLOCKED_PASSES_KEY);
    } catch (error) {
      logger.error('Error getting blocked passes count:', error);
      throw error;
    }
  }

  getClient() {
    return getRedisClient();
  }

  async isConnected() {
    try {
      const client = getRedisClient();
      if (!client) return false;
      
      // Check if client is open and ready
      if (!client.isOpen || !client.isReady) return false;
      
      // Try to ping Redis to verify connection
      await client.ping();
      return true;
    } catch (error) {
      logger.error('Redis connection check failed:', error);
      return false;
    }
  }

  // Token blacklist methods
  async addToTokenBlacklist(token, expiresAt) {
    try {
      const client = getRedisClient();
      const ttl = Math.floor((expiresAt - Date.now()) / 1000);
      
      if (ttl > 0) {
        await client.setEx(`${this.TOKEN_BLACKLIST_KEY}:${token}`, ttl, 'blacklisted');
        logger.debug(`Token added to blacklist: ${token.substring(0, 20)}...`);
      }
    } catch (error) {
      logger.error('Error adding token to blacklist:', error);
      throw error;
    }
  }

  async isTokenBlacklisted(token) {
    try {
      const client = getRedisClient();
      const result = await client.get(`${this.TOKEN_BLACKLIST_KEY}:${token}`);
      return result !== null;
    } catch (error) {
      logger.error('Error checking token blacklist:', error);
      return false; // If Redis is down, allow the token (fail open)
    }
  }

  async removeFromTokenBlacklist(token) {
    try {
      const client = getRedisClient();
      await client.del(`${this.TOKEN_BLACKLIST_KEY}:${token}`);
      logger.debug(`Token removed from blacklist: ${token.substring(0, 20)}...`);
    } catch (error) {
      logger.error('Error removing token from blacklist:', error);
      throw error;
    }
  }

  getConnectionStatus() {
    try {
      const client = getRedisClient();
      if (!client) {
        return {
          status: 'disconnected',
          connected: false
        };
      }
      
      const isConnected = client.isOpen && client.isReady;
      return {
        status: isConnected ? 'ready' : 'connecting',
        connected: isConnected,
        isOpen: client.isOpen,
        isReady: client.isReady
      };
    } catch (error) {
      logger.error('Error getting Redis connection status:', error);
      return {
        status: 'error',
        connected: false
      };
    }
  }
}

module.exports = new RedisService();