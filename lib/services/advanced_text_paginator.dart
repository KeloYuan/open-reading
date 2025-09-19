import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// 高级文本分页器 - 基于anx-reader的精确分页算法
/// 使用WebView + JavaScript实现精确的文本分页和渲染
class AdvancedTextPaginator {
  static const String _htmlTemplate = '''
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
        }
        
        .page-view {
            position: absolute;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            display: flex;
            flex-direction: column;
            padding: var(--page-padding, 20px);
            opacity: 0;
            transition: opacity 0.3s ease;
        }
        
        .page-view.active {
            opacity: 1;
        }
        
        .page-content {
            flex: 1;
            overflow: hidden;
            font-size: var(--font-size, 16px);
            line-height: var(--line-height, 1.6);
            font-family: var(--font-family, -apple-system, BlinkMacSystemFont, 'Segoe UI', system-ui, sans-serif);
            letter-spacing: var(--letter-spacing, 0px);
            word-spacing: var(--word-spacing, 0px);
        }
        
        .page-content.scroll-mode {
            overflow-y: auto;
            height: 100%;
        }
        
        .page-info {
            position: absolute;
            bottom: 10px;
            right: 20px;
            font-size: 12px;
            color: var(--text-color, #666);
            opacity: 0.7;
            pointer-events: none;
        }
        
        .paragraph {
            margin-bottom: var(--paragraph-spacing, 1em);
            text-indent: var(--text-indent, 2em);
        }
        
        .chapter-title {
            font-size: calc(var(--font-size, 16px) * 1.5);
            font-weight: bold;
            text-align: center;
            margin: 2em 0 1em 0;
            text-indent: 0;
            color: var(--text-color, #2C2C2C);
        }
        
        .section-title {
            font-size: calc(var(--font-size, 16px) * 1.2);
            font-weight: bold;
            margin: 1.5em 0 1em 0;
            text-indent: 0;
            color: var(--text-color, #2C2C2C);
        }
        
        /* 主题样式 */
        body.theme-light {
            --bg-color: #FFFBF0;
            --text-color: #2C2C2C;
        }
        
        body.theme-dark {
            --bg-color: #1E1E1E;
            --text-color: #E0E0E0;
        }
        
        body.theme-sepia {
            --bg-color: #F4F1E8;
            --text-color: #5D4E37;
        }
        
        body.theme-green {
            --bg-color: #CCE8CC;
            --text-color: #2F4F2F;
        }
    </style>
</head>
<body>
    <div id="container">
        <div id="paginator"></div>
    </div>
    
    <script>
        class TextPaginator {
            constructor(container) {
                this.container = container;
                this.pages = [];
                this.currentPageIndex = 0;
                this.textContent = '';
                this.config = {
                    fontSize: 16,
                    lineHeight: 1.6,
                    fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", system-ui, sans-serif',
                    letterSpacing: 0,
                    wordSpacing: 0,
                    paragraphSpacing: '1em',
                    textIndent: '2em',
                    pagePadding: 20,
                    theme: 'light'
                };
                
                this.init();
            }
            
            init() {
                this.container.innerHTML = '<div id="paginator"></div>';
                this.paginator = this.container.querySelector('#paginator');
                this.applyStyles();
            }
            
            applyStyles() {
                document.documentElement.style.setProperty('--font-size', this.config.fontSize + 'px');
                document.documentElement.style.setProperty('--line-height', this.config.lineHeight);
                document.documentElement.style.setProperty('--font-family', this.config.fontFamily);
                document.documentElement.style.setProperty('--letter-spacing', this.config.letterSpacing + 'px');
                document.documentElement.style.setProperty('--word-spacing', this.config.wordSpacing + 'px');
                document.documentElement.style.setProperty('--paragraph-spacing', this.config.paragraphSpacing);
                document.documentElement.style.setProperty('--text-indent', this.config.textIndent);
                document.documentElement.style.setProperty('--page-padding', this.config.pagePadding + 'px');
                
                document.body.className = 'theme-' + (this.config.theme || 'light');
            }
            
            async setText(content, config = {}) {
                this.config = { ...this.config, ...config };
                this.textContent = content;
                this.applyStyles();
                
                if (this.config.scrollMode) {
                    this.createScrollView();
                } else {
                    await this.createPages();
                }
                
                return Promise.resolve();
            }
            
            createScrollView() {
                this.container.innerHTML = '';
                this.pages = [];
                
                const pageView = document.createElement('div');
                pageView.className = 'page-view active';
                
                const pageContent = document.createElement('div');
                pageContent.className = 'page-content scroll-mode';
                pageContent.innerHTML = this.formatText(this.textContent);
                
                pageView.appendChild(pageContent);
                this.container.appendChild(pageView);
                
                this.pages = [{ element: pageView, content: this.textContent }];
            }
            
            async createPages() {
                this.container.innerHTML = '';
                this.pages = [];
                
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
                        
                        const testContent = currentPageContent + '\n\n' + paragraph;
                        measureDiv.innerHTML = this.formatText(testContent);
                        
                        const availableHeight = this.container.clientHeight - (this.config.pagePadding * 2) - 30;
                        
                        if (measureDiv.scrollHeight > availableHeight && currentPageContent) {
                            this.createPageElement(currentPageContent, pageIndex++);
                            currentPageContent = paragraph;
                        } else {
                            currentPageContent = testContent;
                        }
                    }
                    
                    if (currentPageContent.trim()) {
                        this.createPageElement(currentPageContent, pageIndex);
                    }
                    
                    if (this.pages.length === 0) {
                        this.createPageElement(this.textContent || '内容为空', 0);
                    }
                    
                    this.goToPage(0);
                } finally {
                    document.body.removeChild(measureDiv);
                }
            }
            
            createPageElement(content, pageIndex) {
                const pageView = document.createElement('div');
                pageView.className = 'page-view';
                pageView.style.display = pageIndex === 0 ? 'flex' : 'none';
                
                const pageContent = document.createElement('div');
                pageContent.className = 'page-content';
                pageContent.innerHTML = this.formatText(content);
                
                const pageInfo = document.createElement('div');
                pageInfo.className = 'page-info';
                pageInfo.textContent = pageIndex + 1 + ' / ' + (this.pages.length + 1);
                
                pageView.appendChild(pageContent);
                pageView.appendChild(pageInfo);
                this.container.appendChild(pageView);
                
                this.pages.push({
                    element: pageView,
                    content: content,
                    info: pageInfo
                });
                
                this.updatePageNumbers();
            }
            
            updatePageNumbers() {
                this.pages.forEach((page, index) => {
                    if (page.info) {
                        page.info.textContent = (index + 1) + ' / ' + this.pages.length;
                    }
                });
            }
            
            formatText(text) {
                return text
                    .split('\n')
                    .map(line => {
                        const trimmed = line.trim();
                        if (!trimmed) return '';
                        
                        if (trimmed.length < 30 && /^(第.{1,10}[章节]|Chapter|CHAPTER)/.test(trimmed)) {
                            return '<h2 class="chapter-title">' + trimmed + '</h2>';
                        }
                        
                        if (trimmed.length < 50 && /^[一二三四五六七八九十]{1,3}[、．]/.test(trimmed)) {
                            return '<h3 class="section-title">' + trimmed + '</h3>';
                        }
                        
                        return '<p class="paragraph">' + trimmed + '</p>';
                    })
                    .filter(line => line)
                    .join('\n');
            }
            
            goToPage(pageIndex) {
                if (pageIndex < 0 || pageIndex >= this.pages.length) return;
                
                this.pages.forEach((page, index) => {
                    page.element.style.display = index === pageIndex ? 'flex' : 'none';
                });
                
                this.currentPageIndex = pageIndex;
            }
            
            nextPage() {
                if (this.currentPageIndex < this.pages.length - 1) {
                    this.goToPage(this.currentPageIndex + 1);
                }
            }
            
            previousPage() {
                if (this.currentPageIndex > 0) {
                    this.goToPage(this.currentPageIndex - 1);
                }
            }
            
            getCurrentPageInfo() {
                return {
                    currentPage: this.currentPageIndex,
                    totalPages: this.pages.length,
                    progress: this.pages.length > 0 ? this.currentPageIndex / this.pages.length : 0
                };
            }
            
            searchText(query) {
                const results = [];
                this.pages.forEach((page, pageIndex) => {
                    const content = page.content.toLowerCase();
                    const queryLower = query.toLowerCase();
                    let startIndex = 0;
                    
                    while (true) {
                        const index = content.indexOf(queryLower, startIndex);
                        if (index === -1) break;
                        
                        const before = content.substring(Math.max(0, index - 20), index);
                        const match = content.substring(index, index + query.length);
                        const after = content.substring(index + query.length, Math.min(content.length, index + query.length + 20));
                        
                        results.push({
                            pageIndex: pageIndex,
                            position: index,
                            context: { before: before, match: match, after: after }
                        });
                        
                        startIndex = index + 1;
                    }
                });
                
                return results;
            }
        }
        
        let paginator = null;
        
        function initializePaginator() {
            const container = document.getElementById('container');
            if (container) {
                paginator = new TextPaginator(container);
                console.log('分页器初始化完成');
            }
        }
        
        window.setText = function(content, config = {}) {
            if (paginator) {
                return paginator.setText(content, config);
            }
            return Promise.resolve();
        };
        
        window.goToPage = function(pageIndex) {
            if (paginator) {
                paginator.goToPage(pageIndex);
                return paginator.getCurrentPageInfo();
            }
            return { currentPage: 0, totalPages: 0, progress: 0 };
        };
        
        window.nextPage = function() {
            if (paginator) {
                paginator.nextPage();
                return paginator.getCurrentPageInfo();
            }
            return { currentPage: 0, totalPages: 0, progress: 0 };
        };
        
        window.previousPage = function() {
            if (paginator) {
                paginator.previousPage();
                return paginator.getCurrentPageInfo();
            }
            return { currentPage: 0, totalPages: 0, progress: 0 };
        };
        
        window.getCurrentPageInfo = function() {
            return paginator ? paginator.getCurrentPageInfo() : { currentPage: 0, totalPages: 0, progress: 0 };
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
        
        document.addEventListener('DOMContentLoaded', function() {
            initializePaginator();
        });
        
        let resizeTimeout;
        window.addEventListener('resize', function() {
            if (!paginator) return;
            
            clearTimeout(resizeTimeout);
            resizeTimeout = setTimeout(() => {
                if (paginator.textContent) {
                    const currentProgress = paginator.getCurrentPageInfo().progress;
                    paginator.setText(paginator.textContent, paginator.config).then(() => {
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

      final htmlFile = File(path.join(htmlDir.path, 'paginator.html'));
      await htmlFile.writeAsString(_htmlTemplate, encoding: utf8);

      return htmlFile.path;
    } catch (e) {
      debugPrint('创建HTML文件失败: $e');
      return '';
    }
  }

  /// 获取HTML文件URI
  static Future<String> getHtmlUri() async {
    final htmlPath = await createHtmlFile();
    if (htmlPath.isEmpty) {
      throw Exception('无法创建HTML文件');
    }
    return 'file://$htmlPath';
  }

  /// 获取配置对象
  static Map<String, dynamic> getConfig({
    double fontSize = 16.0,
    double lineHeight = 1.6,
    String fontFamily =
        '-apple-system, BlinkMacSystemFont, "Segoe UI", system-ui, sans-serif',
    double letterSpacing = 0.0,
    double wordSpacing = 0.0,
    String paragraphSpacing = '1em',
    String textIndent = '2em',
    double pagePadding = 20.0,
    String theme = 'light',
    bool scrollMode = false,
  }) {
    return {
      'fontSize': fontSize,
      'lineHeight': lineHeight,
      'fontFamily': fontFamily,
      'letterSpacing': letterSpacing,
      'wordSpacing': wordSpacing,
      'paragraphSpacing': paragraphSpacing,
      'textIndent': textIndent,
      'pagePadding': pagePadding,
      'theme': theme,
      'scrollMode': scrollMode,
    };
  }
}

/// 搜索结果模型
class SearchResult {
  final int pageIndex;
  final int position;
  final String before;
  final String match;
  final String after;

  SearchResult({
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
