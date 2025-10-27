import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../../models/pass_model.dart';
import '../../core/utils/category_utils.dart';
import '../../features/auth/providers/auth_provider.dart';

class SessionMultiUsePopupUltraCompact extends StatefulWidget {
  final String uid;
  final String promptToken;
  final int remainingUses;
  final String lastUsedAt;
  final PassModel? passModel;
  final Function(int selectedCount) onConfirm;
  final VoidCallback onCancel;

  const SessionMultiUsePopupUltraCompact({
    super.key,
    required this.uid,
    required this.promptToken,
    required this.remainingUses,
    required this.lastUsedAt,
    this.passModel,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  State<SessionMultiUsePopupUltraCompact> createState() => _SessionMultiUsePopupUltraCompactState();
}

class _SessionMultiUsePopupUltraCompactState extends State<SessionMultiUsePopupUltraCompact>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _fadeController;
  
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  
  int selectedCount = 1;
  String? _errorMessage;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 0.9,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeOut,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));
    
    // Start animations
    _fadeController.forward();
    _scaleController.forward();
    
    // Haptic feedback
    HapticFeedback.mediumImpact();
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _handleConfirm() async {
    if (_isProcessing) return;
    
    // Validate selected count
    if (selectedCount > widget.remainingUses) {
      _showErrorMessage('Selected count exceeds remaining uses');
      return;
    }
    
    if (selectedCount < 1) {
      _showErrorMessage('Please select at least 1 person');
      return;
    }
    
    // Check category validation for bouncers
    final currentUser = authProvider.state.user;
    if (currentUser?.role == 'bouncer' && currentUser?.assignedCategory != null) {
      if (widget.passModel?.category != null) {
        final bouncerCategory = currentUser!.assignedCategory!;
        final passCategory = widget.passModel!.category;
        
        // Check if bouncer can verify this pass
        if (!CategoryUtils.canBouncerVerifyPass(bouncerCategory, passCategory)) {
          _showErrorMessage('This pass is ${CategoryUtils.getDisplayName(passCategory)}, not valid for ${CategoryUtils.getDisplayName(bouncerCategory)} bouncer');
          return;
        }
      }
    }
    
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });
    
    HapticFeedback.heavyImpact();
    
    // Animate out
    await Future.wait([
      _scaleController.reverse(),
      _fadeController.reverse(),
    ]);
    
    widget.onConfirm(selectedCount);
  }

  void _handleCancel() async {
    if (_isProcessing) return;
    
    HapticFeedback.selectionClick();
    
    // Animate out
    await Future.wait([
      _scaleController.reverse(),
      _fadeController.reverse(),
    ]);
    
    widget.onCancel();
  }

  void _showErrorMessage(String message) {
    setState(() {
      _errorMessage = message;
    });
    
    // Auto-hide error after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _errorMessage = null;
        });
      }
    });
  }

  String _formatLastUsedTime() {
    try {
      final lastUsed = DateTime.parse(widget.lastUsedAt);
      final now = DateTime.now();
      final difference = now.difference(lastUsed);
      
      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else {
        return '${difference.inHours}h ago';
      }
    } catch (e) {
      return 'Recently';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 700;
    
    return Material(
      color: Colors.transparent,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          color: Colors.black.withOpacity(0.7),
          child: Center(
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                margin: EdgeInsets.all(isSmallScreen ? 8 : 12),
                constraints: BoxConstraints(
                  maxWidth: 340,
                  maxHeight: screenHeight * 0.65,
                ),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Ultra Compact Header
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Color(0xFFFF9800), // Orange
                            Color(0xFF2196F3), // Blue
                          ],
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.group_add_rounded,
                            color: Colors.white,
                            size: isSmallScreen ? 20 : 24,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Session Multi-Use',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: isSmallScreen ? 14 : 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Last used ${_formatLastUsedTime()}',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: isSmallScreen ? 10 : 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${widget.remainingUses} left',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isSmallScreen ? 10 : 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Ultra Compact Content
                    Padding(
                      padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Info message
                          Container(
                            padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
                            decoration: BoxDecoration(
                              color: Color(0xFFFFF3E0), // Light orange background
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Color(0xFFFF9800).withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline_rounded,
                                  color: Color(0xFFFF9800), // Orange icon
                                  size: isSmallScreen ? 12 : 14,
                                ),
                                SizedBox(width: 6),
                                Expanded(
                                  child:                                 Text(
                                  'This pass has been used. You can use it for additional people.',
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 10 : 11,
                                    color: Color(0xFFFF9800), // Orange text
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                ),
                              ],
                            ),
                          ),
                          
                          SizedBox(height: isSmallScreen ? 12 : 16),
                          
                          // People count selector
                          Text(
                            'How many people?',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 14 : 16,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          
                          SizedBox(height: isSmallScreen ? 8 : 12),
                          
                          SizedBox(height: isSmallScreen ? 12 : 16),
                          
                          // Ultra Compact Counter
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Decrease button
                              GestureDetector(
                                onTap: selectedCount > 1 ? () {
                                  HapticFeedback.selectionClick();
                                  setState(() {
                                    selectedCount--;
                                  });
                                } : null,
                                onLongPress: selectedCount > 1 ? () {
                                  HapticFeedback.heavyImpact();
                                  setState(() {
                                    selectedCount = 1;
                                  });
                                  // Show brief feedback
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Selected minimum: 1 person'),
                                      duration: Duration(milliseconds: 1000),
                                      behavior: SnackBarBehavior.floating,
                                      backgroundColor: AppTheme.primaryColor,
                                    ),
                                  );
                                } : null,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
                                  decoration: BoxDecoration(
                                    color: selectedCount > 1 
                                        ? AppTheme.primaryColor 
                                        : Colors.grey[400],
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: selectedCount > 1 ? [
                                      BoxShadow(
                                        color: AppTheme.primaryColor.withOpacity(0.3),
                                        blurRadius: 6,
                                        offset: const Offset(0, 3),
                                      ),
                                    ] : null,
                                  ),
                                  child: Icon(
                                    Icons.remove_rounded,
                                    color: Colors.white,
                                    size: isSmallScreen ? 16 : 18,
                                  ),
                                ),
                              ),
                              
                              SizedBox(width: isSmallScreen ? 12 : 16),
                              
                              // Count display
                              Container(
                                width: isSmallScreen ? 40 : 45,
                                height: isSmallScreen ? 40 : 45,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      isDark ? Colors.grey[800]! : Colors.grey[100]!,
                                      isDark ? Colors.grey[700]! : Colors.grey[200]!,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppTheme.primaryColor.withOpacity(0.4),
                                    width: 2,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    selectedCount.toString(),
                                    style: TextStyle(
                                      fontSize: isSmallScreen ? 14 : 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                ),
                              ),
                              
                              SizedBox(width: isSmallScreen ? 12 : 16),
                              
                              // Increase button
                              GestureDetector(
                                onTap: selectedCount < widget.remainingUses ? () {
                                  HapticFeedback.selectionClick();
                                  setState(() {
                                    selectedCount++;
                                  });
                                } : null,
                                onLongPress: selectedCount < widget.remainingUses ? () {
                                  HapticFeedback.heavyImpact();
                                  setState(() {
                                    selectedCount = widget.remainingUses;
                                  });
                                  // Show brief feedback
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Selected maximum: ${widget.remainingUses} people'),
                                      duration: Duration(milliseconds: 1000),
                                      behavior: SnackBarBehavior.floating,
                                      backgroundColor: AppTheme.primaryColor,
                                    ),
                                  );
                                } : null,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
                                  decoration: BoxDecoration(
                                    color: selectedCount < widget.remainingUses 
                                        ? AppTheme.primaryColor 
                                        : Colors.grey[400],
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: selectedCount < widget.remainingUses ? [
                                      BoxShadow(
                                        color: AppTheme.primaryColor.withOpacity(0.3),
                                        blurRadius: 6,
                                        offset: const Offset(0, 3),
                                      ),
                                    ] : null,
                                  ),
                                  child: Icon(
                                    Icons.add_rounded,
                                    color: Colors.white,
                                    size: isSmallScreen ? 16 : 18,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          
                          SizedBox(height: isSmallScreen ? 8 : 12),
                          
                          // Remaining uses info
                          Text(
                            'Remaining: ${widget.remainingUses} uses',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 10 : 11,
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          
                          SizedBox(height: isSmallScreen ? 4 : 6),
                          
                          // Error message
                          if (_errorMessage != null) ...[
                            SizedBox(height: isSmallScreen ? 8 : 12),
                            Container(
                              padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                border: Border.all(color: Colors.red.shade300),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.error_outline_rounded,
                                    color: Colors.red.shade700,
                                    size: isSmallScreen ? 12 : 14,
                                  ),
                                  SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: TextStyle(
                                        color: Colors.red.shade700,
                                        fontSize: isSmallScreen ? 10 : 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    
                    // Action buttons
                    Container(
                      padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[850] : Colors.grey[50],
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(20),
                          bottomRight: Radius.circular(20),
                        ),
                        border: Border(
                          top: BorderSide(
                            color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _isProcessing ? null : _handleCancel,
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 8 : 10),
                                side: BorderSide(
                                  color: isDark ? Colors.grey[600]! : Colors.grey[400]!,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 12 : 14,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: isSmallScreen ? 8 : 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isProcessing ? null : _handleConfirm,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isProcessing ? Colors.grey[400] : AppTheme.primaryColor,
                                padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 8 : 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                elevation: _isProcessing ? 0 : 3,
                                shadowColor: AppTheme.primaryColor.withOpacity(0.3),
                              ),
                              child: _isProcessing
                                  ? SizedBox(
                                      width: isSmallScreen ? 14 : 16,
                                      height: isSmallScreen ? 14 : 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : Text(
                                      'Confirm',
                                      style: TextStyle(
                                        fontSize: isSmallScreen ? 12 : 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}



