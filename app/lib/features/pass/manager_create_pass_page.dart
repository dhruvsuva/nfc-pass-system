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

class ManagerCreatePassPage extends StatefulWidget {
  const ManagerCreatePassPage({super.key});

  @override
  State<ManagerCreatePassPage> createState() => _ManagerCreatePassPageState();
}

class _ManagerCreatePassPageState extends State<ManagerCreatePassPage>
    with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final _uidController = TextEditingController();
  final _peopleAllowedController = TextEditingController(text: '1');
  final _maxUsesController = TextEditingController();

  String _selectedPassType = 'daily';
  int? _selectedCategory;
  bool _isLoading = false;
  bool _isScanning = false;
  bool _cardScanned = false;
  bool _loadingCategories = true;
  bool _showForm = false;

  final List<String> _passTypes = ['daily', 'seasonal', 'unlimited'];
  List<CategoryModel> _categories = [];

  StreamSubscription<NFCEvent>? _nfcSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeNFC();
    _updateMaxUsesForPassType();
    _loadCategories();

    // Start NFC scan when page loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startInitialNFCScan();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _uidController.dispose();
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

  Future<void> _startInitialNFCScan() async {
    try {
      setState(() {
        _isScanning = true;
      });

      await NFCService.startScan();
    } catch (e) {
      setState(() {
        _isScanning = false;
      });
      _showSnackBar('Error starting NFC scan: $e', isError: true);
    }
  }

  void _handleNFCEvent(NFCEvent event) {
    print(
      '🎯 Manager Create Pass - NFC Event received: ${event.type}, UID: ${event.uid}',
    );
    if (event.type == NFCEventType.tagDiscovered && event.uid != null) {
      print('✅ Tag discovered in Manager Create Pass, setting UID');
      setState(() {
        _uidController.text = event.uid!;
        _cardScanned = true;
        _isScanning = false;
        _showForm = true;
      });

      HapticFeedback.lightImpact();
      _showSnackBar('Card scanned: ${event.uid}', isError: false);
      NFCService.stopScan();
    } else if (event.type == NFCEventType.error) {
      print('❌ NFC Error in Manager Create Pass: ${event.message}');
      setState(() {
        _isScanning = false;
      });
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
        }
      });
    } catch (e) {
      setState(() {
        _loadingCategories = false;
      });
      _showSnackBar('Failed to load categories: $e', isError: true);
    }
  }

  Future<void> _createPass() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Category validation (not needed for unlimited passes)
    if (!_isUnlimitedPassType() && _selectedCategory == null) {
      _showSnackBar('Please select a category', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = authProvider.state.user;
      if (user == null) {
        throw Exception('User not authenticated');
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

      await PassService.createPass(
        uid: _uidController.text.trim(),
        passType: _selectedPassType,
        category: categoryName,
        peopleAllowed: int.parse(_peopleAllowedController.text),
        maxUses: maxUses,
      );

      _showSuccessDialog();
    } catch (e) {
      _showSnackBar('Failed to create pass: $e', isError: true);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: AppTheme.successColor, size: 28),
            const SizedBox(width: 12),
            const Text('Pass Created Successfully'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pass has been created with the following details:'),
            const SizedBox(height: 12),
            _buildDetailRow('UID:', _uidController.text),
            _buildDetailRow('Type:', _selectedPassType.toUpperCase()),
            _buildDetailRow('Category:', _getSelectedCategoryName()),
            _buildDetailRow('People Allowed:', _peopleAllowedController.text),
            _buildDetailRow('Max Uses:', _maxUsesController.text),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              _resetForm();
            },
            child: const Text('Create Another'),
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: AppTheme.bodyStyle.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value, style: AppTheme.bodyStyle)),
        ],
      ),
    );
  }

  void _resetForm() {
    setState(() {
      _uidController.clear();
      _peopleAllowedController.text = '1';
      _selectedPassType = 'daily';
      _selectedCategory = _categories.isNotEmpty ? _categories.first.id : null;
      _cardScanned = false;
      _showForm = false;
      _updateMaxUsesForPassType();
    });
    _startInitialNFCScan();
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
        title: const Text('Create Pass'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: _loadingCategories
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!_showForm) ...[
                    _buildScanningSection(),
                  ] else ...[
                    _buildFormSection(),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildScanningSection() {
    return Column(
      children: [
        const SizedBox(height: 40),
        Icon(
          _isScanning ? Icons.nfc : Icons.nfc_outlined,
          size: 80,
          color: _isScanning ? AppTheme.primaryColor : Colors.grey,
        ),
        const SizedBox(height: 24),
        Text(
          _isScanning ? 'Scanning for NFC Card...' : 'Ready to Scan',
          style: AppTheme.headingStyle.copyWith(
            fontSize: 24,
            color: _isScanning ? AppTheme.primaryColor : Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          _isScanning
              ? 'Hold your NFC card near the device'
              : 'Tap the button below to start scanning',
          style: AppTheme.bodyStyle.copyWith(
            fontSize: 16,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        if (!_isScanning)
          ElevatedButton.icon(
            onPressed: _startInitialNFCScan,
            icon: const Icon(Icons.nfc),
            label: const Text('Start NFC Scan'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              textStyle: const TextStyle(fontSize: 16),
            ),
          ),
        if (_isScanning) const CircularProgressIndicator(),
      ],
    );
  }

  Widget _buildFormSection() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Scanned UID Display
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.nfc, color: AppTheme.successColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Scanned UID',
                          style: AppTheme.captionStyle.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          _uidController.text,
                          style: AppTheme.bodyStyle.copyWith(
                            fontFamily: 'monospace',
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _showForm = false;
                        _cardScanned = false;
                        _uidController.clear();
                      });
                      _startInitialNFCScan();
                    },
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Scan Another Card',
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Pass Type Selection
          Text(
            'Pass Type',
            style: AppTheme.subheadingStyle.copyWith(fontSize: 16),
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
              });
            },
          ),

          const SizedBox(height: 16),

          // Category Selection - Hide for unlimited passes
          if (!_isUnlimitedPassType()) ...[
            Text(
              'Category',
              style: AppTheme.subheadingStyle.copyWith(fontSize: 16),
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

          // People Allowed
          Text(
            'People Allowed',
            style: AppTheme.subheadingStyle.copyWith(fontSize: 16),
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
              hintText: 'Enter number of people allowed',
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter number of people allowed';
              }
              final number = int.tryParse(value);
              if (number == null || number < 1) {
                return 'Please enter a valid number (minimum 1)';
              }
              return null;
            },
          ),

          const SizedBox(height: 16),

          // Max Uses - Hide for unlimited passes
          if (!_isUnlimitedPassType()) ...[
            Text(
              'Max Uses',
              style: AppTheme.subheadingStyle.copyWith(fontSize: 16),
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
                hintText: 'Enter maximum uses',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter maximum uses';
                }
                final number = int.tryParse(value);
                if (number == null || number < 1) {
                  return 'Please enter a valid number (minimum 1)';
                }
                return null;
              },
            ),
          ],

          const SizedBox(height: 32),

          // Create Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _createPass,
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
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Create Pass'),
            ),
          ),
        ],
      ),
    );
  }
}
