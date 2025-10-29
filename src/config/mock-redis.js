// Mock Redis for Vercel deployment
const mockRedis = {
  async get(key) {
    console.log('Mock Redis GET:', key);
    return null;
  },
  
  async set(key, value, options = {}) {
    console.log('Mock Redis SET:', key, value);
    return 'OK';
  },
  
  async del(key) {
    console.log('Mock Redis DEL:', key);
    return 1;
  },
  
  async exists(key) {
    console.log('Mock Redis EXISTS:', key);
    return 0;
  },
  
  async expire(key, seconds) {
    console.log('Mock Redis EXPIRE:', key, seconds);
    return 1;
  },
  
  async keys(pattern) {
    console.log('Mock Redis KEYS:', pattern);
    return [];
  },
  
  async flushall() {
    console.log('Mock Redis FLUSHALL');
    return 'OK';
  },
  
  async ping() {
    return 'PONG';
  },
  
  async quit() {
    console.log('Mock Redis QUIT');
    return 'OK';
  },
  
  isOpen: true,
  connected: true
};

module.exports = mockRedis;
