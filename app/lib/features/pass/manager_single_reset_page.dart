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
import '../../models/pass_model.dart';
import '../auth/providers/auth_provider.dart';

class ManagerSingleResetPage extends StatefulWidget {
  const ManagerSingleResetPage({super.key});

  @override
  State<ManagerSingleResetPage> createState() => _ManagerSingleResetPageState();
}

class _ManagerSingleResetPageState extends State<ManagerSingleResetPage> {
  bool _isScanning = false;
  bool _isLoadingDetails = false;
  bool _isResetting = false;
  String? _scannedUID;
  PassModel? _foundPass;
  StreamSubscription<NFCEvent>? _nfcSubscription;
  final TextEditingController _reasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeNFC();
  }

  @override
  void dispose() {
    _nfcSubscription?.cancel();
    NFCService.stopScan();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _initializeNFC() async {
    try {
      await NFCService.initialize();
      _nfcSubscription = NFCService.nfcEventStream.listen(_handleNFCEvent);
    } catch (e) {
      String errorMessage = 'Failed to initialize NFC';
      if (e.toString().toLowerCase().contains('permission')) {
        errorMessage = 'NFC permission required. Please grant NFC permissions in app settings.';
      } else if (e.toString().toLowerCase().contains('nfc')) {
        errorMessage = 'NFC not available on this device or disabled in settings.';
      } else if (e.toString().toLowerCase().contains('platform')) {
        errorMessage = 'NFC not supported on this platform.';
      }
      ToastService.showError('$errorMessage: ${e.toString()}');
    }
  }

  void _handleNFCEvent(NFCEvent event) {
    // Check if widget is still mounted before calling setState
    if (!mounted) return;
    
    switch (event.type) {
      case NFCEventType.scanStarted:
        if (mounted) {
          setState(() {
            _isScanning = true;
          });
        }
        break;
        
      case NFCEventType.scanStopped:
        if (mounted) {
          setState(() {
            _isScanning = false;
          });
        }
        break;
        
      case NFCEventType.tagDiscovered:
        if (event.uid != null) {
          if (mounted) {
            setState(() {
              _scannedUID = event.uid;
              _isScanning = false;
            });
          }
          HapticFeedback.lightImpact();
          _searchPassByUID(event.uid!);
          NFCService.stopScan();
        } else {
          if (mounted) {
            setState(() {
              _isScanning = false;
            });
          }
          ToastService.showError('No UID detected from NFC card. Please try again.');
        }
        break;
        
      case NFCEventType.error:
        if (mounted) {
          setState(() {
            _isScanning = false;
          });
        }
        String errorMessage = event.message ?? 'Unknown NFC error occurred';
        if (errorMessage.toLowerCase().contains('permission')) {
          errorMessage = 'NFC permission denied. Please enable NFC permissions.';
        } else if (errorMessage.toLowerCase().contains('disabled')) {
          errorMessage = 'NFC is disabled. Please enable NFC in device settings.';
        } else if (errorMessage.toLowerCase().contains('timeout')) {
          errorMessage = 'NFC scan timed out. Please try again.';
        }
        ToastService.showError('NFC Error: $errorMessage');
        break;
    }
  }

  Future<void> _startNFCScan() async {
    if (!mounted) return;
    setState(() {
      _isScanning = true;
      _foundPass = null;
      _scannedUID = null;
    });
    
    try {
      final success = await NFCService.startScan();
      if (!success) {
        if (mounted) {
          setState(() {
            _isScanning = false;
          });
        }
        ToastService.showError('Failed to start NFC scan. Please check NFC is enabled and permissions are granted.');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
      String errorMessage = 'Error starting NFC scan';
      if (e.toString().toLowerCase().contains('permission')) {
        errorMessage = 'NFC permission required. Please grant NFC permissions in app settings.';
      } else if (e.toString().toLowerCase().contains('nfc')) {
        errorMessage = 'NFC not available or disabled. Please enable NFC in device settings.';
      } else if (e.toString().toLowerCase().contains('platform')) {
        errorMessage = 'NFC not supported on this device.';
      }
      ToastService.showError('$errorMessage: ${e.toString()}');
    }
  }

  Future<void> _stopNFCScan() async {
    if (mounted) {
      setState(() {
        _isScanning = false;
      });
    }
    await NFCService.stopScan();
  }

  Future<void> _searchPassByUID(String uid) async {
    if (!mounted) return;
    setState(() {
      _foundPass = null;
      _isLoadingDetails = true;
    });

    try {
      final token = await _getAccessToken();
      if (token == null) {
        if (mounted) {
          setState(() {
            _isLoadingDetails = false;
          });
        }
        ToastService.showError('Authentication failed. Please login again.');
        return;
      }

      final apiUrl = '${AppConfig.baseUrl}/api/pass/search?uid=$uid';
      
      final response = await HttpInterceptor.get(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['pass'] != null) {
          if (mounted) {
            setState(() {
              _foundPass = PassModel.fromJson(responseData['pass']);
              _isLoadingDetails = false;
            });
          }
          ToastService.showSuccess('Pass found successfully!');
        } else {
          if (mounted) {
            setState(() {
              _isLoadingDetails = false;
            });
          }
          ToastService.showError('No pass data received from server.');
        }
      } else if (response.statusCode == 404) {
        if (mounted) {
          setState(() {
            _isLoadingDetails = false;
          });
        }
        ToastService.showError('Pass not found with UID: $uid. Please verify the UID is correct.');
      } else if (response.statusCode == 401) {
        if (mounted) {
          setState(() {
            _isLoadingDetails = false;
          });
        }
        ToastService.showError('Authentication expired. Please login again.');
      } else if (response.statusCode == 403) {
        if (mounted) {
          setState(() {
            _isLoadingDetails = false;
          });
        }
        ToastService.showError('Access denied. You don\'t have permission to search passes.');
      } else {
        if (mounted) {
          setState(() {
            _isLoadingDetails = false;
          });
        }
        try {
          final errorData = json.decode(response.body);
          ToastService.showError('Error: ${errorData['error'] ?? 'Failed to search pass'}');
        } catch (e) {
          ToastService.showError('Server error occurred while searching pass (Status: ${response.statusCode})');
        }
      }
    } on TimeoutException {
      if (mounted) {
        setState(() {
          _isLoadingDetails = false;
        });
      }
      ToastService.showError('Request timed out. Please check your internet connection and try again.');
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingDetails = false;
        });
      }
      String errorMessage = 'Failed to search pass';
      if (e.toString().toLowerCase().contains('network') || e.toString().toLowerCase().contains('connection')) {
        errorMessage = 'Network error. Please check your internet connection.';
      } else if (e.toString().toLowerCase().contains('format')) {
        errorMessage = 'Invalid server response format.';
      } else if (e.toString().toLowerCase().contains('host')) {
        errorMessage = 'Cannot connect to server. Please check server status.';
      }
      ToastService.showError('$errorMessage: ${e.toString()}');
    }
  }

  Future<String?> _getAccessToken() async {
    return await HiveService.getAccessTokenAsync();
  }

  Future<void> _resetPass() async {
    if (_foundPass == null) {
      ToastService.showError('No pass selected for reset');
      return;
    }

    final authProviderInstance = authProvider;
    var user = authProviderInstance.state.user;
    
    if (user == null) {
      await authProviderInstance.loadStoredAuth();
      user = authProviderInstance.state.user;
    }
    
    if (user == null) {
      ToastService.showError('Authentication failed. Please login again.');
      return;
    }
    
    if (user.role != 'admin' && user.role != 'manager') {
      ToastService.showError('Access denied. Only Admin and Manager can reset passes.');
      return;
    }

    // Check if pass is already active
    if (_foundPass!.status.toLowerCase() == 'active') {
      ToastService.showError('This pass is already active and doesn\'t need to be reset.');
      return;
    }

    final confirmed = await _showResetConfirmationDialog();
    if (!confirmed) return;

    if (!mounted) return;
    setState(() {
      _isResetting = true;
    });

    try {
      final result = await PassService.resetPass(
        uid: _foundPass!.uid,
        resetBy: user.id,
        reason: _reasonController.text.trim().isNotEmpty ? _reasonController.text.trim() : null,
      );

      if (result.success) {
        ToastService.showSuccess('Pass has been successfully reset!');
        if (mounted) {
          setState(() {
            _foundPass = result.pass;
          });
        }
        
        // Wait a moment to show the success message before clearing
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          _clearScan();
        }
      } else {
        // Handle specific error messages
        String errorMessage = result.message;
        if (errorMessage.toLowerCase().contains('already reset')) {
          errorMessage = 'This pass has already been reset.';
        } else if (errorMessage.toLowerCase().contains('deleted')) {
          errorMessage = 'Cannot reset a deleted pass.';
        } else if (errorMessage.toLowerCase().contains('not found')) {
          errorMessage = 'Pass not found. It may have been deleted.';
        } else if (errorMessage.toLowerCase().contains('already active')) {
          errorMessage = 'This pass is already active and doesn\'t need to be reset.';
        } else if (errorMessage.toLowerCase().contains('invalid operation')) {
          errorMessage = 'Invalid operation. Only used or blocked passes can be reset.';
        }
        
        ToastService.showError('Failed to reset pass: $errorMessage');
      }
    } catch (e) {
      String errorMessage = 'An unexpected error occurred';
      if (e.toString().toLowerCase().contains('network') || e.toString().toLowerCase().contains('connection')) {
        errorMessage = 'Network error. Please check your connection and try again.';
      } else if (e.toString().toLowerCase().contains('timeout')) {
        errorMessage = 'Request timed out. Please try again.';
      } else if (e.toString().toLowerCase().contains('authentication')) {
        errorMessage = 'Authentication failed. Please login again.';
      } else if (e.toString().toLowerCase().contains('permission')) {
        errorMessage = 'Permission denied. You don\'t have access to reset passes.';
      } else if (e.toString().toLowerCase().contains('server')) {
        errorMessage = 'Server error occurred. Please try again later.';
      }
      
      ToastService.showError('Failed to reset pass: $errorMessage');
    } finally {
      if (mounted) {
        setState(() {
          _isResetting = false;
        });
      }
    }
  }

  Future<bool> _showResetConfirmationDialog() async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange, size: 24),
            const SizedBox(width: 8),
            const Text(
              'Confirm Reset',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(
            maxHeight: 400,
            maxWidth: 350,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Are you sure you want to reset this pass?',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'This action will reactivate the pass and reset its usage count.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                Text(
                  'Pass Details:',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('UID: ${_foundPass?.uid}', 
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('Category: ${_foundPass?.category}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text('Current Status: ${_foundPass?.status.toUpperCase()}',
                        style: TextStyle(
                          fontSize: 12,
                          color: _getStatusColor(_foundPass?.status ?? 'unknown'),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                TextField(
                  controller: _reasonController,
                  decoration: const InputDecoration(
                    labelText: 'Reason (Optional)',
                    hintText: 'Enter reason for reset...',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  maxLines: 2,
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Reset Pass',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    ) ?? false;
  }

  void _clearScan() {
    if (mounted) {
      setState(() {
        _foundPass = null;
        _scannedUID = null;
        _isLoadingDetails = false;
      });
    }
    _reasonController.clear();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Single Pass Reset'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.card_membership, color: Colors.blue),
                          const SizedBox(width: 8),
                          const Text(
                            'Pass Details',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const Divider(),
                      // Status indicator
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: _getStatusColor(_foundPass!.status),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _getStatusIcon(_foundPass!.status),
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Status: ${_foundPass!.status.toUpperCase()}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      _buildDetailRow('UID', _foundPass!.uid),
                      _buildDetailRow('Category', _foundPass!.category),
                      _buildDetailRow('Type', _foundPass!.passType.toUpperCase()),
                      _buildDetailRow('People Allowed', _foundPass!.peopleAllowed.toString()),
                      if (_foundPass!.maxUses > 0) ...[
                        _buildDetailRow('Max Uses', _foundPass!.maxUses.toString()),
                        _buildDetailRow('Used Count', _foundPass!.usedCount.toString()),
                        _buildDetailRow(
                          'Remaining Uses', 
                          (_foundPass!.maxUses - _foundPass!.usedCount).toString(),
                        ),
                      ] else
                        _buildDetailRow('Max Uses', 'Unlimited'),
                      
                      if (_foundPass!.lastScanAt != null)
                        _buildDetailRow('Last Scan', _formatDateTime(_foundPass!.lastScanAt!)),
                      
                      if (_foundPass!.lastUsedAt != null)
                        _buildDetailRow('Last Used', _formatDateTime(_foundPass!.lastUsedAt!)),
                      
                      if (_foundPass!.lastUsedByUsername != null)
                        _buildDetailRow('Last Used By', _foundPass!.lastUsedByUsername!),
                    ],
                  ),
                ),
              ),
                  ],                  ],
                ),
              ),
            ),
            
            // Reset Button Section - Fixed at bottom
            Container(
              padding: EdgeInsets.fromLTRB(16.0, 16.0, 16.0, MediaQuery.of(context).padding.bottom + 80.0), // Increased padding for navigation bar
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.3),
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                    if (_foundPass != null) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _isResetting ? null : _resetPass,
                          icon: _isResetting 
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Icon(Icons.refresh),
                          label: Text(_isResetting ? 'Resetting...' : 'Reset Pass'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],                      const SizedBox(height: 8),
                    ],
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _clearScan,
                        icon: const Icon(Icons.clear),
                        label: const Text('Clear'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[600],
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
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
      return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateTimeStr;
    }
  }
  
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'used':
        return Colors.blue;
      case 'blocked':
        return Colors.red;
      case 'expired':
        return Colors.orange;
      case 'deleted':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }
  
  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Icons.check_circle;
      case 'used':
        return Icons.history;
      case 'blocked':
        return Icons.block;
      case 'expired':
        return Icons.schedule;
      case 'deleted':
        return Icons.delete;
      default:
        return Icons.help;
    }
  }
}