import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';

import '../../core/theme/app_theme.dart';
import '../../core/services/pass_service.dart';
import '../../core/services/toast_service.dart';
import '../../core/nfc/nfc_service.dart';
import '../../core/utils/timezone_utils.dart';
import '../../models/pass_model.dart';
import '../auth/providers/auth_provider.dart';

class PassDetailsPage extends StatefulWidget {
  const PassDetailsPage({super.key});

  @override
  State<PassDetailsPage> createState() => _PassDetailsPageState();
}

class _PassDetailsPageState extends State<PassDetailsPage> {
  PassModel? _passDetails;
  List<Map<String, dynamic>> _usageHistory = [];
  bool _isLoading = false;
  bool _isScanning = false;
  bool _isInitialized = false;
  String? _error;
  String? _currentUID;
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
      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to initialize NFC: $e';
      });
    }
  }

  void _handleNFCEvent(NFCEvent event) {
    switch (event.type) {
      case NFCEventType.scanStarted:
        setState(() {
          _isScanning = true;
          _error = null;
        });
        break;

      case NFCEventType.scanStopped:
        setState(() {
          _isScanning = false;
        });
        break;

      case NFCEventType.tagDiscovered:
        if (event.uid != null) {
          _handleTagDiscovered(event.uid!);
        }
        break;

      case NFCEventType.error:
        setState(() {
          _isScanning = false;
          _error = event.message ?? 'NFC Error';
        });
        break;
    }
  }

  void _handleTagDiscovered(String uid) {
    setState(() {
      _currentUID = uid;
      _isScanning = false;
    });

    // Provide haptic feedback
    HapticFeedback.lightImpact();

    // Load pass details
    _loadPassDetails(uid);
  }

  Future<void> _loadPassDetails(String uid) async {
    setState(() {
      _isLoading = true;
      _error = null;
      _passDetails = null;
    });

    try {
      final passDetailsResponse = await PassService.getPassDetailsByUID(uid);
      setState(() {
        _passDetails = passDetailsResponse?.pass;
        _usageHistory = passDetailsResponse?.usageHistory ?? [];
        _isLoading = false;
        if (passDetailsResponse == null) {
          _error = 'Pass not found. Please check the UID and try again.';
        }
      });
    } catch (e) {
      debugPrint('Error loading pass details: $e');
      setState(() {
        _isLoading = false;
        // Check if it's a 404 error (pass not found)
        if (e.toString().toLowerCase().contains('404') ||
            e.toString().toLowerCase().contains('not found') ||
            e.toString().toLowerCase().contains('pass_not_found')) {
          _error = 'Pass not found. Please check the UID and try again.';
        } else {
          _error = 'Error loading pass details. Please try again.';
        }
      });
    }
  }

  Future<void> _startNFCScan() async {
    if (!_isInitialized) {
      setState(() {
        _error = 'NFC not initialized';
      });
      return;
    }

    try {
      final isSupported = await NFCService.isNFCSupported();
      if (!isSupported) {
        setState(() {
          _error = 'NFC is not supported on this device';
        });
        return;
      }

      final isEnabled = await NFCService.isNFCEnabled();
      if (!isEnabled) {
        setState(() {
          _error = 'NFC is disabled. Please enable NFC in settings.';
        });
        return;
      }

      await NFCService.startScan();
    } catch (e) {
      setState(() {
        _error = 'Failed to start NFC scan: $e';
      });
    }
  }

  Future<void> _stopNFCScan() async {
    try {
      await NFCService.stopScan();
    } catch (e) {
      setState(() {
        _error = 'Failed to stop NFC scan: $e';
      });
    }
  }

  void _clearResults() {
    setState(() {
      _passDetails = null;
      _error = null;
      _currentUID = null;
    });
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ToastService.showSuccess('Copied to clipboard');
  }

  @override
  Widget build(BuildContext context) {
    final user = authProvider.state.user;
    final isAdminOrManager = user?.role == 'admin' || user?.role == 'manager';

    if (!isAdminOrManager) {
      return Scaffold(
        appBar: AppBar(title: const Text('Access Denied')),
        body: const Center(
          child: Text(
            'You do not have permission to access this page.',
            style: TextStyle(fontSize: 16),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pass Details'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          if (_passDetails != null || _currentUID != null)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: _clearResults,
              tooltip: 'Clear Results',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                            'Read-Only View',
                            style: AppTheme.subheadingStyle.copyWith(
                              color: AppTheme.infoColor,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'This screen is for viewing pass details only. The pass will not be consumed or used when viewed here.',
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
            Text('Scan Pass', style: AppTheme.subheadingStyle),
            const SizedBox(height: 16),

            // Current UID Display (if available)
            if (_currentUID != null) ...[
              Card(
                color: AppTheme.successColor.withOpacity(0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(Icons.nfc, color: AppTheme.successColor, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Scanned UID',
                              style: AppTheme.subheadingStyle.copyWith(
                                color: AppTheme.successColor,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _currentUID!,
                              style: AppTheme.bodyStyle.copyWith(
                                fontFamily: 'monospace',
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy),
                        onPressed: () => _copyToClipboard(_currentUID!),
                        tooltip: 'Copy UID',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // NFC Scan Button
            Center(
              child: Column(
                children: [
                  ElevatedButton.icon(
                    onPressed: _isLoading || _isScanning ? null : _startNFCScan,
                    icon: _isScanning
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Icon(Icons.nfc, size: 24),
                    label: Text(
                      _isScanning
                          ? 'Scanning...'
                          : _isLoading
                          ? 'Loading...'
                          : 'Tap to Scan NFC Pass',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isScanning
                          ? AppTheme.warningColor
                          : AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      textStyle: const TextStyle(fontSize: 16),
                    ),
                  ),
                  if (_isScanning) ...[
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: _stopNFCScan,
                      child: const Text('Stop Scanning'),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Error Display
            if (_error != null)
              Card(
                color: AppTheme.errorColor.withOpacity(0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: AppTheme.errorColor),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: AppTheme.errorColor,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Pass Details Display
            if (_passDetails != null) ...[
              const SizedBox(height: 24),
              _buildPassDetailsCard(_passDetails!),
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
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.getStatusColor(
                      pass.status,
                    ).withOpacity(0.1),
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.getStatusColor(pass.status),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          pass.displayStatus,
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

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),

            // Basic Information
            Text(
              'Basic Information',
              style: AppTheme.subheadingStyle.copyWith(
                color: AppTheme.primaryColor,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),

            _buildDetailRow('UID', pass.uid, copyable: true),
            _buildDetailRow('Pass ID', pass.passId, copyable: true),
            _buildDetailRow('Category', pass.category),
            _buildDetailRow('Pass Type', pass.passType.toUpperCase()),
            _buildDetailRow('Allowed Persons', pass.peopleAllowed.toString()),
            _buildDetailRow('Status', pass.displayStatus),

            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 16),

            // Usage Information
            Text(
              'Usage Details',
              style: AppTheme.subheadingStyle.copyWith(
                color: AppTheme.primaryColor,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),

            _buildDetailRow('Max Uses', pass.maxUses.toString()),
            _buildDetailRow('Used Count', pass.usedCount.toString()),
            _buildDetailRow(
              'Remaining Uses',
              remainingUses.toString(),
              valueColor: remainingUses > 0
                  ? AppTheme.successColor
                  : AppTheme.errorColor,
            ),

            if (pass.lastUsedAt != null) ...[
              _buildDetailRow('Last Used', _formatDateTime(pass.lastUsedAt!)),
              if (pass.lastUsedByUsername != null)
                _buildDetailRow('Last Used By', pass.lastUsedByUsername!),
            ],

            if (pass.lastScanAt != null)
              _buildDetailRow('Last Scan', _formatDateTime(pass.lastScanAt!)),

            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 16),

            // Creation Information
            Text(
              'Creation Details',
              style: AppTheme.subheadingStyle.copyWith(
                color: AppTheme.primaryColor,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),

            if (pass.createdByUsername != null)
              _buildDetailRow('Created By', pass.createdByUsername!),
            _buildDetailRow('Created Date', _formatDateTime(pass.createdAt)),
            _buildDetailRow('Last Updated', _formatDateTime(pass.updatedAt)),

            // Usage History
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 16),

            Text(
              'Usage History',
              style: AppTheme.subheadingStyle.copyWith(
                color: AppTheme.primaryColor,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),

            _buildUsageHistorySection(),

            // UID at bottom
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 8),

            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.fingerprint, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Text(
                      'UID: ${pass.uid}',
                      style: AppTheme.bodyStyle.copyWith(
                        fontSize: 11,
                        color: Colors.grey[700],
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => _copyToClipboard(pass.uid),
                      child: Icon(
                        Icons.copy,
                        size: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    bool copyable = false,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: AppTheme.bodyStyle.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: AppTheme.bodyStyle.copyWith(
                      color: valueColor ?? Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
                if (copyable)
                  IconButton(
                    icon: const Icon(Icons.copy, size: 16),
                    onPressed: () => _copyToClipboard(value),
                    tooltip: 'Copy to clipboard',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsageHistorySection() {
    if (_usageHistory.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.grey[50]!, Colors.grey[100]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!, width: 1),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.history, color: Colors.grey[600], size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              'No Usage History',
              style: AppTheme.subheadingStyle.copyWith(
                color: Colors.grey[700],
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This pass has not been used yet.\nUsage logs will appear here after verification.',
              textAlign: TextAlign.center,
              style: AppTheme.bodyStyle.copyWith(
                color: Colors.grey[600],
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Statistics Summary
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.primaryColor.withOpacity(0.1),
                AppTheme.primaryColor.withOpacity(0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.analytics, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Usage Summary',
                      style: AppTheme.subheadingStyle.copyWith(
                        color: AppTheme.primaryColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_usageHistory.length} verification${_usageHistory.length == 1 ? '' : 's'} recorded',
                      style: AppTheme.bodyStyle.copyWith(
                        color: Colors.grey[700],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_usageHistory.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // History List
        Container(
          constraints: const BoxConstraints(maxHeight: 400),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: _usageHistory.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              color: Colors.grey[200],
              indent: 16,
              endIndent: 16,
            ),
            itemBuilder: (context, index) {
              final log = _usageHistory[index];
              return _buildUsageHistoryItem(log, index + 1);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildUsageHistoryItem(Map<String, dynamic> log, int index) {
    final scannedAt = log['scanned_at'] as String?;
    final verifiedBy = log['verified_by'] as String? ?? 'Unknown';
    final verifiedByRole = log['verified_by_role'] as String? ?? 'Unknown';
    final location = log['location'] as String? ?? 'Unknown Location';
    final peopleCount = log['people_count'] as int? ?? 1;
    final status = log['status'] as String? ?? 'success';

    final isSuccess = status.toLowerCase() == 'success';
    final statusColor = isSuccess ? AppTheme.successColor : AppTheme.errorColor;
    final statusIcon = isSuccess ? Icons.check_circle : Icons.error;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: index % 2 == 0 ? Colors.white : Colors.grey[50],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Entry Number and Status Icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: statusColor.withOpacity(0.3), width: 1),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '#$index',
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Icon(statusIcon, color: statusColor, size: 12),
              ],
            ),
          ),

          const SizedBox(width: 16),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date and Time
                Row(
                  children: [
                    Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Text(
                      scannedAt != null
                          ? _formatDateTime(scannedAt)
                          : 'Unknown time',
                      style: AppTheme.bodyStyle.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Verified by and role
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.person,
                        size: 14,
                        color: AppTheme.primaryColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$verifiedBy ($verifiedByRole)',
                        style: AppTheme.bodyStyle.copyWith(
                          fontSize: 12,
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 6),

                // Location and People count
                Row(
                  children: [
                    // Location
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              location,
                              style: AppTheme.bodyStyle.copyWith(
                                fontSize: 12,
                                color: Colors.grey[700],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // People count (if more than 1)
                    if (peopleCount > 1) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.group,
                              size: 12,
                              color: Colors.blue[700],
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '$peopleCount',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.blue[700],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),

                // Status badge
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(String dateTimeStr) {
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      return TimezoneUtils.formatIndian(dateTime);
    } catch (e) {
      return dateTimeStr;
    }
  }
}
