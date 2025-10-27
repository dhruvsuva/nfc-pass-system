import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/router/app_router.dart';
import '../../core/utils/responsive_utils.dart';
import '../../core/utils/spacing_utils.dart';
import '../auth/providers/auth_provider.dart';

class ManagerDashboard extends StatefulWidget {
  const ManagerDashboard({super.key});

  @override
  State<ManagerDashboard> createState() => _ManagerDashboardState();
}

class _ManagerDashboardState extends State<ManagerDashboard> {
  @override
  Widget build(BuildContext context) {
    final user = authProvider.state.user;

    return Scaffold(
      appBar: AppBar(
        title: Text('${(user?.role ?? 'MANAGER').toUpperCase()} Dashboard'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(AppSpacing.getPagePadding(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Info Header
            _buildUserInfoHeader(user),

            SizedBox(height: AppSpacing.getSectionSpacing(context)),

            // Main Actions
            Text('Main Actions', style: AppTheme.subheadingStyle),
            SizedBox(height: AppSpacing.getElementSpacing(context)),
            _buildMainActions(),

            SizedBox(height: AppSpacing.getSectionSpacing(context) * 1.5),

            // Admin Tools
            Text('Admin Tools', style: AppTheme.subheadingStyle),
            SizedBox(height: AppSpacing.getElementSpacing(context)),
            _buildAdminTools(),

            SizedBox(height: AppSpacing.getSectionSpacing(context) * 1.5),
          ],
        ),
      ),
    );
  }

  Widget _buildUserInfoHeader(dynamic user) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.white.withOpacity(0.2),
                child: Icon(Icons.person, size: 30, color: Colors.white),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back,',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      user?.username ?? 'Manager',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        (user?.role ?? 'MANAGER').toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Manage passes, verify entries, and monitor system activity',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainActions() {
    return ResponsiveLayout.buildResponsiveGrid(
      context: context,
      mobileColumns: 2,
      tabletColumns: 3,
      desktopColumns: 4,
      largeDesktopColumns: 5,
      childAspectRatio: ResponsiveBreakpoints.getChildAspectRatio(
        context,
        mobile: 1.0,
        tablet: 1.1,
        desktop: 1.2,
        largeDesktop: 1.3,
      ),
      children: [
        _buildActionCard(
          'Create Pass',
          'Create single NFC pass',
          Icons.add_card,
          AppTheme.primaryColor,
          () => AppRouter.push(context, AppRouter.createPass),
        ),
        _buildActionCard(
          'Bulk Create',
          'Create multiple passes',
          Icons.library_add,
          AppTheme.secondaryColor,
          () => AppRouter.push(context, AppRouter.bulkPass),
        ),
        _buildActionCard(
          'Verify Pass',
          'Scan and verify passes',
          Icons.qr_code_scanner,
          AppTheme.successColor,
          () => AppRouter.push(context, AppRouter.verify),
        ),
        _buildActionCard(
          'Pass List',
          'View all passes',
          Icons.list_alt,
          AppTheme.infoColor,
          () => AppRouter.push(context, AppRouter.passList),
        ),
      ],
    );
  }

  Widget _buildAdminTools() {
    return ResponsiveLayout.buildResponsiveGrid(
      context: context,
      mobileColumns: 2,
      tabletColumns: 3,
      desktopColumns: 4,
      largeDesktopColumns: 5,
      childAspectRatio: ResponsiveBreakpoints.getChildAspectRatio(
        context,
        mobile: 1.0,
        tablet: 1.1,
        desktop: 1.2,
        largeDesktop: 1.3,
      ),
      children: [
        _buildActionCard(
          'Reset Single',
          'Reset specific pass',
          Icons.restore,
          AppTheme.warningColor,
          () => _showResetSingleDialog(),
        ),
        _buildActionCard(
          'Pass Details',
          'View pass information',
          Icons.info_outline,
          AppTheme.infoColor,
          () => AppRouter.push(context, AppRouter.passDetails),
        ),
      ],
    );
  }

  Widget _buildActionCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 24, color: color),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showResetSingleDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Single Pass'),
        content: const Text(
          'Please scan a pass to reset it, or enter the UID manually.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Navigate to verify page for scanning
              AppRouter.push(context, AppRouter.verify);
            },
            child: const Text('Scan Pass'),
          ),
        ],
      ),
    );
  }

  void _handleLogout() async {
    print('🔄 Manager: Starting logout process...');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () {
              print('❌ Manager: Logout cancelled');
              Navigator.pop(context, false);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              print('✅ Manager: Logout confirmed');
              Navigator.pop(context, true);
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      print('🚪 Manager: Executing logout...');
      await authProvider.logout();
      print('🔄 Manager: Logout completed, navigating to login...');
      if (mounted) {
        AppRouter.pushAndClearStack(context, AppRouter.login);
        print('✅ Manager: Navigation to login completed');
      }
    }
  }
}
