import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/reader_core/document/flow_doc.dart';
import 'package:xxread/reader_core/parser/txt_parser.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'TxtParser merges dialogue-like wrapped lines into one flowing paragraph',
      () async {
    final parser = TxtParser();
    final dir = await Directory.systemTemp.createTemp('xxread_txt_dialogue_');
    final file = File('${dir.path}/dialogue.txt');
    await file.writeAsString(
      '第一章 测试\n'
      '“这是第一句台词。”\n'
      '“这是第二句台词。”\n'
      '“这是第三句台词。”\n',
      flush: true,
    );

    addTearDown(() async {
      if (dir.existsSync()) {
        await dir.delete(recursive: true);
      }
    });

    final parsed = await parser.parse(
      bookId: 'txt-dialogue-book',
      title: '对话重排测试',
      author: 'tester',
      filePath: file.path,
    );
    expect(parsed.chapters, isNotEmpty);
    final blocks = parsed.chapters.first.flowDoc.blocks;
    final paragraphs = blocks.whereType<ParagraphBlock>().toList();
    expect(paragraphs, isNotEmpty);
    final body = paragraphs.first.plainText;
    expect(body.contains('\n'), isFalse, reason: body);
    expect(body, contains('“这是第一句台词。”'));
    expect(body, contains('“这是第二句台词。”'));
    expect(body, contains('“这是第三句台词。”'));
  });

  test('TxtParser keeps list hard breaks for structured content', () async {
    final parser = TxtParser();
    final dir = await Directory.systemTemp.createTemp('xxread_txt_list_');
    final file = File('${dir.path}/list.txt');
    await file.writeAsString(
      '第一章 列表\n'
      '- 第一项\n'
      '- 第二项\n'
      '- 第三项\n',
      flush: true,
    );

    addTearDown(() async {
      if (dir.existsSync()) {
        await dir.delete(recursive: true);
      }
    });

    final parsed = await parser.parse(
      bookId: 'txt-list-book',
      title: '列表换行测试',
      author: 'tester',
      filePath: file.path,
    );
    expect(parsed.chapters, isNotEmpty);
    final blocks = parsed.chapters.first.flowDoc.blocks;
    final paragraphs = blocks.whereType<ParagraphBlock>().toList();
    expect(paragraphs, isNotEmpty);
    final body = paragraphs.first.plainText;
    expect(body, contains('\n'));
    expect(body, contains('- 第一项'));
    expect(body, contains('- 第二项'));
    expect(body, contains('- 第三项'));
  });
}
