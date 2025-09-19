import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'pages/advanced_reader_demo_page.dart';

/// 高级阅读器演示应用入口
/// 展示基于anx-reader原理的精确分页效果
void main() {
  runApp(const AdvancedReaderDemoApp());
}

class AdvancedReaderDemoApp extends StatelessWidget {
  const AdvancedReaderDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'xxread 高级阅读器演示',
      theme: ThemeData(primarySwatch: Colors.blue, fontFamily: 'System'),
      home: const DemoHomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class DemoHomePage extends StatelessWidget {
  const DemoHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 应用图标和标题
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.auto_stories,
                  size: 60,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 30),

              const Text(
                'xxread 高级阅读器',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C2C2C),
                ),
              ),

              const SizedBox(height: 10),

              const Text(
                '基于 anx-reader 原理的精确分页技术',
                style: TextStyle(fontSize: 16, color: Color(0xFF666666)),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 50),

              // 功能特性
              _buildFeatureList(),

              const SizedBox(height: 50),

              // 开始体验按钮
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AdvancedReaderDemoPage(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '开始体验高级分页',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // 技术说明
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E8),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF4CAF50).withValues(alpha: 0.2),
                  ),
                ),
                child: const Column(
                  children: [
                    Text(
                      '💡 技术亮点',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E4A2E),
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '本演示展示了如何在Flutter中实现anx-reader的核心分页算法，'
                      '包括智能断点检测、文本完整性保证和响应式布局适配。',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF2E4A2E),
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureList() {
    final features = [
      {
        'icon': Icons.auto_fix_high,
        'title': '智能分页',
        'description': '基于文本边界的精确分页算法',
      },
      {
        'icon': Icons.security,
        'title': '文字完整',
        'description': '100%保证文字不丢失不截断',
      },
      {'icon': Icons.devices, 'title': '响应式', 'description': '自适应各种屏幕尺寸设备'},
      {'icon': Icons.speed, 'title': '高性能', 'description': '优化算法确保流畅体验'},
    ];

    return Column(
      children: features
          .map(
            (feature) => _buildFeatureItem(
              icon: feature['icon'] as IconData,
              title: feature['title'] as String,
              description: feature['description'] as String,
            ),
          )
          .toList(),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF4CAF50), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2C2C2C),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF666666),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
