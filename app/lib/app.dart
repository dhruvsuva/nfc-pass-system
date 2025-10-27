import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/config/app_config.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/network/http_interceptor.dart';
import 'core/services/toast_service.dart';
import 'features/splash/splash_page.dart';

class NFCPassApp extends StatefulWidget {
  const NFCPassApp({super.key});

  @override
  State<NFCPassApp> createState() => _NFCPassAppState();
}

class _NFCPassAppState extends State<NFCPassApp> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Update app colors for light theme only
    AppTheme.updateColors(false); // Always light mode
    
    // Set system UI overlay style for light theme
    _updateSystemUI();
  }

  void _updateSystemUI() {
    // Always use light theme system UI
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarBrightness: Brightness.dark,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      theme: AppTheme.lightTheme,
      themeMode: ThemeMode.light, // Force light mode only
      onGenerateRoute: AppRouter.generateRoute,
      home: const SplashPage(),
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        // Initialize HttpInterceptor with global context for navigation
        HttpInterceptor.setGlobalContext(context);
        
        // Initialize ToastService with global context for custom toasts
        ToastService.setContext(context);
        
        // Ensure responsive design works on all screen sizes
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaleFactor: MediaQuery.of(context).textScaleFactor.clamp(0.8, 1.2),
          ),
          child: child!,
        );
      },
    );
  }
}