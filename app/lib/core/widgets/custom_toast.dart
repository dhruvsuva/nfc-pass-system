import 'dart:async';
import 'package:flutter/material.dart';
import '../utils/responsive_utils.dart';

enum CustomToastType {
  success,
  error,
  warning,
  info,
}

class CustomToast extends StatefulWidget {
  final String message;
  final CustomToastType type;
  final Duration duration;
  final VoidCallback? onDismiss;
  final bool showCloseButton;

  const CustomToast({
    Key? key,
    required this.message,
    required this.type,
    this.duration = const Duration(seconds: 5),
    this.onDismiss,
    this.showCloseButton = true,
  }) : super(key: key);

  @override
  State<CustomToast> createState() => _CustomToastState();

  /// Show a custom toast overlay
  static OverlayEntry? _currentOverlay;
  static Timer? _dismissTimer;

  static void show(
    BuildContext context, {
    required String message,
    required CustomToastType type,
    Duration duration = const Duration(seconds: 5),
    bool showCloseButton = true,
  }) {
    // Remove any existing toast
    dismiss();

    // Use overlay for top right positioning
    _showOverlayToast(context, message, type, duration, showCloseButton);
  }

  static void _showOverlayToast(
    BuildContext context,
    String message,
    CustomToastType type,
    Duration duration,
    bool showCloseButton,
  ) {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) {
      // Fallback to SnackBar if no overlay available
      _showSnackBarToast(context, message, type, duration);
      return;
    }
    final mediaQuery = MediaQuery.of(context);
    
    _currentOverlay = OverlayEntry(
      builder: (context) => Positioned(
        top: mediaQuery.padding.top + 20, // Safe area + spacing
        right: 16,
        child: Material(
          color: Colors.transparent,
          elevation: 0,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: mediaQuery.size.width > 600 
                  ? 400 // Fixed width for larger screens
                  : mediaQuery.size.width - 32, // Responsive for mobile
            ),
            child: CustomToast(
              message: message,
              type: type,
              duration: duration,
              showCloseButton: showCloseButton,
              onDismiss: dismiss,
            ),
          ),
        ),
      ),
    );

    overlay.insert(_currentOverlay!);

    // Auto dismiss after duration
    _dismissTimer = Timer(duration, () {
      dismiss();
    });
  }

  static void _showSnackBarToast(
    BuildContext context,
    String message,
    CustomToastType type,
    Duration duration,
  ) {
    // Get the current ScaffoldMessenger and clear any existing SnackBars
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.clearSnackBars();
    
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              _getIconForType(type),
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        duration: duration,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 20,
          right: 16,
          left: 16,
          bottom: MediaQuery.of(context).size.height - 200,
        ),
        action: SnackBarAction(
          label: '✕',
          textColor: Colors.white,
          onPressed: () {
            scaffoldMessenger.clearSnackBars();
          },
        ),
      ),
    );
  }

  static IconData _getIconForType(CustomToastType type) {
    switch (type) {
      case CustomToastType.success:
        return Icons.check_circle_rounded;
      case CustomToastType.error:
        return Icons.error_rounded;
      case CustomToastType.warning:
        return Icons.warning_rounded;
      case CustomToastType.info:
        return Icons.info_rounded;
    }
  }

  static void dismiss() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    _currentOverlay?.remove();
    _currentOverlay = null;
  }

  // Convenience methods
  static void showSuccess(BuildContext context, String message, {Duration? duration}) {
    show(context, message: message, type: CustomToastType.success, duration: duration ?? const Duration(seconds: 3));
  }

  static void showError(BuildContext context, String message, {Duration? duration}) {
    show(context, message: message, type: CustomToastType.error, duration: duration ?? const Duration(seconds: 5));
  }

  static void showWarning(BuildContext context, String message, {Duration? duration}) {
    show(context, message: message, type: CustomToastType.warning, duration: duration ?? const Duration(seconds: 4));
  }

  static void showInfo(BuildContext context, String message, {Duration? duration}) {
    show(context, message: message, type: CustomToastType.info, duration: duration ?? const Duration(seconds: 3));
  }

  static Color _getBackgroundColor(CustomToastType type) {
    switch (type) {
      case CustomToastType.success:
        return const Color(0xFF10B981); // Green-500
      case CustomToastType.error:
        return const Color(0xFFEF4444); // Red-500
      case CustomToastType.warning:
        return const Color(0xFFF59E0B); // Amber-500
      case CustomToastType.info:
        return const Color(0xFF3B82F6); // Blue-500
    }
  }
}

