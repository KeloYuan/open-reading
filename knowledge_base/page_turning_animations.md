# 翻页动画实现详解

本文档详细介绍电子书阅读器中各种翻页动画的实现原理和代码示例。

---

## 目录
1. [翻页动画类型](#翻页动画类型)
2. [滑动翻页](#滑动翻页)
3. [卷曲翻页](#卷曲翻页)
4. [覆盖翻页](#覆盖翻页)
5. [滚动翻页](#滚动翻页)
6. [性能优化](#性能优化)

---

## 翻页动画类型

### 常见翻页效果对比

| 动画类型 | 视觉效果 | 性能 | 实现难度 | 适用场景 |
|---------|---------|------|----------|----------|
| 滑动翻页 | ★★★★ | ★★★★★ | ★ | 通用 |
| 卷曲翻页 | ★★★★★ | ★★★ | ★★★★★ | 仿真阅读 |
| 覆盖翻页 | ★★★ | ★★★★ | ★★ | 杂志类 |
| 滚动翻页 | ★★ | ★★★★★ | ★ | 长文档 |
| 淡入淡出 | ★ | ★★★★★ | ★ | 简单场景 |

---

## 1. 滑动翻页

### 原理
使用PageView实现左右滑动切换页面，Flutter内置支持。

### 基础实现
```dart
class SlidePaginationView extends StatefulWidget {
  final List<String> pages;
  final int initialPage;
  final Function(int) onPageChanged;
  
  const SlidePaginationView({
    Key? key,
    required this.pages,
    this.initialPage = 0,
    required this.onPageChanged,
  }) : super(key: key);
  
  @override
  State<SlidePaginationView> createState() => _SlidePaginationViewState();
}

class _SlidePaginationViewState extends State<SlidePaginationView> {
  late PageController _controller;
  
  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: widget.initialPage);
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _controller,
      itemCount: widget.pages.length,
      onPageChanged: widget.onPageChanged,
      itemBuilder: (context, index) {
        return _buildPage(widget.pages[index]);
      },
    );
  }
  
  Widget _buildPage(String content) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: SelectableText(
        content,
        style: const TextStyle(fontSize: 18, height: 1.8),
      ),
    );
  }
}
```

### 进阶：自定义滑动效果
```dart
class CustomSlidePaginationView extends StatelessWidget {
  final List<String> pages;
  final int currentPage;
  final PageController controller;
  
  const CustomSlidePaginationView({
    Key? key,
    required this.pages,
    required this.currentPage,
    required this.controller,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: controller,
      itemCount: pages.length,
      itemBuilder: (context, index) {
        return AnimatedBuilder(
          animation: controller,
          builder: (context, child) {
            // 计算页面偏移量（-1到1之间）
            double value = 1.0;
            if (controller.position.haveDimensions) {
              value = (controller.page! - index).abs().clamp(0.0, 1.0);
            }
            
            // 透明度动画
            final opacity = 1.0 - (value * 0.3);
            
            // 缩放动画
            final scale = 1.0 - (value * 0.1);
            
            return Opacity(
              opacity: opacity,
              child: Transform.scale(
                scale: scale,
                child: child,
              ),
            );
          },
          child: _buildPage(pages[index]),
        );
      },
    );
  }
  
  Widget _buildPage(String content) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Text(content, style: const TextStyle(fontSize: 18, height: 1.8)),
    );
  }
}
```

### 性能优化
```dart
class OptimizedSlidePaginationView extends StatefulWidget {
  final List<String> pages;
  
  @override
  State<OptimizedSlidePaginationView> createState() => _OptimizedSlidePaginationViewState();
}

class _OptimizedSlidePaginationViewState extends State<OptimizedSlidePaginationView> {
  late PageController _controller;
  
  // 缓存已构建的页面Widget
  final Map<int, Widget> _cachedPages = {};
  
  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _controller,
      itemCount: widget.pages.length,
      itemBuilder: (context, index) {
        // 使用缓存
        if (!_cachedPages.containsKey(index)) {
          _cachedPages[index] = _buildPage(widget.pages[index]);
        }
        return _cachedPages[index]!;
      },
    );
  }
  
  Widget _buildPage(String content) {
    return RepaintBoundary(  // 防止不必要的重绘
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Text(content, style: const TextStyle(fontSize: 18, height: 1.8)),
      ),
    );
  }
  
  @override
  void dispose() {
    _cachedPages.clear();
    _controller.dispose();
    super.dispose();
  }
}
```

---

## 2. 卷曲翻页（仿真翻页）

### 原理
模拟真实书页翻动的3D效果，使用page_flip插件或自定义实现。

### 使用page_flip插件
```dart
import 'package:page_flip/page_flip.dart';

class CurlPageFlipView extends StatefulWidget {
  final List<String> pages;
  
  const CurlPageFlipView({Key? key, required this.pages}) : super(key: key);
  
  @override
  State<CurlPageFlipView> createState() => _CurlPageFlipViewState();
}

class _CurlPageFlipViewState extends State<CurlPageFlipView> {
  final _controller = GlobalKey<PageFlipWidgetState>();
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageFlipWidget(
        key: _controller,
        backgroundColor: Colors.white,
        // 最后一页
        lastPage: Container(
          color: Colors.white,
          child: const Center(
            child: Text('已到最后一页', style: TextStyle(fontSize: 18)),
          ),
        ),
        // 所有页面
        children: widget.pages.map((page) {
          return Container(
            color: Colors.white,
            padding: const EdgeInsets.all(20),
            child: Text(
              page,
              style: const TextStyle(fontSize: 18, height: 1.8),
            ),
          );
        }).toList(),
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: () {
              _controller.currentState?.previousPage();
            },
            child: const Icon(Icons.chevron_left),
          ),
          const SizedBox(width: 16),
          FloatingActionButton(
            onPressed: () {
              _controller.currentState?.nextPage();
            },
            child: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}
```

### 自定义卷曲效果（简化版）
```dart
class CustomCurlPageFlip extends StatefulWidget {
  final Widget currentPage;
  final Widget? nextPage;
  
  const CustomCurlPageFlip({
    Key? key,
    required this.currentPage,
    this.nextPage,
  }) : super(key: key);
  
  @override
  State<CustomCurlPageFlip> createState() => _CustomCurlPageFlipState();
}

class _CustomCurlPageFlipState extends State<CustomCurlPageFlip> 
    with SingleTickerProviderStateMixin {
  
  late AnimationController _controller;
  late Animation<double> _animation;
  Offset? _dragStart;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragStart: (details) {
        _dragStart = details.localPosition;
      },
      onHorizontalDragUpdate: (details) {
        if (_dragStart != null) {
          final delta = details.localPosition.dx - _dragStart!.dx;
          final width = MediaQuery.of(context).size.width;
          _controller.value = (-delta / width).clamp(0.0, 1.0);
        }
      },
      onHorizontalDragEnd: (details) {
        if (_controller.value > 0.5) {
          _controller.forward();
        } else {
          _controller.reverse();
        }
        _dragStart = null;
      },
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return CustomPaint(
            painter: _PageCurlPainter(
              currentPage: widget.currentPage,
              nextPage: widget.nextPage,
              progress: _animation.value,
            ),
            child: Container(),
          );
        },
      ),
    );
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _PageCurlPainter extends CustomPainter {
  final Widget currentPage;
  final Widget? nextPage;
  final double progress;
  
  _PageCurlPainter({
    required this.currentPage,
    this.nextPage,
    required this.progress,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    // 这里需要复杂的3D变换计算
    // 实际项目中建议使用现成的插件
    
    // 简化版：只实现基本的卷曲效果
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    
    // 绘制当前页
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
    
    // 绘制卷曲的角
    if (progress > 0) {
      final curlSize = size.width * progress;
      final path = Path();
      path.moveTo(size.width, 0);
      path.lineTo(size.width - curlSize, 0);
      path.quadraticBezierTo(
        size.width - curlSize * 0.5, curlSize * 0.5,
        size.width, curlSize,
      );
      path.close();
      
      paint.color = Colors.grey.withOpacity(0.3);
      canvas.drawPath(path, paint);
    }
  }
  
  @override
  bool shouldRepaint(_PageCurlPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
```

---

## 3. 覆盖翻页

### 原理
新页面从右侧覆盖到当前页面上，类似卡片堆叠效果。

### 实现
```dart
class CoverPageFlip extends StatefulWidget {
  final List<String> pages;
  final int initialPage;
  
  const CoverPageFlip({
    Key? key,
    required this.pages,
    this.initialPage = 0,
  }) : super(key: key);
  
  @override
  State<CoverPageFlip> createState() => _CoverPageFlipState();
}

class _CoverPageFlipState extends State<CoverPageFlip> 
    with SingleTickerProviderStateMixin {
  
  late int _currentPage;
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  bool _isForward = true;
  
  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1, 0),  // 从右侧开始
      end: Offset.zero,            // 到达中心
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));
  }
  
  void _nextPage() {
    if (_currentPage < widget.pages.length - 1) {
      setState(() {
        _isForward = true;
        _currentPage++;
      });
      _controller.forward(from: 0);
    }
  }
  
  void _previousPage() {
    if (_currentPage > 0) {
      setState(() {
        _isForward = false;
        _currentPage--;
      });
      _controller.forward(from: 0);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity! < 0) {
          _nextPage();
        } else if (details.primaryVelocity! > 0) {
          _previousPage();
        }
      },
      child: Stack(
        children: [
          // 当前页（底层）
          _buildPage(widget.pages[_currentPage]),
          
          // 动画页（顶层）
          if (_controller.isAnimating)
            SlideTransition(
              position: _slideAnimation,
              child: _buildPage(widget.pages[_currentPage]),
            ),
        ],
      ),
    );
  }
  
  Widget _buildPage(String content) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Text(
        content,
        style: const TextStyle(fontSize: 18, height: 1.8),
      ),
    );
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
```

### 改进版：带阴影效果
```dart
class CoverPageFlipWithShadow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 底层页面
        _buildPage(currentPage),
        
        // 顶层页面（带阴影）
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(
                MediaQuery.of(context).size.width * (1 - _controller.value),
                0,
              ),
              child: Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3 * _controller.value),
                      blurRadius: 20,
                      offset: const Offset(-5, 0),
                    ),
                  ],
                ),
                child: child,
              ),
            );
          },
          child: _buildPage(nextPage),
        ),
      ],
    );
  }
}
```

---

## 4. 滚动翻页

### 原理
垂直滚动，适合长文档阅读。

### 基础实现
```dart
class ScrollPaginationView extends StatefulWidget {
  final List<String> pages;
  final Function(int) onPageChanged;
  
  const ScrollPaginationView({
    Key? key,
    required this.pages,
    required this.onPageChanged,
  }) : super(key: key);
  
  @override
  State<ScrollPaginationView> createState() => _ScrollPaginationViewState();
}

class _ScrollPaginationViewState extends State<ScrollPaginationView> {
  late ScrollController _controller;
  int _currentPage = 0;
  
  @override
  void initState() {
    super.initState();
    _controller = ScrollController();
    _controller.addListener(_onScroll);
  }
  
  void _onScroll() {
    if (!_controller.hasClients) return;
    
    final offset = _controller.offset;
    final screenHeight = MediaQuery.of(context).size.height;
    final currentPage = (offset / screenHeight).round();
    
    if (currentPage != _currentPage) {
      _currentPage = currentPage;
      widget.onPageChanged(currentPage);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    
    return ListView.builder(
      controller: _controller,
      itemCount: widget.pages.length,
      itemBuilder: (context, index) {
        return SizedBox(
          height: screenHeight,
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Text(
              widget.pages[index],
              style: const TextStyle(fontSize: 18, height: 1.8),
            ),
          ),
        );
      },
    );
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
```

### 改进：添加吸附效果
```dart
class SnapScrollPaginationView extends StatefulWidget {
  final List<String> pages;
  
  @override
  State<SnapScrollPaginationView> createState() => _SnapScrollPaginationViewState();
}

class _SnapScrollPaginationViewState extends State<SnapScrollPaginationView> {
  late ScrollController _controller;
  
  @override
  void initState() {
    super.initState();
    _controller = ScrollController();
  }
  
  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    
    return NotificationListener<ScrollEndNotification>(
      onNotification: (notification) {
        // 滚动结束时，吸附到最近的页面
        final currentPage = (_controller.offset / screenHeight).round();
        final targetOffset = currentPage * screenHeight;
        
        _controller.animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
        
        return true;
      },
      child: ListView.builder(
        controller: _controller,
        itemCount: widget.pages.length,
        itemBuilder: (context, index) {
          return SizedBox(
            height: screenHeight,
            child: _buildPage(widget.pages[index]),
          );
        },
      ),
    );
  }
  
  Widget _buildPage(String content) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Text(
        content,
        style: const TextStyle(fontSize: 18, height: 1.8),
      ),
    );
  }
}
```

---

## 5. 淡入淡出翻页

### 实现
```dart
class FadePageFlip extends StatefulWidget {
  final List<String> pages;
  
  @override
  State<FadePageFlip> createState() => _FadePageFlipState();
}

class _FadePageFlipState extends State<FadePageFlip> 
    with SingleTickerProviderStateMixin {
  
  late AnimationController _controller;
  late Animation<double> _fadeOut;
  late Animation<double> _fadeIn;
  int _currentPage = 0;
  int? _nextPage;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    _fadeOut = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );
    
    _fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 1.0, curve: Curves.easeIn),
      ),
    );
    
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _currentPage = _nextPage!;
          _nextPage = null;
          _controller.reset();
        });
      }
    });
  }
  
  void _goToPage(int page) {
    if (page >= 0 && page < widget.pages.length && page != _currentPage) {
      setState(() {
        _nextPage = page;
      });
      _controller.forward();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _goToPage(_currentPage + 1),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Stack(
            children: [
              // 当前页（淡出）
              Opacity(
                opacity: _nextPage == null ? 1.0 : _fadeOut.value,
                child: _buildPage(widget.pages[_currentPage]),
              ),
              
              // 下一页（淡入）
              if (_nextPage != null)
                Opacity(
                  opacity: _fadeIn.value,
                  child: _buildPage(widget.pages[_nextPage!]),
                ),
            ],
          );
        },
      ),
    );
  }
  
  Widget _buildPage(String content) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Text(
        content,
        style: const TextStyle(fontSize: 18, height: 1.8),
      ),
    );
  }
}
```

---

## 性能优化

### 1. 预加载相邻页面
```dart
class PreloadPaginationView extends StatefulWidget {
  final List<String> pages;
  
  @override
  State<PreloadPaginationView> createState() => _PreloadPaginationViewState();
}

class _PreloadPaginationViewState extends State<PreloadPaginationView> {
  late PageController _controller;
  final Map<int, Widget> _pageCache = {};
  
  @override
  void initState() {
    super.initState();
    _controller = PageController();
    _controller.addListener(_onPageChanged);
    
    // 预加载前3页
    for (int i = 0; i < 3 && i < widget.pages.length; i++) {
      _preloadPage(i);
    }
  }
  
  void _onPageChanged() {
    if (!_controller.hasClients) return;
    
    final currentPage = _controller.page!.round();
    
    // 预加载相邻页面
    _preloadPage(currentPage - 1);
    _preloadPage(currentPage);
    _preloadPage(currentPage + 1);
    
    // 清理远离的页面缓存
    _cleanupCache(currentPage);
  }
  
  void _preloadPage(int index) {
    if (index >= 0 && index < widget.pages.length && !_pageCache.containsKey(index)) {
      _pageCache[index] = _buildPage(widget.pages[index]);
    }
  }
  
  void _cleanupCache(int currentPage) {
    // 只保留当前页前后各5页的缓存
    _pageCache.removeWhere((key, value) {
      return (key - currentPage).abs() > 5;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _controller,
      itemCount: widget.pages.length,
      itemBuilder: (context, index) {
        return _pageCache[index] ?? _buildPage(widget.pages[index]);
      },
    );
  }
  
  Widget _buildPage(String content) {
    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Text(
          content,
          style: const TextStyle(fontSize: 18, height: 1.8),
        ),
      ),
    );
  }
}
```

### 2. 使用RepaintBoundary
```dart
Widget _buildOptimizedPage(String content) {
  return RepaintBoundary(  // 防止不必要的重绘
    child: Container(
      padding: const EdgeInsets.all(20),
      child: Text(
        content,
        style: const TextStyle(fontSize: 18, height: 1.8),
      ),
    ),
  );
}
```

### 3. 懒加载图片
```dart
Widget _buildPageWithImages(String content, List<String> images) {
  return ListView(
    children: [
      Text(content),
      ...images.map((imagePath) {
        return FutureBuilder(
          future: _loadImage(imagePath),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return Image.memory(snapshot.data!);
            }
            return const CircularProgressIndicator();
          },
        );
      }),
    ],
  );
}
```

---

## 总结

### 推荐方案
1. **通用场景**: 滑动翻页（PageView）
2. **仿真阅读**: 卷曲翻页（page_flip插件）
3. **长文档**: 滚动翻页（ListView）
4. **性能优先**: 淡入淡出（最轻量）

### 性能对比

| 动画类型 | 帧率 | 内存 | CPU | 推荐度 |
|---------|------|------|-----|--------|
| 滑动 | 60fps | 中 | 低 | ⭐⭐⭐⭐⭐ |
| 卷曲 | 45-55fps | 高 | 高 | ⭐⭐⭐ |
| 覆盖 | 60fps | 中 | 中 | ⭐⭐⭐⭐ |
| 滚动 | 60fps | 低 | 低 | ⭐⭐⭐⭐⭐ |
| 淡入淡出 | 60fps | 低 | 低 | ⭐⭐⭐⭐ |

---

*更新于: 2025-10-19*

