import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
import 'package:http/http.dart' as http;

import '../models/book_source.dart';

/// 规则引擎
/// 高级规则解析系统，支持XPath、CSS选择器、正则表达式和JavaScript脚本
class RuleEngine {
  static final RuleEngine _instance = RuleEngine._internal();
  factory RuleEngine() => _instance;
  RuleEngine._internal();

  /// HTTP客户端配置
  static const Duration _defaultTimeout = Duration(seconds: 30);
  static const String _defaultUserAgent = 'XXRead/1.0 (Advanced Reader)';

  /// 执行搜索规则
  Future<List<SearchBookItem>> executeSearch(
    BookSource bookSource,
    String keyword, {
    int page = 1,
  }) async {
    if (bookSource.ruleSearch == null || !bookSource.ruleSearch!.isValid) {
      throw Exception('书源搜索规则无效');
    }

    try {
      final rule = bookSource.ruleSearch!;

      // 构建搜索URL
      String searchUrl = rule.url
          .replaceAll('{{key}}', Uri.encodeComponent(keyword))
          .replaceAll('{{page}}', page.toString());

      // 处理书源变量
      searchUrl = _processVariables(searchUrl, bookSource.variableMap);

      debugPrint('🔍 搜索URL: $searchUrl');

      // 发送HTTP请求
      final response = await _makeHttpRequest(
        searchUrl,
        bookSource.header,
        timeout: Duration(milliseconds: bookSource.respondTime),
      );

      // 解析HTML内容
      final document = html_parser.parse(response.body);

      // 执行书籍列表规则
      final bookElements = _selectElements(document, rule.bookList);
      final books = <SearchBookItem>[];

      for (final element in bookElements) {
        try {
          final book = SearchBookItem(
            name: _extractText(element, rule.name),
            author: _extractText(element, rule.author),
            kind: rule.kind.isNotEmpty ? _extractText(element, rule.kind) : '',
            lastChapter: rule.lastChapter.isNotEmpty
                ? _extractText(element, rule.lastChapter)
                : '',
            intro: rule.intro.isNotEmpty
                ? _extractText(element, rule.intro)
                : '',
            coverUrl: rule.coverUrl.isNotEmpty
                ? _extractAttribute(element, rule.coverUrl, 'src', 'href')
                : '',
            bookUrl: _makeAbsoluteUrl(
              _extractAttribute(element, rule.bookUrl, 'href', 'src'),
              bookSource.bookSourceUrl,
            ),
            sourceId: bookSource.id,
            sourceName: bookSource.bookSourceName,
          );

          if (book.name.isNotEmpty && book.bookUrl.isNotEmpty) {
            books.add(book);
          }
        } catch (e) {
          debugPrint('解析单个搜索结果失败: $e');
        }
      }

      debugPrint('✅ 搜索完成: 找到${books.length}本书');
      return books;
    } catch (e) {
      debugPrint('❌ 搜索执行失败: $e');
      throw Exception('搜索失败: $e');
    }
  }

  /// 执行发现规则
  Future<List<ExploreBookItem>> executeExplore(
    BookSource bookSource,
    String exploreUrl,
  ) async {
    if (bookSource.ruleExplore == null || !bookSource.ruleExplore!.isValid) {
      throw Exception('书源发现规则无效');
    }

    try {
      final rule = bookSource.ruleExplore!;

      // 处理发现URL
      String finalUrl = exploreUrl.isEmpty ? rule.url : exploreUrl;
      finalUrl = _processVariables(finalUrl, bookSource.variableMap);

      debugPrint('🎯 发现URL: $finalUrl');

      // 发送HTTP请求
      final response = await _makeHttpRequest(
        finalUrl,
        bookSource.header,
        timeout: Duration(milliseconds: bookSource.respondTime),
      );

      // 解析HTML内容
      final document = html_parser.parse(response.body);

      // 执行书籍列表规则
      final bookElements = _selectElements(document, rule.bookList);
      final books = <ExploreBookItem>[];

      for (final element in bookElements) {
        try {
          final book = ExploreBookItem(
            name: _extractText(element, rule.name),
            author: _extractText(element, rule.author),
            kind: rule.kind.isNotEmpty ? _extractText(element, rule.kind) : '',
            lastChapter: rule.lastChapter.isNotEmpty
                ? _extractText(element, rule.lastChapter)
                : '',
            intro: rule.intro.isNotEmpty
                ? _extractText(element, rule.intro)
                : '',
            coverUrl: rule.coverUrl.isNotEmpty
                ? _extractAttribute(element, rule.coverUrl, 'src', 'href')
                : '',
            bookUrl: _makeAbsoluteUrl(
              _extractAttribute(element, rule.bookUrl, 'href', 'src'),
              bookSource.bookSourceUrl,
            ),
            sourceId: bookSource.id,
            sourceName: bookSource.bookSourceName,
          );

          if (book.name.isNotEmpty && book.bookUrl.isNotEmpty) {
            books.add(book);
          }
        } catch (e) {
          debugPrint('解析单个发现结果失败: $e');
        }
      }

      debugPrint('✅ 发现完成: 找到${books.length}本书');
      return books;
    } catch (e) {
      debugPrint('❌ 发现执行失败: $e');
      throw Exception('发现失败: $e');
    }
  }

