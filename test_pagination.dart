import 'package:flutter/material.dart';

void main() {
  // 测试：TextPainter 和 Text() widget 的差异

  final textStyle = TextStyle(
    fontSize: 18.0,
    height: 1.8,
    letterSpacing: 0.2,
  );

  final testText = '这是一行测试文本，包含一些中文字符。';
  final width = 300.0;

  // 使用 TextPainter 测量
  final textPainter = TextPainter(
    text: TextSpan(text: testText, style: textStyle),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  );
  textPainter.layout(maxWidth: width);

  print('TextPainter:');
  print('  Width: ${textPainter.width}');
  print('  Height: ${textPainter.height}');
  print('  Did exceed: ${textPainter.didExceedMaxLines}');

  // 问题：Text() widget 在运行时的布局可能不同！
  // Text() 使用的是 RenderParagraph，算法可能有细微差异
}
