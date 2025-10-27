import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';
import '../../core/nfc/nfc_service.dart';
import '../../core/services/pass_service.dart';
import '../../core/services/toast_service.dart';
import '../../core/storage/hive_service.dart';
import '../../core/network/http_interceptor.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/pass_theme.dart';
import '../../models/pass_model.dart';
import '../auth/providers/auth_provider.dart';

class ManagerPassDetailsPage extends StatefulWidget {
  const ManagerPassDetailsPage({super.key});

  @override
  State<ManagerPassDetailsPage> createState() => _ManagerPassDetailsPageState();
}

class _ManagerPassDetailsPageState extends State<ManagerPassDetailsPage> {
  bool _isScanning = false;
  bool _isLoadingDetails = false;
  String? _scannedUID;
  PassModel? _foundPass;
  List<Map<String, dynamic>> _usageHistory = [];
  Map<String, dynamic>? _statistics;
  StreamSubscription<NFCEvent>? _nfcSubscription;

  @override
  void initState() {
    super.initState();
    _initializeNFC();
  }

  @override
  void dispose() {
    _nfcSubscription?.cancel();
    NFCService.stopScan();
    super.dispose();
  }

  Future<void> _initializeNFC() async {
    try {
      await NFCService.initialize();
      _nfcSubscription = NFCService.nfcEventStream.listen(_handleNFCEvent);
    } catch (e) {
      String errorMessage = 'Failed to initialize NFC';
      
      if (e.toString().contains('not available')) {
        errorMessage = 'NFC is not available on this device';
      } else if (e.toString().contains('disabled')) {
        errorMessage = 'NFC is disabled. Please enable NFC in device settings';
      } else if (e.toString().contains('permission')) {
        errorMessage = 'NFC permission denied. Please grant NFC permission';
      } else {
        errorMessage = 'Failed to initialize NFC: $e';
      }
      
      _showErrorDialog('NFC Initialization Error', errorMessage);
    }
  }

  void _handleNFCEvent(NFCEvent event) {
    switch (event.type) {
      case NFCEventType.scanStarted:
        setState(() {
          _isScanning = true;
        });
        break;
        
      case NFCEventType.scanStopped:
        setState(() {
          _isScanning = false;
        });
        break;
        
      case NFCEventType.tagDiscovered:
        if (event.uid != null) {
          setState(() {
            _scannedUID = event.uid;
            _isScanning = false;
          });
          HapticFeedback.lightImpact();
          _loadPassDetails(event.uid!);
          NFCService.stopScan();
        }
        break;
        
      case NFCEventType.error:
        setState(() {
          _isScanning = false;
        });
        _showSnackBar('NFC Error: ${event.message}', isError: true);
        break;
    }
  }

