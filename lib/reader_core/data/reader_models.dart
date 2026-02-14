import 'package:flutter/material.dart';

@immutable
class Book {
  final String id;
  final String title;
  final String author;
  final String filePath;
  final String format;

  const Book({
    required this.id,
    required this.title,
    required this.author,
    required this.filePath,
    required this.format,
  });
}

@immutable
class Chapter {
  final String id;
  final String bookId;
  final String title;
  final int order;
  final String content;

  const Chapter({
    required this.id,
    required this.bookId,
    required this.title,
    required this.order,
    required this.content,
  });
}

@immutable
class TocItem {
  final String chapterId;
  final String title;
  final int level;
  final int anchorOffset;

  const TocItem({
    required this.chapterId,
    required this.title,
    required this.level,
    required this.anchorOffset,
  });
}

@immutable
class ReaderStyle {
  final String? fontFamily;
  final double fontSize;
  final FontWeight fontWeight;
  final bool italic;
  final double lineHeight;
  final double letterSpacing;
  final TextAlign textAlign;
  final Locale? locale;

  const ReaderStyle({
    this.fontFamily,
    this.fontSize = 18,
    this.fontWeight = FontWeight.w400,
    this.italic = false,
    this.lineHeight = 1.7,
    this.letterSpacing = 0,
    this.textAlign = TextAlign.start,
    this.locale,
  });

  TextStyle toTextStyle({Color? color}) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: italic ? FontStyle.italic : FontStyle.normal,
      height: lineHeight,
      letterSpacing: letterSpacing,
      color: color,
      locale: locale,
    );
  }

  ReaderStyle copyWith({
    String? fontFamily,
    bool clearFontFamily = false,
    double? fontSize,
    FontWeight? fontWeight,
    bool? italic,
    double? lineHeight,
    double? letterSpacing,
    TextAlign? textAlign,
    Locale? locale,
  }) {
    return ReaderStyle(
      fontFamily: clearFontFamily ? null : (fontFamily ?? this.fontFamily),
      fontSize: fontSize ?? this.fontSize,
      fontWeight: fontWeight ?? this.fontWeight,
      italic: italic ?? this.italic,
      lineHeight: lineHeight ?? this.lineHeight,
      letterSpacing: letterSpacing ?? this.letterSpacing,
      textAlign: textAlign ?? this.textAlign,
      locale: locale ?? this.locale,
    );
  }

  String cacheSignature() {
    return [
      fontFamily ?? '',
      fontSize.toStringAsFixed(2),
      fontWeight.value.toString(),
      italic ? '1' : '0',
      lineHeight.toStringAsFixed(3),
      letterSpacing.toStringAsFixed(3),
      textAlign.index.toString(),
      locale?.toLanguageTag() ?? '',
    ].join('|');
  }
}

@immutable
class PageLayout {
  final double usableWidth;
  final double usableHeight;
  final EdgeInsets padding;
  final int columns;
  final double gutter;

  const PageLayout({
    required this.usableWidth,
    required this.usableHeight,
    required this.padding,
    this.columns = 1,
    this.gutter = 24,
  });

  PageLayout copyWith({
    double? usableWidth,
    double? usableHeight,
    EdgeInsets? padding,
    int? columns,
    double? gutter,
  }) {
    return PageLayout(
      usableWidth: usableWidth ?? this.usableWidth,
      usableHeight: usableHeight ?? this.usableHeight,
      padding: padding ?? this.padding,
      columns: columns ?? this.columns,
      gutter: gutter ?? this.gutter,
    );
  }

  String cacheSignature() {
    return [
      usableWidth.toStringAsFixed(2),
      usableHeight.toStringAsFixed(2),
      padding.left.toStringAsFixed(1),
      padding.top.toStringAsFixed(1),
      padding.right.toStringAsFixed(1),
      padding.bottom.toStringAsFixed(1),
      columns.toString(),
      gutter.toStringAsFixed(1),
    ].join('|');
  }
}

@immutable
class Annotation {
  final String id;
  final String bookId;
  final String chapterId;
  final int startOffset;
  final int endOffset;
  final Color color;
  final String? noteText;
  final DateTime createdAt;

  const Annotation({
    required this.id,
    required this.bookId,
    required this.chapterId,
    required this.startOffset,
    required this.endOffset,
    required this.color,
    required this.createdAt,
    this.noteText,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'book_id': bookId,
      'chapter_id': chapterId,
      'start_offset': startOffset,
      'end_offset': endOffset,
      'color': color.toARGB32(),
      'note_text': noteText,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory Annotation.fromMap(Map<String, dynamic> map) {
    return Annotation(
      id: map['id'] as String,
      bookId: map['book_id'] as String,
      chapterId: map['chapter_id'] as String,
      startOffset: map['start_offset'] as int,
      endOffset: map['end_offset'] as int,
      color: Color(map['color'] as int),
      noteText: map['note_text'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }
}

@immutable
class ReadingPosition {
  final String chapterId;
  final int anchorOffset;

  const ReadingPosition({
    required this.chapterId,
    required this.anchorOffset,
  });

  Map<String, dynamic> toMap(String bookId) {
    return {
      'book_id': bookId,
      'chapter_id': chapterId,
      'anchor_offset': anchorOffset,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    };
  }

  factory ReadingPosition.fromMap(Map<String, dynamic> map) {
    return ReadingPosition(
      chapterId: map['chapter_id'] as String,
      anchorOffset: map['anchor_offset'] as int,
    );
  }
}
