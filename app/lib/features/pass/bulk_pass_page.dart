import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/pass_theme.dart';
import '../../core/nfc/nfc_service.dart';
import '../../core/services/pass_service.dart';
import '../../core/services/categories_service.dart';
import '../../core/services/toast_service.dart';
import '../../models/category_model.dart';
import '../auth/providers/auth_provider.dart';

class BulkPassPage extends StatefulWidget {
  const BulkPassPage({super.key});

  @override
  State<BulkPassPage> createState() => _BulkPassPageState();
}

class _BulkPassPageState extends State<BulkPassPage>
    with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final _peopleAllowedController = TextEditingController(text: '1');
  final _maxUsesController = TextEditingController();

  // NFC Scanning
  List<String> _scannedUIDs = [];
  List<String> _duplicateUIDs = [];
  bool _isScanning = false;
  bool _isConfigured = false;
  StreamSubscription<NFCEvent>? _nfcSubscription;

  // Pass Configuration
  String _selectedPassType = 'daily';
  String? _selectedCategory;

  // Bulk Creation
  bool _isCreating = false;
  Map<String, dynamic>? _creationResult;
  bool _loadingCategories = true;

  final List<String> _passTypes = ['daily', 'seasonal', 'unlimited'];
  List<CategoryModel> _categories = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeNFC();
    _updateMaxUsesForPassType();
    _loadCategories();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _peopleAllowedController.dispose();
    _maxUsesController.dispose();
    _nfcSubscription?.cancel();
    if (_isScanning) {
      NFCService.stopScan();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Refresh categories when app comes to foreground
      _loadCategories(forceRefresh: true);
    }
  }

  Future<void> _initializeNFC() async {
    try {
      await NFCService.initialize();
      _nfcSubscription = NFCService.nfcEventStream.listen(_handleNFCEvent);
    } catch (e) {
      _showSnackBar('Failed to initialize NFC: $e', isError: true);
    }
  }

  void _handleNFCEvent(NFCEvent event) {
    if (!_isScanning) return;

    if (event.type == NFCEventType.tagDiscovered && event.uid != null) {
      _handleNFCTagScanned(event.uid!);
    } else if (event.type == NFCEventType.error) {
      _showSnackBar('NFC Error: ${event.message}', isError: true);
    }
  }

  void _handleNFCTagScanned(String uid) {
    // Check for duplicates in current batch
    if (_scannedUIDs.contains(uid)) {
      if (!_duplicateUIDs.contains(uid)) {
        setState(() {
          _duplicateUIDs.add(uid);
        });
        _showSnackBar('Duplicate: $uid (already scanned)', isError: true);
        // Provide haptic feedback for duplicate
        HapticFeedback.heavyImpact();
      }
      return;
    }

    setState(() {
      _scannedUIDs.add(uid);
    });

    // Provide haptic feedback for successful scan
    HapticFeedback.lightImpact();

    _showSnackBar(
      'Scanned: $uid (${_scannedUIDs.length} total)',
      isError: false,
    );
  }

  void _updateMaxUsesForPassType() {
    final defaultMaxUses = {'daily': 1, 'seasonal': 11, 'unlimited': 999999};

    _maxUsesController.text = defaultMaxUses[_selectedPassType].toString();
  }

  bool _isUnlimitedPassType() {
    return _selectedPassType == 'unlimited';
  }

  Future<void> _loadCategories({bool forceRefresh = false}) async {
    try {
      setState(() {
        _loadingCategories = true;
      });

      final categories = await CategoriesService.getCategories(
        forceRefresh: forceRefresh,
      );

      setState(() {
        _categories = categories;
        _loadingCategories = false;
        // Set default category to first category
        if (_categories.isNotEmpty) {
          _selectedCategory = _categories.first.name;
        }
      });
    } catch (e) {
      setState(() {
        _loadingCategories = false;
      });
      _showSnackBar('Failed to load categories: $e', isError: true);
    }
  }

  void _configurePassSettings() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isConfigured = true;
    });

    _showSnackBar(
      'Pass settings configured. Ready to scan cards!',
      isError: false,
    );
  }

  void _resetConfiguration() {
    setState(() {
      _isConfigured = false;
      _scannedUIDs.clear();
      _duplicateUIDs.clear();
      _creationResult = null;
    });

    _showSnackBar(
      'Configuration reset. Please configure pass settings again.',
      isError: false,
    );
  }

  Future<void> _startScanning() async {
    try {
      await NFCService.startScan();
      setState(() {
        _isScanning = true;
      });
      _showSnackBar(
        'NFC scanning started. Tap cards to scan them.',
        isError: false,
      );
    } catch (e) {
      _showSnackBar('Error starting NFC scan: $e', isError: true);
    }
  }

  Future<void> _stopScanning() async {
    try {
      await NFCService.stopScan();
      setState(() {
        _isScanning = false;
      });
      _showSnackBar('NFC scanning stopped', isError: false);
    } catch (e) {
      _showSnackBar('Error stopping NFC scan: $e', isError: true);
    }
  }

  void _clearScannedCards() {
    setState(() {
      _scannedUIDs.clear();
      _duplicateUIDs.clear();
      _creationResult = null;
    });
    _showSnackBar('Cleared all scanned cards', isError: false);
  }

  void _removeScannedUID(String uid) {
    setState(() {
      _scannedUIDs.remove(uid);
      // Don't remove from duplicates - only remove from main list
    });
    _showSnackBar('Removed $uid from list', isError: false);
  }

  void _removeDuplicateUID(String uid) {
    setState(() {
      _duplicateUIDs.remove(uid);
      // Don't remove from main list - only remove from duplicates
    });
    _showSnackBar('Removed duplicate $uid from list', isError: false);
  }

  Future<void> _createBulkPasses() async {
    if (_scannedUIDs.isEmpty) {
      _showSnackBar(
        'No cards scanned. Please scan some cards first.',
        isError: true,
      );
      return;
    }

    final user = authProvider.state.user;
    if (user == null) {
      _showSnackBar('User not authenticated', isError: true);
      return;
    }

    setState(() {
      _isCreating = true;
    });

    try {
      // Stop scanning during creation
      if (_isScanning) {
        await _stopScanning();
      }

      // For unlimited passes, use default values
      final isUnlimited = _isUnlimitedPassType();
      final maxUses = isUnlimited ? 999999 : int.parse(_maxUsesController.text);

      final result = await PassService.createBulkPassesNFC(
        uids: _scannedUIDs,
        passType: _selectedPassType,
        category: isUnlimited ? 'All Access' : _selectedCategory!,
        peopleAllowed: int.parse(_peopleAllowedController.text),
        maxUses: maxUses,
      );

      setState(() {
        _creationResult = result;
      });

      _showSnackBar(
        'Bulk creation completed: ${result['created']}/${result['total']} passes created',
        isError: result['created'] == 0,
      );

      // Show detailed results
      _showResultsDialog(result);
    } on PassServiceException catch (e) {
      _showSnackBar('Bulk creation failed: ${e.message}', isError: true);
      // Show detailed error dialog for service exceptions
      _showErrorDialog('Bulk Creation Failed', e.message);
    } catch (e) {
      String errorMessage = 'Unknown error occurred';
      if (e.toString().contains('SocketException')) {
        errorMessage =
            'Network connection failed. Please check your internet connection.';
      } else if (e.toString().contains('TimeoutException')) {
        errorMessage = 'Request timed out. Please try again.';
      } else if (e.toString().contains('FormatException')) {
        errorMessage = 'Invalid response format from server.';
      } else {
        errorMessage = 'Bulk creation error: $e';
      }
      _showSnackBar(errorMessage, isError: true);
      _showErrorDialog('Bulk Creation Error', errorMessage);
    } finally {
      setState(() {
        _isCreating = false;
      });
    }
  }

  void _showResultsDialog(Map<String, dynamic> result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.assessment, color: Color(0xFF2196F3)),
            SizedBox(width: 8),
            Text('Bulk Creation Results'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildResultRow('Total Scanned', result['total'].toString()),
              _buildResultRow(
                'Successfully Created',
                result['created'].toString(),
                color: AppTheme.successColor,
              ),
              _buildResultRow(
                'Duplicates Found',
                result['duplicates'].toString(),
                color: AppTheme.warningColor,
              ),
              _buildResultRow(
                'Errors',
                result['errors']?.length?.toString() ?? '0',
                color: AppTheme.errorColor,
              ),

              if (result['successful_uids']?.isNotEmpty == true) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  'Successfully Created (${result['successful_uids'].length}):',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...result['successful_uids']
                    .take(5)
                    .map<Widget>(
                      (uid) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '✓ $uid',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                if (result['successful_uids'].length > 5)
                  Text('... and ${result['successful_uids'].length - 5} more'),
              ],

              if (result['duplicate_uids']?.isNotEmpty == true) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  'Duplicates Found (${result['duplicate_uids'].length}):',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.warningColor,
                  ),
                ),
                const SizedBox(height: 8),
                ...result['duplicate_uids']
                    .take(5)
                    .map<Widget>(
                      (uid) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '⚠ $uid',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: AppTheme.warningColor,
                          ),
                        ),
                      ),
                    ),
                if (result['duplicate_uids'].length > 5)
                  Text('... and ${result['duplicate_uids'].length - 5} more'),
              ],

              if (result['errors']?.isNotEmpty == true) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  'Errors (${result['errors'].length}):',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.errorColor,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: result['errors']
                          .map<Widget>(
                            (error) => Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.errorColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: AppTheme.errorColor.withOpacity(0.3),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.error,
                                        size: 16,
                                        color: AppTheme.errorColor,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          'UID: ${error['uid'] ?? 'Unknown'}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'monospace',
                                            color: AppTheme.errorColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    error['error'] ?? 'Unknown error',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.errorColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (result['created'] > 0)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _resetConfiguration();
              },
              child: const Text('Create More'),
            ),
        ],
      ),
    );
  }

  Widget _buildResultRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(label, overflow: TextOverflow.ellipsis, maxLines: 1),
          ),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ),
    );
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
        title: Row(
          children: [
            const Icon(Icons.error, color: AppTheme.errorColor),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message),
              const SizedBox(height: 16),
              const Text(
                'Suggestions:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('• Check your network connection'),
              const Text('• Verify the backend server is running'),
              const Text('• Try scanning fewer cards at once'),
              const Text('• Contact support if the problem persists'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _resetConfiguration();
            },
            child: const Text('Reset & Try Again'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bulk Pass Creation'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          if (_isConfigured)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _resetConfiguration,
              tooltip: 'Reset Configuration',
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Step 1: Configuration
                    _buildConfigurationSection(),

                    const SizedBox(height: 24),

                    // Step 2: NFC Scanning
                    _buildNFCScanningSection(),

                    const SizedBox(height: 24),

                    // Step 3: Create Passes
                    _buildResultsSection(),

                    if (_creationResult != null) ...[
                      const SizedBox(height: 24),
                      _buildCreationResultsCard(),
                    ],

                    // Add extra padding at bottom to ensure button is visible
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ),
          // Fixed bottom section for create button
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(child: _buildCreateButton()),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigurationSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.settings,
                  color: _isConfigured
                      ? AppTheme.successColor
                      : AppTheme.primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'Step 1: Configure Pass Settings',
                  style: AppTheme.subheadingStyle.copyWith(fontSize: 16),
                ),
                if (_isConfigured) ...[
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.check_circle,
                    color: AppTheme.successColor,
                    size: 20,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),

            if (!_isConfigured) ...[
              // Pass Type Selection - Always visible
              DropdownButtonFormField<String>(
                value: _selectedPassType,
                decoration: const InputDecoration(
                  labelText: 'Pass Type',
                  border: OutlineInputBorder(),
                ),
                items: _passTypes.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type.toUpperCase()),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedPassType = value!;
                    _updateMaxUsesForPassType();
                    // Reset category selection when changing pass type
                    if (value == 'unlimited') {
                      _selectedCategory = null;
                    }
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a pass type';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              const SizedBox(height: 16),

              // Category with refresh button - Hide for unlimited passes
              if (!_isUnlimitedPassType()) ...[
                Row(
                  children: [
                    Expanded(
                      child: _loadingCategories
                          ? DropdownButtonFormField<String>(
                              decoration: const InputDecoration(
                                labelText: 'Category',
                                border: OutlineInputBorder(),
                                suffixIcon: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                              items: const [],
                              onChanged: null,
                            )
                          : DropdownButtonFormField<String>(
                              value: _selectedCategory,
                              decoration: const InputDecoration(
                                labelText: 'Category',
                                border: OutlineInputBorder(),
                              ),
                              items: _categories.map((category) {
                                final categoryColor =
                                    PassTheme.getCategoryColor(category.name);
                                return DropdownMenuItem(
                                  value: category.name,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: categoryColor,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          category.name,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedCategory = value!;
                                });
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please select a category';
                                }
                                return null;
                              },
                            ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: !_loadingCategories
                          ? () {
                              _loadCategories(forceRefresh: true);
                            }
                          : null,
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Refresh Categories',
                      style: IconButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                        foregroundColor: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
              ],

              // People Allowed
              TextFormField(
                controller: _peopleAllowedController,
                decoration: const InputDecoration(
                  labelText: 'People Allowed',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter number of people allowed';
                  }
                  final number = int.tryParse(value);
                  if (number == null || number <= 0) {
                    return 'Please enter a valid positive number';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Max Uses - Hide for All Access
              if (!_isUnlimitedPassType()) ...[
                TextFormField(
                  controller: _maxUsesController,
                  decoration: InputDecoration(
                    labelText: 'Max Uses',
                    border: const OutlineInputBorder(),
                    helperText: _selectedPassType == 'daily'
                        ? 'Daily passes typically have 1 use'
                        : 'Seasonal passes typically have 11 uses',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter max uses';
                    }
                    final number = int.tryParse(value);
                    if (number == null || number <= 0) {
                      return 'Please enter a valid positive number';
                    }
                    return null;
                  },
                ),
              ],

              // All Access Info
              if (_isUnlimitedPassType()) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.primaryColor.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: AppTheme.primaryColor),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'All Access passes have unlimited usage and no pass type restrictions.',
                          style: TextStyle(color: AppTheme.primaryColor),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _configurePassSettings,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 24,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                  ),
                  child: const Text(
                    'Configure Settings',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ] else ...[
              // Show configured settings
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.successColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Configured Settings:',
                      style: AppTheme.captionStyle.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.successColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (!_isUnlimitedPassType()) ...[
                      Text('Type: ${_selectedPassType.toUpperCase()}'),
                    ] else ...[
                      Text('Type: UNLIMITED'),
                    ],
                    if (!_isUnlimitedPassType()) ...[
                      Text('Category: $_selectedCategory'),
                    ],
                    Text('People Allowed: ${_peopleAllowedController.text}'),
                    if (!_isUnlimitedPassType()) ...[
                      Text('Max Uses: ${_maxUsesController.text}'),
                    ] else ...[
                      Text('Max Uses: Unlimited'),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNFCScanningSection() {
    final isEnabled = _isConfigured;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.nfc,
                  color: isEnabled
                      ? (_isScanning
                            ? AppTheme.warningColor
                            : AppTheme.primaryColor)
                      : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  'Step 2: Scan NFC Cards',
                  style: AppTheme.subheadingStyle.copyWith(
                    fontSize: 16,
                    color: isEnabled ? null : Colors.grey,
                  ),
                ),
                if (_isScanning) ...[
                  const SizedBox(width: 8),
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),

            if (!isEnabled)
              const Text(
                'Please configure pass settings first.',
                style: TextStyle(color: Colors.grey),
              )
            else ...[
              Text(
                _isScanning
                    ? 'NFC scanning is active. Tap cards near your device to scan them.'
                    : 'Start scanning to collect NFC card UIDs for bulk creation.',
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isScanning ? _stopScanning : _startScanning,
                      icon: Icon(
                        _isScanning ? Icons.stop : Icons.nfc,
                        size: 20,
                      ),
                      label: Text(
                        _isScanning ? 'Stop Scanning' : 'Start Scanning',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isScanning
                            ? AppTheme.warningColor
                            : AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 24,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                      ),
                    ),
                  ),
                  if (_scannedUIDs.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _clearScannedCards,
                      icon: const Icon(Icons.clear, size: 20),
                      label: const Text(
                        'Clear',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.errorColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 24,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                      ),
                    ),
                  ],
                ],
              ),

              if (_scannedUIDs.isNotEmpty || _duplicateUIDs.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Scanned Cards',
                            style: AppTheme.captionStyle.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${_scannedUIDs.length} valid, ${_duplicateUIDs.length} duplicates',
                            style: AppTheme.captionStyle,
                          ),
                        ],
                      ),
                      if (_scannedUIDs.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Valid UIDs:',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: AppTheme.successColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: _scannedUIDs
                              .take(10)
                              .map(
                                (uid) => Chip(
                                  label: Text(
                                    uid,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                  backgroundColor: AppTheme.successColor
                                      .withOpacity(0.1),
                                  side: BorderSide(
                                    color: AppTheme.successColor,
                                  ),
                                  deleteIcon: const Icon(Icons.close, size: 16),
                                  onDeleted: () => _removeScannedUID(uid),
                                ),
                              )
                              .toList(),
                        ),
                        if (_scannedUIDs.length > 10)
                          Text('... and ${_scannedUIDs.length - 10} more'),
                      ],
                      if (_duplicateUIDs.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Duplicate UIDs:',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: AppTheme.warningColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: _duplicateUIDs
                              .take(5)
                              .map(
                                (uid) => Chip(
                                  label: Text(
                                    uid,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                  backgroundColor: AppTheme.warningColor
                                      .withOpacity(0.1),
                                  side: BorderSide(
                                    color: AppTheme.warningColor,
                                  ),
                                  deleteIcon: const Icon(Icons.close, size: 16),
                                  onDeleted: () => _removeDuplicateUID(uid),
                                ),
                              )
                              .toList(),
                        ),
                        if (_duplicateUIDs.length > 5)
                          Text('... and ${_duplicateUIDs.length - 5} more'),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultsSection() {
    final canCreate = _isConfigured && _scannedUIDs.isNotEmpty && !_isCreating;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.create,
                  color: canCreate ? AppTheme.primaryColor : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  'Step 3: Create Passes',
                  style: AppTheme.subheadingStyle.copyWith(
                    fontSize: 16,
                    color: canCreate ? null : Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (!_isConfigured)
              const Text(
                'Complete the previous steps to create passes.',
                style: TextStyle(color: Colors.grey),
              )
            else if (_scannedUIDs.isEmpty)
              const Text(
                'Scan some cards first to create passes.',
                style: TextStyle(color: Colors.grey),
              )
            else ...[
              Text(
                'Ready to create ${_scannedUIDs.length} passes with the configured settings.',
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCreateButton() {
    final canCreate = _isConfigured && _scannedUIDs.isNotEmpty && !_isCreating;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: canCreate ? _createBulkPasses : null,
        icon: _isCreating
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.create, size: 20),
        label: Text(
          _isCreating
              ? 'Creating ${_scannedUIDs.length} Passes...'
              : 'Create ${_scannedUIDs.length} Passes',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: canCreate
              ? AppTheme.primaryColor
              : Colors.grey.shade400,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: canCreate ? 4 : 0,
        ),
      ),
    );
  }

  Widget _buildCreationResultsCard() {
    if (_creationResult == null) return const SizedBox.shrink();

    final result = _creationResult!;
    final created = result['created'] ?? 0;
    final total = result['total'] ?? 0;
    final duplicates = result['duplicates'] ?? 0;
    final errors = result['errors'] ?? [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  created > 0 ? Icons.check_circle : Icons.error,
                  color: created > 0
                      ? AppTheme.successColor
                      : AppTheme.errorColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'Creation Results',
                  style: AppTheme.subheadingStyle.copyWith(fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 12),

            _buildResultRow('Total Scanned', total.toString()),
            _buildResultRow(
              'Successfully Created',
              created.toString(),
              color: AppTheme.successColor,
            ),
            _buildResultRow(
              'Duplicates Found',
              duplicates.toString(),
              color: AppTheme.warningColor,
            ),
            _buildResultRow(
              'Errors',
              errors.length.toString(),
              color: AppTheme.errorColor,
            ),

            if (created > 0) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _showResultsDialog(result),
                child: const Text('View Detailed Results'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