  Future<void> _startNFCScan() async {
    setState(() {
      _isScanning = true;
      _foundPass = null;
      _scannedUID = null;
      _usageHistory.clear();
      _statistics = null;
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

  Future<void> _loadPassDetails(String uid) async {
    if (uid.isEmpty) {
      _showErrorDialog('Invalid UID', 'The scanned UID is empty or invalid.');
      return;
    }

    setState(() {
      _foundPass = null;
      _usageHistory.clear();
      _statistics = null;
      _isLoadingDetails = true;
    });

    try {
      final passDetailsResponse = await PassService.getPassDetailsByUID(uid);
      
      if (passDetailsResponse != null) {
        setState(() {
          _foundPass = passDetailsResponse.pass;
          _usageHistory = passDetailsResponse.usageHistory ?? [];
          _statistics = passDetailsResponse.statistics;
          _isLoadingDetails = false;
        });
        
        _showSnackBar('Pass details loaded successfully', isError: false);
      } else {
        setState(() {
          _isLoadingDetails = false;
        });
        _showErrorDialog('Pass Not Found', 'No pass found with UID: $uid\n\nPlease verify the UID is correct or check if the pass exists in the system.');
      }
    } catch (e) {
      setState(() {
        _isLoadingDetails = false;
      });
      
      String errorMessage = 'Failed to load pass details';
      String errorTitle = 'Error Loading Pass';
      
      if (e.toString().contains('SocketException')) {
        errorMessage = 'Network connection failed. Please check your internet connection and try again.';
        errorTitle = 'Network Error';
      } else if (e.toString().contains('TimeoutException')) {
        errorMessage = 'Request timed out. The server is taking too long to respond. Please try again.';
        errorTitle = 'Timeout Error';
      } else if (e.toString().contains('FormatException')) {
        errorMessage = 'Invalid response format from server. Please contact support if this persists.';
        errorTitle = 'Data Format Error';
      } else if (e.toString().contains('401')) {
        errorMessage = 'Authentication failed. Please login again to continue.';
        errorTitle = 'Authentication Error';
      } else if (e.toString().contains('403')) {
        errorMessage = 'Access denied. You don\'t have permission to view this pass details.';
        errorTitle = 'Permission Error';
      } else if (e.toString().contains('404')) {
        errorMessage = 'Pass not found with UID: $uid';
        errorTitle = 'Pass Not Found';
      } else if (e.toString().contains('500')) {
        errorMessage = 'Server error occurred. Please try again later or contact support.';
        errorTitle = 'Server Error';
      } else {
        errorMessage = 'Failed to load pass details: ${e.toString()}';
      }
      
      _showErrorDialog(errorTitle, errorMessage);
    }
  }

  void _clearScan() {
    setState(() {
      _foundPass = null;
      _scannedUID = null;
      _usageHistory.clear();
      _statistics = null;
      _isLoadingDetails = false;
    });
  }

  void _showSnackBar(String message, {required bool isError}) {
    if (isError) {
      ToastService.showError(message);
    } else {
      ToastService.showSuccess(message);
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: Row(
          children: [
            const Icon(Icons.error, color: Colors.red, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'OK',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (message.contains('Network') || message.contains('timeout') || message.contains('Server'))
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                if (_scannedUID != null) {
                  _loadPassDetails(_scannedUID!);
                }
              },
              child: const Text(
                'Retry',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pass Details'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Info Card
            Card(
              color: AppTheme.infoColor.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: AppTheme.infoColor,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Manager View',
                            style: AppTheme.subheadingStyle.copyWith(
                              color: AppTheme.infoColor,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'View comprehensive pass details including usage history and statistics. This is a read-only view.',
                            style: AppTheme.bodyStyle.copyWith(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // NFC Scan Section
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.nfc,
                      size: 48,
                      color: _isScanning ? Colors.blue : Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _isScanning ? 'Scanning for NFC card...' : 'Tap to scan NFC card',
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    if (_isScanning)
                      const CircularProgressIndicator()
                    else
                      ElevatedButton.icon(
                        onPressed: _startNFCScan,
                        icon: const Icon(Icons.nfc),
                        label: const Text('Start NFC Scan'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                      ),
                    if (_isScanning) ...[
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _stopNFCScan,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Stop Scan'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Scanned UID Display
            if (_scannedUID != null) ...[
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Scanned UID:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _scannedUID!,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // Loading Indicator
            if (_isLoadingDetails) ...[
              const Card(
                elevation: 2,
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Loading pass details...'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // Pass Details Section
            if (_foundPass != null) ...[
              _buildPassDetailsCard(_foundPass!),
              const SizedBox(height: 16),
              
              // Statistics Section
              if (_statistics != null) ...[
                _buildStatisticsCard(_statistics!),
                const SizedBox(height: 16),
              ],
              
              // Usage History Section
              if (_usageHistory.isNotEmpty) ...[
                _buildUsageHistoryCard(_usageHistory),
                const SizedBox(height: 16),
              ],
            ],
            
            // Clear Button
            if (_foundPass != null || _scannedUID != null) ...[
              ElevatedButton.icon(
                onPressed: _clearScan,
                icon: const Icon(Icons.clear),
                label: const Text('Clear'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPassDetailsCard(PassModel pass) {
    final remainingUses = pass.remainingUses ?? (pass.maxUses - pass.usedCount);
    
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.getStatusColor(pass.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.credit_card,
                    color: AppTheme.getStatusColor(pass.status),
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pass Details',
                        style: AppTheme.headingStyle.copyWith(fontSize: 20),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.getStatusColor(pass.status),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          pass.status.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            
            // Basic Information
            _buildDetailRow('UID', pass.uid),
            _buildDetailRow('Pass ID', pass.passId),
            _buildDetailRow('Category', pass.category),
            _buildDetailRow('Type', pass.passType),
            _buildDetailRow('People Allowed', pass.peopleAllowed.toString()),
            
            // Usage Information
            if (pass.category.toLowerCase() != 'all access' && pass.passType != 'unlimited') ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'Usage Information',
                style: AppTheme.subheadingStyle.copyWith(fontSize: 16),
              ),
              const SizedBox(height: 8),
              _buildDetailRow('Max Uses', pass.maxUses?.toString() ?? 'Unlimited'),
              _buildDetailRow('Used Count', pass.usedCount.toString()),
              _buildDetailRow('Remaining Uses', remainingUses.toString()),
            ],
            
            // Timestamps
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              'Timestamps',
              style: AppTheme.subheadingStyle.copyWith(fontSize: 16),
            ),
            const SizedBox(height: 8),
            _buildDetailRow('Created At', _formatDateTime(pass.createdAt)),
            _buildDetailRow('Updated At', _formatDateTime(pass.updatedAt)),
            if (pass.lastScanAt != null)
              _buildDetailRow('Last Scan', _formatDateTime(pass.lastScanAt!)),
            if (pass.lastUsedAt != null)
              _buildDetailRow('Last Used', _formatDateTime(pass.lastUsedAt!)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsCard(Map<String, dynamic> statistics) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.analytics, color: Colors.blue, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Statistics',
                  style: AppTheme.subheadingStyle.copyWith(fontSize: 18),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            
            // Display statistics
            ...statistics.entries.map((entry) {
              return _buildDetailRow(
                _formatStatKey(entry.key),
                entry.value.toString(),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildUsageHistoryCard(List<Map<String, dynamic>> history) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.history, color: Colors.green, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Usage History',
                  style: AppTheme.subheadingStyle.copyWith(fontSize: 18),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            
            // History List
            if (history.isEmpty)
              const Text('No usage history available.')
            else
              ...history.take(10).map((usage) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            usage['result'] ?? 'Unknown',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _getResultColor(usage['result']),
                            ),
                          ),
                          Text(
                            _formatDateTime(usage['scanned_at'] ?? ''),
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                      if (usage['gate_id'] != null) ...[
                        const SizedBox(height: 4),
                        Text('Gate: ${usage['gate_id']}', style: const TextStyle(fontSize: 12)),
                      ],
                      if (usage['consumed_count'] != null && usage['consumed_count'] > 0) ...[
                        const SizedBox(height: 4),
                        Text('Consumed: ${usage['consumed_count']}', style: const TextStyle(fontSize: 12)),
                      ],
                    ],
                  ),
                );
              }).toList(),
              
            if (history.length > 10) ...[
              const SizedBox(height: 8),
              Text(
                'Showing latest 10 entries (${history.length} total)',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(String dateTimeStr) {
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateTimeStr;
    }
  }

  String _formatStatKey(String key) {
    return key.split('_').map((word) => 
      word[0].toUpperCase() + word.substring(1)
    ).join(' ');
  }

  Color _getResultColor(String? result) {
    switch (result?.toLowerCase()) {
      case 'success':
      case 'allowed':
        return Colors.green;
      case 'denied':
      case 'blocked':
      case 'expired':
        return Colors.red;
      case 'warning':
      case 'limited':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}