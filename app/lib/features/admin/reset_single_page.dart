import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/storage/hive_service.dart';
import '../../core/services/toast_service.dart';
import '../../core/nfc/nfc_service.dart';
import '../../core/network/http_interceptor.dart';
import '../../core/providers/nfc_provider.dart';
import '../../models/pass_model.dart';
import '../auth/providers/auth_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
class ResetSinglePage extends StatefulWidget {
  final String? passId;
  final String? uid;
  
  const ResetSinglePage({
    super.key,
    this.passId,
    this.uid,
  });

  @override
  State<ResetSinglePage> createState() => _ResetSinglePageState();
}

class _ResetSinglePageState extends State<ResetSinglePage> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  final _storage = const FlutterSecureStorage();
  final _nfcProvider = NFCProvider();
  
  PassModel? _foundPass;
  bool _isScanning = false;
  bool _isResetting = false;
  bool _isLoadingDetails = false;
  String? _scannedUID;
  StreamSubscription<NFCEvent>? _nfcSubscription;
  
  @override
  void initState() {
    super.initState();
    _initializeNFC();
    
    // Pre-fill if passed from route
    if (widget.uid != null) {
      _scannedUID = widget.uid!;
      _searchPassByUID(widget.uid!);
    }
  }
  
  @override
  void dispose() {
    _nfcSubscription?.cancel();
    _reasonController.dispose();
    super.dispose();
  }
  
  Future<void> _initializeNFC() async {
    try {
      await _nfcProvider.initialize();
      _nfcSubscription = NFCService.nfcEventStream.listen(_handleNFCEvent);
    } catch (e) {
      _showSnackBar('Failed to initialize NFC: $e', isError: true);
    }
  }
  
  void _handleNFCEvent(NFCEvent event) {
    print('🎯 Reset Single Page - NFC Event received: ${event.type}, UID: ${event.uid}');
    if (event.type == NFCEventType.tagDiscovered && event.uid != null) {
      print('✅ Tag discovered in Reset Single Page, calling _searchPassByUID');
      setState(() {
        _scannedUID = event.uid;
        _isScanning = false;
      });
      _searchPassByUID(event.uid!);
    } else if (event.type == NFCEventType.error) {
      print('❌ NFC Error in Reset Single Page: ${event.message}');
      setState(() {
        _isScanning = false;
      });
      _showSnackBar('NFC Error: ${event.message}', isError: true);
    } else {
      print('ℹ️ Other NFC event in Reset Single Page: ${event.type}');
    }
  }
  
  Future<void> _startNFCScan() async {
    setState(() {
      _isScanning = true;
      _foundPass = null;
      _scannedUID = null;
    });
    
    try {
      final success = await NFCService.startScan();
      if (!success) {
        setState(() {
          _isScanning = false;
        });
        _showSnackBar('Failed to start NFC scan', isError: true);
      }
    } catch (e) {
      setState(() {
        _isScanning = false;
      });
      _showSnackBar('Error starting NFC scan: $e', isError: true);
    }
  }
  
  Future<void> _stopNFCScan() async {
    setState(() {
      _isScanning = false;
    });
    await NFCService.stopScan();
  }
  
  Future<void> _searchPassByUID(String uid) async {
    print('🔍 Searching for pass with UID: $uid');
    
    // Clear old details and show loading
    setState(() {
      _foundPass = null;
      _isLoadingDetails = true;
    });
    
    try {
      // Search via API (online-only mode)
      PassModel? pass;
      final token = await _getAccessToken();
      print('🔑 Access token: ${token != null ? 'Available' : 'Missing'}');
      if (token != null) {
        try {
          final apiUrl = '${AppConfig.baseUrl}/api/pass/search?uid=$uid';
          print('🌐 Making API call to: $apiUrl');
          
          final response = await HttpInterceptor.get(
            Uri.parse(apiUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          ).timeout(const Duration(seconds: 10));
          
          print('📡 API Response: ${response.statusCode}');
          print('📄 Response body: ${response.body}');
          
          if (response.statusCode == 200) {
            final responseData = json.decode(response.body);
            pass = PassModel.fromJson(responseData['pass']);
            print('✅ Pass found via API');
          } else if (response.statusCode == 404) {
            print('❌ Pass not found (404)');
            // Pass not found, which is expected for some UIDs
          } else {
            final errorData = json.decode(response.body);
            print('⚠️ API Error: ${response.statusCode} - ${errorData['error']}');
            
            String errorMessage = 'API Error';
            if (response.statusCode == 401) {
              errorMessage = 'Authentication failed: ${errorData['error'] ?? 'Please login again'}';
            } else if (response.statusCode == 403) {
              errorMessage = 'Access denied: ${errorData['error'] ?? 'Insufficient permissions'}';
            } else {
              errorMessage = 'API Error: ${errorData['error'] ?? 'Unknown error'}';
            }
            
            _showSnackBar(errorMessage, isError: true);
          }
        } catch (apiError) {
          print('🚨 Network error: $apiError');
          _showSnackBar('Network error: $apiError', isError: true);
        }
      } else {
        print('🚨 No access token available');
        _showSnackBar('Authentication token not available', isError: true);
      }
      
      setState(() {
        _foundPass = pass;
        _isLoadingDetails = false;
      });
      
      if (pass == null) {
        _showSnackBar('Pass not found for UID: $uid', isError: true);
      } else {
        _showSnackBar('Pass details loaded successfully!', isError: false);
      }
      
    } catch (e) {
      print('💥 Error in _searchPassByUID: $e');
      setState(() {
        _isLoadingDetails = false;
      });
      _showSnackBar('Error searching for pass: $e', isError: true);
    }
  }
  
  void _clearScan() {
    setState(() {
      _foundPass = null;
      _scannedUID = null;
      _isLoadingDetails = false;
    });
  }
  
  Future<String?> _getAccessToken() async {
    return await HiveService.getAccessTokenAsync();
  }
  
  Future<void> _resetPass() async {
    if (_foundPass == null) {
      _showSnackBar('No pass selected for reset', isError: true);
      return;
    }
    
    // Check authentication with multiple fallbacks
    var user = authProvider.state.user;
    
    // If user is null, try to auto-authenticate
    if (user == null) {
      print('🔄 User state is null, attempting auto-authentication...');
      await authProvider.loadStoredAuth();
      user = authProvider.state.user;
      if (user != null) {
        print('✅ Auto-authentication successful, user: ${user.username}');
      }
    }
    
    // Final check - if still null, show error
    if (user == null) {
      print('❌ Authentication failed - user is still null');
      _showSnackBar('Authentication failed. Please login again.', isError: true);
      return;
    }
    
    // Check if user has permission to reset
    if (user.role != 'admin' && user.role != 'manager') {
      _showSnackBar('Access denied. Only Admin and Manager can reset passes.', isError: true);
      return;
    }
    
    print('✅ User authenticated: ${user.username} (${user.role})');
    
    // Show confirmation dialog
    final confirmed = await _showResetConfirmationDialog();
    if (!confirmed) return;
    
    setState(() {
      _isResetting = true;
    });
    
    try {
      // Call actual reset API
      final token = await _getAccessToken();
      if (token == null) {
        _showSnackBar('Authentication token not found', isError: true);
        return;
      }
      
      final response = await HttpInterceptor.patch(
        Uri.parse('${AppConfig.baseUrl}/api/pass/${_foundPass!.id}/reset'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'reason': _reasonController.text.trim().isNotEmpty 
              ? _reasonController.text.trim() 
              : null,
        }),
      );
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final resetPass = PassModel.fromJson(responseData['pass']);
        
        // Update local cache
        await HiveService.addActivePass(resetPass.uid, resetPass);
        
        _showSnackBar('Pass reset successfully!', isError: false);
        
        // Clear form
        setState(() {
          _foundPass = null;
          _scannedUID = null;
          _reasonController.clear();
        });
      } else {
        final errorData = json.decode(response.body);
        String errorMessage = 'Failed to reset pass';
        
        if (response.statusCode == 403) {
          // Check user role for specific message
          final userRole = authProvider.state.user?.role;
          
          if (userRole == 'bouncer') {
            errorMessage = 'Not authorized to reset passes. Only Admin and Manager can reset passes.';
          } else {
            errorMessage = 'Access denied: ${errorData['error'] ?? 'Insufficient permissions'}';
          }
        } else if (response.statusCode == 401) {
          errorMessage = 'Authentication failed: ${errorData['error'] ?? 'Please login again'}';
        } else {
          errorMessage = 'Failed to reset pass: ${errorData['error'] ?? 'Unknown error'}';
        }
        
        _showSnackBar(errorMessage, isError: true);
      }
      
    } catch (e) {
      _showSnackBar('Failed to reset pass: $e', isError: true);
    } finally {
      setState(() {
        _isResetting = false;
      });
    }
  }
  
  Future<bool> _showResetConfirmationDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: AppTheme.warningColor),
            SizedBox(width: 8),
            Text('Confirm Pass Reset'),
             ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to reset this pass?'),
            const SizedBox(height: 12),
            Text('UID: ${_foundPass?.uid}'),
            Text('Pass ID: ${_foundPass?.passId}'),
            Text('Category: ${_foundPass?.category}'),
            Text('Status: ${_foundPass?.status}'),
            const SizedBox(height: 12),
            const Text(
              'This action will restore the pass to active status and clear its usage history.',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.warningColor,
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
              backgroundColor: AppTheme.warningColor,
            ),
            child: const Text('Reset Pass'),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reset Single Pass'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Instructions
              _buildInstructionsCard(),
              
              const SizedBox(height: 24),
              
              // NFC Scan Section
              _buildNFCScanSection(),
              
              const SizedBox(height: 24),
              
              // Pass Details or Loading
              if (_isLoadingDetails) _buildLoadingCard()
              else if (_foundPass != null) _buildPassDetailsCard(),
              
              const SizedBox(height: 24),
              
              // Reset Section
              if (_foundPass != null && !_isLoadingDetails) _buildResetSection(),
              
              // Add bottom padding to avoid navigation bar overlap
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildLoadingCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Loading pass details...',
              style: AppTheme.bodyStyle.copyWith(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please wait while we fetch the information',
              style: AppTheme.captionStyle,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildInstructionsCard() {
    return Card(
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
                  'Reset Pass Instructions',
                  style: AppTheme.subheadingStyle.copyWith(fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('• Tap the "Start NFC Scan" button below'),
            const Text('• Hold the NFC card near your device'),
            const Text('• Review the pass details when found'),
            const Text('• Provide a reason for the reset (optional)'),
            const Text('• Confirm the reset to restore pass to active status'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.warningColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning,
                    size: 16,
                    color: AppTheme.warningColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Resetting a pass will clear its usage history and allow it to be used again.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.warningColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildNFCScanSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Scan NFC Card',
              style: AppTheme.subheadingStyle.copyWith(fontSize: 16),
            ),
            const SizedBox(height: 12),
            
            if (_scannedUID != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.successColor),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: AppTheme.successColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Card Scanned Successfully'),
                          Text(
                            'UID: $_scannedUID',
                            style: const TextStyle(fontFamily: 'monospace'),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: _clearScan,
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              )
             else
               Container(
                 padding: const EdgeInsets.all(12),
                 decoration: BoxDecoration(
                   color: AppTheme.infoColor.withOpacity(0.1),
                   borderRadius: BorderRadius.circular(8),
                   border: Border.all(color: AppTheme.infoColor),
                 ),
                 child: const Row(
                   children: [
                     Icon(Icons.nfc, color: AppTheme.infoColor),
                     SizedBox(width: 8),
                     Expanded(
                       child: Text('No card scanned yet. Tap the button below to start scanning.'),
                     ),
                   ],
                 ),
               ),
            
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isScanning ? null : _startNFCScan,
                    icon: _isScanning
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.nfc),
                    label: Text(_isScanning ? 'Scanning...' : 'Start NFC Scan'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                if (_isScanning) ...[
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _stopNFCScan,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.errorColor,
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      ),
                      child: const Text('Stop'),
                    ),
                  ],
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPassDetailsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pass Details',
              style: AppTheme.subheadingStyle.copyWith(fontSize: 16),
            ),
            const SizedBox(height: 12),
            _buildDetailRow('UID', _foundPass!.uid),
            _buildDetailRow('Pass ID', _foundPass!.passId),
            _buildDetailRow('Type', _foundPass!.passType),
            _buildDetailRow('Category', _foundPass!.category),
            _buildDetailRow('People Allowed', _foundPass!.peopleAllowed.toString()),
            _buildDetailRow('Status', _foundPass!.status),
            _buildDetailRow('Created', _foundPass!.createdAt),
            if (_foundPass!.updatedAt != null)
              _buildDetailRow('Updated', _foundPass!.updatedAt!),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontFamily: 'monospace'),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildResetSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reset Pass',
              style: AppTheme.subheadingStyle.copyWith(fontSize: 16),
            ),
            const SizedBox(height: 12),
            
            TextFormField(
              controller: _reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason for Reset (Optional)',
                hintText: 'Enter reason for resetting this pass',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            
            const SizedBox(height: 16),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isResetting ? null : _resetPass,
                icon: _isResetting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                label: Text(_isResetting ? 'Resetting...' : 'Reset Pass'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.warningColor,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}