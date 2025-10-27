import 'package:flutter/material.dart';
import '../theme/theme_manager.dart';
import '../theme/app_theme.dart';

class ThemeToggleButton extends StatefulWidget {
  final bool showLabel;
  final double? iconSize;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final BorderRadius? borderRadius;
  
  const ThemeToggleButton({
    super.key,
    this.showLabel = false,
    this.iconSize,
    this.padding,
    this.backgroundColor,
    this.foregroundColor,
    this.borderRadius,
  });

  @override
  State<ThemeToggleButton> createState() => _ThemeToggleButtonState();
}

class _ThemeToggleButtonState extends State<ThemeToggleButton>
    with TickerProviderStateMixin {
  late ThemeManager _themeManager;
  late AnimationController _animationController;
  late Animation<double> _rotationAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _themeManager = ThemeManager();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleTheme() async {
    // Start animation
    _animationController.forward().then((_) {
      _animationController.reverse();
    });
    
    // Toggle theme
    await _themeManager.toggleTheme();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _themeManager,
      builder: (context, child) {
        final isDark = _themeManager.isDarkMode;
        final theme = Theme.of(context);
        
        if (widget.showLabel) {
          return _buildButtonWithLabel(isDark, theme);
        } else {
          return _buildIconButton(isDark, theme);
        }
      },
    );
  }

  Widget _buildIconButton(bool isDark, ThemeData theme) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Transform.rotate(
            angle: _rotationAnimation.value * 2 * 3.14159,
            child: IconButton(
              onPressed: _toggleTheme,
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) {
                  return RotationTransition(
                    turns: animation,
                    child: child,
                  );
                },
                child: Icon(
                  _themeManager.themeModeIcon,
                  key: ValueKey(_themeManager.themeMode),
                  size: widget.iconSize ?? 24,
                  color: widget.foregroundColor ?? theme.iconTheme.color,
                ),
              ),
              padding: widget.padding ?? const EdgeInsets.all(8),
              style: IconButton.styleFrom(
                backgroundColor: widget.backgroundColor,
                shape: RoundedRectangleBorder(
                  borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
                ),
              ),
              tooltip: 'Switch to ${isDark ? 'Light' : 'Dark'} Mode',
            ),
          ),
        );
      },
    );
  }

  Widget _buildButtonWithLabel(bool isDark, ThemeData theme) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: ElevatedButton.icon(
            onPressed: _toggleTheme,
            icon: Transform.rotate(
              angle: _rotationAnimation.value * 2 * 3.14159,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) {
                  return RotationTransition(
                    turns: animation,
                    child: child,
                  );
                },
                child: Icon(
                  _themeManager.themeModeIcon,
                  key: ValueKey(_themeManager.themeMode),
                  size: widget.iconSize ?? 20,
                ),
              ),
            ),
            label: Text(_themeManager.themeModeDisplayName),
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.backgroundColor,
              foregroundColor: widget.foregroundColor,
              padding: widget.padding ?? const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A compact theme toggle switch widget
class ThemeToggleSwitch extends StatefulWidget {
  final double? width;
  final double? height;
  final Color? activeColor;
  final Color? inactiveColor;
  final Color? thumbColor;
  
  const ThemeToggleSwitch({
    super.key,
    this.width,
    this.height,
    this.activeColor,
    this.inactiveColor,
    this.thumbColor,
  });

  @override
  State<ThemeToggleSwitch> createState() => _ThemeToggleSwitchState();
}

class _ThemeToggleSwitchState extends State<ThemeToggleSwitch>
    with TickerProviderStateMixin {
  late ThemeManager _themeManager;
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _themeManager = ThemeManager();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _slideAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    // Set initial animation state
    if (_themeManager.isDarkMode) {
      _animationController.value = 1.0;
    }
    
    _themeManager.addListener(_onThemeChanged);
  }

  void _onThemeChanged() {
    if (_themeManager.isDarkMode) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  @override
  void dispose() {
    _themeManager.removeListener(_onThemeChanged);
    _animationController.dispose();
    super.dispose();
  }

  void _toggleTheme() async {
    await _themeManager.toggleTheme();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = widget.width ?? 60.0;
    final height = widget.height ?? 30.0;
    final thumbSize = height - 4;
    
    return GestureDetector(
      onTap: _toggleTheme,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(height / 2),
              color: Color.lerp(
                widget.inactiveColor ?? theme.colorScheme.outline,
                widget.activeColor ?? theme.colorScheme.primary,
                _slideAnimation.value,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Background icons
                Positioned(
                  left: 6,
                  top: (height - 16) / 2,
                  child: Icon(
                    Icons.light_mode,
                    size: 16,
                    color: Colors.white.withOpacity(
                      1.0 - _slideAnimation.value,
                    ),
                  ),
                ),
                Positioned(
                  right: 6,
                  top: (height - 16) / 2,
                  child: Icon(
                    Icons.dark_mode,
                    size: 16,
                    color: Colors.white.withOpacity(_slideAnimation.value),
                  ),
                ),
                // Thumb
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  left: _slideAnimation.value * (width - thumbSize - 4) + 2,
                  top: 2,
                  child: Container(
                    width: thumbSize,
                    height: thumbSize,
                    decoration: BoxDecoration(
                      color: widget.thumbColor ?? Colors.white,
                      borderRadius: BorderRadius.circular(thumbSize / 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Icon(
                      _themeManager.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                      size: thumbSize * 0.6,
                      color: _themeManager.isDarkMode 
                          ? theme.colorScheme.primary 
                          : Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}