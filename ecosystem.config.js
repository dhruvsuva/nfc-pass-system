module.exports = {
  apps: [
    {
      name: 'nfc-pass-backend',
      script: 'src/server.js',
      instances: 'max', // Use all available CPU cores
      exec_mode: 'cluster',
      watch: false,
      max_memory_restart: '1G',
      env: {
        NODE_ENV: 'development',
        PORT: 3000
      },
      env_production: {
        NODE_ENV: 'production',
        PORT: 3000
      },
      env_staging: {
        NODE_ENV: 'staging',
        PORT: 3001
      },
      // Logging configuration
      error_file: 'logs/pm2-err.log',
      out_file: 'logs/pm2-out.log',
      log_file: 'logs/pm2-combined.log',
      time: true,
      
      // Advanced PM2 features
      autorestart: true,
      max_restarts: 10,
      min_uptime: '10s',
      
      // Graceful shutdown
      kill_timeout: 5000,
      listen_timeout: 3000,
      
      // Health monitoring
      health_check_grace_period: 3000,
      
      // Source map support
      source_map_support: true,
      
      // Instance variables
      instance_var: 'INSTANCE_ID'
    },
    {
      name: 'nfc-daily-table-cron',
      script: 'scripts/create_daily_table.js',
      instances: 1,
      exec_mode: 'fork',
      cron_restart: '0 0 * * *', // Run daily at midnight
      watch: false,
      autorestart: false,
      env: {
        NODE_ENV: 'production'
      },
      error_file: 'logs/cron-err.log',
      out_file: 'logs/cron-out.log',
      log_file: 'logs/cron-combined.log',
      time: true
    }
  ],
  
  deploy: {
    production: {
      user: 'deploy',
      host: ['your-production-server.com'],
      ref: 'origin/main',
      repo: 'git@github.com:your-org/nfc-pass-backend.git',
      path: '/var/www/nfc-pass-backend',
      'pre-deploy-local': '',
      'post-deploy': 'npm install && npm run migrate && pm2 reload ecosystem.config.js --env production',
      'pre-setup': '',
      'ssh_options': 'ForwardAgent=yes'
    },
    staging: {
      user: 'deploy',
      host: ['your-staging-server.com'],
      ref: 'origin/develop',
      repo: 'git@github.com:your-org/nfc-pass-backend.git',
      path: '/var/www/nfc-pass-backend-staging',
      'post-deploy': 'npm install && npm run migrate && pm2 reload ecosystem.config.js --env staging',
      'ssh_options': 'ForwardAgent=yes'
    }
  }
};