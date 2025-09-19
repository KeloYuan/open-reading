import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
// import 'package:flutter_inappwebview/flutter_inappwebview.dart'; // WebView功能的模拟实现
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// 高级文本分页器 - 基于anx-reader的精确分页算法
/// 使用WebView + JavaScript实现精确的文本分页和渲染
class AdvancedTextPaginator {
  static const String _htmlTemplate =
      '''
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
    <title>高级文本分页器</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        html, body {
            height: 100%;
            overflow: hidden;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', system-ui, sans-serif;
        }
        
        body {
            background-color: var(--bg-color, #FFFBF0);
            color: var(--text-color, #2C2C2C);
            transition: background-color 0.3s ease, color 0.3s ease;
        }
        
        #container {
            position: relative;
            width: 100vw;
            height: 100vh;
            overflow: hidden;
        }
        
        #paginator {
            position: relative;
            width: 100%;
            height: 100%;
            overflow: hidden;
            display: flex;
            flex-direction: row;
        }
        
        .page-view {
            position: relative;
            width: 100%;
            height: 100%;
            flex: 0 0 auto;
            overflow: hidden;
            display: flex;
            flex-direction: column;
            justify-content: flex-start;
            align-items: center;
        }
        
        .page-content {
            position: relative;
            width: 100%;
            height: 100%;
            padding: var(--page-padding, 20px);
            column-width: var(--column-width, auto);
            column-gap: var(--column-gap, 30px);
            column-fill: auto;
            overflow: hidden;
            text-align: justify;
            line-height: var(--line-height, 1.6);
            font-size: var(--font-size, 16px);
            letter-spacing: var(--letter-spacing, 0px);
            word-wrap: break-word;
            overflow-wrap: break-word;
            hyphens: auto;
            -webkit-line-box-contain: block glyphs replaced;
        }
        
        .page-content p {
            margin-bottom: var(--paragraph-spacing, 0.8em);
            text-indent: var(--text-indent, 2em);
        }
        
        .page-content .chapter-title {
            font-size: 1.2em;
            font-weight: bold;
            margin-bottom: 1em;
            text-align: center;
            text-indent: 0;
        }
        
        /* 页面信息 */
        .page-info {
            position: absolute;
            bottom: 10px;
            left: 50%;
            transform: translateX(-50%);
            font-size: 12px;
            color: var(--text-color, #2C2C2C);
            opacity: 0.6;
            user-select: none;
            pointer-events: none;
        }
        
        /* 滚动模式 */
        .scroll-mode {
            column-width: auto !important;
            column-gap: 0 !important;
            height: auto !important;
            max-width: var(--max-width, 720px);
            margin: 0 auto;
            overflow-y: auto;
        }
        
        /* 选择文本样式 */
        ::selection {
            background-color: rgba(74, 144, 226, 0.3);
        }
        
        ::-moz-selection {
            background-color: rgba(74, 144, 226, 0.3);
        }
        
        /* 响应式设计 */
        @media (max-width: 600px) {
            .page-content {
                column-width: auto !important;
                padding: var(--mobile-padding, 15px);
            }
        }
        
        @media (orientation: landscape) and (max-width: 900px) {
            .page-content {
                column-width: var(--landscape-column-width, auto);
                column-gap: var(--landscape-column-gap, 20px);
            }
        }
    </style>
</head>
<body>
    <div id="container">
        <div id="paginator"></div>
    </div>
    
    <script>
        // 高级分页器JavaScript核心逻辑
        class AdvancedPaginator {
            constructor() {
                this.container = document.getElementById('paginator');
                this.pages = [];
                this.currentPageIndex = 0;
                this.textContent = '';
                this.config = {
                    fontSize: 16,
                    lineHeight: 1.6,
                    letterSpacing: 0,
                    pagePadding: 20,
                    columnGap: 30,
                    paragraphSpacing: '0.8em',
                    textIndent: '2em',
                    maxColumnCount: 1,
                    flow: 'paginated' // 'paginated' or 'scrolled'
                };
                this.isInitialized = false;
                this.initializeEventListeners();
            }
            
            // 初始化事件监听
            initializeEventListeners() {
                // 点击翻页
                document.addEventListener('click', (e) => {
                    if (this.config.flow !== 'paginated') return;
                    
                    const rect = this.container.getBoundingClientRect();
                    const x = e.clientX - rect.left;
                    const width = rect.width;
                    const clickRatio = x / width;
                    
                    if (clickRatio < 0.3) {
                        this.prevPage();
                    } else if (clickRatio > 0.7) {
                        this.nextPage();
                    } else {
                        // 中间区域，可以用于显示菜单
                        this.notifyFlutter('onMiddleClick', { x, y: e.clientY - rect.top });
                    }
                });
                
                // 键盘导航
                document.addEventListener('keydown', (e) => {
                    if (this.config.flow !== 'paginated') return;
                    
                    switch(e.key) {
                        case 'ArrowLeft':
                        case 'ArrowUp':
                        case 'PageUp':
                            e.preventDefault();
                            this.prevPage();
                            break;
                        case 'ArrowRight':
                        case 'ArrowDown':
                        case 'PageDown':
                        case ' ':
                            e.preventDefault();
                            this.nextPage();
                            break;
                    }
                });
                
                // 触摸手势（简化版）
                let touchStartX = 0;
                let touchStartTime = 0;
                
                document.addEventListener('touchstart', (e) => {
                    if (this.config.flow !== 'paginated') return;
                    touchStartX = e.touches[0].clientX;
                    touchStartTime = Date.now();
                });
                
                document.addEventListener('touchend', (e) => {
                    if (this.config.flow !== 'paginated') return;
                    
                    const touchEndX = e.changedTouches[0].clientX;
                    const touchEndTime = Date.now();
                    const deltaX = touchEndX - touchStartX;
                    const deltaTime = touchEndTime - touchStartTime;
                    
                    // 快速滑动或长距离滑动
                    if (deltaTime < 300 || Math.abs(deltaX) > 50) {
                        if (deltaX > 30) {
                            this.prevPage();
                        } else if (deltaX < -30) {
                            this.nextPage();
                        }
                    }
                });
            }
            
            // 设置文本内容并分页
            async setText(text, config = {}) {
                this.textContent = text;
                this.config = { ...this.config, ...config };
                this.applyStyles();
                
                if (this.config.flow === 'scrolled') {
                    this.createScrollView();
                } else {
                    await this.createPages();
                }
                
                this.isInitialized = true;
                this.notifyFlutter('onPaginationComplete', {
                    totalPages: this.pages.length,
                    currentPage: this.currentPageIndex + 1
                });
            }
            
            // 应用样式
            applyStyles() {
                const root = document.documentElement;
                root.style.setProperty('--font-size', this.config.fontSize + 'px');
                root.style.setProperty('--line-height', this.config.lineHeight);
                root.style.setProperty('--letter-spacing', this.config.letterSpacing + 'px');
                root.style.setProperty('--page-padding', this.config.pagePadding + 'px');
                root.style.setProperty('--column-gap', this.config.columnGap + 'px');
                root.style.setProperty('--paragraph-spacing', this.config.paragraphSpacing);
                root.style.setProperty('--text-indent', this.config.textIndent);
                root.style.setProperty('--bg-color', this.config.backgroundColor || '#FFFBF0');
                root.style.setProperty('--text-color', this.config.textColor || '#2C2C2C');
                
                // 响应式列宽计算
                const containerWidth = window.innerWidth - this.config.pagePadding * 2;
                const maxColumnWidth = 600; // 最大列宽
                const columnCount = this.config.maxColumnCount > 1 && containerWidth > 800 
                    ? Math.min(this.config.maxColumnCount, Math.floor(containerWidth / maxColumnWidth))
                    : 1;
                
                if (columnCount > 1) {
                    const columnWidth = (containerWidth - this.config.columnGap * (columnCount - 1)) / columnCount;
                    root.style.setProperty('--column-width', columnWidth + 'px');
                } else {
                    root.style.setProperty('--column-width', 'auto');
                }
            }
            
            // 创建滚动视图
            createScrollView() {
                this.container.innerHTML = '';
                const pageView = document.createElement('div');
                pageView.className = 'page-view';
                
                const pageContent = document.createElement('div');
                pageContent.className = 'page-content scroll-mode';
                pageContent.innerHTML = this.formatText(this.textContent);
                
                pageView.appendChild(pageContent);
                this.container.appendChild(pageView);
                
                this.pages = [{ element: pageView, content: this.textContent }];
            }
            
            // 创建分页视图
            async createPages() {
                this.container.innerHTML = '';
                this.pages = [];
                
                // 创建临时测量元素
                const measureDiv = document.createElement('div');
                measureDiv.className = 'page-content';
                measureDiv.style.position = 'absolute';
                measureDiv.style.top = '-9999px';
                measureDiv.style.left = '-9999px';
                measureDiv.style.visibility = 'hidden';
                document.body.appendChild(measureDiv);
                
                try {
                    const paragraphs = this.textContent.split(/\n\s*\n/).filter(p => p.trim());
                    let currentPageContent = '';
                    let pageIndex = 0;
                    
                    for (let i = 0; i < paragraphs.length; i++) {
                        const paragraph = paragraphs[i].trim();
                        if (!paragraph) continue;
                        
                        // 测试添加这个段落是否会超出页面
                        const testContent = currentPageContent + (currentPageContent ? '\\n\\n' : '') + paragraph;
                        measureDiv.innerHTML = this.formatText(testContent);
                        
                        // 使用精确的高度检测
                        const contentHeight = measureDiv.scrollHeight;
                        const availableHeight = window.innerHeight - this.config.pagePadding * 2;
                        
                        if (contentHeight > availableHeight && currentPageContent) {
                            // 当前段落会导致超出，先创建当前页面
                            this.createPageElement(currentPageContent, pageIndex++);
                            currentPageContent = paragraph;
                        } else {
                            // 可以添加到当前页面
                            if (currentPageContent) {
                                currentPageContent += '\\n\\n' + paragraph;
                            } else {
                                currentPageContent = paragraph;
                            }
                        }
                        
                        // 如果单个段落就超出页面，需要分割段落
                        if (currentPageContent === paragraph) {
                            measureDiv.innerHTML = this.formatText(currentPageContent);
                            if (measureDiv.scrollHeight > availableHeight) {
                                const splitPages = await this.splitLongParagraph(paragraph, measureDiv, availableHeight);
                                splitPages.forEach(content => {
                                    if (content.trim()) {
                                        this.createPageElement(content, pageIndex++);
                                    }
                                });
                                currentPageContent = '';
                            }
                        }
                    }
                    
                    // 创建最后一页
                    if (currentPageContent.trim()) {
                        this.createPageElement(currentPageContent, pageIndex);
                    }
                    
                } finally {
                    document.body.removeChild(measureDiv);
                }
                
                // 确保至少有一页
                if (this.pages.length === 0) {
                    this.createPageElement(this.textContent || '内容为空', 0);
                }
                
                this.goToPage(0);
            }
            
            // 分割过长的段落
            async splitLongParagraph(paragraph, measureDiv, availableHeight) {
                const sentences = paragraph.split(/([。！？.!?])/);
                const pages = [];
                let currentContent = '';
                
                for (let i = 0; i < sentences.length; i += 2) {
                    const sentence = sentences[i] + (sentences[i + 1] || '');
                    const testContent = currentContent + sentence;
                    
                    measureDiv.innerHTML = this.formatText(testContent);
                    
                    if (measureDiv.scrollHeight > availableHeight && currentContent) {
                        pages.push(currentContent);
                        currentContent = sentence;
                    } else {
                        currentContent = testContent;
                    }
                }
                
                if (currentContent.trim()) {
                    pages.push(currentContent);
                }
                
                return pages;
            }
            
            // 创建页面元素
            createPageElement(content, pageIndex) {
                const pageView = document.createElement('div');
                pageView.className = 'page-view';
                pageView.style.display = pageIndex === 0 ? 'flex' : 'none';
                
                const pageContent = document.createElement('div');
                pageContent.className = 'page-content';
                pageContent.innerHTML = this.formatText(content);
                
                const pageInfo = document.createElement('div');
                pageInfo.className = 'page-info';
                pageInfo.textContent = `${pageIndex + 1} / ${this.pages.length + 1}`;
                
                pageView.appendChild(pageContent);
                pageView.appendChild(pageInfo);
                this.container.appendChild(pageView);
                
                this.pages.push({
                    element: pageView,
                    content: content,
                    info: pageInfo
                });
                
                // 更新所有页面的页码信息
                this.updatePageNumbers();
            }
            
            // 更新页码信息
            updatePageNumbers() {
                this.pages.forEach((page, index) => {
                    if (page.info) {
                        page.info.textContent = `${index + 1} / ${this.pages.length}`;
                    }
                });
            }
            
            // 格式化文本
            formatText(text) {
                return text
                    .split('\\n')
                    .map(line => {
                        const trimmed = line.trim();
                        if (!trimmed) return '';
                        
                        // 检测章节标题（简单规则）
                        if (trimmed.length < 30 && /^(第.{1,10}[章节]|Chapter|CHAPTER)/.test(trimmed)) {
                            return `<p class="chapter-title">${trimmed}</p>`;
                        }
                        
                        return `<p>${trimmed}</p>`;
                    })
                    .filter(line => line)
                    .join('');
            }
            
            // 翻页方法
            goToPage(index) {
                if (index < 0 || index >= this.pages.length || this.config.flow === 'scrolled') {
                    return false;
                }
                
                // 隐藏当前页面
                if (this.pages[this.currentPageIndex]) {
                    this.pages[this.currentPageIndex].element.style.display = 'none';
                }
                
                // 显示目标页面
                this.currentPageIndex = index;
                this.pages[this.currentPageIndex].element.style.display = 'flex';
                
                this.notifyFlutter('onPageChanged', {
                    currentPage: this.currentPageIndex + 1,
                    totalPages: this.pages.length,
                    content: this.pages[this.currentPageIndex].content
                });
                
                return true;
            }
            
            nextPage() {
                if (this.goToPage(this.currentPageIndex + 1)) {
                    return true;
                } else {
                    this.notifyFlutter('onReachEnd');
                    return false;
                }
            }
            
            prevPage() {
                if (this.goToPage(this.currentPageIndex - 1)) {
                    return true;
                } else {
                    this.notifyFlutter('onReachStart');
                    return false;
                }
            }
            
            // 获取当前页面信息
            getCurrentPageInfo() {
                return {
                    currentPage: this.currentPageIndex + 1,
                    totalPages: this.pages.length,
                    progress: this.pages.length > 0 ? (this.currentPageIndex + 1) / this.pages.length : 0,
                    content: this.pages[this.currentPageIndex]?.content || ''
                };
            }
            
            // 搜索文本
            searchText(query) {
                const results = [];
                this.pages.forEach((page, pageIndex) => {
                    const content = page.content.toLowerCase();
                    const queryLower = query.toLowerCase();
                    let index = content.indexOf(queryLower);
                    
                    while (index !== -1) {
                        results.push({
                            pageIndex,
                            position: index,
                            context: this.getSearchContext(page.content, index, query.length)
                        });
                        index = content.indexOf(queryLower, index + 1);
                    }
                });
                
                return results;
            }
            
            // 获取搜索上下文
            getSearchContext(content, position, queryLength) {
                const contextLength = 50;
                const start = Math.max(0, position - contextLength);
                const end = Math.min(content.length, position + queryLength + contextLength);
                
                return {
                    before: content.substring(start, position),
                    match: content.substring(position, position + queryLength),
                    after: content.substring(position + queryLength, end)
                };
            }
            
            // 通知Flutter
            notifyFlutter(eventName, data = {}) {
                try {
                    if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
                        window.flutter_inappwebview.callHandler(eventName, data);
                    }
                } catch (error) {
                    console.error('Failed to notify Flutter:', error);
                }
            }
        }
        
        // 全局分页器实例
        let paginator = null;
        
        // 初始化分页器
        function initializePaginator() {
            paginator = new AdvancedPaginator();
            return paginator;
        }
        
        // 暴露给Flutter的方法
        window.setText = function(text, config) {
            if (!paginator) {
                paginator = initializePaginator();
            }
            return paginator.setText(text, config);
        };
        
        window.nextPage = function() {
            return paginator ? paginator.nextPage() : false;
        };
        
        window.prevPage = function() {
            return paginator ? paginator.prevPage() : false;
        };
        
        window.goToPage = function(index) {
            return paginator ? paginator.goToPage(index - 1) : false; // Flutter使用1-based index
        };
        
        window.getCurrentPageInfo = function() {
            return paginator ? paginator.getCurrentPageInfo() : null;
        };
        
        window.searchText = function(query) {
            return paginator ? paginator.searchText(query) : [];
        };
        
        window.updateConfig = function(config) {
            if (paginator) {
                paginator.config = { ...paginator.config, ...config };
                paginator.applyStyles();
                if (paginator.textContent) {
                    return paginator.setText(paginator.textContent, paginator.config);
                }
            }
            return Promise.resolve();
        };
        
        // 页面加载完成后初始化
        document.addEventListener('DOMContentLoaded', function() {
            initializePaginator();
        });
        
        // 窗口大小变化时重新分页
        let resizeTimeout;
        window.addEventListener('resize', function() {
            if (!paginator) return;
            
            clearTimeout(resizeTimeout);
            resizeTimeout = setTimeout(() => {
                if (paginator.textContent) {
                    const currentProgress = paginator.getCurrentPageInfo().progress;
                    paginator.setText(paginator.textContent, paginator.config).then(() => {
                        // 尝试恢复到相近的位置
                        const targetPage = Math.round(currentProgress * paginator.pages.length);
                        paginator.goToPage(Math.max(0, Math.min(targetPage, paginator.pages.length - 1)));
                    });
                }
            }, 300);
        });
    </script>
</body>
</html>
''';

