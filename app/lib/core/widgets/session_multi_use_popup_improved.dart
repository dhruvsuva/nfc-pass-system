import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../../models/pass_model.dart';
import '../../core/utils/category_utils.dart';
import '../../features/auth/providers/auth_provider.dart';

class SessionMultiUsePopupImproved extends StatefulWidget {
  final String uid;
  final String promptToken;
  final int remainingUses;
  final String lastUsedAt;
  final PassModel? passModel;
  final Function(int selectedCount) onConfirm;
  final VoidCallback onCancel;

  const SessionMultiUsePopupImproved({
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
  State<SessionMultiUsePopupImproved> createState() => _SessionMultiUsePopupImprovedState();
}

class _SessionMultiUsePopupImprovedState extends State<SessionMultiUsePopupImproved>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _fadeController;
  late AnimationController _slideController;
  
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  int selectedCount = 1;
  String? _errorMessage;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 0.7,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    
    // Start animations
    _fadeController.forward();
    _scaleController.forward();
    _slideController.forward();
    
    // Haptic feedback
    HapticFeedback.mediumImpact();
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _handleConfirm() async {
    if (_isProcessing) return;
    
    // Validate selected count
    if (selectedCount > widget.remainingUses) {
      _showErrorMessage('Selected count (${selectedCount}) exceeds remaining uses (${widget.remainingUses})');
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
    
    // Enhanced haptic feedback
    HapticFeedback.heavyImpact();
    
    // Animate out with delay for better UX
    await Future.delayed(const Duration(milliseconds: 100));
    await Future.wait([
      _scaleController.reverse(),
      _fadeController.reverse(),
      _slideController.reverse(),
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
      _slideController.reverse(),
    ]);
    
    widget.onCancel();
  }

  void _showErrorMessage(String message) {
    setState(() {
      _errorMessage = message;
    });
    
    // Auto-hide error after 4 seconds
    Future.delayed(const Duration(seconds: 4), () {
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
        return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
      } else {
        return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
      }
    } catch (e) {
      return 'Recently';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenHeight < 700;
    final maxHeight = screenHeight * (isSmallScreen ? 0.85 : 0.8);
    
    return Material(
      color: Colors.transparent,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          color: Colors.black.withOpacity(0.7),
          child: Center(
            child: SlideTransition(
              position: _slideAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  margin: EdgeInsets.all(isSmallScreen ? 16 : 24),
                  constraints: BoxConstraints(
                    maxWidth: isSmallScreen ? screenWidth - 32 : 420,
                    maxHeight: maxHeight,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 30,
                        offset: const Offset(0, 15),
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header with improved design
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(isSmallScreen ? 20 : 24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppTheme.warningColor,
                              AppTheme.warningColor.withOpacity(0.8),
                              AppTheme.primaryColor.withOpacity(0.9),
                            ],
                          ),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(28),
                            topRight: Radius.circular(28),
                          ),
                        ),
                        child: Column(
                          children: [
                            // Icon with animation
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.group_add_rounded,
                                color: Colors.white,
                                size: 36,
                              ),
                            ),
                            
                            SizedBox(height: isSmallScreen ? 12 : 16),
                            
                            Text(
                              'Session Pass Multi-Use',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isSmallScreen ? 20 : 24,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            
                            SizedBox(height: isSmallScreen ? 6 : 8),
                            
                            Text(
                              'Last used ${_formatLastUsedTime()}',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: isSmallScreen ? 13 : 14,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      
                      // Content without scroll
                      Flexible(
                        child: Padding(
                          padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Info message with improved design
                              Container(
                                padding: EdgeInsets.all(isSmallScreen ? 14 : 16),
                                decoration: BoxDecoration(
                                  color: AppTheme.warningColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: AppTheme.warningColor.withOpacity(0.3),
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.info_outline_rounded,
                                      color: AppTheme.warningColor,
                                      size: isSmallScreen ? 20 : 24,
                                    ),
                                    SizedBox(width: isSmallScreen ? 10 : 12),
                                    Expanded(
                                      child: Text(
                                        'This session pass has been used before. You can still use it for additional people if you have remaining uses.',
                                        style: TextStyle(
                                          fontSize: isSmallScreen ? 13 : 14,
                                          color: AppTheme.warningColor,
                                          fontWeight: FontWeight.w500,
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              
                              SizedBox(height: isSmallScreen ? 12 : 16),
                              
                              // Pass details card with improved design
                              if (widget.passModel != null) ...[
                                Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.grey[800] : Colors.grey[50],
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Pass Type and Category
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: AppTheme.primaryColor.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Icon(
                                              _getPassTypeIcon(widget.passModel!.passType),
                                              color: AppTheme.primaryColor,
                                              size: isSmallScreen ? 18 : 20,
                                            ),
                                          ),
                                          SizedBox(width: isSmallScreen ? 10 : 12),
                                          Expanded(
                                            child: Text(
                                              '${widget.passModel!.passType.toUpperCase()} - ${widget.passModel!.category}',
                                              style: TextStyle(
                                                fontSize: isSmallScreen ? 15 : 16,
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.primaryColor,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                          ),
                                        ],
                                      ),
                                      
                                      SizedBox(height: isSmallScreen ? 8 : 12),
                                      Divider(height: 1, color: isDark ? Colors.grey[700] : Colors.grey[300]),
                                      SizedBox(height: isSmallScreen ? 8 : 12),
                                      
                                      // People Allowed and Remaining Uses
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.people_rounded,
                                                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                                                  size: isSmallScreen ? 18 : 20,
                                                ),
                                                SizedBox(width: isSmallScreen ? 8 : 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        'People Allowed',
                                                        style: TextStyle(
                                                          fontSize: isSmallScreen ? 11 : 12,
                                                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                      ),
                                                      SizedBox(height: 4),
                                                      Text(
                                                        '${widget.passModel!.peopleAllowed} people',
                                                        style: TextStyle(
                                                          fontSize: isSmallScreen ? 15 : 16,
                                                          fontWeight: FontWeight.bold,
                                                          color: isDark ? Colors.white : Colors.black87,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: isSmallScreen ? 10 : 12,
                                              vertical: isSmallScreen ? 6 : 8,
                                            ),
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  AppTheme.warningColor.withOpacity(0.2),
                                                  AppTheme.primaryColor.withOpacity(0.2),
                                                ],
                                              ),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(
                                                color: AppTheme.warningColor.withOpacity(0.3),
                                              ),
                                            ),
                                            child: Text(
                                              '${widget.remainingUses} left',
                                              style: TextStyle(
                                                fontSize: isSmallScreen ? 11 : 12,
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.warningColor,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      
                                      SizedBox(height: isSmallScreen ? 8 : 12),
                                      
                                      // UID Display
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.fingerprint_rounded,
                                            color: isDark ? Colors.grey[500] : Colors.grey[500],
                                            size: isSmallScreen ? 14 : 16,
                                          ),
                                          SizedBox(width: isSmallScreen ? 6 : 8),
                                          Expanded(
                                            child: Text(
                                              'UID: ${widget.uid}',
                                              style: TextStyle(
                                                fontFamily: 'monospace',
                                                fontSize: isSmallScreen ? 9 : 10,
                                                color: isDark ? Colors.grey[500] : Colors.grey[500],
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                
                                SizedBox(height: isSmallScreen ? 12 : 16),
                              ],
                              
                              // People count selector with improved design
                              Text(
                                'How many people are entering?',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 16 : 18,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              
                              SizedBox(height: isSmallScreen ? 16 : 20),
                              
                              // Counter with improved design
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
                                      HapticFeedback.mediumImpact();
                                      setState(() {
                                        selectedCount = 1;
                                      });
                                    } : null,
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: EdgeInsets.all(isSmallScreen ? 14 : 16),
                                      decoration: BoxDecoration(
                                        color: selectedCount > 1 
                                            ? AppTheme.primaryColor 
                                            : Colors.grey[400],
                                        borderRadius: BorderRadius.circular(18),
                                        boxShadow: selectedCount > 1 ? [
                                          BoxShadow(
                                            color: AppTheme.primaryColor.withOpacity(0.4),
                                            blurRadius: 12,
                                            offset: const Offset(0, 6),
                                          ),
                                        ] : null,
                                      ),
                                      child: Icon(
                                        Icons.remove_rounded,
                                        color: Colors.white,
                                        size: isSmallScreen ? 22 : 24,
                                      ),
                                    ),
                                  ),
                                  
                                  SizedBox(width: isSmallScreen ? 16 : 20),
                                  
                                  // Count display with improved design
                                  Container(
                                    width: isSmallScreen ? 60 : 70,
                                    height: isSmallScreen ? 60 : 70,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          isDark ? Colors.grey[800]! : Colors.grey[100]!,
                                          isDark ? Colors.grey[700]! : Colors.grey[200]!,
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: AppTheme.primaryColor.withOpacity(0.4),
                                        width: 2.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppTheme.primaryColor.withOpacity(0.2),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Text(
                                        selectedCount.toString(),
                                        style: TextStyle(
                                          fontSize: isSmallScreen ? 20 : 24,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.primaryColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                  
                                  SizedBox(width: isSmallScreen ? 16 : 20),
                                  
                                  // Increase button
                                  GestureDetector(
                                    onTap: selectedCount < widget.remainingUses ? () {
                                      HapticFeedback.selectionClick();
                                      setState(() {
                                        selectedCount++;
                                      });
                                    } : null,
                                    onLongPress: selectedCount < widget.remainingUses ? () {
                                      HapticFeedback.mediumImpact();
                                      setState(() {
                                        selectedCount = widget.remainingUses;
                                      });
                                    } : null,
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: EdgeInsets.all(isSmallScreen ? 14 : 16),
                                      decoration: BoxDecoration(
                                        color: selectedCount < widget.remainingUses 
                                            ? AppTheme.primaryColor 
                                            : Colors.grey[400],
                                        borderRadius: BorderRadius.circular(18),
                                        boxShadow: selectedCount < widget.remainingUses ? [
                                          BoxShadow(
                                            color: AppTheme.primaryColor.withOpacity(0.4),
                                            blurRadius: 12,
                                            offset: const Offset(0, 6),
                                          ),
                                        ] : null,
                                      ),
                                      child: Icon(
                                        Icons.add_rounded,
                                        color: Colors.white,
                                        size: isSmallScreen ? 22 : 24,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              
                              SizedBox(height: isSmallScreen ? 12 : 16),
                              
                              // Remaining uses info with improved design
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isSmallScreen ? 12 : 16,
                                  vertical: isSmallScreen ? 8 : 10,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppTheme.primaryColor.withOpacity(0.3),
                                  ),
                                ),
                                child: Text(
                                  'Remaining uses: ${widget.remainingUses}',
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 13 : 14,
                                    color: AppTheme.primaryColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              
                              // Error message display with improved design
                              if (_errorMessage != null) ...[
                                SizedBox(height: isSmallScreen ? 12 : 16),
                                Container(
                                  padding: EdgeInsets.all(isSmallScreen ? 12 : 14),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    border: Border.all(color: Colors.red.shade300, width: 1.5),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.error_outline_rounded,
                                        color: Colors.red.shade700,
                                        size: isSmallScreen ? 18 : 20,
                                      ),
                                      SizedBox(width: isSmallScreen ? 8 : 10),
                                      Expanded(
                                        child: Text(
                                          _errorMessage!,
                                          style: TextStyle(
                                            color: Colors.red.shade700,
                                            fontSize: isSmallScreen ? 13 : 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              
                              SizedBox(height: isSmallScreen ? 16 : 20),
                            ],
                          ),
                        ),
                      ),
                      
                      // Action buttons with improved design
                      Container(
                        padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[850] : Colors.grey[50],
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(28),
                            bottomRight: Radius.circular(28),
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
                                  padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 14 : 16),
                                  side: BorderSide(
                                    color: isDark ? Colors.grey[600]! : Colors.grey[400]!,
                                    width: 1.5,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: Text(
                                  'Cancel',
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 15 : 16,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: isSmallScreen ? 10 : 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _isProcessing ? null : _handleConfirm,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isProcessing ? Colors.grey[400] : AppTheme.primaryColor,
                                  padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 14 : 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: _isProcessing ? 0 : 6,
                                  shadowColor: AppTheme.primaryColor.withOpacity(0.4),
                                ),
                                child: _isProcessing
                                    ? SizedBox(
                                        width: isSmallScreen ? 18 : 20,
                                        height: isSmallScreen ? 18 : 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : Text(
                                        'Confirm Entry',
                                        style: TextStyle(
                                          fontSize: isSmallScreen ? 15 : 16,
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
      ),
    );
  }

  IconData _getPassTypeIcon(String? passType) {
    switch (passType?.toLowerCase()) {
      case 'daily':
        return Icons.today_rounded;
      case 'weekly':
        return Icons.date_range_rounded;
      case 'monthly':
        return Icons.calendar_month_rounded;
      case 'yearly':
        return Icons.calendar_today_rounded;
      case 'unlimited':
        return Icons.all_inclusive_rounded;
      case 'session':
        return Icons.schedule_rounded;
      default:
        return Icons.confirmation_number_rounded;
    }
  }
}
