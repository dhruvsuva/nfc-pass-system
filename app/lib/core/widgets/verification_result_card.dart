import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/pass_model.dart';
import '../theme/app_theme.dart';
import '../theme/pass_theme.dart';

class VerificationResultCard extends StatefulWidget {
  final String uid;
  final String status;
  final String message;
  final PassModel? passInfo;
  final int? remainingUses;
  final String? lastUsedAt;
  final VoidCallback? onDismiss;
  final Duration displayDuration;
  final bool autoDissmiss;

  const VerificationResultCard({
    super.key,
    required this.uid,
    required this.status,
    required this.message,
    this.passInfo,
    this.remainingUses,
    this.lastUsedAt,
    this.onDismiss,
    this.displayDuration = const Duration(seconds: 4),
    this.autoDissmiss = false,
  });

  @override
  State<VerificationResultCard> createState() => _VerificationResultCardState();
}

class _VerificationResultCardState extends State<VerificationResultCard>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeIn));

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    // Start animations
    _fadeController.forward();
    _scaleController.forward();

    // Trigger haptic feedback and sound
    _triggerFeedback();

    // Auto-dismiss after duration only if enabled
    if (widget.autoDissmiss) {
      debugPrint(
        '🔄 VerificationResultCard: Auto-dismiss enabled, will dismiss after ${widget.displayDuration.inSeconds} seconds',
      );
      Future.delayed(widget.displayDuration, () {
        if (mounted) {
          debugPrint('⏰ VerificationResultCard: Auto-dismiss timer triggered');
          _dismissCard();
        }
      });
    } else {
      debugPrint('🚫 VerificationResultCard: Auto-dismiss disabled');
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  void _triggerFeedback() {
    // Haptic feedback based on status
    switch (widget.status.toLowerCase()) {
      case 'valid':
      case 'consumed':
        HapticFeedback.lightImpact();
        break;
      case 'invalid':
      case 'error':
      case 'blocked':
        HapticFeedback.heavyImpact();
        break;
      case 'used':
      case 'expired':
        HapticFeedback.mediumImpact();
        break;
    }
  }

  void _dismissCard() async {
    debugPrint('🔄 VerificationResultCard: _dismissCard called');
    await _fadeController.reverse();
    if (mounted) {
      debugPrint('📞 VerificationResultCard: Calling onDismiss callback');
      widget.onDismiss?.call();
    } else {
      debugPrint(
        '⚠️ VerificationResultCard: Widget not mounted, skipping onDismiss',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isMobile = screenWidth < 600;

    // Get enhanced color scheme based on pass type and category
    Color backgroundColor = AppTheme.successColor;
    Color textColor = Colors.white;
    bool isUnlimited = widget.passInfo?.passType == 'unlimited';

    if (widget.passInfo != null) {
      backgroundColor = _getEnhancedCategoryColor(
        widget.passInfo!.category,
        widget.passInfo!.passType,
      );
      textColor = _getContrastingTextColor(backgroundColor);
    }

    return Material(
      color: Colors.transparent,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          color: Colors.black.withOpacity(0.6),
          child: Center(
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                margin: EdgeInsets.all(isMobile ? 16 : 20),
                constraints: BoxConstraints(
                  maxWidth: isMobile ? screenWidth * 0.95 : 450,
                  maxHeight: screenHeight * 0.85, // Responsive max height
                ),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(isMobile ? 20 : 24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: isUnlimited
                    ? _buildUnlimitedDesign(textColor, isMobile)
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Header with status
                          _buildHeader(textColor, isMobile),

                          // Scrollable Content
                          Flexible(
                            child: SingleChildScrollView(
                              padding: EdgeInsets.all(isMobile ? 16 : 20),
                              child: Column(
                                children: [
                                  // Pass details
                                  if (widget.passInfo != null)
                                    _buildPassDetails(textColor, isMobile),

                                  const SizedBox(height: 16),

                                  // UID section
                                  _buildUIDSection(textColor, isMobile),
                                ],
                              ),
                            ),
                          ),

                          // Close button at bottom
                          _buildCloseButton(textColor, isMobile),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Color textColor, bool isMobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 20 : 24),
      decoration: BoxDecoration(
        color: textColor.withOpacity(0.1),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(isMobile ? 20 : 24),
          topRight: Radius.circular(isMobile ? 20 : 24),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: textColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              _getStatusIcon(widget.status),
              color: textColor,
              size: isMobile ? 32 : 36,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _getStatusTitle(widget.status),
            style: TextStyle(
              color: textColor,
              fontSize: isMobile ? 20 : 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _getStatusMessage(widget.status),
            style: TextStyle(
              color: textColor.withOpacity(0.9),
              fontSize: isMobile ? 14 : 16,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPassDetails(Color textColor, bool isMobile) {
    final pass = widget.passInfo!;
    // Simple logic: Show remaining uses after this verification
    // Formula: maxUses - (usedCount + 1) where +1 represents this verification
    final currentUsedCount = pass.usedCount;
    final remainingAfterVerification = pass.maxUses - (currentUsedCount + 1);
    final pendingUses = remainingAfterVerification > 0
        ? remainingAfterVerification
        : 0;

    print('🔍 Usage Calculation:');
    print('  - Max Uses: ${pass.maxUses}');
    print('  - Current Used Count: $currentUsedCount');
    print('  - After This Verification: ${currentUsedCount + 1}');
    print('  - Remaining After Verification: $pendingUses');

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 20 : 24),
      decoration: BoxDecoration(
        color: textColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: textColor.withOpacity(0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pass Type and Category Header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pass Type',
                      style: TextStyle(
                        color: textColor.withOpacity(0.8),
                        fontSize: isMobile ? 12 : 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      pass.passType.toUpperCase(),
                      style: TextStyle(
                        color: textColor,
                        fontSize: isMobile ? 16 : 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Category',
                      style: TextStyle(
                        color: textColor.withOpacity(0.8),
                        fontSize: isMobile ? 12 : 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      pass.category,
                      style: TextStyle(
                        color: textColor,
                        fontSize: isMobile ? 16 : 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // UID (small font)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: textColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.tag, size: 16, color: textColor.withOpacity(0.7)),
                const SizedBox(width: 8),
                Text(
                  'UID: ${widget.uid}',
                  style: TextStyle(
                    color: textColor.withOpacity(0.8),
                    fontSize: isMobile ? 11 : 12,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Allowed Persons
          Row(
            children: [
              Icon(Icons.people, size: 20, color: textColor.withOpacity(0.8)),
              const SizedBox(width: 8),
              Text(
                'Allowed Persons: ${pass.peopleAllowed}',
                style: TextStyle(
                  color: textColor,
                  fontSize: isMobile ? 14 : 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Usage Circles - Pending and Total
          Row(
            children: [
              Expanded(
                child: _buildUsageCircle(
                  'Remaining',
                  pendingUses > 0 ? '$pendingUses' : 'Used',
                  pendingUses > 0 ? Icons.refresh : Icons.check_circle,
                  textColor,
                  isMobile,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _buildUsageCircle(
                  'Total',
                  '${pass.maxUses}',
                  Icons.looks_one,
                  textColor,
                  isMobile,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// New usage circle widget with bigger fonts and better design
  Widget _buildUsageCircle(
    String label,
    String value,
    IconData icon,
    Color textColor,
    bool isMobile,
  ) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: textColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: textColor.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        children: [
          // Icon
          Icon(
            icon,
            color: textColor.withOpacity(0.8),
            size: isMobile ? 20 : 24,
          ),
          const SizedBox(height: 8),

          // Big circle with number
          Container(
            width: isMobile ? 70 : 80,
            height: isMobile ? 70 : 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: textColor.withOpacity(0.2),
              border: Border.all(color: textColor.withOpacity(0.4), width: 2),
            ),
            child: Center(
              child: Text(
                value,
                style: TextStyle(
                  color: textColor,
                  fontSize: isMobile ? 24 : 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Label
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: isMobile ? 13 : 15,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBigCircleItem(
    String label,
    String value,
    IconData icon,
    Color textColor,
    bool isMobile,
  ) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: textColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: textColor.withOpacity(0.3), width: 2),
      ),
      child: Column(
        children: [
          // Big circle with number
          Container(
            width: isMobile ? 60 : 80,
            height: isMobile ? 60 : 80,
            decoration: BoxDecoration(color: textColor, shape: BoxShape.circle),
            child: Center(
              child: Text(
                value,
                style: TextStyle(
                  fontSize: isMobile ? 24 : 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Label
          Text(
            label,
            style: TextStyle(
              fontSize: isMobile ? 12 : 14,
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(
    String label,
    String value,
    IconData icon,
    Color textColor,
    bool isMobile, {
    bool fullWidth = false,
  }) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: textColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: textColor.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: textColor, size: isMobile ? 16 : 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: isMobile ? 12 : 14,
                    color: textColor.withOpacity(0.8),
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: isMobile ? 14 : 16,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildUIDSection(Color textColor, bool isMobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: textColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: textColor.withOpacity(0.2), width: 1),
      ),
      child: Row(
        children: [
          Icon(
            Icons.fingerprint,
            color: textColor.withOpacity(0.7),
            size: isMobile ? 20 : 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'UID',
                  style: TextStyle(
                    fontSize: isMobile ? 12 : 14,
                    color: textColor.withOpacity(0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.uid,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: isMobile ? 14 : 16,
                    color: textColor,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCloseButton(Color textColor, bool isMobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: textColor.withOpacity(0.1),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(isMobile ? 20 : 24),
          bottomRight: Radius.circular(isMobile ? 20 : 24),
        ),
        border: Border(
          top: BorderSide(color: textColor.withOpacity(0.2), width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Tap to close',
            style: TextStyle(
              fontSize: isMobile ? 12 : 14,
              color: textColor.withOpacity(0.7),
              fontStyle: FontStyle.italic,
            ),
          ),
          GestureDetector(
            onTap: widget.onDismiss,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: textColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.close,
                color: textColor,
                size: isMobile ? 20 : 24,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to determine contrasting text color
  Color _getContrastingTextColor(Color backgroundColor) {
    // Calculate luminance of background color
    final luminance = backgroundColor.computeLuminance();

    // Return white text for dark backgrounds, dark text for light backgrounds
    return luminance > 0.5 ? Colors.black87 : Colors.white;
  }

  String _getStatusTitle(String status) {
    switch (status.toLowerCase()) {
      case 'valid':
        return 'PASS VALID';
      case 'consumed':
        return 'ENTRIES CONSUMED';
      case 'invalid':
        return 'INVALID PASS';
      case 'used':
        return 'PASS ALREADY USED';
      case 'blocked':
        return 'THIS PASS IS BLOCKED';
      case 'expired':
        return 'PASS EXPIRED';
      case 'error':
        return 'VERIFICATION ERROR';
      default:
        return status.toUpperCase();
    }
  }

  IconData _getPassTypeIcon(String passType) {
    switch (passType.toLowerCase()) {
      case 'session':
        return Icons.access_time;
      case 'daily':
        return Icons.today;
      case 'weekly':
        return Icons.date_range;
      case 'monthly':
        return Icons.calendar_month;
      case 'annual':
        return Icons.calendar_today;
      case 'unlimited':
      case 'all_access':
        return Icons.all_inclusive;
      default:
        return Icons.card_membership;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'valid':
      case 'consumed':
        return Icons.check_circle;
      case 'used':
      case 'expired':
        return Icons.access_time;
      case 'blocked':
      case 'invalid':
      case 'error':
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }

  String _getStatusMessage(String status) {
    switch (status.toLowerCase()) {
      case 'valid':
        return 'Pass is valid and active';
      case 'consumed':
        return 'Pass has been successfully used';
      case 'used':
        return 'Pass has already been used';
      case 'expired':
        return 'Pass has expired';
      case 'blocked':
        return 'Pass has been blocked';
      case 'invalid':
        return 'Pass is not valid';
      case 'error':
        return 'Verification failed';
      default:
        return 'Status unknown';
    }
  }

  /// Enhanced color scheme with better contrast and modern palette
  Color _getEnhancedCategoryColor(String? category, String? passType) {
    if (category == null) return Colors.grey;

    final categoryLower = category.toLowerCase();

    // Special color for unlimited passes
    if (passType == 'unlimited') {
      return const Color(0xFF1A1A2E); // Deep dark blue
    }

    // Enhanced category colors with better contrast
    switch (categoryLower) {
      case 'silver':
        return const Color(0xFF2C3E50); // Dark blue-gray
      case 'gold a':
        return const Color(0xFFE67E22); // Vibrant orange
      case 'gold b':
        return const Color(0xFFD35400); // Dark orange
      case 'platinum a':
        return const Color(0xFF7F8C8D); // Blue-gray
      case 'platinum b':
        return const Color(0xFF27AE60); // Green
      case 'diamond':
        return const Color(0xFF3498DB); // Blue
      case 'all access':
        return const Color(0xFF2C2C54); // Deep purple
      default:
        return const Color(0xFF34495E); // Dark blue-gray
    }
  }

  /// Special design for unlimited passes with infinity symbol
  Widget _buildUnlimitedDesign(Color textColor, bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 24 : 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Infinity symbol
          Container(
            width: isMobile ? 120 : 140,
            height: isMobile ? 120 : 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: textColor.withOpacity(0.3), width: 2),
            ),
            child: Center(
              child: Text(
                '∞',
                style: TextStyle(
                  fontSize: isMobile ? 60 : 70,
                  fontWeight: FontWeight.w300,
                  color: textColor,
                  fontFamily: 'serif',
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // "UNLIMITED" text
          Text(
            'UNLIMITED',
            style: TextStyle(
              fontSize: isMobile ? 18 : 20,
              fontWeight: FontWeight.w600,
              color: textColor,
              letterSpacing: 2,
            ),
          ),

          const SizedBox(height: 8),

          // Category name (small)
          if (widget.passInfo?.category != null)
            Text(
              widget.passInfo!.category.toUpperCase(),
              style: TextStyle(
                fontSize: isMobile ? 12 : 14,
                fontWeight: FontWeight.w400,
                color: textColor.withOpacity(0.7),
                letterSpacing: 1,
              ),
            ),

          const SizedBox(height: 24),

          // UID (very small)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: textColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              widget.uid,
              style: TextStyle(
                fontSize: isMobile ? 10 : 11,
                fontWeight: FontWeight.w500,
                color: textColor.withOpacity(0.8),
                fontFamily: 'monospace',
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Close button
          _buildCloseButton(textColor, isMobile),
        ],
      ),
    );
  }
}
