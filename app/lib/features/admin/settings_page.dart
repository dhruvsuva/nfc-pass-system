import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../core/services/admin_service.dart';
import '../../core/services/toast_service.dart';
import '../auth/providers/auth_provider.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> with TickerProviderStateMixin {
  // Loading states
  bool _isLoading = false;
  bool _isLoadingSystemInfo = false;
  bool _isLoadingCacheInfo = false;
  
  // Data
  Map<String, dynamic>? _systemInfo;
  Map<String, dynamic>? _cacheInfo;
  
  // Animation controllers
  AnimationController? _refreshController;
  AnimationController? _fadeController;
  
  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadInitialData();
  }
  
  void _initializeAnimations() {
    _refreshController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeController?.forward();
  }
  
  @override
  void dispose() {
    _refreshController?.dispose();
    _fadeController?.dispose();
    super.dispose();
  }
  
  Future<void> _loadInitialData() async {
    await Future.wait([
      _loadSystemInfo(),
      _loadCacheInfo(),
    ]);
  }
  
  Future<void> _loadSystemInfo() async {
    if (!mounted) return;
    
    setState(() {
      _isLoadingSystemInfo = true;
    });
    
    try {
      final response = await AdminService.getSystemInfo();
      if (mounted) {
        setState(() {
          _systemInfo = response['systemInfo'];
        });
      }
    } catch (e) {
      if (mounted) {
        _handleError('Failed to load system information', e);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingSystemInfo = false;
        });
      }
    }
  }
  
  Future<void> _loadCacheInfo() async {
    if (!mounted) return;
    
    setState(() {
      _isLoadingCacheInfo = true;
    });
    
    try {
      final response = await AdminService.getCacheStats();
      if (mounted) {
        setState(() {
          _cacheInfo = response;
        });
      }
    } catch (e) {
      if (mounted) {
        _handleError('Failed to load cache information', e);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingCacheInfo = false;
        });
      }
    }
  }
  
  void _handleError(String message, dynamic error) {
    String errorMessage = message;
    
    if (error.toString().contains('network') || error.toString().contains('connection')) {
      errorMessage = '$message. Please check your internet connection.';
    } else if (error.toString().contains('timeout')) {
      errorMessage = '$message. Request timed out.';
    } else if (error.toString().contains('unauthorized') || error.toString().contains('401')) {
      errorMessage = '$message. Please login again.';
    } else if (error.toString().contains('forbidden') || error.toString().contains('403')) {
      errorMessage = '$message. Access denied.';
    }
    
    ToastService.showError(errorMessage);
  }
  
  Future<void> _rebuildCache() async {
    if (!mounted) return;
    
    final confirmed = await _showConfirmationDialog(
      'Rebuild Cache',
      'Are you sure you want to rebuild the cache? This may take a few moments.',
      icon: Icons.build,
    );
    
    if (!confirmed) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      await AdminService.rebuildCache();
      if (mounted) {
        ToastService.showSuccess('Cache rebuilt successfully!');
        await Future.wait([_loadSystemInfo(), _loadCacheInfo()]);
      }
    } catch (e) {
      if (mounted) {
        _handleError('Failed to rebuild cache', e);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _clearCache() async {
    if (!mounted) return;
    
    final confirmed = await _showConfirmationDialog(
      'Clear Cache',
      'Are you sure you want to clear the cache? This will remove all cached data and may affect performance temporarily.',
      icon: Icons.warning,
      isDestructive: true,
    );
    
    if (!confirmed) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      await AdminService.clearCache();
      if (mounted) {
        ToastService.showSuccess('Cache cleared successfully!');
        await Future.wait([_loadSystemInfo(), _loadCacheInfo()]);
      }
    } catch (e) {
      if (mounted) {
        _handleError('Failed to clear cache', e);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _refreshAll() async {
    _refreshController?.forward().then((_) {
      _refreshController?.reverse();
    });
    
    await _loadInitialData();
  }
  
  Future<bool> _showConfirmationDialog(
    String title,
    String content, {
    IconData? icon,
    bool isDestructive = false,
  }) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                color: isDestructive ? Colors.red : AppTheme.primaryColor,
                size: 24,
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDestructive ? Colors.red : AppTheme.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    ) ?? false;
  }
  
  @override
  Widget build(BuildContext context) {
    final user = authProvider.state.user;
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            icon: _refreshController != null ? AnimatedBuilder(
              animation: _refreshController!,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _refreshController!.value * 2 * 3.14159,
                  child: const Icon(Icons.refresh),
                );
              },
            ) : const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _refreshAll,
            tooltip: 'Refresh All',
          ),
        ],
      ),
      body: _fadeController != null
          ? FadeTransition(
              opacity: _fadeController!,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Profile Card
                    _buildProfileCard(user),
                    const SizedBox(height: 16),
                    // System Health Card
                    _buildSystemHealthCard(),
                    const SizedBox(height: 16),
                    // Cache Management Card
                    _buildCacheManagementCard(),
                  ],
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Profile Card
                  _buildProfileCard(user),
                  const SizedBox(height: 16),
                  // System Health Card
                  _buildSystemHealthCard(),
                  const SizedBox(height: 16),
                  // Cache Management Card
                  _buildCacheManagementCard(),
                ],
              ),
            ),
    );
  }
  
  Widget _buildProfileCard(dynamic user) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Icon(
                    Icons.person,
                    size: 30,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.username ?? 'Unknown User',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getRoleColor(user?.role).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          user?.role?.toUpperCase() ?? 'UNKNOWN',
                          style: TextStyle(
                            color: _getRoleColor(user?.role),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSystemHealthCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.successColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.health_and_safety, color: AppTheme.successColor),
                ),
                const SizedBox(width: 12),
                const Text(
                  'System Health',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_isLoadingSystemInfo)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _buildHealthIndicator('Database', 'Healthy', Colors.green),
            _buildHealthIndicator('Redis Cache', _cacheInfo?['redis_status'] ?? 'Unknown', 
              _cacheInfo?['redis_status'] == 'Connected' ? Colors.green : Colors.orange),
            _buildHealthIndicator('API Server', 'Healthy', Colors.green),
            _buildHealthIndicator('System Status', 'Running', Colors.green),
            if (_systemInfo != null) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              _buildInfoRow('Version', _systemInfo!['version'] ?? 'Unknown'),
              _buildInfoRow('Environment', _systemInfo!['environment'] ?? 'Unknown'),
              _buildInfoRow('Uptime', _formatUptime(_systemInfo!['uptime'])),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildCacheManagementCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.warningColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.storage, color: AppTheme.warningColor),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Cache Management',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Cache Stats
            if (_isLoadingCacheInfo)
              const Center(child: CircularProgressIndicator())
            else if (_cacheInfo != null) ...[
              _buildInfoRow('Redis Status', _cacheInfo!['redis_status'] ?? 'Unknown'),
              _buildInfoRow('Total Keys', '${_cacheInfo!['total_keys'] ?? 0}'),
              _buildInfoRow('Active Passes', '${_cacheInfo!['active_passes'] ?? 0}'),
              _buildInfoRow('Blocked Passes', '${_cacheInfo!['blocked_passes'] ?? 0}'),
              const SizedBox(height: 16),
            ],
            
            // Cache Actions
            const Text(
              'Cache Actions',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Manage Redis cache for better performance',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _rebuildCache,
                    icon: _isLoading 
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.build),
                    label: const Text('Rebuild Cache'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _clearCache,
                    icon: _isLoading 
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.clear),
                    label: const Text('Clear Cache'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(
                fontFamily: 'monospace',
                color: Colors.black54,
              ),
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildHealthIndicator(String service, String status, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Text(service),
          const Spacer(),
          Text(
            status,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
  
  Color _getRoleColor(String? role) {
    switch (role?.toLowerCase()) {
      case 'admin':
        return Colors.red;
      case 'manager':
        return Colors.orange;
      case 'bouncer':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
  
  String _formatUptime(dynamic uptime) {
    if (uptime == null) return 'Unknown';
    
    final seconds = uptime is int ? uptime : int.tryParse(uptime.toString()) ?? 0;
    final duration = Duration(seconds: seconds);
    
    final days = duration.inDays;
    final hours = duration.inHours % 24;
    final minutes = duration.inMinutes % 60;
    
    if (days > 0) {
      return '${days}d ${hours}h ${minutes}m';
    } else if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }
}