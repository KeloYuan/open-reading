import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'text_layout_engine.dart' show PageImageInfo;

/// 图片尺寸测量服务
///
/// 支持：
/// 1. 本地文件图片
/// 2. 网络图片
/// 3. Asset图片
/// 4. Base64编码图片
class ImageSizeService {
  /// 从URL或路径获取图片尺寸
  ///
  /// 支持的格式：
  /// - http://... 或 https://... (网络图片)
  /// - file://... (本地文件)
  /// - assets/... (Asset资源)
  /// - data:image/... (Base64)
  static Future<PageImageInfo?> getImageSize(String src) async {
    try {
      ui.Image? image;

      if (src.startsWith('http://') || src.startsWith('https://')) {
        // 网络图片
        image = await _loadNetworkImage(src);
      } else if (src.startsWith('file://')) {
        // 本地文件
        final path = src.substring(7); // 移除 "file://"
        image = await _loadFileImage(path);
      } else if (src.startsWith('assets/') || src.startsWith('asset/')) {
        // Asset资源
        image = await _loadAssetImage(src);
      } else if (src.startsWith('data:image/')) {
        // Base64编码图片
        image = await _loadBase64Image(src);
      } else {
        // 默认当作本地文件处理
        image = await _loadFileImage(src);
      }

      if (image == null) {
        debugPrint('⚠️ 无法加载图片: $src');
        return null;
      }

      final imageInfo = PageImageInfo(
        src: src,
        width: image.width,
        height: image.height,
      );

      // 释放图片资源
      image.dispose();

      return imageInfo;
    } catch (e) {
      debugPrint('❌ 获取图片尺寸失败: $src, 错误: $e');
      return null;
    }
  }

  /// 批量获取图片尺寸
  static Future<List<PageImageInfo>> getImageSizes(List<String> srcs) async {
    final results = <PageImageInfo>[];

    for (final src in srcs) {
      final info = await getImageSize(src);
      if (info != null) {
        results.add(info);
      }
    }

    return results;
  }

  /// 从文本中提取图片URL
  ///
  /// 支持的格式：
  /// - <img src="..."/>
  /// - <img src='...'/>
  /// - ![](...)  (Markdown)
  static List<String> extractImageUrls(String text) {
    final urls = <String>[];

    // HTML img标签
    final htmlPattern = RegExp(r'''<img[^>]+src=["']([^"']+)["'][^>]*>''');
    final htmlMatches = htmlPattern.allMatches(text);
    for (final match in htmlMatches) {
      final url = match.group(1);
      if (url != null) {
        urls.add(url);
      }
    }

    // Markdown图片语法
    final mdPattern = RegExp(r'''!\[([^\]]*)\]\(([^)]+)\)''');
    final mdMatches = mdPattern.allMatches(text);
    for (final match in mdMatches) {
      final url = match.group(2);
      if (url != null) {
        urls.add(url);
      }
    }

    return urls;
  }

  /// 加载网络图片
  static Future<ui.Image?> _loadNetworkImage(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        debugPrint('⚠️ 网络图片请求失败: $url, 状态码: ${response.statusCode}');
        return null;
      }

      final bytes = response.bodyBytes;
      return await _decodeImage(bytes);
    } catch (e) {
      debugPrint('❌ 加载网络图片失败: $url, 错误: $e');
      return null;
    }
  }

  /// 加载本地文件图片
  static Future<ui.Image?> _loadFileImage(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) {
        debugPrint('⚠️ 文件不存在: $path');
        return null;
      }

      final bytes = await file.readAsBytes();
      return await _decodeImage(bytes);
    } catch (e) {
      debugPrint('❌ 加载本地图片失败: $path, 错误: $e');
      return null;
    }
  }

  /// 加载Asset图片
  static Future<ui.Image?> _loadAssetImage(String assetPath) async {
    try {
      final data = await rootBundle.load(assetPath);
      final bytes = data.buffer.asUint8List();
      return await _decodeImage(bytes);
    } catch (e) {
      debugPrint('❌ 加载Asset图片失败: $assetPath, 错误: $e');
      return null;
    }
  }

  /// 加载Base64编码图片
  static Future<ui.Image?> _loadBase64Image(String dataUrl) async {
    try {
      // data:image/png;base64,iVBORw0KGgo...
      final base64String = dataUrl.split(',')[1];
      final bytes = const Base64Decoder().convert(base64String);
      return await _decodeImage(bytes);
    } catch (e) {
      debugPrint('❌ 加载Base64图片失败, 错误: $e');
      return null;
    }
  }

  /// 解码图片字节数据
  static Future<ui.Image?> _decodeImage(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (e) {
      debugPrint('❌ 解码图片失败, 错误: $e');
      return null;
    }
  }
}

/// Base64解码器
class Base64Decoder {
  const Base64Decoder();

  Uint8List convert(String input) {
    // 移除可能的空白字符
    input = input.replaceAll(RegExp(r'\s'), '');

    // Base64字符表
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    final bytes = <int>[];

    // 处理每4个字符为一组
    for (int i = 0; i < input.length; i += 4) {
      int n = 0;
      int count = 0;

      for (int j = 0; j < 4; j++) {
        if (i + j >= input.length) break;

        final c = input[i + j];
        if (c == '=') break;

        final index = chars.indexOf(c);
        if (index == -1) continue;

        n = (n << 6) | index;
        count++;
      }

      if (count >= 2) bytes.add((n >> 16) & 0xFF);
      if (count >= 3) bytes.add((n >> 8) & 0xFF);
      if (count >= 4) bytes.add(n & 0xFF);
    }

    return Uint8List.fromList(bytes);
  }
}