  /// 执行书籍信息规则
  Future<BookInfoItem> executeBookInfo(
    BookSource bookSource,
    String bookUrl,
  ) async {
    if (bookSource.ruleBookInfo == null || !bookSource.ruleBookInfo!.isValid) {
      throw Exception('书源书籍信息规则无效');
    }

    try {
      final rule = bookSource.ruleBookInfo!;

      // 处理初始化URL
      String finalUrl = rule.init.isNotEmpty ? rule.init : bookUrl;
      finalUrl = _processVariables(finalUrl, bookSource.variableMap);

      debugPrint('📖 获取书籍信息: $finalUrl');

      // 发送HTTP请求
      final response = await _makeHttpRequest(
        finalUrl,
        bookSource.header,
        timeout: Duration(milliseconds: bookSource.respondTime),
      );

      // 解析HTML内容
      final document = html_parser.parse(response.body);

      // 提取书籍信息
      final bookInfo = BookInfoItem(
        name: _extractText(document, rule.name),
        author: _extractText(document, rule.author),
        kind: rule.kind.isNotEmpty ? _extractText(document, rule.kind) : '',
        lastChapter: rule.lastChapter.isNotEmpty
            ? _extractText(document, rule.lastChapter)
            : '',
        intro: rule.intro.isNotEmpty ? _extractText(document, rule.intro) : '',
        coverUrl: rule.coverUrl.isNotEmpty
            ? _extractAttribute(document, rule.coverUrl, 'src', 'href')
            : '',
        tocUrl: rule.tocUrl.isNotEmpty
            ? _makeAbsoluteUrl(
                _extractAttribute(document, rule.tocUrl, 'href', 'src'),
                bookUrl,
              )
            : bookUrl, // 默认使用书籍URL
        wordCount: rule.wordCount.isNotEmpty
            ? _extractText(document, rule.wordCount)
            : '',
        sourceId: bookSource.id,
        sourceName: bookSource.bookSourceName,
      );

      debugPrint('✅ 书籍信息获取完成: ${bookInfo.name}');
      return bookInfo;
    } catch (e) {
      debugPrint('❌ 获取书籍信息失败: $e');
      throw Exception('获取书籍信息失败: $e');
    }
  }

  /// 执行目录规则
  Future<List<ChapterItem>> executeToc(
    BookSource bookSource,
    String tocUrl,
  ) async {
    if (bookSource.ruleToc == null || !bookSource.ruleToc!.isValid) {
      throw Exception('书源目录规则无效');
    }

    try {
      final rule = bookSource.ruleToc!;

      // 处理目录URL
      String finalUrl = _processVariables(tocUrl, bookSource.variableMap);

      debugPrint('📚 获取目录: $finalUrl');

      // 发送HTTP请求
      final response = await _makeHttpRequest(
        finalUrl,
        bookSource.header,
        timeout: Duration(milliseconds: bookSource.respondTime),
      );

      // 解析HTML内容
      final document = html_parser.parse(response.body);

      // 执行章节列表规则
      final chapterElements = _selectElements(document, rule.chapterList);
      final chapters = <ChapterItem>[];

      for (int i = 0; i < chapterElements.length; i++) {
        final element = chapterElements[i];

        try {
          final chapter = ChapterItem(
            name: _extractText(element, rule.chapterName),
            url: _makeAbsoluteUrl(
              _extractAttribute(element, rule.chapterUrl, 'href', 'src'),
              tocUrl,
            ),
            index: i,
            isVip: rule.isVip.isNotEmpty
                ? _extractText(
                    element,
                    rule.isVip,
                  ).toLowerCase().contains('vip')
                : false,
            updateTime: rule.updateTime.isNotEmpty
                ? _extractText(element, rule.updateTime)
                : '',
          );

          if (chapter.name.isNotEmpty && chapter.url.isNotEmpty) {
            chapters.add(chapter);
          }
        } catch (e) {
          debugPrint('解析第${i + 1}个章节失败: $e');
        }
      }

      debugPrint('✅ 目录获取完成: ${chapters.length}章');
      return chapters;
    } catch (e) {
      debugPrint('❌ 获取目录失败: $e');
      throw Exception('获取目录失败: $e');
    }
  }