  /// 创建HTML文件并返回路径
  static Future<String> createHtmlFile() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final htmlDir = Directory(path.join(directory.path, 'reader_html'));

      if (!await htmlDir.exists()) {
        await htmlDir.create(recursive: true);
      }

      final htmlFile = File(path.join(htmlDir.path, 'advanced_paginator.html'));
      await htmlFile.writeAsString(_htmlTemplate);

      return htmlFile.path;
    } catch (e) {
      debugPrint('创建HTML文件失败: $e');
      rethrow;
    }
  }

  /// 获取HTML文件URI
  static Future<String> getHtmlUri() async {
    final htmlPath = await createHtmlFile();
    return Platform.isAndroid ? 'file://$htmlPath' : htmlPath;
  }
}

/// 分页配置
class PaginationConfig {
  final double fontSize;
  final double lineHeight;
  final double letterSpacing;
  final double pagePadding;
  final double columnGap;
  final String paragraphSpacing;
  final String textIndent;
  final int maxColumnCount;
  final String flow; // 'paginated' or 'scrolled'
  final String? backgroundColor;
  final String? textColor;

  const PaginationConfig({
    this.fontSize = 16.0,
    this.lineHeight = 1.6,
    this.letterSpacing = 0.0,
    this.pagePadding = 20.0,
    this.columnGap = 30.0,
    this.paragraphSpacing = '0.8em',
    this.textIndent = '2em',
    this.maxColumnCount = 1,
    this.flow = 'paginated',
    this.backgroundColor,
    this.textColor,
  });

