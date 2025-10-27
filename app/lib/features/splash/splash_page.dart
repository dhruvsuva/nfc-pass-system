import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/router/app_router.dart';
import '../../core/utils/responsive_utils.dart';
import '../auth/providers/auth_provider.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _checkAuthAndNavigate();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _animationController.forward();
  }

  Future<void> _checkAuthAndNavigate() async {
    // Wait for splash duration
    await Future.delayed(AppConfig.splashDuration);

    if (!mounted) return;

    try {
      // Check authentication status
      final authState = authProvider.state;
      
      if (authState.isAuthenticated && authState.user != null) {
        // Navigate to appropriate dashboard based on role
        _navigateToDashboard(authState.user!.role);
      } else {
        // Try to auto-authenticate with stored tokens
        await authProvider.loadStoredAuth();
        
        if (mounted) {
          final user = authProvider.state.user;
          if (user != null) {
            _navigateToDashboard(user.role);
          } else {
            _navigateToLogin();
          }
        } else {
          _navigateToLogin();
        }
      }
    } catch (e) {
      print('Error during auto-authentication: $e');
      if (mounted) {
        _navigateToLogin();
      }
    }
  }

  void _navigateToDashboard(String role) {
    String route;
    switch (role) {
      case 'admin':
        route = AppRouter.adminDashboard;
        break;
      case 'manager':
        route = AppRouter.managerDashboard;
        break;
      case 'bouncer':
        route = AppRouter.bouncerDashboard;
        break;
      default:
        route = AppRouter.login;
    }
    
    AppRouter.pushReplacement(context, route);
  }

  void _navigateToLogin() {
    AppRouter.pushReplacement(context, AppRouter.login);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryColor,
      body: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // App Logo/Icon
                    Container(
                      width: ResponsiveSpacing.getIconSize(context) * 6,
                      height: ResponsiveSpacing.getIconSize(context) * 6,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(ResponsiveSpacing.getBorderRadius(context) * 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.nfc,
                        size: ResponsiveSpacing.getIconSize(context) * 3,
                        color: const Color(0xFF2196F3),
                      ),
                    ),
                    
                    SizedBox(height: ResponsiveSpacing.getSpacing(context, 
                      mobile: 32, tablet: 40, desktop: 48)),
                    
                    // App Name
                    Text(
                      AppConfig.appName,
                      style: ResponsiveText.getHeadlineStyle(context).copyWith(
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    SizedBox(height: ResponsiveSpacing.getSpacing(context)),
                    
                    // App Version
                    Text(
                      'Version ${AppConfig.appVersion}',
                      style: ResponsiveText.getBodyStyle(context).copyWith(
                        color: Colors.white.withOpacity(0.8),
                        fontWeight: FontWeight.w300,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    SizedBox(height: ResponsiveSpacing.getSpacing(context, 
                      mobile: 48, tablet: 56, desktop: 64)),
                    
                    // Loading Indicator
                    SizedBox(
                      width: ResponsiveSpacing.getIconSize(context) * 2,
                      height: ResponsiveSpacing.getIconSize(context) * 2,
                      child: const CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    ),
                    
                    SizedBox(height: ResponsiveSpacing.getSpacing(context, 
                      mobile: 16, tablet: 20, desktop: 24)),
                    
                    // Loading Text
                    Text(
                      'Initializing...',
                      style: ResponsiveText.getBodyStyle(context).copyWith(
                        color: Colors.white.withOpacity(0.9),
                        fontWeight: FontWeight.w400,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}