import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../core/nfc/nfc_service.dart';
import '../../core/services/pass_service.dart';
import '../../core/utils/category_utils.dart';

import '../../core/widgets/verification_result_card.dart';
import '../../core/widgets/session_multi_use_popup_ultra_compact.dart';
import '../auth/providers/auth_provider.dart';
import '../../models/pass_model.dart';

class VerifyPage extends StatefulWidget {
  const VerifyPage({super.key});

  @override
  State<VerifyPage> createState() => _VerifyPageState();
}

class _VerifyPageState extends State<VerifyPage> with WidgetsBindingObserver {
  StreamSubscription<NFCEvent>? _nfcSubscription;
  bool _isScanning = false;
  bool _isInitialized = false;
  OverlayEntry? _currentPopup;
  Timer? _autoCloseTimer;
  bool _isDialogShowing = false;
  bool _isVerifying = false; // Track verification in progress
  OverlayEntry? _loadingOverlay; // Loading overlay

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeNFC();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _nfcSubscription?.cancel();
    _closeCurrentPopup();
    _hideLoadingIndicator();
    _autoCloseTimer?.cancel();
    if (_isScanning) {
      NFCService.stopScan();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && _isScanning) {
      NFCService.stopScan();
    }
  }

  Future<void> _initializeNFC() async {
    try {
      await NFCService.initialize();
      _nfcSubscription = NFCService.nfcEventStream.listen(_handleNFCEvent);
      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      print('Failed to initialize NFC: $e');
    }
  }

  void _handleNFCEvent(NFCEvent event) {
    print('🎯 VerifyPage - NFC Event: ${event.type}, UID: ${event.uid}');

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
          _handleTagDiscovered(event.uid!);
        }
        break;

      case NFCEventType.error:
        setState(() {
          _isScanning = false;
        });
        _showErrorToast(event.message ?? 'NFC Error');
        break;
    }
  }

  void _handleTagDiscovered(String uid) {
    print('🏷️ Tag discovered: $uid');

    // Prevent multiple taps during verification
    if (_isVerifying) {
      print('⚠️ Verification already in progress, ignoring tap');
      return;
    }

    // Prevent multiple taps if dialog is already showing
    if (_isDialogShowing) {
      print('⚠️ Dialog already showing, ignoring tap');
      return;
    }

    // Prevent multiple taps if popup is already showing
    if (_currentPopup != null) {
      print('⚠️ Popup already showing, closing previous and showing new');
      _closeCurrentPopup();
      // Add small delay to ensure cleanup is complete
      Future.delayed(const Duration(milliseconds: 100), () {
        _processNFCTap(uid);
      });
      return;
    }

    _processNFCTap(uid);
  }

  void _processNFCTap(String uid) {
    setState(() {
      _isScanning = false;
      _isVerifying = true;
    });

    // Close any existing popup before showing new one
    _closeCurrentPopup();

    // Show immediate loading indicator
    _showLoadingIndicator();

    // Verify the pass and show popup
    _verifyPass(uid);
  }

  Future<void> _verifyPass(String uid) async {
    // Additional safety check - don't proceed if dialog is already showing
    if (_isDialogShowing) {
      _hideLoadingIndicator();
      setState(() {
        _isVerifying = false;
      });
      return;
    }

    try {
      // Disable auto-navigation during verification
      // HttpInterceptor.disableAutoNavigation(); // Method not available

      // First, get pass details to check category
      final passDetails = await PassService.searchPassByUID(uid);

      // Check category restriction for bouncer
      final currentUser = authProvider.state.user;
      if (currentUser?.role == 'bouncer' &&
          currentUser?.assignedCategory != null) {
        if (passDetails?.category != null) {
          final bouncerCategory = currentUser!.assignedCategory!;
          final passCategory = passDetails!.category;

          debugPrint(
            '🔍 Category Check - Bouncer: "$bouncerCategory" | Pass: "$passCategory"',
          );

          // Use utility to check if bouncer can verify this pass
          if (!CategoryUtils.canBouncerVerifyPass(
            bouncerCategory,
            passCategory,
          )) {
            debugPrint(
              '❌ Category mismatch - Bouncer: "$bouncerCategory" | Pass: "$passCategory"',
            );
            _showCategoryRestrictionDialog(uid, passCategory, bouncerCategory);
            return;
          } else {
            debugPrint(
              '✅ Category match - Bouncer: "$bouncerCategory" | Pass: "$passCategory"',
            );
          }
        } else {
          debugPrint('⚠️ Pass category is null for UID: $uid');
        }
      } else {
        debugPrint(
          '⚠️ Bouncer category check skipped - Role: ${currentUser?.role}, AssignedCategory: ${currentUser?.assignedCategory}',
        );
      }

      var result = await PassService.verifyPass(
        uid: uid,
        gateId: 'GATE001',
        scannedBy: authProvider.state.user?.id ?? 0,
      );

      // Fix the used_count in the result by using the search data
      if (result.pass != null && passDetails != null) {
        // Create a new PassModel with the correct usedCount
        final correctedPass = PassModel(
          id: result.pass!.id,
          uid: result.pass!.uid,
          passId: result.pass!.passId,
          passType: result.pass!.passType,
          category: result.pass!.category,
          peopleAllowed: result.pass!.peopleAllowed,
          status: result.pass!.status,
          createdBy: result.pass!.createdBy,
          createdAt: result.pass!.createdAt,
          updatedAt: result.pass!.updatedAt,
          createdByUsername: result.pass!.createdByUsername,
          maxUses: result.pass!.maxUses,
          usedCount:
              passDetails.usedCount, // Use the correct usedCount from search
          remainingUses: result.pass!.remainingUses,
          lastScanAt: result.pass!.lastScanAt,
          lastScanBy: result.pass!.lastScanBy,
          lastUsedAt: result.pass!.lastUsedAt,
          lastUsedBy: result.pass!.lastUsedBy,
          lastUsedByUsername: result.pass!.lastUsedByUsername,
        );

        // Create a new PassVerificationResult with the corrected pass
        result = result.copyWith(pass: correctedPass);
      }

      // Check result status and show appropriate dialog
      if (result.status == 'invalid' &&
          result.message.toLowerCase().contains('not found')) {
        _showPasswordNotFoundDialog(uid);
      } else if (result.status == 'used' ||
          (result.status == 'invalid' &&
              result.message.toLowerCase().contains('already used'))) {
        _showPassAlreadyUsedDialog(uid, result);
      } else if (result.status == 'blocked') {
        _showPassBlockedDialog(uid, result);
      } else if (result.status == 'prompt_multi_use' &&
          result.promptToken != null) {
        // Session pass - 15 minute rule triggered, show multi-use popup
        print('🎯 Session Pass - 15 minute rule triggered!');
        print('🎯 Pass Type: ${result.pass?.passType}');
        print('🎯 Remaining Uses: ${result.remainingUses}');
        print('🎯 Last Used: ${result.lastUsedAt}');
        print('🎯 Prompt Token: ${result.promptToken}');
        _showSessionMultiUsePopup(uid, result);
      } else if (result.status == 'prompt_seasonal_multi_use' &&
          result.promptToken != null) {
        // Seasonal pass - 15 minute rule triggered, show multi-use popup
        print('🎯 Seasonal Pass - 15 minute rule triggered!');
        print('🎯 Pass Type: ${result.pass?.passType}');
        print('🎯 Remaining Uses: ${result.remainingUses}');
        print('🎯 Last Used: ${result.lastUsedAt}');
        print('🎯 Prompt Token: ${result.promptToken}');
        _showSeasonalMultiUsePopup(uid, result);
      } else if (result.pass?.passType == 'session' &&
          result.status == 'valid') {
        // Session pass first time use - allow immediately
        print('🎯 Session Pass - First time use!');
        print('🎯 Pass Type: ${result.pass?.passType}');
        print('🎯 Max Uses: ${result.pass?.maxUses}');
        print('🎯 Remaining Uses: ${result.remainingUses}');
        _showVerificationPopup(uid, result);
      } else {
        // Show popup with result for other cases (valid, expired, etc.)
        _showVerificationPopup(uid, result);
      }
    } catch (e) {
      print('Verification error: $e');

      // Check if error message indicates specific cases
      String errorMessage = e.toString().toLowerCase();
      debugPrint('Verification error message: $errorMessage');

      if (errorMessage.contains('not found') ||
          errorMessage.contains('invalid') ||
          errorMessage.contains('pass_not_found')) {
        _showPasswordNotFoundDialog(uid);
      } else if (errorMessage.contains('pass is blocked') ||
          (errorMessage.contains('blocked') &&
              !errorMessage.contains('not found'))) {
        // Only show blocked dialog if it's specifically about a blocked pass, not a general error
        final dummyResult = PassVerificationResult(
          success: false,
          status: 'blocked',
          message: 'This pass is blocked',
          pass: null,
          additionalData: {},
          promptToken: null,
          remainingUses: 0,
          lastUsedAt: null,
        );
        _showPassBlockedDialog(uid, dummyResult);
      } else if (errorMessage.contains('insufficient uses remaining') ||
          errorMessage.contains('already used')) {
        // Handle insufficient uses remaining as already used case
        final dummyResult = PassVerificationResult(
          success: false,
          status: 'used',
          message:
              'This pass has already been used and has no remaining entries.',
          pass: null,
          additionalData: {},
          promptToken: null,
          remainingUses: 0,
          lastUsedAt: null,
        );
        _showPassAlreadyUsedDialog(uid, dummyResult);
      } else {
        _showErrorToast('Verification failed: $e');
      }
    } finally {
      // Hide loading indicator and reset verification state
      _hideLoadingIndicator();
      setState(() {
        _isVerifying = false;
      });

      // Re-enable auto-navigation
      // HttpInterceptor.enableAutoNavigation(); // Method not available
    }
  }

  void _showVerificationPopup(String uid, PassVerificationResult result) {
    // Close any existing popup
    _closeCurrentPopup();

    _currentPopup = OverlayEntry(
      builder: (context) => Material(
        color: Colors.black54,
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(20),
            constraints: const BoxConstraints(maxWidth: 400),
            child: VerificationResultCard(
              uid: uid,
              status: result.status,
              message: result.message,
              passInfo: result.pass,
              remainingUses: result.remainingUses,
              lastUsedAt: result.lastUsedAt,
              onDismiss: _closeCurrentPopup,
              autoDissmiss: false, // Prevent auto-navigation
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_currentPopup!);

    // Auto-close after 10 seconds
    _autoCloseTimer?.cancel();
    _autoCloseTimer = Timer(const Duration(seconds: 10), () {
      _closeCurrentPopup();
    });
  }

  void _showLoadingIndicator() {
    // Remove any existing loading overlay
    _hideLoadingIndicator();

    _loadingOverlay = OverlayEntry(
      builder: (context) => Material(
        color: Colors.black54,
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 50,
                  height: 50,
                  child: CircularProgressIndicator(
                    strokeWidth: 4,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppTheme.primaryColor,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Verifying Pass...',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please wait',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_loadingOverlay!);
  }

  void _hideLoadingIndicator() {
    _loadingOverlay?.remove();
    _loadingOverlay = null;
  }

  void _closeCurrentPopup() {
    _autoCloseTimer?.cancel();

    // Remove overlay popup if exists
    if (_currentPopup != null) {
      try {
        _currentPopup!.remove();
      } catch (e) {
        debugPrint('Error removing overlay: $e');
      }
      _currentPopup = null;
    }

    // Close any active dialog
    if (_isDialogShowing && mounted) {
      try {
        Navigator.of(context, rootNavigator: true).pop();
      } catch (e) {
        debugPrint('Error closing dialog: $e');
      }
      _isDialogShowing = false;
    }

    // Reset verification state to prevent stuck states
    if (mounted) {
      setState(() {
        _isVerifying = false;
      });
    }
  }

  void _showErrorToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showCategoryRestrictionDialog(
    String uid,
    String passCategory,
    String bouncerCategory,
  ) {
    // Close any existing popup before showing new one
    _closeCurrentPopup();

    // Prevent multiple dialogs
    if (_isDialogShowing) return;

    _isDialogShowing = true;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.block, color: Colors.red[600], size: 28),
              const SizedBox(width: 12),
              const Text(
                'Category Restriction',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                bouncerCategory.toLowerCase() == 'all access'
                    ? 'You can verify passes from any category (All Access).'
                    : 'This pass is $passCategory, not valid for $bouncerCategory bouncer.',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Pass Category:',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            passCategory,
                            style: TextStyle(
                              color: Colors.red[700],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Your Category:',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            bouncerCategory,
                            style: TextStyle(
                              color: Colors.green[700],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.nfc, color: Colors.grey[600], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'UID: $uid',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _isDialogShowing = false;
                setState(() {
                  _isVerifying = false;
                });
              },
              child: Text(
                'OK',
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    ).then((_) {
      _isDialogShowing = false;
      setState(() {
        _isVerifying = false;
      });
    });
  }

  void _showPasswordNotFoundDialog(String uid) {
    // Close any existing popup before showing new one
    _closeCurrentPopup();

    // Prevent multiple dialogs
    if (_isDialogShowing) return;

    _isDialogShowing = true;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red[600], size: 28),
              const SizedBox(width: 12),
              const Text(
                'Pass Not Found',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'The scanned pass could not be found in the system.',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.nfc, color: Colors.grey[600], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'UID: $uid',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Please contact the administrator if you believe this is an error.',
                style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _isDialogShowing = false;
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: const Text(
                'OK',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    ).then((_) {
      _isDialogShowing = false;
    });
  }

  void _showPassAlreadyUsedDialog(String uid, PassVerificationResult result) {
    // Close any existing popup before showing new one
    _closeCurrentPopup();

    // Prevent multiple dialogs
    if (_isDialogShowing) return;

    _isDialogShowing = true;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.block, color: Colors.orange[600], size: 28),
              const SizedBox(width: 12),
              const Text(
                'Pass Already Used',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This pass has already been used and has no remaining entries.',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.nfc, color: Colors.orange[600], size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'UID: $uid',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 14,
                              color: Colors.orange[700],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (result.pass != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Pass ID: ${result.pass!.passId}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.orange[700],
                        ),
                      ),
                      Text(
                        'Category: ${result.pass!.category}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.orange[700],
                        ),
                      ),
                    ],
                    if (result.remainingUses != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Remaining Uses: ${result.remainingUses}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.orange[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (result.lastUsedAt != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Last Used: ${result.lastUsedAt}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.orange[700],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Please contact the administrator to reset this pass if needed.',
                style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _isDialogShowing = false;
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: const Text(
                'OK',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    ).then((_) {
      _isDialogShowing = false;
    });
  }

  void _showPassBlockedDialog(String uid, PassVerificationResult result) {
    // Close any existing popup before showing new one
    _closeCurrentPopup();

    // Prevent multiple dialogs
    if (_isDialogShowing) return;

    _isDialogShowing = true;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.block, color: Colors.red[600], size: 28),
              const SizedBox(width: 12),
              const Text(
                'Pass Blocked',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This pass has been blocked by the administrator and cannot be used.',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.nfc, color: Colors.red[600], size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'UID: $uid',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 14,
                              color: Colors.red[700],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (result.pass != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Pass ID: ${result.pass!.passId}',
                        style: TextStyle(fontSize: 14, color: Colors.red[700]),
                      ),
                      Text(
                        'Category: ${result.pass!.category}',
                        style: TextStyle(fontSize: 14, color: Colors.red[700]),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Please contact the administrator for more information.',
                style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _isDialogShowing = false;
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: const Text(
                'OK',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    ).then((_) {
      _isDialogShowing = false;
    });
  }

  void _showSessionMultiUsePopup(String uid, PassVerificationResult result) {
    // Close any existing popup before showing new one
    _closeCurrentPopup();

    print('🎯 Showing Session Multi-Use Popup for UID: $uid');
    print('🎯 Remaining Uses: ${result.remainingUses}');
    print('🎯 Last Used At: ${result.lastUsedAt}');
    print('🎯 Prompt Token: ${result.promptToken}');

    _currentPopup = OverlayEntry(
      builder: (context) => Material(
        color: Colors.black54,
        child: Center(
          child: Container(
            margin: EdgeInsets.all(
              MediaQuery.of(context).size.height < 700 ? 16 : 20,
            ),
            constraints: BoxConstraints(
              maxWidth: 340,
              maxHeight: MediaQuery.of(context).size.height * 0.65,
            ),
            child: SessionMultiUsePopupUltraCompact(
              uid: uid,
              promptToken: result.promptToken ?? '',
              remainingUses: result.remainingUses ?? 0,
              lastUsedAt: result.lastUsedAt ?? '',
              passModel: result.pass,
              onConfirm: (selectedCount) => _confirmSessionMultiUse(
                uid,
                result.promptToken ?? '',
                selectedCount,
              ),
              onCancel: _closeCurrentPopup,
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_currentPopup!);

    // Auto-close after 15 seconds for session passes
    _autoCloseTimer?.cancel();
    _autoCloseTimer = Timer(const Duration(seconds: 15), () {
      _closeCurrentPopup();
    });
  }

  void _showSeasonalMultiUsePopup(String uid, PassVerificationResult result) {
    // Close any existing popup before showing new one
    _closeCurrentPopup();

    print('🎯 Showing Seasonal Multi-Use Popup for UID: $uid');
    print('🎯 Remaining Uses: ${result.remainingUses}');
    print('🎯 Last Used At: ${result.lastUsedAt}');
    print('🎯 Prompt Token: ${result.promptToken}');

    _currentPopup = OverlayEntry(
      builder: (context) => Material(
        color: Colors.black54,
        child: Center(
          child: Container(
            margin: EdgeInsets.all(
              MediaQuery.of(context).size.height < 700 ? 16 : 20,
            ),
            constraints: BoxConstraints(
              maxWidth: 340,
              maxHeight: MediaQuery.of(context).size.height * 0.65,
            ),
            child: SessionMultiUsePopupUltraCompact(
              uid: uid,
              promptToken: result.promptToken ?? '',
              remainingUses: result.remainingUses ?? 0,
              lastUsedAt: result.lastUsedAt ?? '',
              passModel: result.pass,
              onConfirm: (selectedCount) => _confirmSeasonalMultiUse(
                uid,
                result.promptToken ?? '',
                selectedCount,
              ),
              onCancel: _closeCurrentPopup,
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_currentPopup!);

    // Auto-close after 15 seconds for seasonal passes
    _autoCloseTimer?.cancel();
    _autoCloseTimer = Timer(const Duration(seconds: 15), () {
      _closeCurrentPopup();
    });
  }

  Future<void> _confirmSessionMultiUse(
    String uid,
    String promptToken,
    int selectedCount,
  ) async {
    try {
      print('🎯 Confirming Session Multi-Use:');
      print('🎯 UID: $uid');
      print('🎯 Prompt Token: $promptToken');
      print('🎯 Selected Count: $selectedCount');

      _showLoadingIndicator();

      final result = await PassService.consumePrompt(
        promptToken: promptToken,
        consumeCount: selectedCount,
        gateId: 'GATE001',
        scannedBy: authProvider.state.user?.id ?? 0,
      );

      print('🎯 Session Multi-Use Confirmed Successfully:');
      print('🎯 Result Status: ${result.status}');
      print('🎯 Remaining Uses: ${result.remainingUses}');

      _hideLoadingIndicator();
      _closeCurrentPopup();

      // Show special success message for session multi-use
      _showSessionMultiUseSuccessDialog(uid, selectedCount, result);
    } catch (e) {
      print('❌ Session Multi-Use Confirmation Failed: $e');
      _hideLoadingIndicator();
      _showErrorToast('Failed to confirm session: $e');
    }
  }

  Future<void> _confirmSeasonalMultiUse(
    String uid,
    String promptToken,
    int selectedCount,
  ) async {
    try {
      print('🎯 Confirming Seasonal Multi-Use:');
      print('🎯 UID: $uid');
      print('🎯 Prompt Token: $promptToken');
      print('🎯 Selected Count: $selectedCount');

      _showLoadingIndicator();

      final result = await PassService.consumePrompt(
        promptToken: promptToken,
        consumeCount: selectedCount,
        gateId: 'GATE001',
        scannedBy: authProvider.state.user?.id ?? 0,
      );

      print('🎯 Seasonal Multi-Use Confirmed Successfully:');
      print('🎯 Result Status: ${result.status}');
      print('🎯 Remaining Uses: ${result.remainingUses}');

      _hideLoadingIndicator();
      _closeCurrentPopup();

      // Show special success message for seasonal multi-use
      _showSeasonalMultiUseSuccessDialog(uid, selectedCount, result);
    } catch (e) {
      print('❌ Seasonal Multi-Use Confirmation Failed: $e');
      _hideLoadingIndicator();
      _showErrorToast('Failed to confirm seasonal: $e');
    }
  }

  void _showSessionMultiUseSuccessDialog(
    String uid,
    int selectedCount,
    PassVerificationResult result,
  ) {
    _isDialogShowing = true;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green[600], size: 28),
              const SizedBox(width: 12),
              const Text(
                'Session Pass Used',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Column(
                  children: [
                    Text(
                      'Successfully allowed $selectedCount ${selectedCount == 1 ? 'person' : 'people'} to enter',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.green[700],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Session Pass Multi-Use Entry',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Remaining uses:',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.green[600],
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${result.remainingUses ?? 0}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.green[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Flow information
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.blue[600],
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Session Pass Flow',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• 15-minute window for multi-use\n• One pass for multiple people\n• Real-time remaining uses tracking',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[600],
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.nfc, color: Colors.grey[600], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'UID: $uid',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _isDialogShowing = false;
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[600],
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'OK',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    ).then((_) {
      _isDialogShowing = false;
    });
  }

  void _showSeasonalMultiUseSuccessDialog(
    String uid,
    int selectedCount,
    PassVerificationResult result,
  ) {
    _isDialogShowing = true;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.orange[600], size: 28),
              const SizedBox(width: 12),
              const Text(
                'Seasonal Pass Used',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Column(
                  children: [
                    Text(
                      'Successfully allowed $selectedCount ${selectedCount == 1 ? 'person' : 'people'} to enter',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange[700],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Seasonal Pass Multi-Use Entry',
                      style: TextStyle(fontSize: 12, color: Colors.orange[600]),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Remaining Uses:',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.orange[600],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${result.remainingUses ?? 0}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.orange[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Flow information
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.blue[600],
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Seasonal Pass Flow',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• 15-minute window for multi-use\n• One pass for multiple people\n• Real-time remaining uses tracking',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[600],
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.nfc, color: Colors.grey[600], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'UID: $uid',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _isDialogShowing = false;
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[600],
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'OK',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    ).then((_) {
      _isDialogShowing = false;
    });
  }

  Future<void> _startScan() async {
    if (!_isInitialized) {
      _showErrorToast('NFC not initialized');
      return;
    }

    try {
      await NFCService.startScan();
    } catch (e) {
      _showErrorToast('Failed to start scan: $e');
    }
  }

  Future<void> _stopScan() async {
    try {
      await NFCService.stopScan();
    } catch (e) {
      _showErrorToast('Failed to stop scan: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Pass'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.primaryColor,
              AppTheme.primaryColor.withOpacity(0.8),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Header Section
                Container(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(
                        Icons.nfc,
                        size: 80,
                        color: Colors.white.withOpacity(0.9),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'NFC Pass Verification',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isScanning
                            ? 'Scanning for NFC tags...'
                            : 'Tap the button below to start scanning',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withOpacity(0.8),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                // Main Content
                Container(
                  margin: const EdgeInsets.only(top: 20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Scan Status
                        if (_isScanning) ...[
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppTheme.primaryColor.withOpacity(0.3),
                                width: 2,
                              ),
                            ),
                            child: Column(
                              children: [
                                SizedBox(
                                  width: 60,
                                  height: 60,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 4,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppTheme.primaryColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Scanning for NFC tags...',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        color: AppTheme.primaryColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Hold your device near an NFC tag',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          // Scan Button
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.grey[200]!,
                                width: 2,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.nfc,
                                  size: 80,
                                  color: AppTheme.primaryColor,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Ready to Scan',
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(
                                        color: AppTheme.primaryColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Tap the button below to start scanning for NFC passes',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(color: Colors.grey[600]),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 24),
                                SizedBox(
                                  width: double.infinity,
                                  height: 56,
                                  child: ElevatedButton.icon(
                                    onPressed: _isInitialized
                                        ? _startScan
                                        : null,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryColor,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      elevation: 2,
                                    ),
                                    icon: const Icon(Icons.nfc, size: 24),
                                    label: Text(
                                      _isInitialized
                                          ? 'Start Scanning'
                                          : 'Initializing...',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 32),

                        // Instructions
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.blue[200]!,
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: Colors.blue[600],
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'How to use:',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                          color: Colors.blue[700],
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '1. Tap "Start Scanning" to begin\n'
                                '2. Hold your device near an NFC tag\n'
                                '3. Wait for the verification result\n'
                                '4. The result will be displayed automatically',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Colors.grey[700],
                                      height: 1.5,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),

      // Stop Scan Button (when scanning)
      floatingActionButton: _isScanning
          ? FloatingActionButton.extended(
              onPressed: _stopScan,
              backgroundColor: Colors.red,
              icon: const Icon(Icons.stop, color: Colors.white),
              label: const Text(
                'Stop Scan',
                style: TextStyle(color: Colors.white),
              ),
            )
          : null,
    );
  }
}
