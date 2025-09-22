import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/advanced_text_reader.dart';
import '../services/reading_engine_coordinator.dart';
import '../utils/performance_monitor.dart';

/// 高级阅读功能演示页面
/// 展示所有新实现的功能和性能
class AdvancedReadingDemo extends StatefulWidget {
  const AdvancedReadingDemo({Key? key}) : super(key: key);

  @override
  State<AdvancedReadingDemo> createState() => _AdvancedReadingDemoState();
}

class _AdvancedReadingDemoState extends State<AdvancedReadingDemo>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final ReadingEngineCoordinator _coordinator = ReadingEngineCoordinator();
  // final BookSourceService _sourceService = BookSourceService();
  final PerformanceMonitor _performanceMonitor = PerformanceMonitor();

  // 演示数据
  final String _demoText = '''
第一章 开端

这是一个关于阅读的故事。在数字化时代，人们对高质量阅读体验的追求从未停止。本应用实现了精确的文本分页和字符级渲染，为用户提供与传统纸质书籍相媲美的阅读体验。

技术特性包括：

1. 精确文本测量系统
   - 字符级精确测量
   - Unicode组合字符支持  
   - Emoji完整显示
   - 自适应字体度量

2. 智能分页算法
   - 高级分页算法
   - 断点优先级智能判断
   - 保守分页策略避免缺字漏字
   - 缓存优化提升性能

3. 高性能渲染系统
   - CustomPainter精确绘制
   - 三层数据模型（页面-行-字符）
   - 选择高亮和手柄显示
   - 触摸交互响应流畅

4. 书源系统集成
   - 完整的书源系统兼容
   - 规则引擎支持XPath和CSS选择器
   - 网络书籍搜索和阅读
   - 导入导出和管理功能

5. 阅读引擎协调
   - WebView和高级引擎智能切换
   - 基于文件格式和大小自动选择
   - 性能监控和优化建议
   - 用户偏好学习适应

这些技术的结合，为用户提供了专业级的阅读体验。无论是处理大型TXT文件，还是阅读复杂的EPUB格式，都能获得流畅稳定的表现。

第二章 技术实现

文本测量系统采用了Flutter的TextPainter API，结合自定义的字符宽度缓存，实现了毫秒级的测量响应。系统能够准确处理中英文混排、标点符号、特殊字符等复杂情况。

分页算法使用了断点优先级系统，实现了90%空间利用率：

• 句号、问号、感叹号：优先级9
• 分号、冒号：优先级8  
• 逗号、顿号：优先级7
• 空格：优先级6
• 其他字符：优先级1

这种设计确保了文本在合适的位置换行，避免了重要内容被分割到不同页面。

渲染系统使用了三层数据结构：
1. TextPageData - 页面级数据，包含完整页面信息
2. TextLineData - 行级数据，管理单行文本和布局
3. TextColumnData - 字符级数据，存储每个字符的精确位置

这种设计使得系统能够处理复杂的文字选择、高亮显示和交互操作。

第三章 性能优化

为了确保在各种设备上都能流畅运行，系统实现了多项性能优化：

缓存机制：
- 文本测量结果缓存
- 分页参数缓存  
- 页面内容缓存
- 字体度量缓存

内存管理：
- LRU缓存策略
- 定时清理机制
- 内存使用监控
- 垃圾回收优化

渲染优化：
- 页面Widget缓存
- 选择性重绘
- 批量操作处理
- 帧率监控调节

这些优化使得应用在处理大型文档时仍能保持流畅的用户体验。

第四章 未来展望

未来的发展方向包括：

1. 更多书源支持
2. 云端同步功能
3. AI智能推荐
4. 社交阅读功能
5. 多语言国际化

技术演进将继续关注用户体验的提升，通过持续的算法优化和功能完善，为用户提供更加完美的数字阅读解决方案。

结语

优秀的阅读体验来自于对细节的极致追求。每一个像素的精确定位，每一次触摸的流畅响应，都体现了开发团队对用户体验的重视。

这就是我们的愿景：让数字阅读回归纸质书籍的美好感受。
''';

  // UI状态
  int _currentPage = 1;
  int _totalPages = 1;
  String _selectedText = '';
  bool _isPerformanceMonitoring = false;
  PerformanceReport? _performanceReport;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _initializeDemo();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _performanceMonitor.stopMonitoring();
    super.dispose();
  }

  Future<void> _initializeDemo() async {
    // 初始化阅读引擎协调器
    await _coordinator.initialize();
    
    // 设置性能监控回调
    _performanceMonitor.onPerformanceAlert = (level, message) {
      _showPerformanceAlert(level, message);
    };
    
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBF0),
      appBar: AppBar(
        title: const Text('高级阅读功能演示'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.auto_stories), text: '阅读演示'),
            Tab(icon: Icon(Icons.source), text: '书源系统'),
            Tab(icon: Icon(Icons.settings), text: '引擎配置'),
            Tab(icon: Icon(Icons.analytics), text: '性能监控'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildReadingDemo(),
          _buildBookSourceDemo(),
          _buildEngineConfigDemo(),
          _buildPerformanceDemo(),
        ],
      ),
    );
  }

  /// 构建阅读演示页面
  Widget _buildReadingDemo() {
    return Column(
      children: [
        // 阅读信息栏
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.1),
            border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '高级精确分页演示 (90%空间利用率)',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  Icon(Icons.article, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    '$_currentPage / $_totalPages',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        // 阅读器
        Expanded(
          child: AdvancedTextReader(
            text: _demoText,
            textStyle: const TextStyle(
              fontSize: 18.0,
              height: 1.8,
              letterSpacing: 0.2,
              color: Colors.black87,
            ),
            backgroundColor: const Color(0xFFFFFBF0),
            padding: const EdgeInsets.all(20.0),
            onPageChanged: (current, total) {
              setState(() {
                _currentPage = current;
                _totalPages = total;
              });
            },
            onTextSelected: (text, start, end) {
              setState(() {
                _selectedText = text;
              });
              if (text.isNotEmpty) {
                _showSelectedTextDialog(text);
              }
            },
            enableTextSelection: true,
            enablePageIndicator: true,
          ),
        ),
        
        // 功能按钮栏
        if (_selectedText.isNotEmpty) _buildTextActionBar(),
      ],
    );
  }

  /// 构建书源系统演示
  Widget _buildBookSourceDemo() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDemoCard(
            title: '书源管理功能',
            icon: Icons.source,
            children: [
              const Text('• 书源规则完全兼容'),
              const Text('• 支持XPath和CSS选择器'),
              const Text('• 在线书籍搜索和阅读'),
              const Text('• 导入导出和分组管理'),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _demonstrateBookSourceFeatures,
                icon: const Icon(Icons.play_circle),
                label: const Text('演示书源功能'),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          _buildDemoCard(
            title: '规则引擎示例',
            icon: Icons.code,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('搜索规则示例:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('URL: https://example.com/search?q={{key}}'),
                    Text('书籍列表: .book-list > .book-item'),
                    Text('书名: .title'),
                    Text('作者: .author'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建引擎配置演示
  Widget _buildEngineConfigDemo() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDemoCard(
            title: '阅读引擎选择',
            icon: Icons.settings,
            children: [
              ListTile(
                title: const Text('WebView引擎'),
                subtitle: const Text('适用于EPUB、PDF等格式'),
                leading: Radio<ReadingEngineType>(
                  value: ReadingEngineType.webView,
                  groupValue: _coordinator.currentEngine,
                  onChanged: (value) => _switchEngine(value!),
                ),
              ),
              ListTile(
                title: const Text('高级引擎'),
                subtitle: const Text('适用于TXT格式，提供极致体验'),
                leading: Radio<ReadingEngineType>(
                  value: ReadingEngineType.advanced,
                  groupValue: _coordinator.currentEngine,
                  onChanged: (value) => _switchEngine(value!),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          _buildDemoCard(
            title: '自动选择策略',
            icon: Icons.auto_fix_high,
            children: [
              DropdownButtonFormField<EngineSelectionStrategy>(
                value: _coordinator.selectionStrategy,
                decoration: const InputDecoration(
                  labelText: '选择策略',
                  border: OutlineInputBorder(),
                ),
                items: EngineSelectionStrategy.values.map((strategy) {
                  return DropdownMenuItem(
                    value: strategy,
                    child: Text(_getStrategyName(strategy)),
                  );
                }).toList(),
                onChanged: (strategy) {
                  if (strategy != null) {
                    _coordinator.setSelectionStrategy(strategy);
                    setState(() {});
                  }
                },
              ),
              const SizedBox(height: 16),
              const Text('系统会根据文件格式、大小、历史性能等因素智能选择最适合的引擎。'),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建性能监控演示
  Widget _buildPerformanceDemo() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDemoCard(
            title: '性能监控',
            icon: Icons.analytics,
            children: [
              Row(
                children: [
                  Switch(
                    value: _isPerformanceMonitoring,
                    onChanged: _togglePerformanceMonitoring,
                  ),
                  const SizedBox(width: 8),
                  const Text('启用性能监控'),
                ],
              ),
              if (_performanceMonitor.latestSnapshot != null)
                _buildPerformanceSnapshot(),
            ],
          ),
          
          const SizedBox(height: 16),
          
          if (_performanceReport != null) _buildPerformanceReport(),
          
          const SizedBox(height: 16),
          
          _buildDemoCard(
            title: '内存优化',
            icon: Icons.memory,
            children: [
              const Text('应用包含多项内存优化技术：'),
              const SizedBox(height: 8),
              const Text('• 智能缓存管理'),
              const Text('• 自动垃圾回收'),
              const Text('• 内存泄漏检测'),
              const Text('• 性能警告系统'),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _performanceMonitor.optimizeMemory,
                icon: const Icon(Icons.cleaning_services),
                label: const Text('执行内存优化'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建演示卡片
  Widget _buildDemoCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  /// 构建性能快照显示
  Widget _buildPerformanceSnapshot() {
    final snapshot = _performanceMonitor.latestSnapshot!;
    
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('最新性能数据:', style: TextStyle(fontWeight: FontWeight.bold)),
          Text('内存使用: ${snapshot.memoryUsageMB.toStringAsFixed(1)} MB'),
          Text('CPU使用率: ${snapshot.cpuUsage.toStringAsFixed(1)}%'),
          Text('帧率: ${snapshot.frameRate.toStringAsFixed(1)} fps'),
        ],
      ),
    );
  }

  /// 构建性能报告显示
  Widget _buildPerformanceReport() {
    return _buildDemoCard(
      title: '性能分析报告',
      icon: Icons.assessment,
      children: [
        Text('监控时长: ${_performanceReport!.timeRange.inMinutes} 分钟'),
        Text('平均内存使用: ${_performanceReport!.averageMemoryUsage.toStringAsFixed(1)} MB'),
        Text('峰值内存使用: ${_performanceReport!.peakMemoryUsage.toStringAsFixed(1)} MB'),
        Text('平均帧率: ${_performanceReport!.averageFrameRate.toStringAsFixed(1)} fps'),
        Text('性能水平: ${_performanceReport!.performanceLevel.displayName}'),
        if (_performanceReport!.recommendations.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text('优化建议:', style: TextStyle(fontWeight: FontWeight.bold)),
          ..._performanceReport!.recommendations.map((rec) => Text('• $rec')),
        ],
      ],
    );
  }

  /// 构建文字操作栏
  Widget _buildTextActionBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          TextButton.icon(
            onPressed: _copySelectedText,
            icon: const Icon(Icons.copy),
            label: const Text('复制'),
          ),
          TextButton.icon(
            onPressed: _shareSelectedText,
            icon: const Icon(Icons.share),
            label: const Text('分享'),
          ),
          TextButton.icon(
            onPressed: _addHighlight,
            icon: const Icon(Icons.highlight),
            label: const Text('高亮'),
          ),
        ],
      ),
    );
  }

  /// 演示书源功能
  void _demonstrateBookSourceFeatures() async {
    // 显示书源功能演示对话框
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('书源系统演示'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('书源系统主要功能:'),
            SizedBox(height: 8),
            Text('✓ 兼容书源格式'),
            Text('✓ 支持在线搜索和阅读'),
            Text('✓ 智能规则引擎解析'),
            Text('✓ 批量导入导出管理'),
            Text('✓ 性能监控和优化'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('了解'),
          ),
        ],
      ),
    );
  }

  /// 切换阅读引擎
  void _switchEngine(ReadingEngineType engineType) async {
    final success = await _coordinator.switchEngine(engineType);
    if (success) {
      setState(() {});
      _showSnackBar('已切换到${engineType.name}引擎');
    } else {
      _showSnackBar('引擎切换失败');
    }
  }

  /// 获取策略名称
  String _getStrategyName(EngineSelectionStrategy strategy) {
    switch (strategy) {
      case EngineSelectionStrategy.automatic:
        return '自动选择';
      case EngineSelectionStrategy.alwaysWebView:
        return '总是WebView';
      case EngineSelectionStrategy.alwaysAdvanced:
        return '总是高级';
      case EngineSelectionStrategy.userPreference:
        return '用户偏好';
    }
  }

  /// 切换性能监控
  void _togglePerformanceMonitoring(bool enabled) {
    setState(() {
      _isPerformanceMonitoring = enabled;
    });
    
    if (enabled) {
      _performanceMonitor.startMonitoring();
      _showSnackBar('性能监控已启动');
    } else {
      _performanceMonitor.stopMonitoring();
      setState(() {
        _performanceReport = _performanceMonitor.generateReport();
      });
      _showSnackBar('性能监控已停止');
    }
  }

  /// 显示选中文本对话框
  void _showSelectedTextDialog(String text) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('已选择文本'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                text.length > 100 ? '${text.substring(0, 100)}...' : text,
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
            ),
            const SizedBox(height: 8),
            Text('选中字符数: ${text.length}'),
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

  /// 复制选中文字
  void _copySelectedText() {
    if (_selectedText.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: _selectedText));
      _showSnackBar('已复制到剪贴板');
    }
  }

  /// 分享选中文字
  void _shareSelectedText() {
    // 这里应该调用分享功能
    _showSnackBar('分享功能演示');
  }

  /// 添加高亮
  void _addHighlight() {
    _showSnackBar('高亮功能演示');
  }

  /// 显示性能警告
  void _showPerformanceAlert(PerformanceLevel level, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('性能警告: $message'),
        backgroundColor: level.color,
      ),
    );
  }

  /// 显示提示消息
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
