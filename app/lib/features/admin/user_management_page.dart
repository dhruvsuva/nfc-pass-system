import 'dart:async';
import 'package:flutter/material.dart';

import '../../core/services/user_service.dart';
import '../../core/services/toast_service.dart';
import '../../core/utils/responsive_utils.dart';
import '../../core/router/app_router.dart';
import '../../models/user_model.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  List<UserModel> _users = [];
  bool _isLoading = false;
  String? _error;
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalUsers = 0;
  final int _limit = 20;

  // Search and filters
  final TextEditingController _searchController = TextEditingController();
  String _selectedRole = 'all';
  String _selectedStatus = 'all';
  Timer? _searchDebounce;

  // Available roles and statuses
  final List<Map<String, String>> _roles = [
    {'value': 'all', 'label': 'All Roles'},
    {'value': 'admin', 'label': 'Admin'},
    {'value': 'manager', 'label': 'Manager'},
    {'value': 'bouncer', 'label': 'Bouncer'},
  ];

  final List<Map<String, String>> _statuses = [
    {'value': 'all', 'label': 'All Status'},
    {'value': 'active', 'label': 'Active'},
    {'value': 'blocked', 'label': 'Blocked'},
  ];


  @override
  void initState() {
    super.initState();
    _loadUsers();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      _onFilterChanged();
    });
  }

  Future<void> _loadUsers({bool showLoading = true}) async {
    if (_isLoading) return;
    
    if (showLoading) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    
    try {
      print('Loading users with filters - Role: $_selectedRole, Status: $_selectedStatus, Search: ${_searchController.text}');
      
      final result = await UserService.getAllUsers(
        page: _currentPage,
        limit: _limit,
        search: _searchController.text.isNotEmpty ? _searchController.text : null,
        role: _selectedRole != 'all' ? _selectedRole : null,
        status: _selectedStatus != 'all' ? _selectedStatus : null,
      );
      
      if (mounted) {
        setState(() {
          _users = result['users'] as List<UserModel>;
          final pagination = result['pagination'] as Map<String, dynamic>;
          _currentPage = pagination['currentPage'] ?? 1;
          _totalPages = pagination['totalPages'] ?? 1;
          _totalUsers = pagination['totalUsers'] ?? 0;
          _isLoading = false;
        });
        
        print('Loaded ${_users.length} users (Page $_currentPage of $_totalPages)');
      }
    } catch (e) {
      print('Error loading users: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  void _onFilterChanged() {
    setState(() {
      _currentPage = 1; // Reset to first page when filtering
    });
    _loadUsers();
  }


  Future<void> _createUser() async {
    if (_isLoading) return;
    
    print('Opening Add User dialog...');
    
    try {
      final result = await showDialog<UserModel>(
        context: context,
        barrierDismissible: true,
        useSafeArea: true,
        builder: (context) => const UserFormDialog(),
      );
      
      print('Dialog result: $result');
      
      if (result != null) {
        try {
          print('Creating user with data: ${result.toJson()}');
          await UserService.createUser(result);
          ToastService.showSuccess('User created successfully');
          _onFilterChanged(); // Refresh with current filters
          
          // Auto-open appropriate dashboard based on role
          _openUserDashboard(result.role, result.username);
        } catch (e) {
          print('Error creating user: $e');
          ToastService.showError('Failed to create user: ${e.toString()}');
        }
      } else {
        print('Dialog was dismissed without result');
      }
    } catch (e) {
      print('Error showing dialog: $e');
      ToastService.showError('Failed to open Add User dialog: ${e.toString()}');
    }
  }

  void _openUserDashboard(String role, String username) {
    String route;
    String message;
    
    switch (role) {
      case 'admin':
        route = AppRouter.adminDashboard;
        message = 'Admin dashboard opened for $username';
        break;
      case 'manager':
        route = AppRouter.managerDashboard;
        message = 'Manager dashboard opened for $username';
        break;
      case 'bouncer':
        route = AppRouter.bouncerDashboard;
        message = 'Bouncer dashboard opened for $username';
        break;
      default:
        return;
    }
    
    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('User Created Successfully!'),
        content: Text('$message\n\nWould you like to open their dashboard?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Stay Here'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              AppRouter.push(context, route);
            },
            child: Text('Open Dashboard'),
          ),
        ],
      ),
    );
  }

  Future<void> _editUser(UserModel user) async {
    if (_isLoading) return;
    
    final result = await showDialog<UserModel>(
      context: context,
      barrierDismissible: true,
      useSafeArea: true,
      builder: (context) => UserFormDialog(user: user),
    );
    
    if (result != null) {
      try {
        await UserService.updateUser(result);
        ToastService.showSuccess('User updated successfully');
        _onFilterChanged(); // Refresh with current filters
      } catch (e) {
        ToastService.showError('Failed to update user: ${e.toString()}');
      }
    }
  }

  Future<void> _changePassword(UserModel user) async {
    final newPassword = await _showPasswordDialog('Change Password', 'Enter new password for ${user.username}');
    if (newPassword != null && newPassword.isNotEmpty) {
      try {
        await UserService.changePassword(user.id, newPassword);
        ToastService.showSuccess('Password changed successfully');
      } catch (e) {
        ToastService.showError('Failed to change password: ${e.toString()}');
      }
    }
  }

  Future<void> _blockUser(UserModel user) async {
    final reason = await _showTextDialog('Block User', 'Enter reason for blocking ${user.username}');
    if (reason != null && reason.isNotEmpty) {
      try {
        await UserService.blockUser(user.id, reason: reason);
        ToastService.showSuccess('User blocked successfully');
        _onFilterChanged(); // Refresh with current filters
      } catch (e) {
        ToastService.showError('Failed to block user: ${e.toString()}');
      }
    }
  }

  Future<void> _unblockUser(UserModel user) async {
    try {
        await UserService.unblockUser(user.id);
      ToastService.showSuccess('User unblocked successfully');
      _onFilterChanged(); // Refresh with current filters
    } catch (e) {
      ToastService.showError('Failed to unblock user: ${e.toString()}');
    }
  }

  Future<void> _deleteUser(UserModel user) async {
    final confirmed = await _showConfirmDialog(
      'Delete User',
      'Are you sure you want to delete user "${user.username}"? This action cannot be undone.',
    );
    
    if (confirmed == true) {
      try {
        await UserService.deleteUser(user.id);
        ToastService.showSuccess('User deleted successfully');
        _onFilterChanged(); // Refresh with current filters
      } catch (e) {
        ToastService.showError('Failed to delete user: ${e.toString()}');
      }
    }
  }


  Future<String?> _showTextDialog(String title, String message) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Reason',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Future<String?> _showPasswordDialog(String title, String message) async {
    final controller = TextEditingController();
    bool obscureText = true;
    
    return showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(obscureText ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => obscureText = !obscureText),
                  ),
                ),
                obscureText: obscureText,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Change'),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _showConfirmDialog(String title, String message) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadUsers(),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filters Section
          _buildFiltersSection(),
          
          // Users List
          Expanded(
            child: _buildUsersList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createUser,
        tooltip: 'Add User',
        child: const Icon(Icons.person_add),
      ),
    );
  }

  Widget _buildFiltersSection() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filters',
              style: ResponsiveText.getBodyStyle(context).copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            
            // Search Field
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search users',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _onFilterChanged();
                        },
                      )
                    : null,
                border: const OutlineInputBorder(),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Role and Status Filters
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedRole,
                    decoration: const InputDecoration(
                      labelText: 'Role',
                      border: OutlineInputBorder(),
                    ),
                    items: _roles.map((role) {
                      return DropdownMenuItem<String>(
                        value: role['value'],
                        child: Text(role['label']!),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedRole = value!;
                      });
                      _onFilterChanged();
                    },
                  ),
                ),
                
                const SizedBox(width: 16),
                
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedStatus,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                    ),
                    items: _statuses.map((status) {
                      return DropdownMenuItem<String>(
                        value: status['value'],
                        child: Text(status['label']!),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedStatus = value!;
                      });
                      _onFilterChanged();
                    },
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Results Count
            Text(
              'Showing $_totalUsers users',
              style: ResponsiveText.getCaptionStyle(context).copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsersList() {
    if (_isLoading && _users.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading users',
              style: ResponsiveText.getBodyStyle(context).copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: ResponsiveText.getCaptionStyle(context).copyWith(
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _loadUsers(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    
    if (_users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No users found',
              style: ResponsiveText.getBodyStyle(context).copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your filters or add a new user',
              style: ResponsiveText.getCaptionStyle(context).copyWith(
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: () => _loadUsers(showLoading: false),
      child: ListView.builder(
        itemCount: _users.length,
        itemBuilder: (context, index) {
          final user = _users[index];
          return _buildUserCard(user);
        },
      ),
    );
  }

  Widget _buildUserCard(UserModel user) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getRoleColor(user.role),
          child: Text(
            user.username[0].toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          user.username,
          style: ResponsiveText.getBodyStyle(context).copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Role: ${user.role.toUpperCase()}'),
            if (user.assignedCategory != null)
              Text('Category: ${user.assignedCategory}'),
            Text('Status: ${user.status.toUpperCase()}'),
            Text('Created: ${_formatDate(user.createdAt)}'),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handleUserAction(value, user),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: ListTile(
                leading: Icon(Icons.edit),
                title: Text('Edit'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'password',
              child: ListTile(
                leading: Icon(Icons.lock),
                title: Text('Change Password'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            if (user.role != 'admin' && user.status == 'active')
              const PopupMenuItem(
                value: 'block',
                child: ListTile(
                  leading: Icon(Icons.block, color: Colors.orange),
                  title: Text('Block'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            if (user.role != 'admin' && user.status == 'blocked')
              const PopupMenuItem(
                value: 'unblock',
                child: ListTile(
                  leading: Icon(Icons.check_circle, color: Colors.green),
                  title: Text('Unblock'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            if (user.role != 'admin')
              const PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete, color: Colors.red),
                  title: Text('Delete'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _handleUserAction(String action, UserModel user) {
    switch (action) {
      case 'edit':
        _editUser(user);
        break;
      case 'password':
        _changePassword(user);
        break;
      case 'block':
        _blockUser(user);
        break;
      case 'unblock':
        _unblockUser(user);
        break;
      case 'delete':
        _deleteUser(user);
        break;
    }
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'admin':
        return Colors.red;
      case 'manager':
        return Colors.blue;
      case 'bouncer':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      // Convert UTC to IST (UTC + 5:30)
      final istDate = date.add(const Duration(hours: 5, minutes: 30));
      return '${istDate.day}/${istDate.month}/${istDate.year}';
    } catch (e) {
      return 'Invalid date';
    }
  }
}

// User Form Dialog
class UserFormDialog extends StatefulWidget {
  final UserModel? user;
  
  const UserFormDialog({super.key, this.user});
  
  @override
  State<UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<UserFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  String _selectedRole = 'bouncer';
  String _selectedStatus = 'active';
  String? _selectedCategory;
  bool _obscurePassword = true;
  bool _isLoading = false;
  
  // Available categories for bouncer
  final List<Map<String, String>> _categories = [
    {'name': 'All Access', 'color': '#000000'},
    {'name': 'Platinum A', 'color': '#bcbabb'},
    {'name': 'Platinum B', 'color': '#9ad3a6'},
    {'name': 'Diamond', 'color': '#79b7de'},
    {'name': 'Gold A', 'color': '#eac23c'},
    {'name': 'Gold B', 'color': '#cc802a'},
    {'name': 'Silver', 'color': '#ebebeb'},
  ];
  
  bool get _isEditing => widget.user != null;
  
  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _usernameController.text = widget.user!.username;
      _selectedRole = widget.user!.role;
      _selectedStatus = widget.user!.status;
      // Only set assigned category if the user is a bouncer
      _selectedCategory = widget.user!.role == 'bouncer' ? widget.user!.assignedCategory : null;
    } else {
      // Set default parameters for new user
      _setRoleBasedParameters(_selectedRole);
    }
  }

  void _setRoleBasedParameters(String role) {
    switch (role) {
      case 'admin':
        _selectedStatus = 'active';
        _selectedCategory = null;
        break;
      case 'manager':
        _selectedStatus = 'active';
        _selectedCategory = null;
        break;
      case 'bouncer':
        _selectedStatus = 'active';
        _selectedCategory = 'All Access'; // Default category for bouncer
        break;
    }
  }
  
  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
  
  Future<void> _saveUser() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final user = UserModel(
        id: widget.user?.id ?? 0, // Use 0 for new users, will be set by backend
        username: _usernameController.text.trim(),
        password: _passwordController.text.isNotEmpty ? _passwordController.text : null,
        role: _selectedRole,
        status: _selectedStatus,
        assignedCategory: _selectedRole == 'bouncer' ? _selectedCategory : null,
        createdAt: widget.user?.createdAt ?? DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
      );
      
      Navigator.pop(context, user);
    } catch (e) {
      ToastService.showError('Error creating user: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Edit User' : 'Create User'),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: ResponsiveBreakpoints.getResponsiveValue(
            context,
            mobile: 300.0,
            tablet: 400.0,
            desktop: 450.0,
          ),
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a username';
                    }
                    if (value.trim().length < 3) {
                      return 'Username must be at least 3 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                if (!_isEditing)
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    obscureText: _obscurePassword,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a password';
                      }
                      if (value.length < 4) {
                        return 'Password must be at least 4 characters';
                      }
                      return null;
                    },
                  ),
                
                if (!_isEditing) const SizedBox(height: 16),
                
                DropdownButtonFormField<String>(
                  value: _selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'Role',
                    prefixIcon: Icon(Icons.work),
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'admin', child: Text('Admin')),
                    DropdownMenuItem(value: 'manager', child: Text('Manager')),
                    DropdownMenuItem(value: 'bouncer', child: Text('Bouncer')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedRole = value;
                        if (value != 'bouncer') {
                          _selectedCategory = null;
                        }
                        
                        // Auto-set parameters based on role
                        _setRoleBasedParameters(value);
                      });
                    }
                  },
                ),
                
                const SizedBox(height: 16),
                
                DropdownButtonFormField<String>(
                  value: _selectedStatus,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    prefixIcon: Icon(Icons.info),
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'active', child: Text('Active')),
                    DropdownMenuItem(value: 'blocked', child: Text('Blocked')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedStatus = value!;
                    });
                  },
                ),
                
                if (_selectedRole == 'bouncer') ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Assigned Category',
                      prefixIcon: Icon(Icons.category),
                      border: OutlineInputBorder(),
                    ),
                    items: _categories
                        .map((category) {
                      return DropdownMenuItem<String>(
                        value: category['name'],
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: Color(int.parse(category['color']!.replaceAll('#', '0xff'))),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                category['name']!,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedCategory = value;
                      });
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveUser,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_isEditing ? 'Update' : 'Create'),
        ),
      ],
    );
  }
}