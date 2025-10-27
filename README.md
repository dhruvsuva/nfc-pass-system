# NFC Pass Management System

🎫 **A comprehensive NFC-based festival pass management system with real-time verification, role-based access control, and offline-first architecture.**

## 🚀 Features

### 🔐 **Authentication & Authorization**
- **Role-based Access Control**: Admin, Manager, Bouncer roles
- **JWT Authentication** with refresh tokens
- **Secure password hashing** with bcrypt
- **Session management** with automatic token refresh

### 🎫 **Pass Management**
- **Create Passes**: Single and bulk creation
- **NFC Integration**: Scan NFC tags to auto-populate UID
- **Pass Types**: Daily, Seasonal, Session passes
- **Categories**: VIP, General, Staff, Media, Vendor
- **Real-time Verification**: Online and offline modes

### 📱 **Mobile App (Flutter)**
- **Cross-platform**: iOS and Android support
- **NFC Scanning**: Native Android NFC integration
- **Offline-first**: Works without internet connection
- **Real-time Updates**: WebSocket integration
- **Modern UI**: Material Design with dark/light themes

### 🔧 **Backend (Node.js)**
- **RESTful APIs**: Complete CRUD operations
- **Real-time Events**: WebSocket support
- **Database**: MySQL with connection pooling
- **Caching**: Redis for performance
- **Logging**: Comprehensive audit trails

### 👥 **User Management (Admin Only)**
- **Create/Update/Delete Users**
- **Block/Unblock Users**
- **Role Management**
- **User Statistics**
- **Real-time Notifications**

## 📋 Prerequisites

### Backend Requirements
- **Node.js** >= 16.0.0
- **MySQL** >= 8.0
- **Redis** >= 6.0
- **npm** or **yarn**

### Flutter App Requirements
- **Flutter** >= 3.0.0
- **Dart** >= 3.0.0
- **Android Studio** (for Android development)
- **Xcode** (for iOS development, macOS only)
- **Android device** with NFC support

## 🛠️ Installation & Setup

### 1. Backend Setup

#### Clone the Repository
```bash
git clone <repository-url>
cd nfc-pass-system
```

#### Install Dependencies
```bash
npm install
# or
yarn install
```

#### Environment Configuration
Create `.env` file in the root directory:

```env
# Server Configuration
PORT=3000
NODE_ENV=development
CORS_ORIGIN=*

# Database Configuration
DB_HOST=localhost
DB_PORT=3306
DB_NAME=nfc_pass_system
DB_USER=your_db_user
DB_PASSWORD=your_db_password

# Redis Configuration
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=your_redis_password

# JWT Configuration
JWT_SECRET=your_super_secret_jwt_key_here
JWT_REFRESH_SECRET=your_super_secret_refresh_key_here
JWT_EXPIRES_IN=1h
JWT_REFRESH_EXPIRES_IN=7d

# Admin User (Created on first run)
ADMIN_USERNAME=admin
ADMIN_PASSWORD=admin123
ADMIN_EMAIL=admin@example.com
```

#### Database Setup

1. **Create MySQL Database**:
```sql
CREATE DATABASE nfc_pass_system;
USE nfc_pass_system;
```

2. **Run Migrations**:
```bash
# Run database migrations
node scripts/migrate.js

# Or manually run SQL files in order:
mysql -u your_user -p nfc_pass_system < src/models/migrations/001_initial_schema.sql
mysql -u your_user -p nfc_pass_system < src/models/migrations/002_add_indexes.sql
mysql -u your_user -p nfc_pass_system < src/models/migrations/003_add_user_management_fields.sql
```

#### Start the Backend
```bash
# Development mode
npm run dev

# Production mode
npm start

# With PM2 (recommended for production)
npm install -g pm2
pm2 start ecosystem.config.js
```

#### Verify Backend Installation
```bash
# Health check
curl http://localhost:3000/health

# Should return: {"status":"OK","timestamp":"..."}
```

### 2. Flutter App Setup

#### Navigate to App Directory
```bash
cd app
```

#### Install Flutter Dependencies
```bash
flutter pub get
```

#### Configure App Settings
Update `lib/core/config/app_config.dart`:

```dart
class AppConfig {
  // Update with your backend URL
  static const String baseUrl = 'http://your-backend-url:3000';
  
  // WebSocket URL
  static const String wsUrl = 'ws://your-backend-url:3000';
  
  // Other configurations...
}
```

