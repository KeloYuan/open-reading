import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:xxread/models/book_source.dart';
import 'package:xxread/utils/fast_gbk_decoder.dart';

/// 在线书源解析服务（Legado 常见规则兼容子集）
///
/// 当前支持：
/// - URL 模板变量：`{{searchKey}}` / `searchKey` / `{{page}}` / `{{searchPage}}`
/// - Legado URL 配置格式：`url,{ "method":"POST","body":{...},"headers":{...} }`
/// - 规则解析：HTML/CSS 选择器、基础 JSONPath（`$.a.b[0]`）
/// - 字段提取：`selector@text`、`selector@href`、`$.path`
///
/// 当前不支持：
/// - `@js`、XPath、复杂规则链表达式
class OnlineBookSourceService {
  OnlineBookSourceService({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  static final OnlineBookSourceService _instance = OnlineBookSourceService();

  factory OnlineBookSourceService.instance() => _instance;

  final http.Client _httpClient;

  Future<List<OnlineBookItem>> searchBooks({
    required BookSource source,
    required String keyword,
    int page = 1,
  }) async {
    final trimmedKeyword = keyword.trim();
    if (trimmedKeyword.isEmpty) return const <OnlineBookItem>[];

    final rule = source.ruleSearch;
    if (rule == null ||
        rule.url.trim().isEmpty ||
        rule.bookList.trim().isEmpty) {
      return const <OnlineBookItem>[];
    }

    try {
      final request = _buildRequest(
        rawRule: rule.url,
        source: source,
        keyword: trimmedKeyword,
        page: page,
        searchPage: page,
      );
      final response = await _sendRequest(source: source, request: request);
      final body = _decodeBody(
        response.bodyBytes,
        preferredCharset: _resolvePreferredCharset(
          source: source,
          explicitCharset: rule.charset,
        ),
        responseHeaders: response.headers,
      );
      final baseUrl = response.request?.url.toString() ?? request.url;

      return _parseBookList(
        source: source,
        responseBody: body,
        baseUrl: baseUrl,
        listRule: rule.bookList,
        nameRule: rule.name,
        authorRule: rule.author,
        introRule: rule.intro,
        coverRule: rule.coverUrl,
        bookUrlRule: rule.bookUrl,
        latestChapterRule: rule.lastChapter,
      );
    } catch (e) {
      debugPrint('书源搜索失败(${source.bookSourceName}): $e');
      return const <OnlineBookItem>[];
    }
  }

  Future<List<OnlineBookItem>> searchBooksAcrossSources({
    required List<BookSource> sources,
    required String keyword,
    int page = 1,
    int maxConcurrent = 4,
  }) async {
    final trimmedKeyword = keyword.trim();
    if (trimmedKeyword.isEmpty || sources.isEmpty) {
      return const <OnlineBookItem>[];
    }

    final effectiveConcurrency = maxConcurrent.clamp(1, 10);
    final merged = <OnlineBookItem>[];
    final seenKeys = <String>{};

    for (var start = 0; start < sources.length; start += effectiveConcurrency) {
      final end = (start + effectiveConcurrency) > sources.length
          ? sources.length
          : (start + effectiveConcurrency);
      final chunk = sources.sublist(start, end);

      final chunkResults = await Future.wait(
        chunk.map(
          (source) => searchBooks(
            source: source,
            keyword: trimmedKeyword,
            page: page,
          ),
        ),
      );

      for (final list in chunkResults) {
        for (final item in list) {
          final key = '${item.sourceId}|${item.bookUrl}';
          if (seenKeys.add(key)) {
            merged.add(item);
          }
        }
      }
    }

    merged.sort((a, b) {
      final sourceCompare = a.sourceName.compareTo(b.sourceName);
      if (sourceCompare != 0) return sourceCompare;
      final titleCompare = a.title.compareTo(b.title);
      if (titleCompare != 0) return titleCompare;
      return a.author.compareTo(b.author);
    });
    return merged;
  }

  Future<List<OnlineChapterItem>> getChapters({
    required BookSource source,
    required String bookUrl,
  }) async {
    final rule = source.ruleToc;
    if (rule == null ||
        rule.chapterList.trim().isEmpty ||
        rule.chapterName.trim().isEmpty ||
        rule.chapterUrl.trim().isEmpty) {
      return const <OnlineChapterItem>[];
    }

    try {
      final preferredCharset = _resolvePreferredCharset(source: source);
      var tocTargetUrl = bookUrl;

      final tocUrlRule = source.ruleBookInfo?.tocUrl.trim() ?? '';
      if (tocUrlRule.isNotEmpty) {
        try {
          final detailRequest = _buildRequest(
            rawRule: bookUrl,
            source: source,
          );
          final detailResponse = await _sendRequest(
            source: source,
            request: detailRequest,
          );
          final detailBody = _decodeBody(
            detailResponse.bodyBytes,
            preferredCharset: preferredCharset,
            responseHeaders: detailResponse.headers,
          );
          final detailBaseUrl =
              detailResponse.request?.url.toString() ?? detailRequest.url;
          final detailJson = _tryParseJson(detailBody);
          final detailDoc =
              detailJson == null ? html_parser.parse(detailBody) : null;
          final parsedTocUrl = _extractField(
            item: detailJson ?? detailDoc?.documentElement,
            rule: tocUrlRule,
            baseUrl: detailBaseUrl,
            isUrl: true,
            rootJson: detailJson,
            rootDocument: detailDoc,
          );
          if (parsedTocUrl.trim().isNotEmpty) {
            tocTargetUrl = parsedTocUrl.trim();
          }
        } catch (e) {
          debugPrint('解析目录地址失败(${source.bookSourceName}): $e');
        }
      }

      final request = _buildRequest(
        rawRule: tocTargetUrl,
        source: source,
      );
      final response = await _sendRequest(source: source, request: request);
      final body = _decodeBody(
        response.bodyBytes,
        preferredCharset: preferredCharset,
        responseHeaders: response.headers,
      );
      final baseUrl = response.request?.url.toString() ?? request.url;

      final jsonData = _tryParseJson(body);
      final htmlDoc = jsonData == null ? html_parser.parse(body) : null;
      final listItems = _extractListItems(
        listRule: rule.chapterList,
        jsonData: jsonData,
        htmlDoc: htmlDoc,
      );

      final chapters = <OnlineChapterItem>[];
      for (final item in listItems) {
        final title = _extractField(
          item: item,
          rule: rule.chapterName,
          baseUrl: baseUrl,
          isUrl: false,
          rootJson: jsonData,
          rootDocument: htmlDoc,
        );
        final url = _extractField(
          item: item,
          rule: rule.chapterUrl,
          baseUrl: baseUrl,
          isUrl: true,
          rootJson: jsonData,
          rootDocument: htmlDoc,
        );

        if (title.isEmpty || url.isEmpty) continue;

        chapters.add(OnlineChapterItem(title: title, url: url));
      }

      return chapters;
    } catch (e) {
      debugPrint('获取目录失败(${source.bookSourceName}): $e');
      return const <OnlineChapterItem>[];
    }
  }

  Future<OnlineChapterContent> getChapterContent({
    required BookSource source,
    required OnlineChapterItem chapter,
    int maxNextPages = 4,
  }) async {
    final contentRule = source.ruleContent;
    if (contentRule == null || contentRule.content.trim().isEmpty) {
      return OnlineChapterContent(
        title: chapter.title,
        chapterUrl: chapter.url,
        content: '',
      );
    }

    var currentUrl = chapter.url;
    final visited = <String>{};
    final contentBuffer = StringBuffer();
    var pagesFetched = 0;
    final preferredCharset = _resolvePreferredCharset(source: source);

    while (currentUrl.isNotEmpty &&
        !visited.contains(currentUrl) &&
        pagesFetched <= maxNextPages) {
      visited.add(currentUrl);

      final request = _buildRequest(rawRule: currentUrl, source: source);
      final response = await _sendRequest(source: source, request: request);
      final body = _decodeBody(
        response.bodyBytes,
        preferredCharset: preferredCharset,
        responseHeaders: response.headers,
      );
      final baseUrl = response.request?.url.toString() ?? request.url;

      final jsonData = _tryParseJson(body);
      final htmlDoc = jsonData == null ? html_parser.parse(body) : null;

      var contentPart = _extractField(
        item: jsonData ?? htmlDoc?.documentElement,
        rule: contentRule.content,
        baseUrl: baseUrl,
        isUrl: false,
        rootJson: jsonData,
        rootDocument: htmlDoc,
      );
      contentPart = _htmlToText(contentPart);
      contentPart = _applyReplaceRules(contentPart, contentRule.replaceRegex);
      contentPart = _normalizeContentText(contentPart);

      if (contentPart.isNotEmpty) {
        if (contentBuffer.isNotEmpty) {
          contentBuffer.writeln();
          contentBuffer.writeln();
        }
        contentBuffer.write(contentPart);
      }

      final nextRule = contentRule.nextUrl.trim();
      if (nextRule.isEmpty) {
        break;
      }

      final nextUrl = _extractField(
        item: jsonData ?? htmlDoc?.documentElement,
        rule: nextRule,
        baseUrl: baseUrl,
        isUrl: true,
        rootJson: jsonData,
        rootDocument: htmlDoc,
      );

      if (nextUrl.isEmpty || visited.contains(nextUrl)) {
        break;
      }

      currentUrl = nextUrl;
      pagesFetched += 1;
    }

    return OnlineChapterContent(
      title: chapter.title,
      chapterUrl: chapter.url,
      content: contentBuffer.toString(),
    );
  }

  Future<http.Response> _sendRequest({
    required BookSource source,
    required _SourceRequest request,
  }) async {
    final uri = Uri.parse(request.url);
    final mergedHeaders = <String, String>{
      'User-Agent': 'XXRead/2.0',
      'Accept': '*/*',
      ...source.header,
      ...request.headers,
    };

    final timeout = Duration(
      milliseconds: source.respondTime <= 0 ? 180000 : source.respondTime,
    );

    late final http.Response response;
    switch (request.method) {
      case 'POST':
        response = await _httpClient
            .post(uri, headers: mergedHeaders, body: request.body)
            .timeout(timeout);
        break;
      case 'PUT':
        response = await _httpClient
            .put(uri, headers: mergedHeaders, body: request.body)
            .timeout(timeout);
        break;
      case 'DELETE':
        response = await _httpClient
            .delete(uri, headers: mergedHeaders, body: request.body)
            .timeout(timeout);
        break;
      default:
        response =
            await _httpClient.get(uri, headers: mergedHeaders).timeout(timeout);
        break;
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final preview = _decodeBody(
        response.bodyBytes,
        responseHeaders: response.headers,
      );
      final compactPreview =
          preview.replaceAll(RegExp(r'\s+'), ' ').trimLeft().trimRight();
      final snippet = compactPreview.isEmpty
          ? ''
          : compactPreview.length <= 180
              ? compactPreview
              : '${compactPreview.substring(0, 180)}...';
      throw Exception(
        'HTTP ${response.statusCode} 请求失败: ${uri.toString()}'
        '${snippet.isEmpty ? '' : ' | $snippet'}',
      );
    }

    return response;
  }

  _SourceRequest _buildRequest({
    required String rawRule,
    required BookSource source,
    String keyword = '',
    int page = 1,
    int searchPage = 1,
  }) {
    final trimmed = rawRule.trim();
    if (trimmed.isEmpty) {
      throw Exception('空请求规则');
    }
    if (trimmed.toLowerCase().startsWith('@js:')) {
      throw UnsupportedError('暂不支持 @js URL 规则');
    }

    final expanded = _applyTemplate(
      trimmed,
      keyword: keyword,
      page: page,
      searchPage: searchPage,
    );
    final parsed = _parseLegadoUrlRule(expanded);

    final fallbackBase = source.bookSourceUrl.trim();
    final resolvedUrl = _resolveAbsoluteUrl(parsed.url, fallbackBase);
    if (resolvedUrl.isEmpty) {
      throw Exception('无法解析请求地址: ${parsed.url}');
    }

    final headers = <String, String>{};
    var method = 'GET';
    String? body;

    final optionMap = parsed.options;
    if (optionMap != null) {
      final rawMethod = (optionMap['method'] ?? '').toString().trim();
      if (rawMethod.isNotEmpty) {
        method = rawMethod.toUpperCase();
      }

      final optionHeaders = optionMap['headers'] ?? optionMap['header'];
      if (optionHeaders is Map) {
        optionHeaders.forEach((key, value) {
          headers[key.toString()] = value?.toString() ?? '';
        });
      }

      final optionBody = optionMap['body'];
      if (optionBody != null) {
        final configuredContentType = _getHeaderIgnoreCase(
          headers,
          'content-type',
        );
        final isFormBody = _looksLikeFormContentType(configuredContentType);

        if (optionBody is Map || optionBody is List) {
          if (optionBody is Map && isFormBody) {
            final params = optionBody.map(
              (key, value) => MapEntry(
                key.toString(),
                value?.toString() ?? '',
              ),
            );
            body = params.entries
                .map(
                  (entry) => '${Uri.encodeQueryComponent(entry.key)}='
                      '${Uri.encodeQueryComponent(entry.value)}',
                )
                .join('&');
            _putHeaderIfAbsentIgnoreCase(
              headers,
              'Content-Type',
              'application/x-www-form-urlencoded; charset=utf-8',
            );
          } else {
            body = jsonEncode(optionBody);
            _putHeaderIfAbsentIgnoreCase(
              headers,
              'Content-Type',
              'application/json; charset=utf-8',
            );
          }
        } else {
          body = optionBody.toString();
        }
      }
    }

    return _SourceRequest(
      url: resolvedUrl,
      method: method,
      headers: headers,
      body: body,
    );
  }

  List<OnlineBookItem> _parseBookList({
    required BookSource source,
    required String responseBody,
    required String baseUrl,
    required String listRule,
    required String nameRule,
    required String authorRule,
    required String introRule,
    required String coverRule,
    required String bookUrlRule,
    required String latestChapterRule,
  }) {
    final jsonData = _tryParseJson(responseBody);
    final htmlDoc = jsonData == null ? html_parser.parse(responseBody) : null;
    final items = _extractListItems(
      listRule: listRule,
      jsonData: jsonData,
      htmlDoc: htmlDoc,
    );

    final books = <OnlineBookItem>[];
    for (final item in items) {
      final title = _extractField(
        item: item,
        rule: nameRule,
        baseUrl: baseUrl,
        isUrl: false,
        rootJson: jsonData,
        rootDocument: htmlDoc,
      );
      final bookUrl = _extractField(
        item: item,
        rule: bookUrlRule,
        baseUrl: baseUrl,
        isUrl: true,
        rootJson: jsonData,
        rootDocument: htmlDoc,
      );
      if (title.isEmpty || bookUrl.isEmpty) continue;

      final author = _extractField(
        item: item,
        rule: authorRule,
        baseUrl: baseUrl,
        isUrl: false,
        rootJson: jsonData,
        rootDocument: htmlDoc,
      );
      final intro = _extractField(
        item: item,
        rule: introRule,
        baseUrl: baseUrl,
        isUrl: false,
        rootJson: jsonData,
        rootDocument: htmlDoc,
      );
      final coverUrl = _extractField(
        item: item,
        rule: coverRule,
        baseUrl: baseUrl,
        isUrl: true,
        rootJson: jsonData,
        rootDocument: htmlDoc,
      );
      final latestChapter = _extractField(
        item: item,
        rule: latestChapterRule,
        baseUrl: baseUrl,
        isUrl: false,
        rootJson: jsonData,
        rootDocument: htmlDoc,
      );

      books.add(
        OnlineBookItem(
          title: title,
          author: author,
          intro: intro,
          coverUrl: coverUrl,
          bookUrl: bookUrl,
          latestChapter: latestChapter,
          sourceId: source.id,
          sourceName: source.bookSourceName,
        ),
      );
    }

    return books;
  }

  List<dynamic> _extractListItems({
    required String listRule,
    required dynamic jsonData,
    required dom.Document? htmlDoc,
  }) {
    final cleanRule = _sanitizeRule(listRule);
    if (cleanRule.isEmpty) return const <dynamic>[];

    if (jsonData != null) {
      final jsonItems = _extractJsonList(jsonData, cleanRule);
      if (jsonItems.isNotEmpty) return jsonItems;
    }

    if (htmlDoc != null) {
      final selector = _normalizeCssSelector(cleanRule);
      if (selector.isEmpty) return const <dynamic>[];
      return htmlDoc.querySelectorAll(selector);
    }

    return const <dynamic>[];
  }

  String _extractField({
    required dynamic item,
    required String rule,
    required String baseUrl,
    required bool isUrl,
    required dynamic rootJson,
    required dom.Document? rootDocument,
  }) {
    final cleanRule = _sanitizeRule(rule);
    if (cleanRule.isEmpty) return '';

    final candidates = cleanRule
        .split('||')
        .map((segment) => _sanitizeRule(segment))
        .where((segment) => segment.isNotEmpty);

    for (final candidate in candidates) {
      final value = _extractFieldByRule(
        item: item,
        rule: candidate,
        rootJson: rootJson,
        rootDocument: rootDocument,
      );
      final normalized = _normalizeExtractedString(value);
      if (normalized.isEmpty) continue;
      if (isUrl) {
        final absolute = _resolveAbsoluteUrl(normalized, baseUrl);
        if (absolute.isNotEmpty) {
          return absolute;
        }
      } else {
        return normalized;
      }
    }

    return '';
  }

  String _extractFieldByRule({
    required dynamic item,
    required String rule,
    required dynamic rootJson,
    required dom.Document? rootDocument,
  }) {
    if (rule.startsWith(r'$')) {
      final direct = _jsonPathGet(item, rule);
      final directString = _dynamicToString(direct);
      if (directString.isNotEmpty) return directString;

      final fallback = _jsonPathGet(rootJson, rule);
      return _dynamicToString(fallback);
    }

    if (_looksLikeCssRule(rule) && rootDocument != null) {
      return _extractFromHtml(item, rule, rootDocument);
    }

    if (item is Map) {
      if (item.containsKey(rule)) {
        return _dynamicToString(item[rule]);
      }
      final dotted = _jsonPathGet(item, rule);
      final dottedString = _dynamicToString(dotted);
      if (dottedString.isNotEmpty) return dottedString;
    }

    final fallback = _jsonPathGet(rootJson, rule);
    return _dynamicToString(fallback);
  }

  String _extractFromHtml(
      dynamic item, String rule, dom.Document rootDocument) {
    final atIndex = rule.lastIndexOf('@');
    String selector = rule;
    String accessor = 'text';
    if (atIndex > 0) {
      selector = rule.substring(0, atIndex).trim();
      accessor = rule.substring(atIndex + 1).trim().toLowerCase();
    }

    dom.Element? target;
    final normalizedSelector = _normalizeCssSelector(selector);
    if (item is dom.Element && normalizedSelector.isEmpty) {
      target = item;
    } else if (item is dom.Element && normalizedSelector.isNotEmpty) {
      target = item.querySelector(normalizedSelector);
    } else if (normalizedSelector.isNotEmpty) {
      target = rootDocument.querySelector(normalizedSelector);
    } else {
      target = rootDocument.documentElement;
    }

    if (target == null) return '';

    switch (accessor) {
      case '':
      case 'text':
      case 'txt':
        return target.text;
      case 'html':
        return target.innerHtml;
      case 'outerhtml':
        return target.outerHtml;
      default:
        return target.attributes[accessor] ?? '';
    }
  }

  List<dynamic> _extractJsonList(dynamic jsonData, String rule) {
    final extracted = _jsonPathGet(jsonData, rule);
    if (extracted == null) return const <dynamic>[];
    if (extracted is List) return extracted;
    if (extracted is Map) return <dynamic>[extracted];
    return <dynamic>[extracted];
  }

  dynamic _jsonPathGet(dynamic data, String pathRule) {
    if (data == null) return null;
    final normalizedPath = _normalizeJsonPath(pathRule);
    if (normalizedPath.isEmpty) return null;

    if (normalizedPath == r'$') {
      return data;
    }

    var path = normalizedPath;
    if (path.startsWith(r'$.')) {
      path = path.substring(2);
    } else if (path.startsWith(r'$[')) {
      path = path.substring(1);
    } else if (path.startsWith(r'$')) {
      path = path.substring(1);
    }

    path = path
        .replaceAllMapped(
          RegExp(r"\['([^']+)'\]"),
          (match) => '.${match.group(1)}',
        )
        .replaceAllMapped(
          RegExp(r'\["([^"]+)"\]'),
          (match) => '.${match.group(1)}',
        );

    final segments = _splitJsonSegments(path);
    dynamic current = data;
    for (final segment in segments) {
      if (segment == '*') {
        if (current is List) {
          return current;
        }
        if (current is Map) {
          return current.values.toList();
        }
        return null;
      }

      if (current is Map) {
        current = current[segment];
        continue;
      }

      if (current is List) {
        final index = int.tryParse(segment);
        if (index == null || index < 0 || index >= current.length) {
          return null;
        }
        current = current[index];
        continue;
      }

      return null;
    }
    return current;
  }

  List<String> _splitJsonSegments(String path) {
    final segments = <String>[];
    for (final part in path.split('.')) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;

      final matches = RegExp(r'([^\[\]]+)|\[(\d+|\*)\]').allMatches(trimmed);
      if (matches.isEmpty) {
        segments.add(trimmed);
        continue;
      }
      for (final match in matches) {
        final key = match.group(1);
        final index = match.group(2);
        if (key != null && key.isNotEmpty) {
          segments.add(key);
        }
        if (index != null && index.isNotEmpty) {
          segments.add(index);
        }
      }
    }
    return segments;
  }

  _ParsedUrlRule _parseLegadoUrlRule(String rawRule) {
    final trimmed = rawRule.trim();
    for (var i = 0; i < trimmed.length; i++) {
      if (trimmed[i] != ',') continue;
      final urlPart = trimmed.substring(0, i).trim();
      final optionPart = trimmed.substring(i + 1).trimLeft();
      if (!optionPart.startsWith('{')) continue;
      try {
        final decoded = jsonDecode(optionPart);
        if (decoded is Map) {
          return _ParsedUrlRule(
            url: urlPart,
            options: decoded.map(
              (key, value) => MapEntry(key.toString(), value),
            ),
          );
        }
      } catch (_) {
        // ignore malformed candidate, continue scanning the next comma
      }
    }

    return _ParsedUrlRule(url: trimmed, options: null);
  }

  String _applyTemplate(
    String input, {
    required String keyword,
    required int page,
    required int searchPage,
  }) {
    final replacements = <String, String>{
      'searchKey': keyword,
      'key': keyword,
      'page': page.toString(),
      'searchPage': searchPage.toString(),
    };

    var output = input.replaceAllMapped(
      RegExp(r'\{\{\s*([A-Za-z0-9_]+)\s*\}\}'),
      (match) => replacements[match.group(1)] ?? '',
    );
    if (keyword.isNotEmpty) {
      output = output.replaceAll('searchKey', keyword);
    }
    return output;
  }

  String _normalizeJsonPath(String rule) {
    final clean = _sanitizeRule(rule);
    if (clean.isEmpty) return '';
    final logicalSplit = clean.split('&&').first.trim();
    if (logicalSplit.isEmpty) return '';
    return logicalSplit;
  }

  String _sanitizeRule(String rule) {
    var result = rule.trim();
    if (result.isEmpty) return '';

    final jsIndex = result.toLowerCase().indexOf('@js:');
    if (jsIndex >= 0) {
      result = result.substring(0, jsIndex).trim();
    }

    if (result.startsWith('@css:')) {
      result = result.substring(5).trim();
    }
    if (result.startsWith('@json:')) {
      result = result.substring(6).trim();
    }
    if (result.startsWith('@Json:')) {
      result = result.substring(6).trim();
    }
    if (result.startsWith('@XPath:')) {
      result = result.substring(7).trim();
    }

    final regexSplit = result.indexOf('##');
    if (regexSplit > 0) {
      result = result.substring(0, regexSplit).trim();
    }

    return result;
  }

  String _normalizeCssSelector(String selector) {
    return selector
        .replaceAll('&&', ' ')
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .join(' ');
  }

  bool _looksLikeCssRule(String rule) {
    if (rule.startsWith(r'$')) return false;
    if (rule.contains('@')) return true;
    final cssHint = RegExp(r'[#\.\[\]> ]');
    if (cssHint.hasMatch(rule)) return true;
    return RegExp(r'^[A-Za-z][A-Za-z0-9_-]*$').hasMatch(rule);
  }

  String _resolveAbsoluteUrl(String maybeUrl, String baseUrl) {
    final raw = maybeUrl.trim();
    if (raw.isEmpty) return '';
    try {
      final uri = Uri.parse(raw);
      if (uri.hasScheme) {
        return uri.toString();
      }
    } catch (_) {
      return '';
    }

    if (baseUrl.trim().isEmpty) return raw;
    try {
      final baseUri = Uri.parse(baseUrl);
      return baseUri.resolve(raw).toString();
    } catch (_) {
      return raw;
    }
  }

  dynamic _tryParseJson(String text) {
    final trimmed = text.trim();
    if (!(trimmed.startsWith('{') || trimmed.startsWith('['))) {
      return null;
    }
    try {
      return jsonDecode(trimmed);
    } catch (_) {
      return null;
    }
  }

  String _decodeBody(
    List<int> bytes, {
    String? preferredCharset,
    Map<String, String>? responseHeaders,
  }) {
    return _decodeBodyInternal(
      bytes,
      preferredCharset: preferredCharset,
      responseHeaders: responseHeaders,
    );
  }

  String _decodeBodyInternal(
    List<int> bytes, {
    String? preferredCharset,
    Map<String, String>? responseHeaders,
  }) {
    if (bytes.isEmpty) return '';

    final candidates = <String>[];
    void addCandidate(String? raw) {
      final normalized = _normalizeCharset(raw);
      if (normalized.isEmpty || candidates.contains(normalized)) return;
      candidates.add(normalized);
    }

    addCandidate(preferredCharset);
    addCandidate(_extractCharsetFromHeaders(responseHeaders));
    addCandidate(_extractCharsetFromHtmlMeta(bytes));

    for (final candidate in candidates) {
      final decoded = _decodeByCharset(bytes, candidate);
      if (decoded != null) {
        return decoded;
      }
    }

    try {
      return utf8.decode(bytes);
    } catch (_) {
      final uint8 = Uint8List.fromList(bytes);
      if (isLikelyValidGbkByteStream(uint8)) {
        return decodeGbkFast(uint8, lenient: true);
      }
      final utf8Lenient = utf8.decode(bytes, allowMalformed: true);
      if (!utf8Lenient.contains('\uFFFD')) {
        return utf8Lenient;
      }
      return latin1.decode(bytes);
    }
  }

  String? _decodeByCharset(List<int> bytes, String normalizedCharset) {
    switch (normalizedCharset) {
      case 'utf8':
        return utf8.decode(bytes, allowMalformed: true);
      case 'latin1':
        return latin1.decode(bytes);
      case 'ascii':
        return ascii.decode(bytes, allowInvalid: true);
      case 'gbk':
        return decodeGbkFast(Uint8List.fromList(bytes), lenient: true);
      default:
        return null;
    }
  }

  String _normalizeCharset(String? rawCharset) {
    if (rawCharset == null) return '';
    var charset = rawCharset.trim().toLowerCase();
    if (charset.isEmpty) return '';

    final semicolon = charset.indexOf(';');
    if (semicolon >= 0) {
      charset = charset.substring(0, semicolon).trim();
    }
    if (charset.startsWith('charset=')) {
      charset = charset.substring('charset='.length).trim();
    }

    charset = charset.replaceAll('"', '').replaceAll("'", '');

    switch (charset) {
      case 'utf-8':
      case 'utf8':
        return 'utf8';
      case 'latin-1':
      case 'latin1':
      case 'iso-8859-1':
        return 'latin1';
      case 'us-ascii':
      case 'ascii':
        return 'ascii';
      case 'gbk':
      case 'gb2312':
      case 'gb18030':
      case 'x-gbk':
      case 'cp936':
        return 'gbk';
      default:
        return charset;
    }
  }

  String _extractCharsetFromHeaders(Map<String, String>? headers) {
    if (headers == null || headers.isEmpty) return '';
    final contentType = _getHeaderIgnoreCase(headers, 'content-type');
    if (contentType == null || contentType.trim().isEmpty) {
      return '';
    }
    final match = RegExp(
      r'''charset\s*=\s*["']?\s*([^;"'\s]+)''',
      caseSensitive: false,
    ).firstMatch(contentType);
    return match?.group(1)?.trim() ?? '';
  }

  String _extractCharsetFromHtmlMeta(List<int> bytes) {
    final sampleLength = bytes.length < 4096 ? bytes.length : 4096;
    if (sampleLength <= 0) return '';
    final sample = latin1.decode(bytes.sublist(0, sampleLength));

    final charsetMatch = RegExp(
      r'''<meta[^>]*charset\s*=\s*["']?\s*([^>"'\s/]+)''',
      caseSensitive: false,
    ).firstMatch(sample);
    if (charsetMatch != null) {
      return charsetMatch.group(1)?.trim() ?? '';
    }

    final contentMatch = RegExp(
      r'''<meta[^>]*content\s*=\s*["'][^"']*charset\s*=\s*([^;"'\s>]+)''',
      caseSensitive: false,
    ).firstMatch(sample);
    return contentMatch?.group(1)?.trim() ?? '';
  }

  String? _resolvePreferredCharset({
    required BookSource source,
    String? explicitCharset,
  }) {
    final candidates = <String?>[
      explicitCharset,
      source.httpConfig['charset'],
      source.httpConfig['Charset'],
      source.ruleSearch?.charset,
    ];

    for (final candidate in candidates) {
      final normalized = _normalizeCharset(candidate);
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }
    return null;
  }

  String? _getHeaderIgnoreCase(Map<String, String> headers, String key) {
    final target = key.toLowerCase();
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == target) {
        return entry.value;
      }
    }
    return null;
  }

  void _putHeaderIfAbsentIgnoreCase(
    Map<String, String> headers,
    String key,
    String value,
  ) {
    if (_getHeaderIgnoreCase(headers, key) != null) return;
    headers[key] = value;
  }

  bool _looksLikeFormContentType(String? rawContentType) {
    if (rawContentType == null) return false;
    final normalized = rawContentType.toLowerCase();
    return normalized.contains('application/x-www-form-urlencoded');
  }

  String _dynamicToString(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    if (value is num || value is bool) return value.toString();
    if (value is List) {
      for (final item in value) {
        final str = _dynamicToString(item);
        if (str.trim().isNotEmpty) return str;
      }
      return '';
    }
    if (value is Map) {
      return jsonEncode(value);
    }
    return value.toString();
  }

  String _normalizeExtractedString(String text) {
    return text
        .replaceAll('\u00A0', ' ')
        .replaceAll(RegExp(r'\r\n?'), '\n')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  String _htmlToText(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    if (!RegExp(r'<[^>]+>').hasMatch(trimmed)) {
      return trimmed;
    }

    var html = trimmed;
    html = html.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
    html = html.replaceAll(
      RegExp(
        r'</(p|div|li|h1|h2|h3|h4|h5|h6|tr|blockquote)>',
        caseSensitive: false,
      ),
      '\n',
    );
    return html_parser.parseFragment(html).text ?? '';
  }

  String _applyReplaceRules(String content, String replaceRule) {
    if (replaceRule.trim().isEmpty || content.isEmpty) return content;

    var result = content;
    final lines = replaceRule
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty);
    for (final line in lines) {
      final pair = line.split('##');
      if (pair.length < 2) continue;
      final pattern = pair.first;
      final replacement = pair.sublist(1).join('##');
      try {
        result =
            result.replaceAll(RegExp(pattern, multiLine: true), replacement);
      } catch (_) {
        // ignore invalid regex
      }
    }
    return result;
  }

  String _normalizeContentText(String text) {
    return text
        .replaceAll(RegExp(r'\r\n?'), '\n')
        .replaceAll(RegExp(r'[ \t]+\n'), '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }
}

class OnlineBookItem {
  const OnlineBookItem({
    required this.title,
    required this.author,
    required this.intro,
    required this.coverUrl,
    required this.bookUrl,
    required this.latestChapter,
    required this.sourceId,
    required this.sourceName,
  });

  final String title;
  final String author;
  final String intro;
  final String coverUrl;
  final String bookUrl;
  final String latestChapter;
  final String sourceId;
  final String sourceName;
}

class OnlineChapterItem {
  const OnlineChapterItem({
    required this.title,
    required this.url,
  });

  final String title;
  final String url;
}

class OnlineChapterContent {
  const OnlineChapterContent({
    required this.title,
    required this.chapterUrl,
    required this.content,
  });

  final String title;
  final String chapterUrl;
  final String content;
}

class _SourceRequest {
  const _SourceRequest({
    required this.url,
    required this.method,
    required this.headers,
    this.body,
  });

  final String url;
  final String method;
  final Map<String, String> headers;
  final String? body;
}

class _ParsedUrlRule {
  const _ParsedUrlRule({
    required this.url,
    required this.options,
  });

  final String url;
  final Map<String, dynamic>? options;
}
