const jwt = require('jsonwebtoken');
const logger = require('../utils/logger');

const JWT_SECRET = process.env.JWT_SECRET || 'your-super-secret-jwt-key';
const JWT_EXPIRY = process.env.JWT_EXPIRY || '8h';
const JWT_REFRESH_SECRET = process.env.JWT_REFRESH_SECRET || 'your-super-secret-refresh-key';
const JWT_REFRESH_EXPIRY = process.env.JWT_REFRESH_EXPIRY || '7d';

class JWTService {
  static generateAccessToken(payload) {
    try {
      return jwt.sign(payload, JWT_SECRET, {
        expiresIn: JWT_EXPIRY,
        issuer: 'nfc-pass-system',
        audience: 'nfc-pass-users'
      });
    } catch (error) {
      logger.error('Error generating access token:', error);
      throw error;
    }
  }

  static generateRefreshToken(payload) {
    try {
      return jwt.sign(payload, JWT_REFRESH_SECRET, {
        expiresIn: JWT_REFRESH_EXPIRY,
        issuer: 'nfc-pass-system',
        audience: 'nfc-pass-users'
      });
    } catch (error) {
      logger.error('Error generating refresh token:', error);
      throw error;
    }
  }

  static verifyAccessToken(token) {
    try {
      return jwt.verify(token, JWT_SECRET, {
        issuer: 'nfc-pass-system',
        audience: 'nfc-pass-users'
      });
    } catch (error) {
      logger.error('Error verifying access token:', error);
      throw error;
    }
  }

  static verifyRefreshToken(token) {
    try {
      return jwt.verify(token, JWT_REFRESH_SECRET, {
        issuer: 'nfc-pass-system',
        audience: 'nfc-pass-users'
      });
    } catch (error) {
      logger.error('Error verifying refresh token:', error);
      throw error;
    }
  }

  static decodeToken(token) {
    try {
      return jwt.decode(token, { complete: true });
    } catch (error) {
      logger.error('Error decoding token:', error);
      throw error;
    }
  }

  static generateTokenPair(user) {
    try {
      const payload = {
        userId: user.id,
        username: user.username,
        role: user.role,
        status: user.status
      };

      const accessToken = this.generateAccessToken(payload);
      const refreshToken = this.generateRefreshToken({ userId: user.id });

      return {
        accessToken,
        refreshToken,
        expiresIn: JWT_EXPIRY
      };
    } catch (error) {
      logger.error('Error generating token pair:', error);
      throw error;
    }
  }

  static getTokenExpiry(token) {
    try {
      const decoded = this.decodeToken(token);
      return decoded.payload.exp;
    } catch (error) {
      logger.error('Error getting token expiry:', error);
      return null;
    }
  }

  static isTokenExpired(token) {
    try {
      const expiry = this.getTokenExpiry(token);
      if (!expiry) return true;
      
      const now = Math.floor(Date.now() / 1000);
      return expiry < now;
    } catch (error) {
      logger.error('Error checking token expiry:', error);
      return true;
    }
  }
}

module.exports = JWTService;