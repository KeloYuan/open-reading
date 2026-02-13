import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

/// 封面生成器
///
/// 为没有封面的书籍生成美观的默认封面
class CoverGenerator {
  /// 生成文本封面
  ///
  /// [title] 书名
  /// [author] 作者
  /// [format] 文件格式（TXT, MOBI等）
  /// [width] 封面宽度
  /// [height] 封面高度
  /// Returns: 封面图片的字节数据
  static Future<Uint8List> generateTextCover({
    required String title,
    String author = 'Unknown',
    String format = 'TXT',
    int width = 400,
    int height = 600,
  }) async {
    // 创建画布
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = Size(width.toDouble(), height.toDouble());

    // 根据格式选择配色
    final colorScheme = _getColorScheme(format);

    // 绘制渐变背景
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: colorScheme.gradientColors,
    );

    final paint = Paint()
      ..shader =
          gradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    // 绘制装饰元素
    _drawDecorations(canvas, size, colorScheme.decorationColor);

    // 绘制书名
    _drawText(
      canvas,
      title,
      size,
      fontSize: _calculateTitleFontSize(title),
      fontWeight: FontWeight.bold,
      color: Colors.white,
      maxLines: 4,
      y: size.height * 0.3,
    );

    // 绘制作者
    _drawText(
      canvas,
      author,
      size,
      fontSize: 24,
      fontWeight: FontWeight.w400,
      color: Colors.white.withValues(alpha: 0.9),
      maxLines: 2,
      y: size.height * 0.7,
    );

    // 绘制格式标签
    _drawFormatTag(canvas, size, format, colorScheme.tagColor);

    // 转换为图片
    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    return byteData!.buffer.asUint8List();
  }

  /// 保存封面到磁盘
  ///
  /// [imageBytes] 图片字节数据
  /// [bookFileName] 书籍文件名（用于生成封面文件名）
  /// Returns: 保存的封面路径
  static Future<String> saveCover(
    Uint8List imageBytes,
    String bookFileName,
  ) async {
    try {
      final documentsDir = await getApplicationDocumentsDirectory();
      final coversDir = Directory(join(documentsDir.path, 'covers'));
      if (!await coversDir.exists()) {
        await coversDir.create(recursive: true);
      }

      // 生成唯一的封面文件名
      final coverFileName =
          '${basenameWithoutExtension(bookFileName)}_${DateTime.now().millisecondsSinceEpoch}.png';
      final coverPath = join(coversDir.path, coverFileName);

      // 保存文件
      final file = File(coverPath);
      await file.writeAsBytes(imageBytes);

      return coverPath;
    } catch (e) {
      debugPrint('保存封面失败: $e');
      rethrow;
    }
  }

  /// 计算标题字体大小
  static double _calculateTitleFontSize(String title) {
    if (title.length <= 10) {
      return 48;
    } else if (title.length <= 20) {
      return 40;
    } else if (title.length <= 30) {
      return 32;
    } else {
      return 28;
    }
  }

  /// 绘制文本
  static void _drawText(
    Canvas canvas,
    String text,
    Size size, {
    required double fontSize,
    required FontWeight fontWeight,
    required Color color,
    required double y,
    int maxLines = 1,
  }) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
          height: 1.3,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: maxLines,
    );

    textPainter.layout(maxWidth: size.width - 60);

    final xCenter = (size.width - textPainter.width) / 2;
    textPainter.paint(canvas, Offset(xCenter, y));
  }

  /// 绘制装饰元素
  static void _drawDecorations(Canvas canvas, Size size, Color color) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // 绘制边框
    final borderRect = Rect.fromLTWH(30, 30, size.width - 60, size.height - 60);
    canvas.drawRRect(
      RRect.fromRectAndRadius(borderRect, const Radius.circular(8)),
      paint,
    );

    // 绘制装饰线
    paint.strokeWidth = 1;
    canvas.drawLine(
      Offset(60, size.height * 0.25),
      Offset(size.width - 60, size.height * 0.25),
      paint,
    );
    canvas.drawLine(
      Offset(60, size.height * 0.75),
      Offset(size.width - 60, size.height * 0.75),
      paint,
    );
  }

  /// 绘制格式标签
  static void _drawFormatTag(
      Canvas canvas, Size size, String format, Color color) {
    final tagRect = Rect.fromLTWH(
      size.width - 100,
      size.height - 60,
      80,
      40,
    );

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(tagRect, const Radius.circular(8)),
      paint,
    );

    final textPainter = TextPainter(
      text: TextSpan(
        text: format.toUpperCase(),
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    textPainter.layout();

    final xCenter = tagRect.center.dx - textPainter.width / 2;
    final yCenter = tagRect.center.dy - textPainter.height / 2;
    textPainter.paint(canvas, Offset(xCenter, yCenter));
  }

  /// 获取配色方案
  static _ColorScheme _getColorScheme(String format) {
    switch (format.toUpperCase()) {
      case 'TXT':
        return _ColorScheme(
          gradientColors: [
            const Color(0xFF667eea),
            const Color(0xFF764ba2),
          ],
          decorationColor: Colors.white,
          tagColor: const Color(0xFF764ba2),
        );
      case 'MOBI':
      case 'AZW':
      case 'AZW3':
        return _ColorScheme(
          gradientColors: [
            const Color(0xFFf093fb),
            const Color(0xFFf5576c),
          ],
          decorationColor: Colors.white,
          tagColor: const Color(0xFFf5576c),
        );
      case 'FB2':
        return _ColorScheme(
          gradientColors: [
            const Color(0xFF4facfe),
            const Color(0xFF00f2fe),
          ],
          decorationColor: Colors.white,
          tagColor: const Color(0xFF00f2fe),
        );
      case 'RTF':
        return _ColorScheme(
          gradientColors: [
            const Color(0xFFfa709a),
            const Color(0xFFfee140),
          ],
          decorationColor: Colors.white,
          tagColor: const Color(0xFFfa709a),
        );
      default:
        return _ColorScheme(
          gradientColors: [
            const Color(0xFF89f7fe),
            const Color(0xFF66a6ff),
          ],
          decorationColor: Colors.white,
          tagColor: const Color(0xFF66a6ff),
        );
    }
  }
}

/// 配色方案
class _ColorScheme {
  final List<Color> gradientColors;
  final Color decorationColor;
  final Color tagColor;

  _ColorScheme({
    required this.gradientColors,
    required this.decorationColor,
    required this.tagColor,
  });
}