  Map<String, dynamic> toMap() {
    return {
      'fontSize': fontSize,
      'lineHeight': lineHeight,
      'letterSpacing': letterSpacing,
      'pagePadding': pagePadding,
      'columnGap': columnGap,
      'paragraphSpacing': paragraphSpacing,
      'textIndent': textIndent,
      'maxColumnCount': maxColumnCount,
      'flow': flow,
      'backgroundColor': backgroundColor,
      'textColor': textColor,
    };
  }
}

/// 页面信息
class PageInfo {
  final int currentPage;
  final int totalPages;
  final double progress;
  final String content;

  const PageInfo({
    required this.currentPage,
    required this.totalPages,
    required this.progress,
    required this.content,
  });

  factory PageInfo.fromMap(Map<String, dynamic> map) {
    return PageInfo(
      currentPage: map['currentPage'] ?? 1,
      totalPages: map['totalPages'] ?? 1,
      progress: map['progress']?.toDouble() ?? 0.0,
      content: map['content'] ?? '',
    );
  }
}

/// 搜索结果
class SearchResult {
  final int pageIndex;
  final int position;
  final String before;
  final String match;
  final String after;

  const SearchResult({
    required this.pageIndex,
    required this.position,
    required this.before,
    required this.match,
    required this.after,
  });

  factory SearchResult.fromMap(Map<String, dynamic> map) {
    final context = map['context'] ?? {};
    return SearchResult(
      pageIndex: map['pageIndex'] ?? 0,
      position: map['position'] ?? 0,
      before: context['before'] ?? '',
      match: context['match'] ?? '',
      after: context['after'] ?? '',
    );
  }
}
