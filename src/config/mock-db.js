// In-memory database for Vercel deployment
const inMemoryDB = {
  users: [
    {
      id: 1,
      username: 'admin',
      password_hash: '$2b$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', // password
      role: 'admin',
      status: 'active',
      created_at: new Date(),
      updated_at: new Date()
    }
  ],
  passes: [],
  categories: [
    { id: 1, name: 'VIP', description: 'VIP Pass', created_at: new Date() },
    { id: 2, name: 'General', description: 'General Pass', created_at: new Date() },
    { id: 3, name: 'Student', description: 'Student Pass', created_at: new Date() }
  ],
  settings: [
    { setting_key: 'app_name', setting_value: 'NFC Pass System', updated_at: new Date() },
    { setting_key: 'max_passes_per_day', setting_value: '1000', updated_at: new Date() }
  ]
};

// Mock database functions
const mockDB = {
  async executeQuery(query, params = []) {
    console.log('Mock DB Query:', query);
    
    // Handle different query types
    if (query.includes('SELECT') && query.includes('users')) {
      if (query.includes('WHERE username')) {
        const username = params[0];
        const user = inMemoryDB.users.find(u => u.username === username);
        return user ? [user] : [];
      }
      return inMemoryDB.users;
    }
    
    if (query.includes('SELECT') && query.includes('passes')) {
      return inMemoryDB.passes;
    }
    
    if (query.includes('SELECT') && query.includes('categories')) {
      return inMemoryDB.categories;
    }
    
    if (query.includes('SELECT') && query.includes('settings')) {
      return inMemoryDB.settings;
    }
    
    if (query.includes('INSERT')) {
      // Mock insert - just return success
      return [{ insertId: Math.floor(Math.random() * 1000) + 1 }];
    }
    
    if (query.includes('UPDATE')) {
      // Mock update - just return success
      return [{ affectedRows: 1 }];
    }
    
    if (query.includes('DELETE')) {
      // Mock delete - just return success
      return [{ affectedRows: 1 }];
    }
    
    return [];
  },
  
  async getConnection() {
    return {
      release: () => {},
      query: mockDB.executeQuery
    };
  }
};

module.exports = mockDB;
