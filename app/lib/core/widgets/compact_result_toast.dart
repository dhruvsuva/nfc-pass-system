import 'package:flutter/material.dart';
import '../utils/responsive_utils.dart';

class CompactResultToast extends StatefulWidget {
  final String status;
  final String message;
  final String? uid;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;

  const CompactResultToast({
    Key? key,
    required this.status,
    required this.message,
    this.uid,
    this.onTap,
    this.onDismiss,
  }) : super(key: key);

  @override
  State<CompactResultToast> createState() => _CompactResultToastState();
}

class _CompactResultToastState extends State<CompactResultToast>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Color _getStatusColor() {
    switch (widget.status.toLowerCase()) {
      case 'valid':
        return Colors.green;
      case 'invalid':
        return Colors.red;
      case 'expired':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon() {
    switch (widget.status.toLowerCase()) {
      case 'valid':
        return Icons.check_circle;
      case 'invalid':
        return Icons.cancel;
      case 'expired':
        return Icons.access_time;
      default:
        return Icons.info;
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
    final statusColor = _getStatusColor();
    final statusIcon = _getStatusIcon();

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: GestureDetector(
              onTap: widget.onTap,
              child: Container(
                margin: EdgeInsets.only(
                  right: ResponsiveSpacing.getHorizontalPadding(context),
                  top: ResponsiveSpacing.getVerticalPadding(context),
                ),
                padding: EdgeInsets.all(ResponsiveSpacing.getCardPadding(context)),
                constraints: BoxConstraints(
                  maxWidth: ResponsiveBreakpoints.getResponsiveValue(
                    context,
                    mobile: 280,
                    tablet: 320,
                    desktop: 360,
                    largeDesktop: 400,
                  ),
                  minWidth: ResponsiveBreakpoints.getResponsiveValue(
                    context,
                    mobile: 200,
                    tablet: 240,
                    desktop: 280,
                    largeDesktop: 320,
                  ),
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(ResponsiveSpacing.getBorderRadius(context)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: statusColor.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Adjust spacing based on available width and responsive breakpoints
                    final isVeryConstrained = constraints.maxWidth < 120;
                    final horizontalSpacing = ResponsiveSpacing.getSpacing(
                      context,
                      mobile: isVeryConstrained ? 4.0 : 8.0,
                      tablet: 10.0,
                      desktop: 12.0,
                      largeDesktop: 14.0,
                    );
                    final iconSpacing = ResponsiveSpacing.getSpacing(
                      context,
                      mobile: isVeryConstrained ? 6.0 : 10.0,
                      tablet: 12.0,
                      desktop: 14.0,
                      largeDesktop: 16.0,
                    );
                    
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: EdgeInsets.all(
                            ResponsiveSpacing.getSpacing(
                              context,
                              mobile: isVeryConstrained ? 4 : 6,
                              tablet: 8,
                              desktop: 10,
                              largeDesktop: 12,
                            ),
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(ResponsiveSpacing.getBorderRadius(context) / 2),
                          ),
                          child: Icon(
                            statusIcon,
                            color: statusColor,
                            size: ResponsiveSpacing.getIconSize(context),
                          ),
                        ),
                        SizedBox(width: iconSpacing),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.status.toUpperCase(),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: statusColor,
                                  fontSize: ResponsiveText.getCaptionSize(
                                    context,
                                  ) + (isVeryConstrained ? -2 : 0),
                                  decoration: TextDecoration.none,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: ResponsiveSpacing.getSpacing(context) / 4),
                              Text(
                                widget.message,
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontSize: ResponsiveText.getCaptionSize(
                                    context,
                                  ) - (isVeryConstrained ? 2 : 1),
                                  decoration: TextDecoration.none,
                                ),
                                maxLines: isVeryConstrained ? 1 : 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (widget.uid != null && !isVeryConstrained) ...[
                                SizedBox(height: ResponsiveSpacing.getSpacing(context) / 4),
                                Text(
                                  'UID: ${widget.uid!.substring(0, 8)}...',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: ResponsiveText.getCaptionSize(context) - 2,
                                    decoration: TextDecoration.none,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                        SizedBox(width: horizontalSpacing),
                        GestureDetector(
                          onTap: _dismiss,
                          child: Container(
                            padding: EdgeInsets.all(
                              ResponsiveSpacing.getSpacing(
                                context,
                                mobile: isVeryConstrained ? 2 : 4,
                                tablet: 6,
                                desktop: 8,
                                largeDesktop: 10,
                              ),
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(ResponsiveSpacing.getBorderRadius(context) / 3),
                            ),
                            child: Icon(
                              Icons.close,
                              color: Colors.grey[600],
                              size: ResponsiveSpacing.getIconSize(context),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}