import 'package:flutter/material.dart';

import '../models/book_source.dart';
import '../services/book_source_service.dart';

/// 书源管理页面
/// 提供书源搜索、管理、导入导出功能
class BookSourcePage extends StatefulWidget {
  const BookSourcePage({super.key});

  @override
  State<BookSourcePage> createState() => _BookSourcePageState();
}

class _BookSourcePageState extends State<BookSourcePage>
    with TickerProviderStateMixin {
  final BookSourceService _sourceService = BookSourceService();
  final TextEditingController _searchController = TextEditingController();

  List<BookSource> _allSources = [];
  List<BookSource> _filteredSources = [];
  Map<String, int> _stats = {};
  List<String> _groups = [];

  String _selectedGroup = '全部';
  int _selectedType = -1; // -1: 全部, 0: 小说, 1: 漫画, 2: 有声书
  bool _showEnabledOnly = false;
  bool _isLoading = true;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadData();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final sources = await _sourceService.getAllSources();
      final stats = await _sourceService.getStats();
      final groups = await _sourceService.getAllGroups();

      if (mounted) {
        setState(() {
          _allSources = sources;
          _stats = stats;
          _groups = ['全部', ...groups];
          _isLoading = false;
        });

        _applyFilters();
        _fadeController.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('加载书源失败: $e');
      }
    }
  }

  void _applyFilters() {
    List<BookSource> filtered = _allSources;

    // 应用分组筛选
    if (_selectedGroup != '全部') {
      filtered = filtered
          .where((source) => source.bookSourceGroup == _selectedGroup)
          .toList();
    }

    // 应用类型筛选
    if (_selectedType >= 0) {
      filtered = filtered
          .where((source) => source.bookSourceType == _selectedType)
          .toList();
    }

    // 应用启用状态筛选
    if (_showEnabledOnly) {
      filtered = filtered.where((source) => source.enabled).toList();
    }

    // 应用搜索筛选
    final query = _searchController.text.toLowerCase();
    if (query.isNotEmpty) {
      filtered = filtered.where((source) {
        return source.bookSourceName.toLowerCase().contains(query) ||
            source.bookSourceComment.toLowerCase().contains(query) ||
            source.bookSourceGroup.toLowerCase().contains(query);
      }).toList();
    }

    setState(() {
      _filteredSources = filtered;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              Theme.of(context).colorScheme.secondary.withValues(alpha: 0.05),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildSearchBar(),
              _buildFilters(),
              Expanded(child: _buildContent()),
            ],
          ),
        ),
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(
            Icons.source,
            size: 32,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '书源管理',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                ),
                if (_stats.isNotEmpty)
                  Text(
                    '总共 ${_stats['total'] ?? 0} 个书源，已启用 ${_stats['enabled'] ?? 0} 个',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: _showMenuDialog,
            icon: const Icon(Icons.more_vert),
            tooltip: '更多选项',
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: '搜索书源名称、分组或注释...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    _searchController.clear();
                    _applyFilters();
                  },
                  icon: const Icon(Icons.clear),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
        onChanged: (_) => _applyFilters(),
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // 分组筛选
          Expanded(
            child: _buildFilterDropdown('分组', _selectedGroup, _groups, (value) {
              setState(() => _selectedGroup = value!);
              _applyFilters();
            }),
          ),
          const SizedBox(width: 8),

          // 类型筛选
          Expanded(
            child: _buildFilterDropdown(
              '类型',
              _getTypeText(_selectedType),
              ['全部', '小说', '漫画', '有声书'],
              (value) {
                setState(() => _selectedType = _getTypeIndex(value!));
                _applyFilters();
              },
            ),
          ),
          const SizedBox(width: 8),

          // 启用状态筛选
          FilterChip(
            label: const Text('仅启用'),
            selected: _showEnabledOnly,
            onSelected: (value) {
              setState(() => _showEnabledOnly = value);
              _applyFilters();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown(
    String label,
    String value,
    List<String> items,
    void Function(String?) onChanged,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          items: items.map((item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(
                item,
                style: Theme.of(context).textTheme.bodySmall,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_filteredSources.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.source_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              _allSources.isEmpty ? '暂无书源' : '没有匹配的书源',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              _allSources.isEmpty ? '点击右下角按钮添加书源' : '请调整筛选条件',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
            ),
          ],
        ),
      );
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredSources.length,
        itemBuilder: (context, index) =>
            _buildSourceCard(_filteredSources[index]),
      ),
    );
  }

  Widget _buildSourceCard(BookSource source) {
    final colorScheme = Theme.of(context).colorScheme;
    final onSurface = colorScheme.onSurface;
    final surface = colorScheme.surface;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _showSourceDetail(source),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    source.typeIcon,
                    size: 22,
                    color: source.enabled
                        ? colorScheme.primary
                        : colorScheme.outline,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          source.bookSourceName,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: source.enabled
                                        ? onSurface
                                        : onSurface.withValues(alpha: 0.45),
                                  ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _buildInfoChip(source.typeName, source.typeIcon),
                            if (source.bookSourceGroup.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              _buildInfoChip(
                                source.bookSourceGroup,
                                Icons.folder_outlined,
                              ),
                            ],
                            const Spacer(),
                            if (source.hasSearch)
                              _buildFeatureChip(
                                '搜索',
                                Icons.search,
                                colorScheme.primary,
                              ),
                            if (source.hasExplore) ...[
                              const SizedBox(width: 4),
                              _buildFeatureChip(
                                '发现',
                                Icons.explore,
                                Colors.green,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: source.enabled,
                    onChanged: (value) => _toggleSourceEnabled(source, value),
                    activeColor: colorScheme.primary,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
              if (source.bookSourceComment.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  source.bookSourceComment,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: onSurface.withValues(alpha: 0.65),
                        height: 1.4,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    source.bookSourceUrl,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: onSurface.withValues(alpha: 0.45),
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => _testSource(source),
                        icon: const Icon(Icons.speed),
                        tooltip: '测试连接',
                      ),
                      IconButton(
                        onPressed: () => _showSourceDetail(source),
                        icon: const Icon(Icons.info_outline),
                        tooltip: '详情',
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureChip(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton(
      onPressed: _showAddSourceDialog,
      tooltip: '添加书源',
      child: const Icon(Icons.add),
    );
  }

  String _getTypeText(int type) {
    switch (type) {
      case 0:
        return '小说';
      case 1:
        return '漫画';
      case 2:
        return '有声书';
      default:
        return '全部';
    }
  }

  int _getTypeIndex(String text) {
    switch (text) {
      case '小说':
        return 0;
      case '漫画':
        return 1;
      case '有声书':
        return 2;
      default:
        return -1;
    }
  }

  Future<void> _toggleSourceEnabled(BookSource source, bool enabled) async {
    try {
      final success = await _sourceService.toggleSourceEnabled(
        source.id,
        enabled,
      );
      if (success) {
        _loadData(); // 刷新数据
        _showSuccessSnackBar(enabled ? '书源已启用' : '书源已禁用');
      } else {
        _showErrorSnackBar('操作失败');
      }
    } catch (e) {
      _showErrorSnackBar('操作失败: $e');
    }
  }

  void _testSource(BookSource source) {
    _showInfoSnackBar('书源测试功能开发中...');
  }

  void _showSourceDetail(BookSource source) {
    // TODO: 实现书源详情页面
    _showInfoSnackBar('书源详情功能开发中...');
  }

  void _showAddSourceDialog() {
    // TODO: 实现添加书源对话框
    _showInfoSnackBar('添加书源功能开发中...');
  }

  void _showMenuDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('更多选项'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.file_download),
              title: const Text('导入书源'),
              onTap: () {
                Navigator.pop(context);
                _showInfoSnackBar('导入书源功能开发中...');
              },
            ),
            ListTile(
              leading: const Icon(Icons.file_upload),
              title: const Text('导出书源'),
              onTap: () {
                Navigator.pop(context);
                _showInfoSnackBar('导出书源功能开发中...');
              },
            ),
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('刷新'),
              onTap: () {
                Navigator.pop(context);
                _loadData();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showInfoSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.blue),
    );
  }
}
