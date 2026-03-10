import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gbk_codec/gbk_codec.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:xxread/models/book_source.dart';
import 'package:xxread/services/books/book_source_service.dart';
import 'package:xxread/services/books/online_book_source_service.dart';

void main() {
  group('BookSource import compatibility', () {
    test('normalizes legado one-click import url', () {
      final resolved = normalizeBookSourceImportUrl(
        'legado://import/bookSource?src=https%3A%2F%2Fexample.com%2Fsources.json',
      );

      expect(resolved, 'https://example.com/sources.json');
    });

    test('decodes gbk payload and strips utf8 bom wrapper', () {
      final gbkPayload = gbk_bytes.encode(
        '[{"bookSourceName":"起点","bookSourceUrl":"https://example.com"}]',
      );
      final decodedGbk = decodeBookSourceImportPayload(
        gbkPayload,
        responseHeaders: {'content-type': 'application/json; charset=gbk'},
      );
      expect(decodedGbk, contains('起点'));

      final wrappedUtf8 = utf8.encode(
        '\uFEFF<html><body><pre>[{"bookSourceName":"番茄","bookSourceUrl":"https://example.com"}]</pre></body></html>',
      );
      final decodedWrapped = decodeBookSourceImportPayload(wrappedUtf8);
      expect(decodedWrapped, startsWith('['));
      expect(decodedWrapped, contains('番茄'));
    });
  });

  group('BookSource compatibility', () {
    test('maps legacy searchUrl into ruleSearch.url', () {
      final source = BookSource.fromJson({
        'bookSourceName': 'Test Source',
        'bookSourceUrl': 'https://example.com',
        'searchUrl': 'https://example.com/search?q=searchKey',
        'ruleSearch': {
          'bookList': r'$.items',
          'name': r'$.name',
          'author': r'$.author',
          'bookUrl': r'$.url',
        },
      });

      expect(
        source.ruleSearch?.url,
        'https://example.com/search?q=searchKey',
      );
    });
  });

  group('OnlineBookSourceService', () {
    test('supports legado html selector chains inline regex and nextContentUrl',
        () async {
      final source = BookSource.fromJson({
        'bookSourceName': 'Legado HTML Source',
        'bookSourceUrl': 'https://example.com',
        'searchUrl': 'https://example.com/search?q=searchKey',
        'ruleSearch': {
          'bookList': 'class.sitembox@tag.dl',
          'name': 'tag.h3@tag.a@text##\\s+作者：.*##',
          'author': 'class.book_other@tag.span.0@text',
          'bookUrl': 'tag.h3@tag.a@href',
          'coverUrl': 'class.lazyload@_src',
        },
        'ruleToc': {
          'chapterList': 'id.list@tag.li!0',
          'chapterName': 'tag.a@text##^VIP章节\\s*##',
          'chapterUrl':
              'tag.a@href##\$##,{"headers":{"Referer":"https://example.com/book/1"}}',
        },
        'ruleContent': {
          'content': 'id.content',
          'nextContentUrl': 'text.下一页@href',
        },
      });

      expect(source.ruleContent?.nextUrl, 'text.下一页@href');

      final service = OnlineBookSourceService(
        httpClient: MockClient((request) async {
          if (request.url.path == '/search') {
            const html = '''
              <html><body>
                <div class="sitembox">
                  <dl>
                    <h3><a href="/book/1">凡人修仙传 作者：忘语</a></h3>
                    <p class="book_other"><span>忘语</span><span>连载</span></p>
                    <img class="lazyload" _src="/cover.jpg" />
                  </dl>
                </div>
              </body></html>
            ''';
            return http.Response.bytes(
              utf8.encode(html),
              200,
              headers: {'content-type': 'text/html; charset=utf-8'},
            );
          }

          if (request.url.path == '/book/1') {
            const html = '''
              <html><body>
                <ul id="list">
                  <li><a href="/ignore">目录说明</a></li>
                  <li><a href="/chapter/1">VIP章节 第一章 开始</a></li>
                </ul>
              </body></html>
            ''';
            return http.Response.bytes(
              utf8.encode(html),
              200,
              headers: {'content-type': 'text/html; charset=utf-8'},
            );
          }

          if (request.url.path == '/chapter/1') {
            expect(
              request.headers['Referer'],
              'https://example.com/book/1',
            );
            const html = '''
              <html><body>
                <div id="content"><p>第一段内容</p></div>
                <a href="/chapter/1-2">下一页</a>
              </body></html>
            ''';
            return http.Response.bytes(
              utf8.encode(html),
              200,
              headers: {'content-type': 'text/html; charset=utf-8'},
            );
          }

          if (request.url.path == '/chapter/1-2') {
            expect(
              request.headers['Referer'],
              'https://example.com/book/1',
            );
            const html = '''
              <html><body>
                <div id="content"><p>第二段内容</p></div>
              </body></html>
            ''';
            return http.Response.bytes(
              utf8.encode(html),
              200,
              headers: {'content-type': 'text/html; charset=utf-8'},
            );
          }

          return http.Response('not found', 404);
        }),
      );

      final books = await service.searchBooks(
        source: source,
        keyword: '凡人',
      );
      expect(books, hasLength(1));
      expect(books.first.title, '凡人修仙传');
      expect(books.first.author, '忘语');
      expect(books.first.coverUrl, 'https://example.com/cover.jpg');

      final chapters = await service.getChapters(
        source: source,
        bookUrl: books.first.bookUrl,
      );
      expect(chapters, hasLength(1));
      expect(chapters.first.title, '第一章 开始');

      final content = await service.getChapterContent(
        source: source,
        chapter: chapters.first,
      );
      expect(content.content, contains('第一段内容'));
      expect(content.content, contains('第二段内容'));
    });

    test('searchBooks parses json list rules', () async {
      final source = BookSource.fromJson({
        'bookSourceName': 'JSON Source',
        'bookSourceUrl': 'https://example.com',
        'searchUrl': 'https://example.com/search?q=searchKey',
        'ruleSearch': {
          'bookList': r'$.items',
          'name': r'$.name',
          'author': r'$.author',
          'bookUrl': r'$.url',
          'intro': r'$.intro',
          'coverUrl': r'$.cover',
          'lastChapter': r'$.latest',
        },
      });

      final service = OnlineBookSourceService(
        httpClient: MockClient((request) async {
          expect(request.url.toString(), contains('q=%E5%87%A1%E4%BA%BA'));
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'name': '凡人修仙传',
                  'author': '忘语',
                  'url': '/book/1',
                  'intro': '一介凡人修仙',
                  'cover': '/cover.jpg',
                  'latest': '第1章',
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

      final books = await service.searchBooks(
        source: source,
        keyword: '凡人修仙',
      );

      expect(books, hasLength(1));
      expect(books.first.title, '凡人修仙传');
      expect(books.first.author, '忘语');
      expect(books.first.bookUrl, 'https://example.com/book/1');
      expect(books.first.coverUrl, 'https://example.com/cover.jpg');
    });

    test('parses chapter list and joins next-page chapter content', () async {
      final source = BookSource.fromJson({
        'bookSourceName': 'HTML Source',
        'bookSourceUrl': 'https://example.com',
        'ruleToc': {
          'chapterList': '#list li',
          'chapterName': 'a@text',
          'chapterUrl': 'a@href',
        },
        'ruleContent': {
          'content': '#content',
          'nextUrl': 'a.next@href',
        },
      });
      expect(source.ruleToc?.chapterList, '#list li');
      expect(source.ruleToc?.chapterName, 'a@text');
      expect(source.ruleToc?.chapterUrl, 'a@href');

      final service = OnlineBookSourceService(
        httpClient: MockClient((request) async {
          final path = request.url.path;
          if (path == '/book/1') {
            const html = '''
              <html><body>
                <ul id="list">
                  <li><a href="/chapter/1">第一章 开始</a></li>
                </ul>
              </body></html>
              ''';
            return http.Response.bytes(
              utf8.encode(html),
              200,
              headers: {'content-type': 'text/html; charset=utf-8'},
            );
          }
          if (path == '/chapter/1') {
            const html = '''
              <html><body>
                <div id="content"><p>第一段内容</p></div>
                <a class="next" href="/chapter/1-2">下一页</a>
              </body></html>
              ''';
            return http.Response.bytes(
              utf8.encode(html),
              200,
              headers: {'content-type': 'text/html; charset=utf-8'},
            );
          }
          if (path == '/chapter/1-2') {
            const html = '''
              <html><body>
                <div id="content"><p>第二段内容</p></div>
              </body></html>
              ''';
            return http.Response.bytes(
              utf8.encode(html),
              200,
              headers: {'content-type': 'text/html; charset=utf-8'},
            );
          }
          return http.Response('', 404);
        }),
      );

      final chapters = await service.getChapters(
        source: source,
        bookUrl: 'https://example.com/book/1',
      );
      expect(chapters, hasLength(1));
      expect(chapters.first.title, '第一章 开始');
      expect(chapters.first.url, 'https://example.com/chapter/1');

      final content = await service.getChapterContent(
        source: source,
        chapter: chapters.first,
      );
      expect(content.content, contains('第一段内容'));
      expect(content.content, contains('第二段内容'));
    });

    test('searchBooks returns empty list when http status is non-2xx',
        () async {
      final source = BookSource.fromJson({
        'bookSourceName': 'HTTP Error Source',
        'bookSourceUrl': 'https://example.com',
        'searchUrl': 'https://example.com/search?q=searchKey',
        'ruleSearch': {
          'bookList': r'$.items',
          'name': r'$.name',
          'author': r'$.author',
          'bookUrl': r'$.url',
        },
      });

      final service = OnlineBookSourceService(
        httpClient: MockClient((request) async {
          return http.Response(
            jsonEncode({
              'items': [
                {'name': '不应该解析', 'author': 'X', 'url': '/book/2'},
              ],
            }),
            503,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

      final books = await service.searchBooks(
        source: source,
        keyword: '测试',
      );
      expect(books, isEmpty);
    });

    test('supports GBK html decoding for chapter and content pages', () async {
      final source = BookSource.fromJson({
        'bookSourceName': 'GBK Source',
        'bookSourceUrl': 'https://example.com',
        'ruleToc': {
          'chapterList': '#list li',
          'chapterName': 'a@text',
          'chapterUrl': 'a@href',
        },
        'ruleContent': {
          'content': '#content',
        },
      });

      final service = OnlineBookSourceService(
        httpClient: MockClient((request) async {
          if (request.url.path == '/book/gbk') {
            const html = '''
              <html><body>
                <ul id="list">
                  <li><a href="/chapter/gbk-1">第一章 开始</a></li>
                </ul>
              </body></html>
              ''';
            return http.Response.bytes(
              gbk_bytes.encode(html),
              200,
              headers: {'content-type': 'text/html; charset=gbk'},
            );
          }

          if (request.url.path == '/chapter/gbk-1') {
            const html = '''
              <html><body>
                <div id="content">这是GBK正文内容</div>
              </body></html>
              ''';
            return http.Response.bytes(
              gbk_bytes.encode(html),
              200,
              headers: {'content-type': 'text/html; charset=gb2312'},
            );
          }

          return http.Response('not found', 404);
        }),
      );

      final chapters = await service.getChapters(
        source: source,
        bookUrl: 'https://example.com/book/gbk',
      );
      expect(chapters, hasLength(1));
      expect(chapters.first.title, '第一章 开始');

      final content = await service.getChapterContent(
        source: source,
        chapter: chapters.first,
      );
      expect(content.content, contains('这是GBK正文内容'));
    });

    test('url option body map supports form-urlencoded post', () async {
      final source = BookSource.fromJson({
        'bookSourceName': 'Form Source',
        'bookSourceUrl': 'https://example.com',
        'ruleSearch': {
          'url':
              'https://example.com/search,{"method":"POST","headers":{"Content-Type":"application/x-www-form-urlencoded"},"body":{"q":"searchKey","page":"{{page}}"}}',
          'bookList': r'$.items',
          'name': r'$.name',
          'author': r'$.author',
          'bookUrl': r'$.url',
        },
      });

      final service = OnlineBookSourceService(
        httpClient: MockClient((request) async {
          expect(request.method, 'POST');
          expect(
            request.headers['content-type'],
            contains('application/x-www-form-urlencoded'),
          );
          final payload = utf8.decode(request.bodyBytes);
          expect(payload, contains('q=%E5%87%A1%E4%BA%BA'));
          expect(payload, contains('page=3'));

          return http.Response(
            jsonEncode({
              'items': [
                {
                  'name': '凡人修仙传',
                  'author': '忘语',
                  'url': '/book/1',
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

      final books = await service.searchBooks(
        source: source,
        keyword: '凡人',
        page: 3,
      );
      expect(books, hasLength(1));
      expect(books.first.title, '凡人修仙传');
    });

    test('getChapters returns empty list when toc request is non-2xx',
        () async {
      final source = BookSource.fromJson({
        'bookSourceName': 'TOC Error Source',
        'bookSourceUrl': 'https://example.com',
        'ruleToc': {
          'chapterList': '#list li',
          'chapterName': 'a@text',
          'chapterUrl': 'a@href',
        },
      });

      final service = OnlineBookSourceService(
        httpClient: MockClient((request) async {
          return http.Response('server error', 500);
        }),
      );

      final chapters = await service.getChapters(
        source: source,
        bookUrl: 'https://example.com/book/1',
      );
      expect(chapters, isEmpty);
    });

    test('detects gbk from html meta when response header misses charset',
        () async {
      final source = BookSource.fromJson({
        'bookSourceName': 'Meta Charset Source',
        'bookSourceUrl': 'https://example.com',
        'ruleToc': {
          'chapterList': '#list li',
          'chapterName': 'a@text',
          'chapterUrl': 'a@href',
        },
      });

      final service = OnlineBookSourceService(
        httpClient: MockClient((request) async {
          const html = '''
            <html>
              <head><meta charset="gbk"></head>
              <body>
                <ul id="list">
                  <li><a href="/chapter/meta-1">第一章 元信息编码</a></li>
                </ul>
              </body>
            </html>
            ''';
          return http.Response.bytes(
            gbk_bytes.encode(html),
            200,
            headers: {'content-type': 'text/html'},
          );
        }),
      );

      final chapters = await service.getChapters(
        source: source,
        bookUrl: 'https://example.com/book/meta',
      );
      expect(chapters, hasLength(1));
      expect(chapters.first.title, '第一章 元信息编码');
    });
  });
}