#### Android Setup

1. **Update `android/app/src/main/AndroidManifest.xml`**:
```xml
<!-- Add NFC permissions -->
<uses-permission android:name="android.permission.NFC" />
<uses-feature android:name="android.hardware.nfc" android:required="true" />

<!-- Add internet permission -->
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
```

2. **Update `android/app/build.gradle`**:
```gradle
android {
    compileSdkVersion 34
    
    defaultConfig {
        minSdkVersion 21
        targetSdkVersion 34
    }
}
```

#### Build and Run
```bash
# Check connected devices
flutter devices

# Run on connected device
flutter run

# Build APK
flutter build apk --release

# Build App Bundle (for Play Store)
flutter build appbundle --release
```

## 🔧 Configuration

### Backend Configuration

#### Rate Limiting
```javascript
// Adjust in src/server.js
const globalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 1000, // requests per window
});
```

#### Database Connection Pool
```javascript
// Adjust in src/config/db.js
const pool = mysql.createPool({
  connectionLimit: 10,
  acquireTimeout: 60000,
  timeout: 60000,
});
```

#### Redis Configuration
```javascript
// Adjust in src/config/redis.js
const redis = new Redis({
  host: process.env.REDIS_HOST,
  port: process.env.REDIS_PORT,
  retryDelayOnFailover: 100,
  maxRetriesPerRequest: 3,
});
```

### Flutter App Configuration

#### Network Timeouts
```dart
// In lib/core/network/api_service.dart
static const Duration _timeout = Duration(seconds: 30);
```

#### Offline Sync Settings
```dart
// In lib/core/services/offline_sync_service.dart
static const int _maxRetries = 5;
static const int _syncIntervalMs = 60000; // 1 minute
```

## 🧪 Testing

### Backend Testing
```bash
# Run all tests
npm test

# Run specific test file
npm test src/tests/unit/user.controller.test.js

# Run with coverage
npm run test:coverage
```

### Flutter Testing
```bash
# Run all tests
flutter test

# Run specific test
flutter test test/unit/nfc_provider_test.dart

# Run widget tests
flutter test test/widget/

# Run integration tests
flutter test integration_test/
```

### API Testing with Postman

1. **Import Collection**: Import `postman_collection.json`
2. **Set Variables**:
   - `baseUrl`: Your backend URL
   - `adminUsername`: admin
   - `adminPassword`: admin123
3. **Run Tests**: Execute the collection to test all endpoints

## 📱 Usage

### Admin Dashboard
1. **Login** with admin credentials
2. **User Management**: Create/manage users
3. **Pass Management**: Create and monitor passes
4. **System Settings**: Configure system parameters
5. **Logs & Analytics**: View system logs and statistics

### Manager Dashboard
1. **Pass Creation**: Create individual and bulk passes
2. **Pass Verification**: Verify passes at entry points
3. **Reports**: View pass usage reports
4. **Team Management**: Manage bouncer accounts

### Bouncer App
1. **NFC Scanning**: Scan NFC tags for verification
2. **Offline Mode**: Verify passes without internet
3. **Quick Actions**: Block/unblock passes
4. **Personal Logs**: View scanning history

## 🔒 Security

### Authentication
- **JWT tokens** with short expiration times
- **Refresh token rotation**
- **Password hashing** with bcrypt (12 rounds)
- **Rate limiting** on authentication endpoints

### Authorization
- **Role-based access control** (RBAC)
- **API endpoint protection**
- **Resource-level permissions**
- **Admin-only operations** properly secured

### Data Protection
- **Input validation** on all endpoints
- **SQL injection prevention**
- **XSS protection**
- **CORS configuration**
- **Helmet.js** security headers

## 🚀 Deployment

### Backend Deployment

#### Using PM2 (Recommended)
```bash
# Install PM2 globally
npm install -g pm2

# Start application
pm2 start ecosystem.config.js

# Monitor
pm2 monit

# Logs
pm2 logs
```

#### Using Docker
```bash
# Build image
docker build -t nfc-pass-backend .

# Run container
docker run -d -p 3000:3000 --env-file .env nfc-pass-backend

# Or use docker-compose
docker-compose up -d
```

