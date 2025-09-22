import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart';
import '../models/highlight.dart';
import '../models/note.dart';
import '../models/book.dart';

/// 笔记导出服务
/// 支持多种格式的笔记导出和分享
class NoteExportService {
  static final NoteExportService _instance = NoteExportService._internal();

  factory NoteExportService() {
    return _instance;
  }

  NoteExportService._internal();

  /// 导出高亮和笔记为Markdown格式
  Future<String> exportToMarkdown({
    required Book book,
    required List<Highlight> highlights,
    required List<Note> notes,
  }) async {
    final buffer = StringBuffer();

    // 书籍信息
    buffer.writeln('# ${book.title}');
    buffer.writeln();
    buffer.writeln('**作者**: ${book.author}');
    buffer.writeln('**导出时间**: ${DateTime.now().toIso8601String()}');
    buffer.writeln();

    // 高亮部分
    if (highlights.isNotEmpty) {
      buffer.writeln('## 📝 高亮标记');
      buffer.writeln();

      // 按章节分组
      final highlightsByChapter = <String, List<Highlight>>{};
      for (final highlight in highlights) {
        final chapter = highlight.chapter ?? '未知章节';
        highlightsByChapter.putIfAbsent(chapter, () => []).add(highlight);
      }

      for (final entry in highlightsByChapter.entries) {
        buffer.writeln('### ${entry.key}');
        buffer.writeln();

        for (final highlight in entry.value) {
          buffer.writeln('> ${highlight.selectedText}');
          buffer.writeln();
          buffer.writeln('**颜色**: ${highlight.getColorName()}');
          if (highlight.noteText?.isNotEmpty == true) {
            buffer.writeln('**笔记**: ${highlight.noteText}');
          }
          buffer.writeln('**页码**: ${highlight.pageNumber}');
          buffer.writeln(
            '**时间**: ${highlight.createDate != null ? _formatDate(highlight.createDate!) : "未知"}',
          );
          buffer.writeln();
          buffer.writeln('---');
          buffer.writeln();
        }
      }
    }

    // 笔记部分
    if (notes.isNotEmpty) {
      buffer.writeln('## 📖 笔记');
      buffer.writeln();

      // 按章节分组
      final notesByPage = <int, List<Note>>{};
      for (final note in notes) {
        notesByPage.putIfAbsent(note.pageNumber, () => []).add(note);
      }

      final sortedPages = notesByPage.keys.toList()..sort();

      for (final pageNumber in sortedPages) {
        buffer.writeln('### 第 $pageNumber 页');
        buffer.writeln();

        for (final note in notesByPage[pageNumber]!) {
          if (note.selectedText.isNotEmpty) {
            buffer.writeln('**选中文本**: ${note.selectedText}');
            buffer.writeln();
          }
          buffer.writeln('**笔记内容**: ${note.noteText}');
          buffer.writeln();
          buffer.writeln(
            '**时间**: ${note.createDate != null ? _formatDate(note.createDate!) : "未知"}',
          );
          if (note.updateDate != null) {
            buffer.writeln('**更新时间**: ${_formatDate(note.updateDate!)}');
          }
          buffer.writeln();
          buffer.writeln('---');
          buffer.writeln();
        }
      }
    }

    return buffer.toString();
  }

