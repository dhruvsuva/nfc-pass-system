import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/router/app_router.dart';
import '../../core/utils/responsive_utils.dart';
import '../../core/utils/spacing_utils.dart';
import '../auth/providers/auth_provider.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  @override
  Widget build(BuildContext context) {
    final user = authProvider.state.user;

    return Scaffold(
      appBar: AppBar(
        title: Text('${(user?.role ?? 'ADMIN').toUpperCase()} Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(
          AppSpacing.getPagePadding(context),
        ), // Normalized padding
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Info Header
            _buildUserInfoHeader(user),

            SizedBox(
              height: AppSpacing.getSectionSpacing(context),
            ), // Normalized spacing
            // Main Actions
            Text('Main Actions', style: AppTheme.subheadingStyle),
            SizedBox(
              height: AppSpacing.getElementSpacing(context),
            ), // Normalized spacing
            _buildMainActions(),

            SizedBox(
              height: AppSpacing.getSectionSpacing(context),
            ), // Normalized spacing
            // Admin Tools
            Text(
              '${(user?.role ?? 'ADMIN').toUpperCase()} Tools',
              style: AppTheme.subheadingStyle,
            ),
            SizedBox(
              height: AppSpacing.getElementSpacing(context),
            ), // Normalized spacing
            _buildAdminTools(),
          ],
        ),
      ),
    );
  }

  Widget _buildUserInfoHeader(dynamic user) {
    final username = user?.username ?? 'Unknown';
    final role = user?.role ?? 'Unknown';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User Avatar and Basic Info
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white,
                child: Text(
                  username.isNotEmpty ? username[0].toUpperCase() : 'U',
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      username,
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
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        role.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Role-specific description
          const SizedBox(height: 12),
          Text(
            _getRoleDescription(role),
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  String _getRoleDescription(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return 'You have full access to all system features and administrative controls.';
      case 'manager':
        return 'You can manage passes, view logs, and access most system features.';
      case 'bouncer':
        return 'You can verify passes and view logs for your assigned category.';
      default:
        return 'Welcome to the system dashboard.';
    }
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
        tablet: 1.2,
        desktop: 1.3,
        largeDesktop: 1.4,
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
    final user = authProvider.state.user;
    final isAdmin = user?.role == 'admin';

    List<Widget> adminToolCards = [
      // Reset Single - Available to both Admin and Manager
      _buildActionCard(
        'Reset Single',
        'Reset specific pass',
        Icons.restore,
        AppTheme.warningColor,
        () => AppRouter.push(context, AppRouter.resetSingle),
      ),
      // Pass Details - Available to both Admin and Manager
      _buildActionCard(
        'Pass Details',
        'View pass information',
        Icons.info_outline,
        AppTheme.infoColor,
        () => AppRouter.push(context, AppRouter.passDetails),
      ),
    ];

    // Admin-only features
    if (isAdmin) {
      adminToolCards.addAll([
        _buildActionCard(
          'Reset Daily',
          'Reset all daily passes',
          Icons.refresh,
          AppTheme.warningColor,
          () => AppRouter.push(context, AppRouter.resetDaily),
        ),
        _buildActionCard(
          'User Management',
          'Manage system users',
          Icons.people,
          AppTheme.infoColor,
          () => AppRouter.push(context, AppRouter.userManagement),
        ),
        _buildActionCard(
          'Category Management',
          'Manage pass categories',
          Icons.category,
          AppTheme.secondaryColor,
          () => AppRouter.push(context, AppRouter.categoryManagement),
        ),
        _buildActionCard(
          'Settings',
          'System configuration',
          Icons.settings,
          AppTheme.primaryColor,
          () => AppRouter.push(context, AppRouter.settings),
        ),
      ]);
    }

    return ResponsiveLayout.buildResponsiveGrid(
      context: context,
      mobileColumns: 2,
      tabletColumns: 3,
      desktopColumns: 4,
      largeDesktopColumns: 6,
      childAspectRatio: ResponsiveBreakpoints.getChildAspectRatio(
        context,
        mobile: 1.2,
        tablet: 1.3,
        desktop: 1.4,
        largeDesktop: 1.5,
      ),
      children: adminToolCards,
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
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: AppSpacing.getCardPaddingEdgeInsets(context),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: ResponsiveSpacing.getIconSize(context),
                color: color,
              ),
              AppSpacing.responsiveVerticalSpace(
                context,
                mobile: AppSpacing.sm,
                tablet: AppSpacing.md,
                desktop: AppSpacing.md,
              ),
              Flexible(
                child: Text(
                  title,
                  style: AppTheme.getSubheadingStyle(
                    context,
                  ).copyWith(fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              AppSpacing.responsiveVerticalSpace(
                context,
                mobile: AppSpacing.xs,
                tablet: AppSpacing.sm,
                desktop: AppSpacing.sm,
              ),
              Flexible(
                child: Text(
                  subtitle,
                  style: AppTheme.getCaptionStyle(context),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await authProvider.logout();
      if (mounted) {
        AppRouter.pushAndClearStack(context, AppRouter.login);
      }
    }
  }
}
