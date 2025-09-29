import 'package:flutter/material.dart';
import '../pages/reader_page.dart';

/// 阅读器演示页面
///
/// 用于展示和测试阅读器的功能
class ReaderDemoPage extends StatelessWidget {
  const ReaderDemoPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('阅读器演示'),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                '点击下方按钮开始体验阅读器',
                style: TextStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () => _openReader(context),
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  textStyle: const TextStyle(fontSize: 16),
                ),
                child: const Text('开始阅读'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 打开阅读器
  void _openReader(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ReaderPage(
          bookContent: _getSampleText(),
          bookTitle: '演示书籍',
          initialPageIndex: 0,
        ),
      ),
    );
  }

  /// 获取示例文本
  String _getSampleText() {
    return '''
第一章：沉浸式阅读体验

在这个数字化时代，阅读已经从纸质书籍逐渐转向了数字化平台。一个优秀的电子阅读器不仅要能够清晰地显示文字，更要提供沉浸式的阅读体验，让读者能够专注于内容本身，而不被界面的复杂操作所干扰。

本阅读器专为提供最佳的阅读体验而设计，具有以下特色功能：

1. 沉浸式布局设计
文本内容占据屏幕约90%的区域，上下贯穿，不留白。这种设计理念来源于对纸质书籍阅读体验的深度模拟，让用户在阅读时能够获得最大的视觉空间。

2. 智能分页引擎
系统内置高效的分页引擎，能够根据文本内容和当前显示设置（字体、边距等）预先计算并缓存页面数据。分页计算在后台进行，不会阻塞UI线程，确保流畅的用户体验。

3. 多种翻页模式
支持三种不同的翻页模式：
- 左右滑动：通过左右滑动手势或点击屏幕左右侧切换页面
- 上下滚动：类似网页的连续滚动阅读模式
- 仿真翻页：模拟真实纸张翻页的卷曲动画效果

4. 智能信息浮层
在阅读界面顶部显示系统时间和电池电量百分比，底部显示当前页码和总页数。这些信息浮层设计得既不影响阅读，又能提供必要的信息。

5. 交互式工具栏
点击屏幕中央区域可以唤出工具栏，再次点击或点击内容区域即可隐藏。工具栏提供丰富的设置选项：
- 阅读主题切换（白天、夜间、护眼）
- 字体大小调整
- 行间距和页边距设置
- TTS语音朗读功能

第二章：技术实现细节

阅读器的核心技术基于Flutter框架，采用Provider状态管理模式，确保性能和可维护性的完美平衡。

分页算法优化：
分页引擎采用TextPainter进行精确的文本测量，考虑了字体特性、行高、字间距等因素。通过智能缓存机制，避免重复计算，提升性能。

动画系统：
所有动画都经过精心调优，达到60FPS的流畅度标准。工具栏的显示隐藏使用SlideTransition和FadeTransition，提供丝滑的视觉体验。

内存管理：
对于大体积的文本文件，系统采用智能内存管理策略，按需加载页面内容，避免内存溢出问题。

第三章：用户体验设计

好的阅读器不仅仅是技术的堆砌，更重要的是对用户体验的深度考虑。

视觉设计：
采用科学的色彩搭配和字体选择，护眼模式采用暖色调，减少蓝光对眼睛的伤害。夜间模式采用深色背景，适合暗光环境阅读。

交互设计：
所有交互都经过用户习惯分析，符合直觉操作。点击区域划分科学合理，左侧30%为上一页，右侧30%为下一页，中央40%为菜单唤出。

无障碍设计：
支持TTS语音朗读功能，配合文本高亮显示，为视力障碍用户提供便利。字体大小可以在12-36像素之间自由调节。

第四章：性能优化

性能是阅读器最重要的指标之一。用户期望的是瞬间响应，而不是等待。

加载优化：
打开书籍文件并渲染第一页的过程控制在1秒内完成。通过预加载和智能缓存技术，确保翻页操作的即时响应。

内存优化：
对于超过10MB的大文件，采用分段加载策略，只在内存中保持当前页面及前后几页的内容，其余内容按需加载。

渲染优化：
使用高效的绘制算法，避免不必要的重绘操作。文本渲染采用硬件加速，确保在各种设备上都能获得流畅的显示效果。

第五章：未来展望

阅读器的发展永无止境，我们将持续优化和改进，为用户提供更好的阅读体验。

即将推出的功能：
- 智能书签和笔记系统
- 云端同步阅读进度
- 个性化推荐算法
- 多格式文档支持
- 社交阅读功能

技术演进：
随着硬件性能的提升和新技术的涌现，我们将探索更多可能性：
- AI辅助阅读理解
- 沉浸式AR阅读体验
- 个性化排版算法
- 智能护眼技术

结语

优秀的阅读器应该是透明的——用户在使用时感受不到技术的存在，只专注于内容本身。这正是我们努力的方向：通过精湛的技术实现无感的用户体验，让阅读回归本质。

每一行代码、每一个像素、每一毫秒的优化，都是为了让用户在知识的海洋中自由遨游。这就是我们的使命，也是我们的承诺。
''';
  }
}