  /// 导出为JSON格式
  Future<String> exportToJson({
    required Book book,
    required List<Highlight> highlights,
    required List<Note> notes,
  }) async {
    final data = {
      'book': {
        'title': book.title,
        'author': book.author,
        'filePath': book.filePath,
      },
      'exportTime': DateTime.now().toIso8601String(),
      'highlights': highlights.map((h) => h.toExportMap()).toList(),
      'notes': notes
          .map(
            (n) => {
              'selectedText': n.selectedText,
              'noteText': n.noteText,
              'pageNumber': n.pageNumber,
              'createDate': n.createDate?.toIso8601String(),
              'updateDate': n.updateDate?.toIso8601String(),
            },
          )
          .toList(),
    };

    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// 导出为CSV格式
  Future<String> exportToCsv({
    required Book book,
    required List<Highlight> highlights,
    required List<Note> notes,
  }) async {
    final buffer = StringBuffer();

    // CSV头部
    buffer.writeln('类型,章节,页码,选中文本,笔记内容,颜色,创建时间,更新时间');

    // 高亮数据
    for (final highlight in highlights) {
      final row = [
        '高亮',
        highlight.chapter ?? '',
        highlight.pageNumber.toString(),
        _escapeCsvField(highlight.selectedText),
        _escapeCsvField(highlight.noteText ?? ''),
        highlight.getColorName(),
        highlight.createDate != null ? _formatDate(highlight.createDate!) : '',
        highlight.updateDate != null ? _formatDate(highlight.updateDate!) : '',
      ];
      buffer.writeln(row.join(','));
    }

    // 笔记数据
    for (final note in notes) {
      final row = [
        '笔记',
        '',
        note.pageNumber.toString(),
        _escapeCsvField(note.selectedText),
        _escapeCsvField(note.noteText),
        '',
        note.createDate != null ? _formatDate(note.createDate!) : '',
        note.updateDate != null ? _formatDate(note.updateDate!) : '',
      ];
      buffer.writeln(row.join(','));
    }

    return buffer.toString();
  }

  /// 保存文件到设备
  Future<File> saveToFile(String content, String fileName) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(content, encoding: utf8);
      return file;
    } catch (e) {
      debugPrint('保存文件失败: $e');
      rethrow;
    }
  }

  /// 分享笔记
  Future<void> shareNotes({
    required Book book,
    required List<Highlight> highlights,
    required List<Note> notes,
    String format = 'markdown',
  }) async {
    try {
      String content;
      String fileName;

      switch (format.toLowerCase()) {
        case 'json':
          content = await exportToJson(
            book: book,
            highlights: highlights,
            notes: notes,
          );
          fileName = '${book.title}_笔记.json';
          break;
        case 'csv':
          content = await exportToCsv(
            book: book,
            highlights: highlights,
            notes: notes,
          );
          fileName = '${book.title}_笔记.csv';
          break;
        default:
          content = await exportToMarkdown(
            book: book,
            highlights: highlights,
            notes: notes,
          );
          fileName = '${book.title}_笔记.md';
          break;
      }

      final file = await saveToFile(content, fileName);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: '《${book.title}》的阅读笔记',
        text: '这是我在阅读《${book.title}》时记录的高亮和笔记',
      );

      debugPrint('笔记分享成功: $fileName');
    } catch (e) {
      debugPrint('分享笔记失败: $e');
      rethrow;
    }
  }

  /// 生成阅读统计报告
  Future<String> generateReadingReport({
    required Book book,
    required List<Highlight> highlights,
    required List<Note> notes,
  }) async {
    final buffer = StringBuffer();

    buffer.writeln('# 《${book.title}》阅读报告');
    buffer.writeln();
    buffer.writeln('**作者**: ${book.author}');
    buffer.writeln('**生成时间**: ${DateTime.now().toIso8601String()}');
    buffer.writeln();

    // 统计信息
    buffer.writeln('## 📊 阅读统计');
    buffer.writeln();
    buffer.writeln('- **高亮数量**: ${highlights.length}');
    buffer.writeln('- **笔记数量**: ${notes.length}');

    if (highlights.isNotEmpty) {
      // 颜色分布
      final colorStats = <String, int>{};
      for (final highlight in highlights) {
        final colorName = highlight.getColorName();
        colorStats[colorName] = (colorStats[colorName] ?? 0) + 1;
      }

      buffer.writeln('- **高亮颜色分布**:');
      for (final entry in colorStats.entries) {
        buffer.writeln('  - ${entry.key}: ${entry.value}次');
      }

      // 章节分布
      final chapterStats = <String, int>{};
      for (final highlight in highlights) {
        final chapter = highlight.chapter ?? '未知章节';
        chapterStats[chapter] = (chapterStats[chapter] ?? 0) + 1;
      }

      if (chapterStats.isNotEmpty) {
        buffer.writeln('- **章节高亮分布**:');
        for (final entry in chapterStats.entries) {
          buffer.writeln('  - ${entry.key}: ${entry.value}处');
        }
      }
    }

    buffer.writeln();

    // 最近活动
    final allItems = <Map<String, dynamic>>[];

    for (final highlight in highlights) {
      allItems.add({
        'type': 'highlight',
        'date': highlight.createDate?.toIso8601String(),
        'content': highlight.selectedText,
        'note': highlight.noteText,
        'page': highlight.pageNumber,
        'color': highlight.getColorName(),
      });
    }

    for (final note in notes) {
      allItems.add({
        'type': 'note',
        'date': note.createDate?.toIso8601String(),
        'content': note.selectedText,
        'note': note.noteText,
        'page': note.pageNumber,
      });
    }

    allItems.sort(
      (a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime),
    );

    if (allItems.isNotEmpty) {
      buffer.writeln('## 🕒 最近活动');
      buffer.writeln();

      final recentItems = allItems.take(10);
      for (final item in recentItems) {
        final type = item['type'] == 'highlight' ? '高亮' : '笔记';
        final date = _formatDate(item['date'] as DateTime);
        final page = item['page'];
        final content = item['content'].toString();
        final note = item['note']?.toString() ?? '';

        buffer.writeln('- **$date** (第${page}页) - $type');
        if (content.isNotEmpty) {
          buffer.writeln('  > $content');
        }
        if (note.isNotEmpty) {
          buffer.writeln('  📝 $note');
        }
        if (item['type'] == 'highlight' && item['color'] != null) {
          buffer.writeln('  🎨 ${item['color']}');
        }
        buffer.writeln();
      }
    }

    return buffer.toString();
  }

  /// 格式化日期
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  /// 转义CSV字段
  String _escapeCsvField(String field) {
    if (field.contains(',') || field.contains('"') || field.contains('\n')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }
}
