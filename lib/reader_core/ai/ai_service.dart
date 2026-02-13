class AIRequestMeta {
  final String bookId;
  final String chapterId;
  final int? pageIndex;

  const AIRequestMeta({
    required this.bookId,
    required this.chapterId,
    this.pageIndex,
  });
}

abstract class AIService {
  Future<String> askSelection({
    required String selectedText,
    required String contextBefore,
    required String contextAfter,
    required AIRequestMeta meta,
  });

  Future<String> analyzePage({
    required String pageText,
    required AIRequestMeta meta,
  });
}

class MockAIService implements AIService {
  @override
  Future<String> askSelection({
    required String selectedText,
    required String contextBefore,
    required String contextAfter,
    required AIRequestMeta meta,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 450));
    return 'AI(模拟): 你选择的内容是“$selectedText”。\n\n上文: ${_trim(contextBefore)}\n下文: ${_trim(contextAfter)}';
  }

  @override
  Future<String> analyzePage(
      {required String pageText, required AIRequestMeta meta}) async {
    await Future<void>.delayed(const Duration(milliseconds: 450));
    return 'AI(模拟): 本页共 ${pageText.length} 字，建议重点关注段落开头与结尾处的论点。';
  }

  String _trim(String text) {
    if (text.length <= 80) return text;
    return '${text.substring(0, 80)}...';
  }
}
