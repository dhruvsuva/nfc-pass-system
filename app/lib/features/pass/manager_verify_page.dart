import 'package:flutter/material.dart';
import 'dart:async';
import '../../core/nfc/nfc_service.dart';
import '../../core/services/pass_service.dart';
import '../../models/pass_model.dart';

class ManagerVerifyPage extends StatefulWidget {
  const ManagerVerifyPage({super.key});

  @override
  State<ManagerVerifyPage> createState() => _ManagerVerifyPageState();
}

class _ManagerVerifyPageState extends State<ManagerVerifyPage> {
  bool _isScanning = false;
  bool _isVerifying = false;
  String? _errorMessage;
  Timer? _autoCloseTimer;
  List<Map<String, dynamic>> _recentScans = [];
  StreamSubscription<NFCEvent>? _nfcSubscription;

  @override
  void initState() {
    super.initState();
    _initializeNFC();
  }

  @override
  void dispose() {
    _autoCloseTimer?.cancel();
    _nfcSubscription?.cancel();
    NFCService.stopScan();
    super.dispose();
  }

  Future<void> _initializeNFC() async {
    try {
      await NFCService.initialize();
      _nfcSubscription = NFCService.nfcEventStream.listen(_handleNFCEvent);
      _startScan();
    } catch (e) {
      _showErrorDialog('NFC Error', 'Failed to initialize NFC: $e');
    }
  }

  void _handleNFCEvent(NFCEvent event) {
    switch (event.type) {
      case NFCEventType.scanStarted:
        setState(() {
          _isScanning = true;
          _errorMessage = null;
        });
        break;
        
      case NFCEventType.scanStopped:
        setState(() {
          _isScanning = false;
        });
        break;
        
      case NFCEventType.tagDiscovered:
        if (event.uid != null && !_isVerifying) {
          _verifyPass(event.uid!);
        }
        break;
        
      case NFCEventType.error:
        setState(() {
          _isScanning = false;
          _errorMessage = event.message ?? 'NFC Error';
        });
        _showErrorDialog('NFC Error', event.message ?? 'NFC Error');
        break;
    }
  }

  void _startScan() async {
    if (_isScanning) return;
    
    setState(() {
      _isScanning = true;
      _errorMessage = null;
    });

    try {
      final success = await NFCService.startScan();
      if (!success) {
        setState(() {
          _isScanning = false;
          _errorMessage = 'Failed to start NFC scan';
        });
        _showErrorDialog('NFC Error', 'Failed to start NFC scan');
      }
    } catch (e) {
      setState(() {
        _isScanning = false;
        _errorMessage = 'Error starting NFC scan: $e';
      });
      _showErrorDialog('NFC Error', 'Error starting NFC scan: $e');
    }
  }

  void _stopScan() {
    setState(() {
      _isScanning = false;
    });
    NFCService.stopScan();
  }

