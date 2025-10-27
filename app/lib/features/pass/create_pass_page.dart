import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/pass_theme.dart';
import '../../core/nfc/nfc_service.dart';
import '../../core/services/pass_service.dart';
import '../../core/services/categories_service.dart';
import '../../core/services/toast_service.dart';
import '../../models/pass_model.dart';
import '../../models/category_model.dart';
import '../auth/providers/auth_provider.dart';

class CreatePassPage extends StatefulWidget {
  const CreatePassPage({super.key});

  @override
  State<CreatePassPage> createState() => _CreatePassPageState();
}

class _CreatePassPageState extends State<CreatePassPage>
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
  String? _errorMessage;

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

    // Start NFC scan immediately
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
      _showError('Failed to initialize NFC: $e');
    }
  }

  Future<void> _startInitialNFCScan() async {
    try {
      setState(() {
        _isScanning = true;
        _errorMessage = null;
      });

      await NFCService.startScan();
    } catch (e) {
      setState(() {
        _isScanning = false;
        _errorMessage = 'Error starting NFC scan: $e';
      });
    }
  }

  void _handleNFCEvent(NFCEvent event) {
    print(
      '🎯 Create Pass - NFC Event received: ${event.type}, UID: ${event.uid}',
    );

    if (event.type == NFCEventType.tagDiscovered && event.uid != null) {
      print('✅ Tag discovered in Create Pass, setting UID');

      // Validate UID format
      if (!_isValidUID(event.uid!)) {
        setState(() {
          _isScanning = false;
          _errorMessage =
              'Invalid UID format. UID must be 4-128 alphanumeric characters.';
        });
        _showError('Invalid UID format. Please use a different card.');
        return;
      }

      setState(() {
        _uidController.text = event.uid!;
        _cardScanned = true;
        _isScanning = false;
        _showForm = true;
        _errorMessage = null;
      });

      // Provide haptic feedback
      HapticFeedback.lightImpact();

      _showSuccess('Card scanned successfully: ${event.uid}');

      // Stop scanning
      NFCService.stopScan();
    } else if (event.type == NFCEventType.error) {
      print('❌ NFC Error in Create Pass: ${event.message}');
      setState(() {
        _isScanning = false;
        _errorMessage = 'NFC Error: ${event.message}';
      });
      _showError('NFC Error: ${event.message}');
    }
  }

  bool _isValidUID(String uid) {
    // UID should be alphanumeric and between 4-128 characters
    return RegExp(r'^[a-zA-Z0-9]{4,128}$').hasMatch(uid);
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
      _errorMessage = null;
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
        _errorMessage = 'Failed to load categories: $e';
      });
      _showError('Failed to load categories: $e');
    }
  }

  Future<void> _createPass() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_cardScanned || _uidController.text.trim().isEmpty) {
      _showError('Please scan a card first');
      return;
    }

    final user = authProvider.state.user;
    if (user == null) {
      _showError('User not authenticated. Please login again.');
      return;
    }

    // Validate UID format
    if (!_isValidUID(_uidController.text.trim())) {
      _showError(
        'Invalid UID format. UID must be 4-128 alphanumeric characters.',
      );
      return;
    }

    // Get the selected category (not needed for unlimited passes)
    String categoryName;
    if (_isUnlimitedPassType()) {
      categoryName = 'All Access'; // Default category for unlimited passes
    } else {
      if (_selectedCategory == null) {
        _showError('Please select a category');
        return;
      }
      final selectedCategoryModel = _categories.firstWhere(
        (cat) => cat.id == _selectedCategory,
      );
      categoryName = selectedCategoryModel.name;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Check if UID already exists before creating
      final existingPass = await PassService.searchPassByUID(
        _uidController.text.trim(),
      );
      if (existingPass != null) {
        _showDuplicateErrorDialog(
          _uidController.text.trim(),
          existingPass.passId,
        );
        return;
      }

      // For unlimited passes, use default values
      final isUnlimited = _isUnlimitedPassType();
      final passType = _selectedPassType;
      final maxUses = isUnlimited ? 999999 : int.parse(_maxUsesController.text);

      // Create pass using PassService
      final pass = await PassService.createPass(
        uid: _uidController.text.trim(),
        passType: passType,
        category: categoryName,
        peopleAllowed: int.parse(_peopleAllowedController.text),
        maxUses: maxUses,
      );

      _showSuccess('Pass created successfully!');

      // Show success dialog
      _showSuccessDialog(pass);
    } on PassServiceException catch (e) {
      // Handle specific error types
      if (e.code == 'DUPLICATE_UID') {
        _showDuplicateErrorDialog(_uidController.text.trim(), e.existingPassId);
      } else if (e.isNetworkError) {
        _showError(
          'Network error. Please check your connection and try again.',
        );
      } else if (e.isClientError) {
        _showError('Invalid data: ${e.message}');
      } else if (e.isServerError) {
        _showError('Server error. Please try again later.');
      } else {
        _showError('Failed to create pass: ${e.message}');
      }
    } catch (e) {
      _showError('Unexpected error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showDuplicateErrorDialog(String uid, String? existingPassId) {
    showDialog(
      context: context,
      useSafeArea: true,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error, color: AppTheme.errorColor),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Card Already Registered',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.9,
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This card is already registered in the system.',
                  style: AppTheme.bodyStyle.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'UID: $uid',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 14,
                        ),
                      ),
                      if (existingPassId != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Pass ID: $existingPassId',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Each NFC card can only be registered once. Please use a different card to create a new pass.',
                  style: AppTheme.bodyStyle,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
          if (existingPassId != null)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _showInfo('Pass details: $existingPassId');
              },
              child: const Text('View Details'),
            ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _resetForm();
            },
            child: const Text('Scan Different Card'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(PassModel pass) {
    final categoryColor = PassTheme.getCategoryColor(pass.category);

    showDialog(
      context: context,
      useSafeArea: true,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: AppTheme.successColor),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Pass Created Successfully',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.9,
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Your pass has been created and is ready to use!'),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),

                // Pass Details
                _buildDetailRow('UID', pass.uid, isMonospace: true),
                _buildDetailRow('Pass ID', pass.passId, isMonospace: true),
                _buildDetailRow('Type', pass.passType.toUpperCase()),
                _buildDetailRow(
                  'Category',
                  pass.category,
                  categoryColor: categoryColor,
                ),
                _buildDetailRow(
                  'People Allowed',
                  pass.peopleAllowed.toString(),
                ),
                _buildDetailRow('Max Uses', pass.maxUses.toString()),
                _buildDetailRow('Status', pass.status.toUpperCase()),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _resetForm();
            },
            child: const Text('Create Another'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // Go back to previous screen
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    bool isMonospace = false,
    Color? categoryColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: categoryColor != null
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: categoryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: categoryColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      value,
                      style: TextStyle(
                        color: categoryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                : Text(
                    value,
                    style: TextStyle(
                      fontFamily: isMonospace ? 'monospace' : null,
                      fontSize: isMonospace ? 12 : null,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _resetForm() {
    setState(() {
      _cardScanned = false;
      _showForm = false;
      _uidController.clear();
      _peopleAllowedController.text = '1';
      _selectedPassType = 'daily';
      _selectedCategory = _categories.isNotEmpty ? _categories.first.id : null;
      _errorMessage = null;
    });
    _updateMaxUsesForPassType();
    _startInitialNFCScan();
  }

  void _showError(String message) {
    ToastService.showError(message);
  }

  void _showSuccess(String message) {
    ToastService.showSuccess(message);
  }

  void _showInfo(String message) {
    ToastService.showInfo(message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Pass'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          if (_showForm)
            IconButton(
              onPressed: _resetForm,
              icon: const Icon(Icons.refresh),
              tooltip: 'Reset Form',
            ),
        ],
      ),
      body: _showForm ? _buildPassForm() : _buildNFCScanPrompt(),
    );
  }

  Widget _buildNFCScanPrompt() {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // NFC Icon with animation
              AnimatedContainer(
                duration: const Duration(milliseconds: 1000),
                child: Icon(
                  Icons.nfc,
                  size: 80,
                  color: _isScanning ? AppTheme.primaryColor : Colors.grey,
                ),
              ),
              const SizedBox(height: 24),

              // Title
              Text(
                'Tap Card to Scan',
                style: AppTheme.headingStyle.copyWith(fontSize: 24),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Status message
              if (_isScanning) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                const Text(
                  'Hold your device near an NFC card to scan its UID.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ] else if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.errorColor.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error, color: AppTheme.errorColor, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: AppTheme.errorColor),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _startInitialNFCScan,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry Scan'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                  ),
                ),
              ] else ...[
                const Text(
                  'Please wait while we prepare NFC scanning...',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],

              const SizedBox(height: 32),

              // Cancel button
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPassForm() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // UID Display Section
                  _buildUIDDisplaySection(),

                  const SizedBox(height: 24),

                  // Pass Configuration
                  _buildPassConfigSection(),

                  const SizedBox(height: 24), // Reduced from 32
                ],
              ),
            ),
          ),
        ),
        // Create Button - Fixed at bottom
        Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
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
    );
  }

  Widget _buildUIDDisplaySection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.nfc, color: Color(0xFF2196F3)),
                const SizedBox(width: 8),
                Text(
                  'Scanned Card',
                  style: AppTheme.subheadingStyle.copyWith(fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.successColor.withOpacity(0.1),
                border: Border.all(color: AppTheme.successColor),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: AppTheme.successColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Card Scanned Successfully',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'UID: ${_uidController.text}',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      _resetForm();
                    },
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Scan Different Card',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPassConfigSection() {
    final isEnabled = _cardScanned;

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
                  Icons.settings,
                  color: isEnabled ? AppTheme.primaryColor : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  'Configure Pass Details',
                  style: AppTheme.subheadingStyle.copyWith(
                    fontSize: 16,
                    color: isEnabled ? null : Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (!isEnabled)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Please scan a card first to configure the pass.',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else ...[
              // Pass Type Selection - Always visible
              DropdownButtonFormField<String>(
                value: _selectedPassType,
                decoration: const InputDecoration(
                  labelText: 'Pass Type *',
                  border: OutlineInputBorder(),
                  helperText: 'Select the type of pass to create',
                ),
                items: _passTypes.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type.toUpperCase()),
                  );
                }).toList(),
                onChanged: isEnabled
                    ? (value) {
                        setState(() {
                          _selectedPassType = value!;
                          _updateMaxUsesForPassType();
                          // Reset category selection when changing pass type
                          if (value == 'unlimited') {
                            _selectedCategory = null;
                          }
                        });
                      }
                    : null,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a pass type';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Category Selection - Hide for unlimited passes
              if (!_isUnlimitedPassType()) ...[
                Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: _loadingCategories
                          ? DropdownButtonFormField<int>(
                              decoration: const InputDecoration(
                                labelText: 'Category *',
                                border: OutlineInputBorder(),
                                suffixIcon: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                              items: [],
                              onChanged: null,
                            )
                          : DropdownButtonFormField<int>(
                              value: _selectedCategory,
                              decoration: const InputDecoration(
                                labelText: 'Category *',
                                border: OutlineInputBorder(),
                                helperText: 'Select the category for this pass',
                              ),
                              items: _categories.map((category) {
                                final categoryColor =
                                    PassTheme.getCategoryColor(category.name);
                                return DropdownMenuItem(
                                  value: category.id,
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
                              onChanged: isEnabled
                                  ? (value) {
                                      setState(() {
                                        _selectedCategory = value;
                                        // Reset pass type to daily when switching categories
                                        _selectedPassType = 'daily';
                                        _updateMaxUsesForPassType();
                                      });
                                    }
                                  : null,
                              validator: (value) {
                                if (value == null) {
                                  return 'Please select a category';
                                }
                                return null;
                              },
                            ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: isEnabled && !_loadingCategories
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
                  labelText: 'People Allowed *',
                  border: OutlineInputBorder(),
                  helperText: 'Number of people allowed with this pass (1-100)',
                ),
                keyboardType: TextInputType.number,
                enabled: isEnabled,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(3),
                ],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter number of people allowed';
                  }
                  final number = int.tryParse(value.trim());
                  if (number == null || number < 1 || number > 100) {
                    return 'Please enter a valid number (1-100)';
                  }
                  return null;
                },
              ),

              // Max Uses - Hide for unlimited passes
              if (!_isUnlimitedPassType()) ...[
                const SizedBox(height: 16),

                TextFormField(
                  controller: _maxUsesController,
                  decoration: InputDecoration(
                    labelText: 'Max Uses *',
                    border: const OutlineInputBorder(),
                    helperText: _selectedPassType == 'seasonal'
                        ? 'Number of times this pass can be used (default: 11 for seasonal)'
                        : 'Number of times this pass can be used (default: 1 for daily)',
                  ),
                  keyboardType: TextInputType.number,
                  enabled: isEnabled,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3),
                  ],
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter max uses';
                    }
                    final number = int.tryParse(value.trim());
                    if (number == null || number < 1 || number > 100) {
                      return 'Please enter a valid number (1-100)';
                    }
                    return null;
                  },
                ),
              ] else ...[
                // Show info for All Access
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade600),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'All Access passes have unlimited usage and no pass type restrictions.',
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontSize: 14,
                          ),
                        ),
                      ),
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

  Widget _buildCreateButton() {
    // For unlimited passes, we don't need category selection
    final isEnabled =
        _cardScanned &&
        !_isLoading &&
        (_isUnlimitedPassType() || _selectedCategory != null);

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: isEnabled ? _createPass : null,
        icon: _isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.add),
        label: Text(_isLoading ? 'Creating Pass...' : 'Create Pass'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}
