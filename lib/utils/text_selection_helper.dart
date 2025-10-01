import 'package:flutter/material.dart';

/// 文本选择辅助类
class TextSelectionHelper {
  /// 检测长按手势并处理文本选择
  static void handleLongPress(
    BuildContext context,
    String pageText,
    Offset position,
    Function(String selectedText, Offset position) onTextSelected,
  ) {
    // 简化的文本选择实现
    // 在实际应用中，这里需要更复杂的文本选择逻辑
    
    // 模拟选择一个词或句子
    final words = pageText.split(' ');
    if (words.isNotEmpty) {
      // 简单选择第一个词作为示例
      final selectedText = words.first.length > 10 
          ? words.first.substring(0, 10)
          : words.first;
      
      onTextSelected(selectedText, position);
    }
  }
  
  /// 计算文本在页面中的位置
  static Offset calculateTextPosition(
    String text,
    String searchText,
    Size pageSize,
    TextStyle textStyle,
  ) {
    // 简化的位置计算
    return Offset(pageSize.width * 0.5, pageSize.height * 0.3);
  }
}