import 'dart:async';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/pass_theme.dart';
import '../../core/services/pass_service.dart';
import '../../core/services/categories_service.dart';
import '../../core/services/toast_service.dart';
import '../../core/utils/timezone_utils.dart';
import '../../models/pass_model.dart';
import '../../models/category_model.dart';
import '../auth/providers/auth_provider.dart';

class PassListPage extends StatefulWidget {
  const PassListPage({super.key});

  @override
  State<PassListPage> createState() => _PassListPageState();
}

class _PassListPageState extends State<PassListPage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  List<PassModel> _passes = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMoreData = true;
  String? _error;

  // Pagination
  int _currentPage = 1;
  final int _pageSize = 50;

  // Filters
  String? _selectedStatus;
  String? _selectedPassType;
  String? _selectedCategory;
  String? _searchQuery;

  // Category summary
  Map<String, int> _categoryCounts = {};

  // Pass management
  bool _isProcessing = false;

  // Caching
  Map<String, List<PassModel>> _passCache = {};
  String? _lastSearchQuery;
  String? _lastStatusFilter;
  String? _lastPassTypeFilter;
  String? _lastCategoryFilter;

  // Bulk selection
  bool _isSelectionMode = false;
  Set<int> _selectedPassIds = {};
  bool _isSelectAll = false;

  // Search debouncing
  Timer? _searchDebounceTimer;
  static const Duration _searchDebounceDelay = Duration(milliseconds: 500);

  @override
  void initState() {
    super.initState();
    _loadPasses();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _searchDebounceTimer?.cancel();
    _clearCache();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMoreData) {
        _loadMorePasses();
      }
    }
  }

  Future<void> _loadPasses({bool refresh = false}) async {
    if (_isLoading) return;

    if (refresh) {
      setState(() {
        _currentPage = 1;
        _passes.clear();
        _hasMoreData = true;
        _error = null;
      });
      _clearCache();
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (_searchQuery != null && _searchQuery!.length < 2) {
        setState(() {
          _isLoading = false;
          _error = 'Search query must be at least 2 characters long';
        });
        return;
      }

      final response = await PassService.getPassList(
        page: _currentPage,
        limit: _pageSize,
        status: _selectedStatus,
        passType: _selectedPassType,
        category: _selectedCategory,
        search: _searchQuery,
      );

      if (response.passes.isEmpty && _currentPage == 1) {
        setState(() {
          _isLoading = false;
          _error =
              'No passes found. Try adjusting your filters or search criteria.';
          _hasMoreData = false;
        });
        return;
      }

      setState(() {
        if (refresh) {
          _passes = response.passes;
        } else {
          _passes.addAll(response.passes);
        }
        _hasMoreData = response.hasNextPage;
        _isLoading = false;
        _error =
            null; // Clear any previous error when we get a successful response
      });

      final cacheKey = _getCacheKey();
      _passCache[cacheKey] = List.from(_passes);
      _updateLastFilters();
      _calculateCategoryCounts();

      if (refresh && response.passes.isNotEmpty) {
        ToastService.showSuccess('Loaded ${response.passes.length} passes');
      }
    } on PassServiceException catch (e) {
      setState(() {
        _isLoading = false;
        _error = _getUserFriendlyErrorMessage(e.message);
        _hasMoreData = false;
      });
      ToastService.showError(_getUserFriendlyErrorMessage(e.message));
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error =
            'Failed to connect to server. Please check your internet connection.';
        _hasMoreData = false;
      });
      ToastService.showError('Connection failed. Please try again.');
    }
  }

  Future<void> _loadMorePasses() async {
    if (_isLoadingMore || !_hasMoreData || _isLoading) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      _currentPage++;
      final response = await PassService.getPassList(
        page: _currentPage,
        limit: _pageSize,
        status: _selectedStatus,
        passType: _selectedPassType,
        category: _selectedCategory,
        search: _searchQuery,
      );

      setState(() {
        _passes.addAll(response.passes);
        _hasMoreData = response.hasNextPage;
        _isLoadingMore = false;
      });

      final cacheKey = _getCacheKey();
      _passCache[cacheKey] = List.from(_passes);
      _calculateCategoryCounts();

      if (response.passes.isNotEmpty) {
        ToastService.showSuccess(
          'Loaded ${response.passes.length} more passes',
        );
      }
    } on PassServiceException catch (e) {
      setState(() {
        _currentPage--;
        _isLoadingMore = false;
      });
      ToastService.showError(_getUserFriendlyErrorMessage(e.message));
    } catch (e) {
      setState(() {
        _currentPage--;
        _isLoadingMore = false;
      });
      ToastService.showError('Failed to load more passes. Please try again.');
    }
  }

  String _getUserFriendlyErrorMessage(String error) {
    if (error.contains('network') || error.contains('connection')) {
      return 'Network error. Please check your internet connection.';
    } else if (error.contains('timeout')) {
      return 'Request timeout. Please try again.';
    } else if (error.contains('unauthorized') || error.contains('401')) {
      return 'Session expired. Please log in again.';
    } else if (error.contains('forbidden') || error.contains('403')) {
      return 'Access denied. You don\'t have permission to perform this action.';
    } else if (error.contains('not found') || error.contains('404')) {
      return 'Resource not found. Please refresh and try again.';
    } else if (error.contains('server error') || error.contains('500')) {
      return 'Server error. Please try again later.';
    }
    return error;
  }

  void _calculateCategoryCounts() {
    _categoryCounts.clear();
    for (final pass in _passes) {
      _categoryCounts[pass.category] =
          (_categoryCounts[pass.category] ?? 0) + 1;
    }
  }

  String _getCacheKey() {
    return '${_searchQuery ?? ''}_${_selectedStatus ?? ''}_${_selectedPassType ?? ''}_${_selectedCategory ?? ''}';
  }

  bool _hasFiltersChanged() {
    return _searchQuery != _lastSearchQuery ||
        _selectedStatus != _lastStatusFilter ||
        _selectedPassType != _lastPassTypeFilter ||
        _selectedCategory != _lastCategoryFilter;
  }

  void _updateLastFilters() {
    _lastSearchQuery = _searchQuery;
    _lastStatusFilter = _selectedStatus;
    _lastPassTypeFilter = _selectedPassType;
    _lastCategoryFilter = _selectedCategory;
  }

  void _clearCache() {
    _passCache.clear();
  }

  void _clearAllFilters() {
    setState(() {
      _selectedStatus = null;
      _selectedPassType = null;
      _selectedCategory = null;
      _searchQuery = null;
      _searchController.clear();
    });
    _loadPasses(refresh: true);
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      _selectedPassIds.clear();
      _isSelectAll = false;
    });
  }

  void _toggleSelectAll() {
    setState(() {
      _isSelectAll = !_isSelectAll;
      if (_isSelectAll) {
        _selectedPassIds = _passes.map((p) => p.id).toSet();
      } else {
        _selectedPassIds.clear();
      }
    });
  }

  Future<void> _bulkDeletePasses() async {
    if (_selectedPassIds.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Selected Passes'),
        content: Text(
          'Are you sure you want to delete ${_selectedPassIds.length} passes? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Deleting Passes'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Deleting ${_selectedPassIds.length} passes...'),
            const SizedBox(height: 8),
            Text(
              'Please wait while we delete the selected passes.',
              style: AppTheme.captionStyle.copyWith(
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );

    setState(() {
      _isProcessing = true;
    });

    try {
      // Delete passes one by one since bulk delete is not available
      int deletedCount = 0;
      int failedCount = 0;

      for (final passId in _selectedPassIds) {
        try {
          await PassService.deletePass(passId);
          deletedCount++;
        } catch (e) {
          print('Failed to delete pass $passId: $e');
          failedCount++;
        }
      }

      // Close progress dialog
      Navigator.of(context).pop();

      setState(() {
        _passes.removeWhere((pass) => _selectedPassIds.contains(pass.id));
        _selectedPassIds.clear();
        _isSelectAll = false;
        _isSelectionMode = false;
        _isProcessing = false;
      });

      _calculateCategoryCounts();

      // Show result message
      if (failedCount == 0) {
        ToastService.showSuccess('Successfully deleted $deletedCount passes');
      } else {
        ToastService.showError(
          'Deleted $deletedCount passes, $failedCount failed',
        );
      }

      // Auto refresh the page after a short delay
      Future.delayed(const Duration(milliseconds: 500), () {
        _loadPasses(refresh: true);
      });
    } catch (e) {
      // Close progress dialog
      Navigator.of(context).pop();

      setState(() {
        _isProcessing = false;
      });
      ToastService.showError('Failed to delete passes: ${e.toString()}');
    }
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Passes'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _selectedStatus,
              decoration: const InputDecoration(labelText: 'Status'),
              items: const [
                DropdownMenuItem(value: null, child: Text('All Statuses')),
                DropdownMenuItem(value: 'active', child: Text('Active')),
                DropdownMenuItem(value: 'blocked', child: Text('Blocked')),
                DropdownMenuItem(value: 'expired', child: Text('Expired')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedStatus = value;
                });
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedPassType,
              decoration: const InputDecoration(labelText: 'Pass Type'),
              items: const [
                DropdownMenuItem(value: null, child: Text('All Types')),
                DropdownMenuItem(value: 'daily', child: Text('Daily')),
                DropdownMenuItem(value: 'seasonal', child: Text('Seasonal')),
                DropdownMenuItem(value: 'unlimited', child: Text('Unlimited')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedPassType = value;
                });
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _selectedStatus = null;
                _selectedPassType = null;
                _selectedCategory = null;
              });
              Navigator.of(context).pop();
              _loadPasses(refresh: true);
            },
            child: const Text('Clear All'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _loadPasses(refresh: true);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSelectionMode
            ? Text('${_selectedPassIds.length} selected')
            : const Text('Pass List'),
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: _toggleSelectionMode,
                tooltip: 'Cancel Selection',
              )
            : null,
        actions: _isSelectionMode
            ? [
                if (_passes.isNotEmpty)
                  IconButton(
                    icon: Icon(
                      _isSelectAll ? Icons.deselect : Icons.select_all,
                    ),
                    onPressed: _toggleSelectAll,
                    tooltip: _isSelectAll ? 'Deselect All' : 'Select All',
                  ),
                if (_selectedPassIds.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.delete_forever),
                    onPressed: _isProcessing ? null : _bulkDeletePasses,
                    tooltip: 'Delete Selected',
                  ),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.checklist),
                  onPressed: _passes.isNotEmpty ? _toggleSelectionMode : null,
                  tooltip: 'Select Multiple',
                ),
                IconButton(
                  icon: const Icon(Icons.filter_list),
                  onPressed: _showFilterDialog,
                  tooltip: 'Filter Passes',
                ),
              ],
      ),
      bottomNavigationBar: _isSelectionMode && _selectedPassIds.isNotEmpty
          ? Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                border: Border(
                  top: BorderSide(
                    color: AppTheme.primaryColor.withOpacity(0.3),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_selectedPassIds.length} pass${_selectedPassIds.length == 1 ? '' : 'es'} selected',
                      style: AppTheme.bodyStyle.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _isProcessing ? null : _bulkDeletePasses,
                    icon: const Icon(Icons.delete_forever),
                    label: const Text('Delete'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.errorColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            )
          : null,
      body: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return <Widget>[
            // Sticky Search Bar
            SliverToBoxAdapter(
              child: Container(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by Category, Type, UID...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = null;
                                });
                                _loadPasses(refresh: true);
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppTheme.primaryColor,
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    onChanged: (value) {
                      _searchDebounceTimer?.cancel();

                      final trimmedValue = value.trim();
                      final newQuery = trimmedValue.isEmpty
                          ? null
                          : trimmedValue;

                      if (_searchQuery != newQuery) {
                        setState(() {
                          _searchQuery = newQuery;
                        });
                      }

                      _searchDebounceTimer = Timer(_searchDebounceDelay, () {
                        if (newQuery == null || newQuery.length >= 2) {
                          _loadPasses(refresh: true);
                        }
                      });
                    },
                    onSubmitted: (value) {
                      _searchDebounceTimer?.cancel();
                      setState(() {
                        _searchQuery = value.trim().isEmpty
                            ? null
                            : value.trim();
                      });
                      _loadPasses(refresh: true);
                    },
                  ),
                ),
              ),
            ),

            // Sticky Category Summary
            if (_categoryCounts.isNotEmpty)
              SliverToBoxAdapter(
                child: Container(
                  height: 60,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _categoryCounts.length,
                    itemBuilder: (context, index) {
                      final category = _categoryCounts.keys.elementAt(index);
                      final count = _categoryCounts[category]!;
                      final isSelected = _selectedCategory == category;

                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedCategory = isSelected ? null : category;
                            });
                            _loadPasses(refresh: true);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.primaryColor
                                  : AppTheme.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppTheme.primaryColor,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  category,
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : AppTheme.primaryColor,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.white.withOpacity(0.2)
                                        : AppTheme.primaryColor,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    count.toString(),
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

            // Sticky Filter Chips
            if (_selectedStatus != null ||
                _selectedPassType != null ||
                _selectedCategory != null)
              SliverToBoxAdapter(
                child: Container(
                  height: 50,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      if (_selectedStatus != null)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Chip(
                            label: Text('Status: $_selectedStatus'),
                            onDeleted: () {
                              setState(() {
                                _selectedStatus = null;
                              });
                              _loadPasses(refresh: true);
                            },
                          ),
                        ),
                      if (_selectedPassType != null)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Chip(
                            label: Text('Type: $_selectedPassType'),
                            onDeleted: () {
                              setState(() {
                                _selectedPassType = null;
                              });
                              _loadPasses(refresh: true);
                            },
                          ),
                        ),
                      if (_selectedCategory != null)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Chip(
                            label: Text('Category: $_selectedCategory'),
                            onDeleted: () {
                              setState(() {
                                _selectedCategory = null;
                              });
                              _loadPasses(refresh: true);
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ];
        },
        body: _buildPassList(),
      ),
    );
  }

  Widget _buildPassList() {
    if (_isLoading && _passes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Loading passes...',
              style: AppTheme.bodyStyle.copyWith(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    if (_error != null && _passes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: AppTheme.errorColor),
              const SizedBox(height: 16),
              Text(
                'Failed to Load Passes',
                style: AppTheme.headingStyle.copyWith(
                  color: AppTheme.errorColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: AppTheme.bodyStyle.copyWith(color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _loadPasses(refresh: true),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _error = null;
                      });
                    },
                    icon: const Icon(Icons.clear),
                    label: const Text('Clear'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade600,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    if (_passes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'No Passes Available',
                style: AppTheme.headingStyle.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _searchQuery != null ||
                        _selectedStatus != null ||
                        _selectedPassType != null ||
                        _selectedCategory != null
                    ? 'No passes match your current filters. Try adjusting your search criteria.'
                    : 'No passes have been created yet. Create your first pass to get started.',
                style: AppTheme.bodyStyle.copyWith(color: Colors.grey.shade500),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (_searchQuery != null ||
                  _selectedStatus != null ||
                  _selectedPassType != null ||
                  _selectedCategory != null)
                ElevatedButton.icon(
                  onPressed: _clearAllFilters,
                  icon: const Icon(Icons.clear_all),
                  label: const Text('Clear Filters'),
                ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadPasses(refresh: true),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: _passes.length + (_isLoadingMore ? 1 : 0),
        cacheExtent: 1000,
        addAutomaticKeepAlives: false,
        addRepaintBoundaries: true,
        addSemanticIndexes: false,
        itemBuilder: (context, index) {
          if (index >= _passes.length) {
            return Container(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Column(
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 8),
                    Text(
                      'Loading more passes...',
                      style: AppTheme.captionStyle.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final pass = _passes[index];
          return _buildPassCard(pass);
        },
      ),
    );
  }

  Widget _buildPassCard(PassModel pass) {
    final usagePercentage = pass.maxUses > 0
        ? pass.usedCount / pass.maxUses
        : 0.0;
    final remainingUses = pass.maxUses - pass.usedCount;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _isSelectionMode
            ? () {
                setState(() {
                  if (_selectedPassIds.contains(pass.id)) {
                    _selectedPassIds.remove(pass.id);
                  } else {
                    _selectedPassIds.add(pass.id);
                  }
                  _isSelectAll = _selectedPassIds.length == _passes.length;
                });
              }
            : null,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: _isSelectionMode && _selectedPassIds.contains(pass.id)
                ? Border.all(color: AppTheme.primaryColor, width: 2)
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pass.uid,
                            style: AppTheme.headingStyle.copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            pass.category,
                            style: AppTheme.bodyStyle.copyWith(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: PassTheme.getStatusColor(
                              pass.status,
                            ).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            pass.status.toUpperCase(),
                            style: AppTheme.captionStyle.copyWith(
                              color: PassTheme.getStatusColor(pass.status),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          pass.passType.toUpperCase(),
                          style: AppTheme.captionStyle.copyWith(
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'People Allowed: ${pass.peopleAllowed}',
                            style: AppTheme.bodyStyle,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Max Uses: ${pass.maxUses == 999999 ? 'Unlimited' : pass.maxUses.toString()}',
                            style: AppTheme.bodyStyle,
                          ),
                        ],
                      ),
                    ),
                    if (pass.maxUses != 999999) ...[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Remaining: $remainingUses',
                            style: AppTheme.captionStyle.copyWith(
                              color: remainingUses > 0
                                  ? AppTheme.successColor
                                  : AppTheme.errorColor,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
                if (pass.maxUses != 999999) ...[
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: usagePercentage,
                    backgroundColor: Colors.grey.shade300,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      remainingUses > 0
                          ? AppTheme.primaryColor
                          : AppTheme.errorColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          'Used: ${pass.usedCount}',
                          style: AppTheme.captionStyle,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      if (pass.lastScanAt != null)
                        Flexible(
                          child: Text(
                            'Last scan: ${_formatDateTime(pass.lastScanAt!)}',
                            style: AppTheme.captionStyle,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDateTime(String dateTimeString) {
    try {
      final dateTime = DateTime.parse(dateTimeString);
      return TimezoneUtils.formatIndian(dateTime);
    } catch (e) {
      return dateTimeString;
    }
  }
}