class _CustomToastState extends State<CustomToast>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _countdownController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _countdownAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );

    _countdownController = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.2, 0.0), // Slide from right
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));

    _countdownAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _countdownController,
      curve: Curves.linear,
    ));

    _animationController.forward();
    _countdownController.forward();

    // Auto dismiss when countdown completes
    _countdownController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _dismiss();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _countdownController.dispose();
    super.dispose();
  }

  Color _getBackgroundColor() {
    switch (widget.type) {
      case CustomToastType.success:
        return const Color(0xFF10B981); // Green-500
      case CustomToastType.error:
        return const Color(0xFFEF4444); // Red-500
      case CustomToastType.warning:
        return const Color(0xFFF59E0B); // Amber-500
      case CustomToastType.info:
        return const Color(0xFF3B82F6); // Blue-500
    }
  }

  IconData _getIcon() {
    switch (widget.type) {
      case CustomToastType.success:
        return Icons.check_circle_rounded;
      case CustomToastType.error:
        return Icons.error_rounded;
      case CustomToastType.warning:
        return Icons.warning_rounded;
      case CustomToastType.info:
        return Icons.info_rounded;
    }
  }

  void _dismiss() {
    _animationController.reverse().then((_) {
      if (widget.onDismiss != null) {
        widget.onDismiss!();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = _getBackgroundColor();
    final icon = _getIcon();

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    // Primary shadow for depth
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                      spreadRadius: 0,
                    ),
                    // Secondary shadow for definition
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                      spreadRadius: 0,
                    ),
                    // Subtle top highlight
                    BoxShadow(
                      color: Colors.white.withOpacity(0.8),
                      blurRadius: 1,
                      offset: const Offset(0, -1),
                      spreadRadius: 0,
                    ),
                  ],
                  border: Border.all(
                    color: backgroundColor.withOpacity(0.15),
                    width: 0.5,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: backgroundColor,
                          width: 4,
                        ),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Icon
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: backgroundColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              icon,
                              color: backgroundColor,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Message
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                widget.message,
                                style: TextStyle(
                                  color: const Color(0xFF111827), // Gray-900
                                  fontSize: ResponsiveText.getBodySize(context),
                                  fontWeight: FontWeight.w600,
                                  height: 1.5,
                                  letterSpacing: 0.2,
                                ),
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          // Close button with countdown
                          if (widget.showCloseButton) ...[
                            const SizedBox(width: 12),
                            GestureDetector(
                              onTap: _dismiss,
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF9FAFB), // Gray-50
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: const Color(0xFFE5E7EB), // Gray-200
                                    width: 0.5,
                                  ),
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    // Countdown progress circle
                                    AnimatedBuilder(
                                      animation: _countdownAnimation,
                                      builder: (context, child) {
                                        return SizedBox(
                                          width: 36,
                                          height: 36,
                                          child: CircularProgressIndicator(
                                            value: _countdownAnimation.value,
                                            strokeWidth: 2,
                                            backgroundColor: const Color(0xFFE5E7EB),
                                            valueColor: AlwaysStoppedAnimation<Color>(
                                              backgroundColor.withOpacity(0.6),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    // Close icon
                                    const Icon(
                                      Icons.close_rounded,
                                      color: Color(0xFF6B7280), // Gray-500
                                      size: 16,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}