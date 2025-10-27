import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/spacing_utils.dart';
import '../utils/responsive_utils.dart';

/// Consistent loading indicator widget for the app
class LoadingIndicator extends StatelessWidget {
  final String? message;
  final bool showMessage;
  final Color? color;
  final double? size;

  const LoadingIndicator({
    super.key,
    this.message,
    this.showMessage = true,
    this.color,
    this.size,
  });

  @override
  Widget build(BuildContext context) {
    final indicatorColor = color ?? AppTheme.primaryColor;
    final indicatorSize = size ?? ResponsiveSpacing.getIconSize(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: indicatorSize,
            height: indicatorSize,
            child: CircularProgressIndicator(
              color: indicatorColor,
              strokeWidth: 3.0,
            ),
          ),
          if (showMessage) ...[
            AppSpacing.responsiveVerticalSpace(
              context,
              mobile: AppSpacing.md,
              tablet: AppSpacing.lg,
              desktop: AppSpacing.lg,
            ),
            Text(
              message ?? 'Loading...',
              style: AppTheme.getBodyStyle(context).copyWith(
                color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

/// Loading overlay that can be shown over existing content
class LoadingOverlay extends StatelessWidget {
  final Widget child;
  final bool isLoading;
  final String? loadingMessage;
  final Color? overlayColor;

  const LoadingOverlay({
    super.key,
    required this.child,
    required this.isLoading,
    this.loadingMessage,
    this.overlayColor,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: overlayColor ?? Colors.black.withOpacity(0.3),
            child: LoadingIndicator(
              message: loadingMessage,
            ),
          ),
      ],
    );
  }
}

/// Small loading indicator for buttons and inline use
class SmallLoadingIndicator extends StatelessWidget {
  final Color? color;
  final double? size;

  const SmallLoadingIndicator({
    super.key,
    this.color,
    this.size,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size ?? 16.0,
      height: size ?? 16.0,
      child: CircularProgressIndicator(
        color: color ?? Colors.white,
        strokeWidth: 2.0,
      ),
    );
  }
}

/// Loading card for list items
class LoadingCard extends StatelessWidget {
  final double? height;
  final EdgeInsets? margin;

  const LoadingCard({
    super.key,
    this.height,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: margin ?? AppSpacing.getCardPaddingEdgeInsets(context),
      child: Container(
        height: height ?? 120.0,
        padding: AppSpacing.getCardPaddingEdgeInsets(context),
        child: const LoadingIndicator(
          showMessage: false,
        ),
      ),
    );
  }
}

/// Shimmer loading effect for content placeholders
class ShimmerLoading extends StatefulWidget {
  final Widget child;
  final bool isLoading;
  final Color? baseColor;
  final Color? highlightColor;

  const ShimmerLoading({
    super.key,
    required this.child,
    required this.isLoading,
    this.baseColor,
    this.highlightColor,
  });

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    if (widget.isLoading) {
      _animationController.repeat();
    }
  }

  @override
  void didUpdateWidget(ShimmerLoading oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoading && !oldWidget.isLoading) {
      _animationController.repeat();
    } else if (!widget.isLoading && oldWidget.isLoading) {
      _animationController.stop();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isLoading) {
      return widget.child;
    }

    final baseColor = widget.baseColor ?? Colors.grey[300]!;
    final highlightColor = widget.highlightColor ?? Colors.grey[100]!;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [baseColor, highlightColor, baseColor],
              stops: [
                (_animation.value - 1).clamp(0.0, 1.0),
                _animation.value.clamp(0.0, 1.0),
                (_animation.value + 1).clamp(0.0, 1.0),
              ],
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
    );
  }
}

/// Loading state for entire pages
class PageLoadingState extends StatelessWidget {
  final String? title;
  final String? message;
  final VoidCallback? onRetry;
  final String? retryButtonText;

  const PageLoadingState({
    super.key,
    this.title,
    this.message,
    this.onRetry,
    this.retryButtonText,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.getPagePaddingEdgeInsets(context),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              LoadingIndicator(
                message: title ?? 'Loading',
              ),
              if (message != null) ...[
                AppSpacing.responsiveVerticalSpace(
                  context,
                  mobile: AppSpacing.lg,
                  tablet: AppSpacing.xl,
                  desktop: AppSpacing.xl,
                ),
                Text(
                  message!,
                  style: AppTheme.getBodyStyle(context).copyWith(
                    color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              if (onRetry != null) ...[
                AppSpacing.responsiveVerticalSpace(
                  context,
                  mobile: AppSpacing.xl,
                  tablet: AppSpacing.xxl,
                  desktop: AppSpacing.xxl,
                ),
                ElevatedButton(
                  onPressed: onRetry,
                  child: Text(retryButtonText ?? 'Retry'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}