  /// 执行正文规则
  Future<ContentItem> executeContent(
    BookSource bookSource,
    String contentUrl,
  ) async {
    if (bookSource.ruleContent == null || !bookSource.ruleContent!.isValid) {
      throw Exception('书源正文规则无效');
    }

    try {
      final rule = bookSource.ruleContent!;

      // 处理正文URL
      String finalUrl = _processVariables(contentUrl, bookSource.variableMap);

      debugPrint('📄 获取正文: $finalUrl');

      // 发送HTTP请求
      final response = await _makeHttpRequest(
        finalUrl,
        bookSource.header,
        timeout: Duration(milliseconds: bookSource.respondTime),
      );

      // 解析HTML内容
      final document = html_parser.parse(response.body);

      // 提取正文内容
      String content = _extractText(document, rule.content);

      // 应用替换规则
      if (rule.replaceRegex.isNotEmpty) {
        content = _applyReplaceRules(content, rule.replaceRegex);
      }

      // 提取下一页URL
      String nextUrl = '';
      if (rule.nextUrl.isNotEmpty) {
        nextUrl = _makeAbsoluteUrl(
          _extractAttribute(document, rule.nextUrl, 'href', 'src'),
          contentUrl,
        );
      }

      final contentItem = ContentItem(
        content: content,
        nextUrl: nextUrl,
        sourceUrl: contentUrl,
      );

      debugPrint('✅ 正文获取完成: ${content.length}字符');
      return contentItem;
    } catch (e) {
      debugPrint('❌ 获取正文失败: $e');
      throw Exception('获取正文失败: $e');
    }
  }

  /// 发送HTTP请求
  Future<http.Response> _makeHttpRequest(
    String url,
    Map<String, String> headers, {
    Duration? timeout,
  }) async {
    final client = http.Client();

    try {
      final uri = Uri.parse(url);
      final request = http.Request('GET', uri);

      // 设置默认和自定义请求头
      request.headers['User-Agent'] = _defaultUserAgent;
      request.headers['Accept'] =
          'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8';
      request.headers['Accept-Language'] = 'zh-CN,zh;q=0.9,en;q=0.8';
      request.headers['Accept-Encoding'] = 'gzip, deflate';
      request.headers['Connection'] = 'keep-alive';

      // 应用自定义请求头
      headers.forEach((key, value) {
        request.headers[key] = value;
      });

      final streamedResponse = await client
          .send(request)
          .timeout(timeout ?? _defaultTimeout);

      return await http.Response.fromStream(streamedResponse);
    } finally {
      client.close();
    }
  }

  /// 选择HTML元素
  List<dom.Element> _selectElements(dom.Document document, String selector) {
    if (selector.isEmpty) return [];

    try {
      // 支持CSS选择器
      if (selector.startsWith('@css:') || !selector.contains('@')) {
        final cssSelector = selector.startsWith('@css:')
            ? selector.substring(5)
            : selector;
        return document.querySelectorAll(cssSelector);
      }

      // 支持XPath选择器（简化实现）
      if (selector.startsWith('@xpath:')) {
        // 简化的XPath支持，转换为CSS选择器
        final xpath = selector.substring(7);
        final cssSelector = _convertXPathToCSS(xpath);
        return document.querySelectorAll(cssSelector);
      }

      // 默认作为CSS选择器处理
      return document.querySelectorAll(selector);
    } catch (e) {
      debugPrint('元素选择失败: $selector -> $e');
      return [];
    }
  }

  /// 提取文本内容
  String _extractText(dom.Node node, String rule) {
    if (rule.isEmpty) return '';

    try {
      if (node is dom.Document) {
        final elements = _selectElements(node, rule);
        if (elements.isNotEmpty) {
          return elements.first.text.trim();
        }
      } else if (node is dom.Element) {
        if (rule.startsWith('@text') || rule == '.') {
          return node.text.trim();
        } else if (rule.startsWith('@attr:')) {
          final attrName = rule.substring(6);
          return node.attributes[attrName] ?? '';
        } else if (rule.startsWith('@css:') || !rule.contains('@')) {
          final cssSelector = rule.startsWith('@css:')
              ? rule.substring(5)
              : rule;
          final elements = node.querySelectorAll(cssSelector);
          if (elements.isNotEmpty) {
            return elements.first.text.trim();
          }
        }
      }

      return '';
    } catch (e) {
      debugPrint('文本提取失败: $rule -> $e');
      return '';
    }
  }