#### Environment Variables for Production
```env
NODE_ENV=production
PORT=3000
DB_HOST=your-production-db-host
REDIS_HOST=your-production-redis-host
JWT_SECRET=your-super-secure-production-secret
```

### Flutter App Deployment

#### Android Play Store
```bash
# Build signed APK
flutter build apk --release

# Build App Bundle (recommended)
flutter build appbundle --release

# Files will be in build/app/outputs/
```

#### iOS App Store
```bash
# Build for iOS
flutter build ios --release

# Open in Xcode for signing and upload
open ios/Runner.xcworkspace
```

## 📊 Monitoring

### Backend Monitoring
- **PM2 Monitoring**: `pm2 monit`
- **Logs**: `pm2 logs` or check `logs/` directory
- **Health Endpoint**: `GET /health`
- **Database Monitoring**: Monitor MySQL performance
- **Redis Monitoring**: Monitor cache hit rates

### App Monitoring
- **Crash Reporting**: Integrate Firebase Crashlytics
- **Analytics**: Integrate Firebase Analytics
- **Performance**: Monitor app performance metrics

## 🔧 Troubleshooting

### Common Backend Issues

#### Database Connection Issues
```bash
# Check MySQL service
sudo systemctl status mysql

# Check connection
mysql -u your_user -p -h localhost
```

#### Redis Connection Issues
```bash
# Check Redis service
sudo systemctl status redis

# Test connection
redis-cli ping
```

#### Port Already in Use
```bash
# Find process using port 3000
lsof -i :3000

# Kill process
kill -9 <PID>
```

### Common Flutter Issues

#### NFC Not Working
1. **Check NFC permissions** in AndroidManifest.xml
2. **Verify device has NFC** capability
3. **Enable NFC** in device settings
4. **Check target SDK** version compatibility

#### Build Issues
```bash
# Clean build
flutter clean
flutter pub get

# Clear Gradle cache
cd android
./gradlew clean
```

#### Network Issues
1. **Check backend URL** in app_config.dart
2. **Verify network permissions**
3. **Test API endpoints** with Postman
4. **Check firewall settings**

## 📚 API Documentation

### Authentication Endpoints
- `POST /auth/login` - User login
- `POST /auth/refresh` - Refresh token
- `POST /auth/logout` - User logout

### Pass Management
- `POST /api/pass/create` - Create single pass
- `POST /api/pass/bulk` - Create bulk passes
- `GET /api/pass/:id` - Get pass details
- `PATCH /api/pass/:id` - Update pass
- `DELETE /api/pass/:id` - Delete pass

### Verification
- `POST /api/pass/verify` - Verify pass
- `POST /api/pass/block` - Block pass
- `POST /api/pass/unblock` - Unblock pass

### User Management (Admin Only)
- `POST /api/users` - Create user
- `GET /api/users` - List users
- `GET /api/users/:id` - Get user
- `PATCH /api/users/:id` - Update user
- `DELETE /api/users/:id` - Delete user
- `PATCH /api/users/:id/block` - Block user
- `PATCH /api/users/:id/unblock` - Unblock user
- `GET /api/users/stats` - User statistics

### Logs & Analytics
- `GET /api/logs` - Get logs
- `GET /api/logs/stats` - Log statistics
- `POST /api/logs/sync` - Sync offline logs

## 🤝 Contributing

1. **Fork** the repository
2. **Create** a feature branch
3. **Commit** your changes
4. **Push** to the branch
5. **Create** a Pull Request

### Development Guidelines
- Follow **ESLint** rules for backend
- Follow **Dart/Flutter** style guide
- Write **comprehensive tests**
- Update **documentation**
- Use **conventional commits**

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

For support and questions:
- **Create an issue** on GitHub
- **Check documentation** thoroughly
- **Review troubleshooting** section
- **Test with Postman** collection

## 🎯 Roadmap

- [ ] **iOS NFC Support** - Core NFC integration
- [ ] **Web Dashboard** - Browser-based admin panel
- [ ] **Advanced Analytics** - Detailed reporting
- [ ] **Multi-tenant Support** - Multiple organizations
- [ ] **API Rate Limiting** - Per-user limits
- [ ] **Backup & Recovery** - Automated backups
- [ ] **Push Notifications** - Real-time alerts
- [ ] **Geofencing** - Location-based verification

---

**Built with ❤️ for secure and efficient event management**