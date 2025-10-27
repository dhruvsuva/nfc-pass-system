import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/pass_theme.dart';
import '../../core/nfc/nfc_service.dart';
import '../../core/providers/nfc_provider.dart';
import '../../core/services/pass_service.dart';
import '../../core/services/categories_service.dart';
import '../../core/services/toast_service.dart';
import '../../models/pass_model.dart';
import '../../models/category_model.dart';
import '../auth/providers/auth_provider.dart';

class ManagerBulkCreatePage extends StatefulWidget {
  const ManagerBulkCreatePage({super.key});

  @override
  State<ManagerBulkCreatePage> createState() => _ManagerBulkCreatePageState();
}

class _ManagerBulkCreatePageState extends State<ManagerBulkCreatePage>
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
  int? _selectedCategory;

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
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
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
    print(
      '🎯 Manager Bulk Create - NFC Event received: ${event.type}, UID: ${event.uid}',
    );
    if (event.type == NFCEventType.tagDiscovered && event.uid != null) {
      final uid = event.uid!;

      if (_scannedUIDs.contains(uid)) {
        print('⚠️ Duplicate UID detected: $uid');
        if (!_duplicateUIDs.contains(uid)) {
          setState(() {
            _duplicateUIDs.add(uid);
          });
        }
        HapticFeedback.heavyImpact();
        _showSnackBar('Duplicate card: $uid', isError: true);
      } else {
        print('✅ New UID added: $uid');
        setState(() {
          _scannedUIDs.add(uid);
          _duplicateUIDs.remove(uid);
        });
        HapticFeedback.lightImpact();
        _showSnackBar(
          'Card added: $uid (${_scannedUIDs.length} total)',
          isError: false,
        );
      }
    } else if (event.type == NFCEventType.error) {
      print('❌ NFC Error in Manager Bulk Create: ${event.message}');
      _showSnackBar('NFC Error: ${event.message}', isError: true);
    }
  }

  void _updateMaxUsesForPassType() {
    final defaultMaxUses = {'daily': 1, 'seasonal': 11, 'unlimited': 999999};

    _maxUsesController.text = defaultMaxUses[_selectedPassType].toString();
  }

  String _getSelectedCategoryName() {
    if (_selectedCategory == null || _categories.isEmpty) {
      return '';
    }

    final category = _categories.firstWhere(
      (cat) => cat.id == _selectedCategory,
      orElse: () => CategoryModel(
        id: 0,
        name: '',
        colorCode: '',
        description: '',
        createdAt: '',
        updatedAt: '',
      ),
    );

    return category.name;
  }

  bool _isUnlimitedPassType() {
    return _selectedPassType == 'unlimited';
  }

  Future<void> _loadCategories({bool forceRefresh = false}) async {
    if (!forceRefresh && _categories.isNotEmpty) {
      setState(() {
        _loadingCategories = false;
      });
      return;
    }

    setState(() {
      _loadingCategories = true;
    });

    try {
      final categories = await CategoriesService.getCategories();
      setState(() {
        _categories = categories;
        _loadingCategories = false;

        // Auto-select first category if none selected
        if (_selectedCategory == null && categories.isNotEmpty) {
          _selectedCategory = categories.first.id;
          _checkConfiguration();
        }
      });
    } catch (e) {
      setState(() {
        _loadingCategories = false;
      });
      _showSnackBar('Failed to load categories: $e', isError: true);
    }
  }

  void _checkConfiguration() {
    setState(() {
      // For unlimited passes, we don't need category selection
      final needsCategory = !_isUnlimitedPassType();
      _isConfigured =
          (!needsCategory || _selectedCategory != null) &&
          _peopleAllowedController.text.isNotEmpty &&
          _maxUsesController.text.isNotEmpty;
    });
  }

  Future<void> _startScanning() async {
    try {
      setState(() {
        _isScanning = true;
      });

      await NFCService.startScan();
      _showSnackBar(
        'NFC scanning started. Hold cards near device.',
        isError: false,
      );
    } catch (e) {
      setState(() {
        _isScanning = false;
      });
      _showSnackBar('Error starting NFC scan: $e', isError: true);
    }
  }

  Future<void> _stopScanning() async {
    try {
      await NFCService.stopScan();
      setState(() {
        _isScanning = false;
      });
      _showSnackBar('NFC scanning stopped.', isError: false);
    } catch (e) {
      _showSnackBar('Error stopping NFC scan: $e', isError: true);
    }
  }

  void _removeScannedUID(String uid) {
    setState(() {
      _scannedUIDs.remove(uid);
      _duplicateUIDs.remove(uid);
    });
    _showSnackBar('Removed $uid from list', isError: false);
  }

  void _clearAllScannedUIDs() {
    setState(() {
      _scannedUIDs.clear();
      _duplicateUIDs.clear();
    });
    _showSnackBar('Cleared all scanned cards', isError: false);
  }

  Future<void> _createBulkPasses() async {
    if (_scannedUIDs.isEmpty) {
      _showSnackBar(
        'No cards scanned. Please scan some cards first.',
        isError: true,
      );
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Category validation (not needed for unlimited passes)
    if (!_isUnlimitedPassType() && _selectedCategory == null) {
      _showSnackBar('Please select a category', isError: true);
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

      // Get the category name (not needed for unlimited passes)
      String categoryName;
      if (_isUnlimitedPassType()) {
        categoryName = 'All Access'; // Default category for unlimited passes
      } else {
        final selectedCategoryModel = _categories.firstWhere(
          (cat) => cat.id == _selectedCategory,
        );
        categoryName = selectedCategoryModel.name;
      }

      // For unlimited passes, use default values
      final isUnlimited = _isUnlimitedPassType();
      final maxUses = isUnlimited ? 999999 : int.parse(_maxUsesController.text);

      final result = await PassService.createBulkPassesNFC(
        uids: _scannedUIDs,
        passType: _selectedPassType,
        category: categoryName,
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
    } catch (e) {
      _showSnackBar('Bulk creation failed: $e', isError: true);
    } finally {
      setState(() {
        _isCreating = false;
      });
    }
  }

  void _showResultsDialog(Map<String, dynamic> result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              result['created'] > 0 ? Icons.check_circle : Icons.error,
              color: result['created'] > 0
                  ? AppTheme.successColor
                  : AppTheme.errorColor,
              size: 28,
            ),
            const SizedBox(width: 12),
            const Text('Bulk Creation Results'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildResultRow('Total Cards:', '${result['total']}'),
              _buildResultRow(
                'Successfully Created:',
                '${result['created']}',
                color: result['created'] > 0 ? AppTheme.successColor : null,
              ),
              _buildResultRow(
                'Duplicates:',
                '${result['duplicates']}',
                color: result['duplicates'] > 0 ? AppTheme.warningColor : null,
              ),
              _buildResultRow(
                'Errors:',
                '${result['errors']?.length ?? 0}',
                color: (result['errors']?.length ?? 0) > 0
                    ? AppTheme.errorColor
                    : null,
              ),

              if (result['errors'] != null && result['errors'].isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Error Details:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 100,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: ListView.builder(
                    itemCount: result['errors'].length,
                    itemBuilder: (context, index) {
                      final error = result['errors'][index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Text(
                          '${error['uid']}: ${error['error']}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              _resetForNewBatch();
            },
            child: const Text('Create Another Batch'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Return to dashboard
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Widget _buildResultRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTheme.bodyStyle.copyWith(fontWeight: FontWeight.w600),
          ),
          Text(
            value,
            style: AppTheme.bodyStyle.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _resetForNewBatch() {
    setState(() {
      _scannedUIDs.clear();
      _duplicateUIDs.clear();
      _creationResult = null;
      _isScanning = false;
    });
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
        title: const Text('Bulk Create Passes'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          if (_scannedUIDs.isNotEmpty)
            IconButton(
              onPressed: _clearAllScannedUIDs,
              icon: const Icon(Icons.clear_all),
              tooltip: 'Clear All',
            ),
        ],
      ),
      body: _loadingCategories
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildConfigurationSection(),
                    const SizedBox(height: 24),
                    _buildScanningSection(),
                    const SizedBox(height: 24),
                    _buildScannedCardsSection(),
                    const SizedBox(height: 24),
                    _buildCreateSection(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildConfigurationSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _isConfigured ? Icons.check_circle : Icons.settings,
                  color: _isConfigured
                      ? AppTheme.successColor
                      : AppTheme.primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'Step 1: Configure Pass Settings',
                  style: AppTheme.subheadingStyle.copyWith(fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Pass Type Selection
            Text(
              'Pass Type',
              style: AppTheme.subheadingStyle.copyWith(fontSize: 14),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedPassType,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
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
                  _checkConfiguration();
                });
              },
            ),

            const SizedBox(height: 16),

            // Category Selection - Hide for unlimited passes
            if (!_isUnlimitedPassType()) ...[
              Text(
                'Category',
                style: AppTheme.subheadingStyle.copyWith(fontSize: 14),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                value: _selectedCategory,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                items: _categories.map((category) {
                  return DropdownMenuItem(
                    value: category.id,
                    child: Row(
                      children: [
                        Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: Color(
                              int.parse(
                                '0xFF${category.colorCode.replaceAll('#', '')}',
                              ),
                            ),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(category.name),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value;
                    _checkConfiguration();
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return 'Please select a category';
                  }
                  return null;
                },
              ),
            ],

            const SizedBox(height: 16),

            Row(
              children: [
                // People Allowed
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'People Allowed',
                        style: AppTheme.subheadingStyle.copyWith(fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _peopleAllowedController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        onChanged: (_) => _checkConfiguration(),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          final number = int.tryParse(value);
                          if (number == null || number < 1) {
                            return 'Min 1';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 16),

                // Max Uses - Hide for unlimited passes
                if (!_isUnlimitedPassType())
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Max Uses',
                          style: AppTheme.subheadingStyle.copyWith(
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _maxUsesController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          onChanged: (_) => _checkConfiguration(),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Required';
                            }
                            final number = int.tryParse(value);
                            if (number == null || number < 1) {
                              return 'Min 1';
                            }
                            return null;
                          },
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

  Widget _buildScanningSection() {
    final canScan = _isConfigured && !_isCreating;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _isScanning ? Icons.nfc : Icons.nfc_outlined,
                  color: canScan
                      ? (_isScanning
                            ? AppTheme.successColor
                            : AppTheme.primaryColor)
                      : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  'Step 2: Scan NFC Cards',
                  style: AppTheme.subheadingStyle.copyWith(
                    fontSize: 16,
                    color: canScan ? null : Colors.grey,
                  ),
                ),
                const Spacer(),
                if (_scannedUIDs.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '${_scannedUIDs.length} cards',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            if (!_isConfigured)
              const Text(
                'Complete the configuration above to start scanning.',
                style: TextStyle(color: Colors.grey),
              )
            else ...[
              Text(
                _isScanning
                    ? 'Hold NFC cards near the device to scan them.'
                    : 'Tap the button below to start scanning NFC cards.',
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: canScan
                          ? (_isScanning ? _stopScanning : _startScanning)
                          : null,
                      icon: Icon(_isScanning ? Icons.stop : Icons.nfc),
                      label: Text(
                        _isScanning ? 'Stop Scanning' : 'Start Scanning',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isScanning
                            ? AppTheme.errorColor
                            : AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildScannedCardsSection() {
    if (_scannedUIDs.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.credit_card, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Scanned Cards (${_scannedUIDs.length})',
                  style: AppTheme.subheadingStyle.copyWith(fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Container(
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.builder(
                itemCount: _scannedUIDs.length,
                itemBuilder: (context, index) {
                  final uid = _scannedUIDs[index];
                  final isDuplicate = _duplicateUIDs.contains(uid);

                  return ListTile(
                    dense: true,
                    leading: Icon(
                      Icons.nfc,
                      color: isDuplicate
                          ? AppTheme.warningColor
                          : AppTheme.primaryColor,
                      size: 20,
                    ),
                    title: Text(
                      uid,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 14,
                        color: isDuplicate ? AppTheme.warningColor : null,
                      ),
                    ),
                    subtitle: isDuplicate
                        ? const Text(
                            'Duplicate detected',
                            style: TextStyle(fontSize: 12),
                          )
                        : null,
                    trailing: IconButton(
                      onPressed: () => _removeScannedUID(uid),
                      icon: const Icon(Icons.remove_circle_outline, size: 20),
                      color: AppTheme.errorColor,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateSection() {
    final canCreate = _isConfigured && _scannedUIDs.isNotEmpty && !_isCreating;

    return Card(
      elevation: 2,
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
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: canCreate ? _createBulkPasses : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isCreating
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text('Creating ${_scannedUIDs.length} Passes...'),
                          ],
                        )
                      : Text('Create ${_scannedUIDs.length} Passes'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
