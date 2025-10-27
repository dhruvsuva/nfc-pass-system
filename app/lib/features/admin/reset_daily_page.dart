import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../core/theme/app_theme.dart';
import '../../core/config/app_config.dart';
import '../../core/network/http_interceptor.dart';
import '../../core/services/toast_service.dart';
import '../../core/storage/hive_service.dart';
import '../auth/providers/auth_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ResetDailyPage extends StatefulWidget {
  const ResetDailyPage({super.key});

  @override
  State<ResetDailyPage> createState() => _ResetDailyPageState();
}

class _ResetDailyPageState extends State<ResetDailyPage> {
  bool _isResetting = false;
  int? _resetCount;
  final _storage = const FlutterSecureStorage();
  
  Future<String?> _getAccessToken() async {
    return await HiveService.getAccessTokenAsync();
  }
  
  Future<void> _resetDailyPasses() async {
    final confirmed = await _showConfirmationDialog();
    if (!confirmed) return;
    
    setState(() {
      _isResetting = true;
    });
    
    try {
      // Call actual reset daily API
      final response = await HttpInterceptor.post(
        Uri.parse('${AppConfig.baseUrl}/api/admin/reset-daily'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${await _getAccessToken()}',
        },
        body: json.encode({
          'confirm': 'true',
          'date': DateTime.now().toIso8601String().split('T')[0], // YYYY-MM-DD
        }),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final count = data['summary']['passesReset'] ?? 0;
        
        // Clear local cache after successful reset
        await HiveService.clearAllActivePasses();
        
        setState(() {
          _resetCount = count;
        });
        
        _showSnackBar('Successfully reset $count daily passes!', isError: false);
      } else {
        final errorData = json.decode(response.body);
        _showSnackBar('Failed to reset: ${errorData['error'] ?? 'Unknown error'}', isError: true);
      }
      
    } catch (e) {
      // Show user-friendly error message as requested
      _showSnackBar('There was an error while resetting daily passes. Please try again later.', isError: true);
    } finally {
      setState(() {
        _isResetting = false;
      });
    }
  }
  
  Future<bool> _showConfirmationDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: AppTheme.errorColor),
            SizedBox(width: 8),
            Text('Confirm Daily Reset'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to reset all daily passes?'),
            SizedBox(height: 12),
            Text('This action will:'),
            Text('• Reset all daily passes to active status'),
            Text('• Clear all usage history'),
            Text('• Allow all passes to be used again'),
            SizedBox(height: 12),
            Text(
              'This action cannot be undone!',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.errorColor,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Reset All'),
          ),
        ],
      ),
    ) ?? false;
  }
  
  void _showSnackBar(String message, {required bool isError}) {
    if (isError) {
      ToastService.showError(message);
    } else {
      ToastService.showSuccess(message);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final user = authProvider.state.user;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reset Daily Passes'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            // Warning Card
            Card(
              color: AppTheme.errorColor.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Icon(
                      Icons.warning,
                      color: AppTheme.errorColor,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'DANGER ZONE',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.errorColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This action will reset ALL daily passes in the system. Use with extreme caution.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.errorColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Instructions
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info_outline, color: AppTheme.infoColor),
                        const SizedBox(width: 8),
                        Text(
                          'Reset Instructions',
                          style: AppTheme.subheadingStyle.copyWith(fontSize: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text('• This operation resets ALL daily passes in the system'),
                    const Text('• All passes will be restored to active status'),
                    const Text('• All usage history will be cleared'),
                    const Text('• This action cannot be undone'),
                    const Text('• Only administrators can perform this operation'),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Current Status
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Status',
                      style: AppTheme.subheadingStyle.copyWith(fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.credit_card, color: AppTheme.infoColor),
                        const SizedBox(width: 8),
                        Text('Active Passes: Online Mode'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.person, color: AppTheme.infoColor),
                        const SizedBox(width: 8),
                        Text('Current User: ${user?.username ?? 'Unknown'}'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.access_time, color: AppTheme.infoColor),
                        const SizedBox(width: 8),
                        Text('Current Time: ${DateTime.now().toString().substring(0, 19)}'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Reset Button
            SizedBox(
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _isResetting ? null : _resetDailyPasses,
                icon: _isResetting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.refresh),
                label: Text(
                  _isResetting ? 'Resetting All Passes...' : 'Reset All Daily Passes',
                  style: const TextStyle(fontSize: 18),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.errorColor,
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Result Display
            if (_resetCount != null)
              Card(
                color: AppTheme.successColor.withOpacity(0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: AppTheme.successColor,
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Reset Completed',
                        style: AppTheme.subheadingStyle.copyWith(
                          color: AppTheme.successColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Successfully reset $_resetCount passes',
                        style: const TextStyle(
                          color: AppTheme.successColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            
            // Extra bottom padding to avoid navigation bar overlap
            const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }
}