import 'package:flutter/material.dart';

import '../../features/splash/splash_page.dart';
import '../../features/auth/login_page.dart';
import '../../features/dashboard/admin_dashboard.dart';
import '../../features/dashboard/manager_dashboard.dart';
import '../../features/dashboard/bouncer_dashboard.dart';
import '../../features/pass/create_pass_page.dart';
import '../../features/pass/bulk_pass_page.dart';
import '../../features/pass/verify_page.dart';
import '../../features/pass/pass_list_page.dart';
import '../../features/logs/logs_page.dart';
import '../../features/admin/reset_daily_page.dart';
import '../../features/admin/user_management_page.dart';
import '../../features/admin/reset_single_page.dart';
import '../../features/admin/settings_page.dart';
import '../../features/admin/category_management_page.dart';
import '../../features/pass/pass_details_page.dart';

class AppRouter {
  static const String splash = '/';
  static const String login = '/login';
  static const String adminDashboard = '/admin-dashboard';
  static const String managerDashboard = '/manager-dashboard';
  static const String bouncerDashboard = '/bouncer-dashboard';
  static const String createPass = '/create-pass';
  static const String bulkPass = '/bulk-pass';
  static const String verify = '/verify';
  static const String passList = '/pass-list';
  static const String logs = '/logs';
  static const String resetDaily = '/reset-daily';
  static const String resetSingle = '/reset-single';
  static const String userManagement = '/user-management';
  static const String categoryManagement = '/category-management';
  static const String settings = '/settings';
  static const String passDetails = '/pass-details';
  
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute(builder: (_) => const SplashPage());
      
      case login:
        return MaterialPageRoute(builder: (_) => const LoginPage());
      
      case adminDashboard:
        return MaterialPageRoute(builder: (_) => const AdminDashboard());
      
      case managerDashboard:
        return MaterialPageRoute(builder: (_) => const ManagerDashboard());
      
      case bouncerDashboard:
        return MaterialPageRoute(builder: (_) => const BouncerDashboard());
      
      case createPass:
        return MaterialPageRoute(builder: (_) => const CreatePassPage());
      
      case bulkPass:
        return MaterialPageRoute(builder: (_) => const BulkPassPage());
      
      case verify:
        return MaterialPageRoute(builder: (_) => const VerifyPage());
      
      case passList:
        return MaterialPageRoute(builder: (_) => const PassListPage());
      
      case logs:
        return MaterialPageRoute(builder: (_) => const LogsPage());
      
      
      case resetDaily:
        return MaterialPageRoute(builder: (_) => const ResetDailyPage());
      
      case resetSingle:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => ResetSinglePage(
            passId: args?['passId'],
            uid: args?['uid'],
          ),
        );
      
      case userManagement:
        return MaterialPageRoute(builder: (_) => const UserManagementPage());
      
      case categoryManagement:
        return MaterialPageRoute(builder: (_) => const CategoryManagementPage());
      
      case AppRouter.settings:
        return MaterialPageRoute(builder: (_) => const SettingsPage());
      
      case passDetails:
        return MaterialPageRoute(builder: (_) => const PassDetailsPage());
      
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('Page Not Found')),
            body: const Center(
              child: Text('Page not found'),
            ),
          ),
        );
    }
  }
  
  // Navigation helpers
  static void pushReplacement(BuildContext context, String routeName, {Object? arguments}) {
    Navigator.pushReplacementNamed(context, routeName, arguments: arguments);
  }
  
  static void push(BuildContext context, String routeName, {Object? arguments}) {
    Navigator.pushNamed(context, routeName, arguments: arguments);
  }
  
  static void pop(BuildContext context, [Object? result]) {
    Navigator.pop(context, result);
  }
  
  static void popUntil(BuildContext context, String routeName) {
    Navigator.popUntil(context, ModalRoute.withName(routeName));
  }
  
  static void pushAndClearStack(BuildContext context, String routeName, {Object? arguments}) {
    Navigator.pushNamedAndRemoveUntil(
      context,
      routeName,
      (route) => false,
      arguments: arguments,
    );
  }
}