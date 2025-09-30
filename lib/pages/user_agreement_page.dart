import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 用户协议页面
///
/// 在首次启动应用时显示，包含用户协议内容和同意按钮
/// 具有优美的动画效果和符合项目风格的毛玻璃设计
///
/// 核心功能：
/// - [_showAnimatedContent] 显示带动画的协议内容
/// - [_onAgreePressed] 处理用户同意操作
/// - [_onDisagreePressed] 处理用户拒绝操作
class UserAgreementPage extends StatefulWidget {
  /// 用户同意协议后的回调
  final VoidCallback onAgreed;

  /// 用户拒绝协议后的回调（可选）
  final VoidCallback? onDisagreed;

  const UserAgreementPage({
    super.key,
    required this.onAgreed,
    this.onDisagreed,
  });

  @override
  State<UserAgreementPage> createState() => _UserAgreementPageState();
}

class _UserAgreementPageState extends State<UserAgreementPage>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _slideController;

  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;

  bool _showContent = false;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _startAnimations();
  }

  /// 初始化所有动画控制器和动画
  void _initAnimations() {
    // 淡入动画
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));

    // 缩放动画
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    // 滑动动画
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );
  }

  /// 启动动画序列
  void _startAnimations() async {
    await Future.delayed(const Duration(milliseconds: 200));

    // 并行启动背景动画
    _fadeController.forward();
    _scaleController.forward();

    // 延迟启动内容动画
    await Future.delayed(const Duration(milliseconds: 300));
    setState(() => _showContent = true);
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // 动态背景
          _buildAnimatedBackground(),
          // 主内容
          AnimatedBuilder(
            animation: _fadeAnimation,
            builder: (context, child) {
              return Opacity(
                opacity: _fadeAnimation.value,
                child: _buildContent(),
              );
            },
          ),
        ],
      ),
    );
  }

  /// 构建动态背景
  Widget _buildAnimatedBackground() {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: const [0.0, 0.3, 0.6, 1.0],
                colors: [
                  Theme.of(context).colorScheme.primary.withOpacity(0.15),
                  Theme.of(
                    context,
                  ).colorScheme.secondary.withOpacity(0.08),
                  Theme.of(
                    context,
                  ).colorScheme.tertiary.withOpacity(0.12),
                  Theme.of(context).colorScheme.surface.withOpacity(0.95),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// 构建主要内容
  Widget _buildContent() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Spacer(flex: 1),
            // 应用图标和标题
            _buildHeader(),
            const SizedBox(height: 40),
            // 协议内容卡片
            Expanded(
              flex: 6,
              child: _showContent
                  ? SlideTransition(
                      position: _slideAnimation,
                      child: _buildAgreementCard(),
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(height: 24),
            // 底部按钮
            if (_showContent)
              SlideTransition(
                position: _slideAnimation,
                child: _buildButtons(),
              ),
            const Spacer(flex: 1),
          ],
        ),
      ),
    );
  }

  /// 构建页面头部（应用图标和标题）
  Widget _buildHeader() {
    return Column(
      children: [
        // 应用图标
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.secondary,
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: const Icon(
            Icons.auto_stories_rounded,
            color: Colors.white,
            size: 40,
          ),
        ),
        const SizedBox(height: 16),
        // 应用标题
        Text(
          '小元读书',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '优雅的阅读体验',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  /// 构建协议内容卡片
  Widget _buildAgreementCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.outline.withOpacity(0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              // 卡片标题
              Container(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.article_outlined,
                        color: Theme.of(context).colorScheme.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '用户服务协议',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              // 协议内容
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: _buildAgreementContent(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建协议内容文本
  Widget _buildAgreementContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('欢迎使用小元读书'),
        _buildSectionContent('该应用为开发版，不代表最终结果，仅供测试使用，无法使用的功能就是还没做好'),

        /*const SizedBox(height: 20),
        _buildSectionTitle('1. 服务描述'),
        _buildSectionContent(
          '小元读书是一款专业的电子书阅读应用，为您提供优雅的阅读体验。我们支持EPUB、PDF等多种格式，'
          '并提供书签管理、阅读统计、云端同步、TTS朗读等功能。',
        ),

        const SizedBox(height: 16),
        _buildSectionTitle('2. 隐私保护'),
        _buildSectionContent(
          '我们高度重视您的隐私权。除非获得您的明确同意，我们不会收集、使用或分享您的个人信息。'
          '您的阅读数据将安全存储在本地设备上。',
        ),

        const SizedBox(height: 16),
        _buildSectionTitle('3. 数据安全'),
        _buildSectionContent(
          '应用会在您的设备上存储阅读进度、书签、笔记等数据。我们采用行业标准的安全措施保护您的数据。'
          '如您选择使用云端同步功能，数据将通过加密传输。',
        ),

        const SizedBox(height: 16),
        _buildSectionTitle('4. 使用条款'),
        _buildSectionContent(
          '• 请确保您导入的书籍内容符合相关法律法规\n'
          '• 不得将应用用于任何非法或有害活动\n'
          '• 我们保留在必要时更新协议条款的权利\n'
          '• 继续使用应用即表示您同意遵守这些条款',
        ),*/
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.primaryContainer.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '点击"同意并继续"即表示您已阅读并同意上述条款',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 构建章节标题
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  /// 构建章节内容
  Widget _buildSectionContent(String content) {
    return Text(
      content,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        height: 1.6,
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
      ),
    );
  }

  /// 构建底部按钮
  Widget _buildButtons() {
    return Row(
      children: [
        // 拒绝按钮
        Expanded(
          child: _buildActionButton(
            label: '退出应用',
            onPressed: _onDisagreePressed,
            isPrimary: false,
          ),
        ),
        const SizedBox(width: 16),
        // 同意按钮
        Expanded(
          flex: 2,
          child: _buildActionButton(
            label: '同意并继续',
            onPressed: _onAgreePressed,
            isPrimary: true,
          ),
        ),
      ],
    );
  }

  /// 构建操作按钮
  Widget _buildActionButton({
    required String label,
    required VoidCallback onPressed,
    required bool isPrimary,
  }) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        boxShadow: isPrimary
            ? [
                BoxShadow(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: isPrimary
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(
                      context,
                    ).colorScheme.surface.withOpacity(0.8),
              foregroundColor: isPrimary
                  ? Theme.of(context).colorScheme.onPrimary
                  : Theme.of(context).colorScheme.onSurface,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
                side: isPrimary
                    ? BorderSide.none
                    : BorderSide(
                        color: Theme.of(
                          context,
                        ).colorScheme.outline.withOpacity(0.3),
                      ),
              ),
            ),
            child: Text(
              label,
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
          ),
        ),
      ),
    );
  }

  /// 处理用户同意操作
  ///
  /// 保存用户同意状态到SharedPreferences，并调用成功回调
  Future<void> _onAgreePressed() async {
    try {
      // 保存用户同意状态
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('userAgreementAccepted', true);
      await prefs.setString(
        'agreementAcceptedDate',
        DateTime.now().toIso8601String(),
      );

      debugPrint('✅ 用户协议已同意，状态已保存');

      // 添加触觉反馈
      // HapticFeedback.lightImpact();

      // 调用成功回调
      widget.onAgreed();
    } catch (e) {
      debugPrint('❌ 保存协议状态失败: $e');
      // 即使保存失败，也允许用户继续使用
      widget.onAgreed();
    }
  }

  /// 处理用户拒绝操作
  ///
  /// 如果用户拒绝协议，可以退出应用或显示说明
  void _onDisagreePressed() {
    // 显示确认对话框
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退出应用'),
        content: const Text('如果您不同意用户协议，将无法使用本应用。确定要退出吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (widget.onDisagreed != null) {
                widget.onDisagreed!();
              }
            },
            child: const Text('确定退出'),
          ),
        ],
      ),
    );
  }
}

/// 用户协议服务
///
/// 提供协议相关的辅助方法
class UserAgreementService {
  static const String _keyAgreementAccepted = 'userAgreementAccepted';
  static const String _keyAcceptedDate = 'agreementAcceptedDate';

  /// 检查用户是否已同意协议
  static Future<bool> hasUserAcceptedAgreement() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyAgreementAccepted) ?? false;
    } catch (e) {
      debugPrint('❌ 检查协议状态失败: $e');
      return false;
    }
  }

  /// 获取用户同意协议的日期
  static Future<DateTime?> getAgreementAcceptedDate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dateString = prefs.getString(_keyAcceptedDate);
      return dateString != null ? DateTime.parse(dateString) : null;
    } catch (e) {
      debugPrint('❌ 获取协议日期失败: $e');
      return null;
    }
  }

  /// 重置协议状态（用于测试或重新显示协议）
  static Future<void> resetAgreementStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyAgreementAccepted);
      await prefs.remove(_keyAcceptedDate);
      debugPrint('🔄 协议状态已重置');
    } catch (e) {
      debugPrint('❌ 重置协议状态失败: $e');
    }
  }
}