  /// 提取属性值
  String _extractAttribute(
    dom.Node node,
    String rule,
    String defaultAttr,
    String secondaryAttr,
  ) {
    if (rule.isEmpty) return '';

    try {
      if (node is dom.Document) {
        final elements = _selectElements(node, rule);
        if (elements.isNotEmpty) {
          return elements.first.attributes[defaultAttr] ??
              elements.first.attributes[secondaryAttr] ??
              '';
        }
      } else if (node is dom.Element) {
        if (rule.startsWith('@attr:')) {
          final attrName = rule.substring(6);
          return node.attributes[attrName] ?? '';
        } else if (rule.startsWith('@css:') || !rule.contains('@')) {
          final cssSelector = rule.startsWith('@css:')
              ? rule.substring(5)
              : rule;
          final elements = node.querySelectorAll(cssSelector);
          if (elements.isNotEmpty) {
            return elements.first.attributes[defaultAttr] ??
                elements.first.attributes[secondaryAttr] ??
                '';
          }
        } else {
          // 直接返回默认属性
          return node.attributes[defaultAttr] ??
              node.attributes[secondaryAttr] ??
              '';
        }
      }

      return '';
    } catch (e) {
      debugPrint('属性提取失败: $rule -> $e');
      return '';
    }
  }

  /// 处理变量替换
  String _processVariables(String text, Map<String, String> variables) {
    String result = text;

    variables.forEach((key, value) {
      result = result.replaceAll('{{$key}}', value);
    });

    return result;
  }

  /// 生成绝对URL
  String _makeAbsoluteUrl(String url, String baseUrl) {
    if (url.isEmpty) return '';

    try {
      final uri = Uri.parse(url);
      if (uri.hasScheme) {
        return url; // 已经是绝对URL
      }

      final base = Uri.parse(baseUrl);
      return base.resolve(url).toString();
    } catch (e) {
      debugPrint('生成绝对URL失败: $url + $baseUrl -> $e');
      return url;
    }
  }

  /// 应用替换规则
  String _applyReplaceRules(String content, String replaceRules) {
    try {
      final rules = replaceRules.split('##');
      String result = content;

      for (final rule in rules) {
        if (rule.trim().isEmpty) continue;

        final parts = rule.split('|||');
        if (parts.length >= 2) {
          final pattern = parts[0].trim();
          final replacement = parts[1].trim();

          if (pattern.isNotEmpty) {
            result = result.replaceAll(RegExp(pattern), replacement);
          }
        }
      }

      return result;
    } catch (e) {
      debugPrint('替换规则应用失败: $e');
      return content;
    }
  }

  /// 简化的XPath转CSS选择器
  String _convertXPathToCSS(String xpath) {
    // 这是一个简化的转换，只支持基本的XPath语法
    return xpath
        .replaceAll('//', ' ')
        .replaceAll('/', ' > ')
        .replaceAll('@class', '.class')
        .replaceAll('@id', '#id')
        .trim();
  }
}

/// 搜索书籍项
class SearchBookItem {
  final String name;
  final String author;
  final String kind;
  final String lastChapter;
  final String intro;
  final String coverUrl;
  final String bookUrl;
  final String sourceId;
  final String sourceName;

  const SearchBookItem({
    required this.name,
    required this.author,
    required this.kind,
    required this.lastChapter,
    required this.intro,
    required this.coverUrl,
    required this.bookUrl,
    required this.sourceId,
    required this.sourceName,
  });
}

/// 发现书籍项
class ExploreBookItem {
  final String name;
  final String author;
  final String kind;
  final String lastChapter;
  final String intro;
  final String coverUrl;
  final String bookUrl;
  final String sourceId;
  final String sourceName;

  const ExploreBookItem({
    required this.name,
    required this.author,
    required this.kind,
    required this.lastChapter,
    required this.intro,
    required this.coverUrl,
    required this.bookUrl,
    required this.sourceId,
    required this.sourceName,
  });
}

/// 书籍信息项
class BookInfoItem {
  final String name;
  final String author;
  final String kind;
  final String lastChapter;
  final String intro;
  final String coverUrl;
  final String tocUrl;
  final String wordCount;
  final String sourceId;
  final String sourceName;

  const BookInfoItem({
    required this.name,
    required this.author,
    required this.kind,
    required this.lastChapter,
    required this.intro,
    required this.coverUrl,
    required this.tocUrl,
    required this.wordCount,
    required this.sourceId,
    required this.sourceName,
  });
}

/// 章节项
class ChapterItem {
  final String name;
  final String url;
  final int index;
  final bool isVip;
  final String updateTime;

  const ChapterItem({
    required this.name,
    required this.url,
    required this.index,
    required this.isVip,
    required this.updateTime,
  });
}

/// 正文内容项
class ContentItem {
  final String content;
  final String nextUrl;
  final String sourceUrl;

  const ContentItem({
    required this.content,
    required this.nextUrl,
    required this.sourceUrl,
  });
}
