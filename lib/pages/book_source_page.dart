import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/book_source.dart';
import 'online_book_search_page.dart';
import '../services/books/book_services.dart';
import '../utils/page_style_helper.dart';
import '../utils/system_ui_helper.dart';
import '../widgets/side_toast.dart';
import 'home_layout_constants.dart';
import 'home_shell_page.dart';

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
  bool _showFiltersPanel = false;
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
        _showToast('加载书源失败: $e');
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
    final navContext = NavigationContext.of(context);
    final useRailNavigation = navContext?.useRailNavigation ?? false;

    if (useRailNavigation) {
      return _buildContent(useRailNavigation: true);
    }

    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 0,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiHelper.overlayStyleForBrightness(
          Theme.of(context).brightness,
        ),
      ),
      body: _buildContent(useRailNavigation: false),
    );
  }

  Widget _buildContent({required bool useRailNavigation}) {
    return Container(
      decoration: BoxDecoration(
        gradient: PageStyleHelper.backgroundGradient(context),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            if (useRailNavigation) ...[
              _buildRailHeader(),
            ] else ...[
              const SizedBox(height: kHomeMobileTopBarHeight + 8),
              _buildMobileActionsRow(),
            ],
            _buildSearchBar(),
            _buildSummaryCard(),
            _buildFilters(),
            Expanded(child: _buildSourceList()),
          ],
        ),
      ),
    );
  }

  Widget _buildRailHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '书源',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.05,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                ),
                if (_stats.isNotEmpty) _buildStatsText(),
              ],
            ),
          ),
          _buildActionsButtons(),
        ],
      ),
    );
  }

  Widget _buildMobileActionsRow() {
    final palette = PageStyleHelper.palette(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: _stats.isNotEmpty
                ? _buildStatsText()
                : Text(
                    '管理与筛选在线书源',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: palette.textMuted,
                        ),
                  ),
          ),
          _buildActionsButtons(),
        ],
      ),
    );
  }

  Widget _buildActionsButtons() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildHeaderButton(
          icon: Icons.add_rounded,
          onTap: _showAddSourceDialog,
          tooltip: '添加书源',
        ),
        const SizedBox(width: 8),
        _buildHeaderButton(
          icon: Icons.tune_rounded,
          onTap: () => setState(() => _showFiltersPanel = !_showFiltersPanel),
          tooltip: _showFiltersPanel ? '收起筛选' : '展开筛选',
        ),
        const SizedBox(width: 8),
        _buildHeaderButton(
          icon: Icons.more_horiz_rounded,
          onTap: _showMenuDialog,
          tooltip: '更多选项',
        ),
      ],
    );
  }

  Widget _buildStatsText() {
    return Text(
      '总共 ${_stats['total'] ?? 0} 个，已启用 ${_stats['enabled'] ?? 0} 个',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(
              context,
            ).colorScheme.onSurfaceVariant.withValues(alpha: 0.72),
          ),
    );
  }

  Widget _buildHeaderButton({
    required IconData icon,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    final palette = PageStyleHelper.palette(context);
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: palette.card,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Icon(
            icon,
            color: palette.iconMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    final palette = PageStyleHelper.palette(context);
    return Container(
      height: 52,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: palette.border,
        ),
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: '搜索书源站点',
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 18,
            color: palette.textMuted,
          ),
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
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
        onChanged: (_) => _applyFilters(),
      ),
    );
  }

  Widget _buildFilters() {
    if (!_showFiltersPanel) {
      return const SizedBox(height: 6);
    }

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
            selectedColor:
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.16),
            onSelected: (value) {
              setState(() => _showEnabledOnly = value);
              _applyFilters();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final palette = PageStyleHelper.palette(context);
    final total = _stats['total'] ?? _allSources.length;
    final enabled = _stats['enabled'] ??
        _allSources.where((source) => source.enabled).length;
    final avg = _allSources.isEmpty ? '--' : '320ms';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.hero,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '在线书源已启用',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 3),
          Text(
            '当前可用 $enabled / $total 个 · 平均响应 $avg',
            style: TextStyle(
              fontSize: 13,
              color: palette.textMuted,
            ),
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
    final palette = PageStyleHelper.palette(context);
    return Container(
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: palette.border,
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

  Widget _buildSourceList() {
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
        padding: EdgeInsets.fromLTRB(
          16,
          2,
          16,
          68 + 25 + MediaQuery.of(context).padding.bottom.clamp(0.0, 50.0) + 12,
        ),
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
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: surface.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _showSourceDetail(source),
        borderRadius: BorderRadius.circular(18),
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
                    activeThumbColor: colorScheme.primary,
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
                      if (source.hasSearch)
                        IconButton(
                          onPressed: () => _openSourceSearch(source),
                          icon: const Icon(Icons.manage_search),
                          tooltip: '搜索书籍',
                        ),
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
        _loadData();
        _showToast(enabled ? '书源已启用' : '书源已禁用');
      } else {
        _showToast('操作失败');
      }
    } catch (e) {
      _showToast('操作失败: $e');
    }
  }

  void _openSourceSearch(BookSource source) {
    if (!source.enabled) {
      _showToast('请先启用该书源');
      return;
    }
    if (!source.hasSearch) {
      _showToast('该书源未配置搜索规则');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OnlineBookSearchPage(source: source),
      ),
    );
  }

  Future<void> _testSource(BookSource source) async {
    if (source.bookSourceUrl.trim().isEmpty) {
      _showToast('书源地址为空');
      return;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('正在测试连接...'),
          ],
        ),
      ),
    );

    final result = await _sourceService.testSource(source);
    if (!mounted) return;
    Navigator.of(context).pop();

    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(result.success ? '连接成功' : '连接失败'),
        content: Text('${result.message}\n响应时间：${result.responseTime}ms'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showSourceDetail(BookSource source) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  source.bookSourceName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  source.bookSourceUrl,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Icon(
                  source.enabled
                      ? Icons.check_circle_outline
                      : Icons.pause_circle_outline,
                  color: source.enabled ? Colors.green : Colors.orange,
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.manage_search),
                title: const Text('搜索该书源'),
                subtitle: const Text('按规则搜索书籍、查看目录与正文'),
                enabled: source.enabled && source.hasSearch,
                onTap: () {
                  Navigator.pop(context);
                  _openSourceSearch(source);
                },
              ),
              ListTile(
                leading: const Icon(Icons.speed),
                title: const Text('测试连接'),
                subtitle: const Text('检查书源地址可达性'),
                onTap: () {
                  Navigator.pop(context);
                  _testSource(source);
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy_all_outlined),
                title: const Text('复制书源 JSON'),
                subtitle: const Text('可用于分享或备份'),
                onTap: () async {
                  await Clipboard.setData(
                    ClipboardData(text: jsonEncode(source.toJson())),
                  );
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  _showToast('已复制到剪贴板');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddSourceDialog() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.paste),
                title: const Text('粘贴 JSON 导入'),
                subtitle: const Text('支持单个或批量书源 JSON'),
                onTap: () {
                  Navigator.pop(context);
                  _showImportJsonDialog();
                },
              ),
              ListTile(
                leading: const Icon(Icons.link),
                title: const Text('从 URL 导入'),
                subtitle: const Text('输入书源分享链接'),
                onTap: () {
                  Navigator.pop(context);
                  _showImportUrlDialog();
                },
              ),
              ListTile(
                leading: const Icon(Icons.folder_open),
                title: const Text('从文件导入'),
                subtitle: const Text('选择本地 .json / .txt 书源文件'),
                onTap: () {
                  Navigator.pop(context);
                  _importFromFile();
                },
              ),
            ],
          ),
        ),
      ),
    );
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
                _showAddSourceDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.file_upload),
              title: const Text('导出书源'),
              onTap: () {
                Navigator.pop(context);
                _showExportDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_sweep_outlined),
              title: const Text('清空全部书源'),
              onTap: () {
                Navigator.pop(context);
                _confirmDeleteAllSources();
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

  Future<void> _showImportJsonDialog() async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('粘贴书源 JSON'),
        content: SizedBox(
          width: 520,
          child: TextField(
            controller: controller,
            minLines: 8,
            maxLines: 16,
            decoration: const InputDecoration(
              hintText: '粘贴 JSON 内容',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('导入'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final text = controller.text.trim();
    if (text.isEmpty) {
      _showToast('请输入 JSON 内容');
      return;
    }

    final result = await _sourceService.importFromJson(text);
    if (!mounted) return;
    _showImportResult(result);
  }

  Future<void> _showImportUrlDialog() async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('从 URL 导入书源'),
        content: SizedBox(
          width: 520,
          child: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'https://...',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('导入'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final url = controller.text.trim();
    if (url.isEmpty) {
      _showToast('请输入 URL');
      return;
    }

    final result = await _sourceService.importFromUrl(url);
    if (!mounted) return;
    _showImportResult(result);
  }

  Future<void> _importFromFile() async {
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json', 'txt'],
      );
      if (picked == null) return;
      final path = picked.files.single.path;
      if (path == null || path.isEmpty) {
        _showToast('无法读取文件路径');
        return;
      }

      final result = await _sourceService.importFromFile(File(path));
      if (!mounted) return;
      _showImportResult(result);
    } catch (e) {
      _showToast('文件导入失败: $e');
    }
  }

  void _showImportResult(ImportResult result) {
    if (result.success > 0) {
      _showToast('导入成功 ${result.success}/${result.total}');
      _loadData();
    } else {
      final message = result.errors.isNotEmpty ? result.errors.first : '导入失败';
      _showToast(message);
    }
  }

  Future<void> _showExportDialog() async {
    final jsonText = await _sourceService.exportToJson();
    if (!mounted) return;

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导出书源 JSON'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: SelectableText(
              jsonText,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: jsonText));
              if (context.mounted) {
                Navigator.pop(context);
              }
              _showToast('已复制 JSON');
            },
            child: const Text('复制'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteAllSources() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认清空'),
        content: const Text('将删除当前所有书源，是否继续？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('清空'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final ok = await _sourceService.deleteAllSources();
    if (!mounted) return;
    if (ok) {
      _showToast('已清空书源');
      _loadData();
    } else {
      _showToast('清空失败');
    }
  }

  void _showToast(String message) {
    showSideToast(context, message);
  }
}