  Future<void> _verifyPass(String uid) async {
    if (_isVerifying) return;
    
    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      final result = await PassService.verifyPass(
        uid: uid,
        gateId: 'manager_gate',
        scannedBy: 1, // Manager ID - should be dynamic
      );

      setState(() {
        _isVerifying = false;
      });

      // Add to recent scans
      _addToRecentScans(uid, result.success, result.pass);

      // Show result popup
      _showVerificationResult(result);

      // Auto close after 3 seconds if successful
      if (result.success) {
        _autoCloseTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) {
            _clearResults();
          }
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isVerifying = false;
      });
      
      _addToRecentScans(uid, false, null, error: e.toString());
      _showErrorDialog('Verification Failed', e.toString());
    }
  }

  void _addToRecentScans(String uid, bool success, PassModel? pass, {String? error}) {
    final scan = {
      'uid': uid,
      'success': success,
      'timestamp': DateTime.now(),
      'pass': pass,
      'error': error,
    };
    
    setState(() {
      _recentScans.insert(0, scan);
      // Keep only last 10 scans
      if (_recentScans.length > 10) {
        _recentScans = _recentScans.take(10).toList();
      }
    });
  }

  void _clearResults() {
    setState(() {
      _errorMessage = null;
    });
    _autoCloseTimer?.cancel();
  }

  void _showVerificationResult(PassVerificationResult result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              result.success ? Icons.check_circle : Icons.error,
              color: result.success ? Colors.green : Colors.red,
              size: 28,
            ),
            const SizedBox(width: 8),
            Text(
              result.success ? 'Verification Successful' : 'Verification Failed',
              style: TextStyle(
                color: result.success ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              result.message,
              style: const TextStyle(fontSize: 16),
            ),
            if (result.pass != null) ...[
              const SizedBox(height: 16),
              _buildPassDetails(result.pass!),
            ],
            if (result.remainingUses != null) ...[
              const SizedBox(height: 8),
              Text(
                'Remaining Uses: ${result.remainingUses}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _clearResults();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildPassDetails(PassModel pass) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pass Details',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          _buildDetailRow('UID', pass.uid),
          _buildDetailRow('Type', pass.passType.toUpperCase()),
          _buildDetailRow('Category', pass.category),
          _buildDetailRow('People Allowed', pass.peopleAllowed.toString()),
          _buildDetailRow('Used Count', pass.usedCount.toString()),
          _buildDetailRow('Max Uses', pass.maxUses.toString()),
          if (pass.lastUsedAt != null)
            _buildDetailRow('Last Used', _formatDateTime(pass.lastUsedAt!)),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(String dateTimeString) {
    try {
      final dateTime = DateTime.parse(dateTimeString);
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateTimeString;
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.error, color: Colors.red),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Pass'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_isScanning ? Icons.stop : Icons.play_arrow),
            onPressed: _isScanning ? _stopScan : _startScan,
            tooltip: _isScanning ? 'Stop Scanning' : 'Start Scanning',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Scanning Status Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Icon(
                      _isScanning ? Icons.nfc : Icons.nfc_outlined,
                      size: 64,
                      color: _isScanning ? Colors.blue : Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _isScanning 
                          ? 'Ready to scan NFC tags'
                          : 'NFC scanning stopped',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isScanning 
                          ? 'Tap an NFC tag to verify the pass'
                          : 'Press the play button to start scanning',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    if (_isVerifying) ...[
                      const SizedBox(height: 16),
                      const CircularProgressIndicator(),
                      const SizedBox(height: 8),
                      const Text('Verifying pass...'),
                    ],
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red[200]!),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error, color: Colors.red),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Recent Scans
            if (_recentScans.isNotEmpty) ...[
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Recent Scans',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: _recentScans.length,
                  itemBuilder: (context, index) {
                    final scan = _recentScans[index];
                    final success = scan['success'] as bool;
                    final timestamp = scan['timestamp'] as DateTime;
                    final pass = scan['pass'] as PassModel?;
                    final error = scan['error'] as String?;
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Icon(
                          success ? Icons.check_circle : Icons.error,
                          color: success ? Colors.green : Colors.red,
                        ),
                        title: Text(
                          'UID: ${scan['uid']}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')} - ${timestamp.day}/${timestamp.month}/${timestamp.year}',
                            ),
                            if (pass != null)
                              Text(
                                '${pass.passType.toUpperCase()} | ${pass.category}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: Colors.blue,
                                ),
                              ),
                            if (error != null)
                              Text(
                                error,
                                style: const TextStyle(color: Colors.red),
                              ),
                          ],
                        ),
                        trailing: success 
                            ? const Icon(Icons.verified, color: Colors.green)
                            : const Icon(Icons.cancel, color: Colors.red),
                      ),
                    );
                  },
                ),
              ),
            ] else ...[
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No recent scans',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Start scanning to see verification history',
                        style: TextStyle(
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}