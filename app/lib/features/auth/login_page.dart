import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../core/router/app_router.dart';
import '../../core/utils/responsive_utils.dart';
import '../../core/services/toast_service.dart';
import 'providers/auth_provider.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  String? _errorType;

  @override
  void initState() {
    super.initState();
    // Clear any existing error messages when page loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _errorMessage = null;
          _errorType = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Clear previous errors
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _errorType = null;
    });

    try {
      print('Attempting login for user: ${_usernameController.text.trim()}');
      
      final success = await authProvider.login(
        _usernameController.text.trim(),
        _passwordController.text,
      );

      if (success && mounted) {
        final user = authProvider.state.user;
        if (user != null) {
          print('Login successful for user: ${user.username} with role: ${user.role}');
          ToastService.showSuccess('Welcome back, ${user.username}!');
          _navigateToDashboard(user.role);
        } else {
          _showError('Login failed - User data not found', 'error');
        }
      } else {
        final error = authProvider.state.error ?? 'Login failed';
        print('Login failed with error: $error');
        _showError(error, 'error');
      }
    } catch (e) {
      print('Login exception: $e');
      _showError('Network error. Please check your connection and try again.', 'network');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showError(String message, String type) {
    setState(() {
      _errorMessage = message;
      _errorType = type;
    });
  }

  void _clearError() {
    setState(() {
      _errorMessage = null;
      _errorType = null;
    });
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
        _showError('Invalid user role. Please contact administrator.', 'error');
        return;
    }
    
    AppRouter.pushAndClearStack(context, route);
  }

  Color _getErrorColor() {
    switch (_errorType) {
      case 'network':
        return Colors.orange;
      case 'blocked':
        return Colors.red;
      case 'error':
      default:
        return AppTheme.errorColor;
    }
  }

  IconData _getErrorIcon() {
    switch (_errorType) {
      case 'network':
        return Icons.wifi_off;
      case 'blocked':
        return Icons.block;
      case 'error':
      default:
        return Icons.error_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primaryColor.withOpacity(0.1),
              AppTheme.secondaryColor.withOpacity(0.05),
            ],
          ),
        ),
        child: SafeArea(
          child: ResponsiveLayout.buildResponsiveContainer(
            context: context,
            maxWidth: ResponsiveBreakpoints.getResponsiveValue(
              context,
              mobile: double.infinity,
              tablet: 500.0,
              desktop: 450.0,
              largeDesktop: 500.0,
            ),
            child: Center(
              child: SingleChildScrollView(
                padding: ResponsiveSpacing.getPagePadding(context),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(height: ResponsiveSpacing.getVerticalPadding(context) * 2.5),
                      
                      // Logo
                      Container(
                        width: ResponsiveSpacing.getIconSize(context) * 6,
                        height: ResponsiveSpacing.getIconSize(context) * 6,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          borderRadius: BorderRadius.circular(ResponsiveSpacing.getBorderRadius(context)),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryColor.withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.nfc,
                          size: ResponsiveSpacing.getIconSize(context) * 3,
                          color: Colors.white,
                        ),
                      ),
                      
                      SizedBox(height: ResponsiveSpacing.getSpacing(context, 
                        mobile: 32, tablet: 40, desktop: 48)),
                      
                      // App Title
                      Text(
                        'NFC Pass System',
                        style: ResponsiveText.getHeadlineStyle(context).copyWith(
                          color: AppTheme.primaryColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      
                      SizedBox(height: ResponsiveSpacing.getSpacing(context)),
                      
                      // Subtitle
                      Text(
                        'Secure Access Management',
                        style: ResponsiveText.getBodyStyle(context).copyWith(
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      
                      SizedBox(height: ResponsiveSpacing.getSpacing(context, 
                        mobile: 48, tablet: 56, desktop: 64)),

                      // Username Field
                      TextFormField(
                        controller: _usernameController,
                        style: ResponsiveText.getBodyStyle(context),
                        decoration: InputDecoration(
                          labelText: 'Username',
                          labelStyle: ResponsiveText.getBodyStyle(context),
                          prefixIcon: Icon(Icons.person_outline, 
                            size: ResponsiveSpacing.getIconSize(context)),
                          hintText: 'Enter your username',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(ResponsiveSpacing.getBorderRadius(context)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(ResponsiveSpacing.getBorderRadius(context)),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(ResponsiveSpacing.getBorderRadius(context)),
                            borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: ResponsiveSpacing.getHorizontalPadding(context),
                            vertical: ResponsiveSpacing.getVerticalPadding(context),
                          ),
                        ),
                        textInputAction: TextInputAction.next,
                        onChanged: (_) => _clearError(),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your username';
                          }
                          if (value.trim().length < 3) {
                            return 'Username must be at least 3 characters';
                          }
                          return null;
                        },
                      ),

                      SizedBox(height: ResponsiveSpacing.getSpacing(context, mobile: 16, tablet: 20, desktop: 24)),

                      // Password Field
                      TextFormField(
                        controller: _passwordController,
                        style: ResponsiveText.getBodyStyle(context),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          labelStyle: ResponsiveText.getBodyStyle(context),
                          prefixIcon: Icon(Icons.lock_outline, 
                            size: ResponsiveSpacing.getIconSize(context)),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off : Icons.visibility,
                              size: ResponsiveSpacing.getIconSize(context),
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                          hintText: 'Enter your password',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(ResponsiveSpacing.getBorderRadius(context)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(ResponsiveSpacing.getBorderRadius(context)),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(ResponsiveSpacing.getBorderRadius(context)),
                            borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: ResponsiveSpacing.getHorizontalPadding(context),
                            vertical: ResponsiveSpacing.getVerticalPadding(context),
                          ),
                        ),
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _handleLogin(),
                        onChanged: (_) => _clearError(),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your password';
                          }
                          if (value.length < 4) {
                            return 'Password must be at least 4 characters';
                          }
                          return null;
                        },
                      ),

                      SizedBox(height: ResponsiveSpacing.getSpacing(context, mobile: 24, tablet: 32, desktop: 40)),

                      // Error Message
                      if (_errorMessage != null)
                        Container(
                          padding: const EdgeInsets.all(16),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: _getErrorColor().withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _getErrorColor().withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _getErrorIcon(),
                                color: _getErrorColor(),
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _errorType == 'network' ? 'Connection Error' : 
                                      _errorType == 'blocked' ? 'Account Blocked' : 'Login Error',
                                      style: ResponsiveText.getBodyStyle(context).copyWith(
                                        color: _getErrorColor(),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _errorMessage!,
                                      style: ResponsiveText.getCaptionStyle(context).copyWith(
                                        color: _getErrorColor(),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.close,
                                  color: _getErrorColor(),
                                  size: 20,
                                ),
                                onPressed: _clearError,
                              ),
                            ],
                          ),
                        ),

                      // Login Button
                      SizedBox(
                        width: double.infinity,
                        height: ResponsiveBreakpoints.getResponsiveValue(
                          context,
                          mobile: 48.0,
                          tablet: 52.0,
                          desktop: 56.0,
                          largeDesktop: 60.0,
                        ),
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            elevation: 2,
                            shadowColor: AppTheme.primaryColor.withOpacity(0.3),
                            padding: EdgeInsets.symmetric(
                              vertical: ResponsiveSpacing.getVerticalPadding(context) * 0.8,
                              horizontal: ResponsiveSpacing.getHorizontalPadding(context),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(ResponsiveSpacing.getBorderRadius(context)),
                            ),
                          ),
                          child: _isLoading
                              ? SizedBox(
                                  height: ResponsiveSpacing.getIconSize(context),
                                  width: ResponsiveSpacing.getIconSize(context),
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  'Sign In',
                                  style: ResponsiveText.getBodyStyle(context).copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),

                      SizedBox(height: ResponsiveSpacing.getSpacing(context, mobile: 32, tablet: 40, desktop: 48)),
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
}