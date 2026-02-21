import 'dart:convert';

class PagePlan {
  final String chapterId;
  final List<Page> pages;
  final String cacheKey;

  const PagePlan({
    required this.chapterId,
    required this.pages,
    required this.cacheKey,
  });

  Map<String, dynamic> toMap() {
    return {
      'chapter_id': chapterId,
      'cache_key': cacheKey,
      'pages': pages.map((e) => e.toMap()).toList(),
    };
  }

  String toJson() => jsonEncode(toMap());

  factory PagePlan.fromMap(Map<String, dynamic> map) {
    return PagePlan(
      chapterId: map['chapter_id'] as String,
      cacheKey: map['cache_key'] as String,
      pages: (map['pages'] as List<dynamic>)
          .map((e) => Page.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }

  factory PagePlan.fromJson(String json) {
    return PagePlan.fromMap(Map<String, dynamic>.from(jsonDecode(json) as Map));
  }
}

class Page {
  final int index;
  final int startOffset;
  final int endOffset;
  final List<Fragment> fragments;

  const Page({
    required this.index,
    required this.startOffset,
    required this.endOffset,
    required this.fragments,
  });

  Map<String, dynamic> toMap() {
    return {
      'index': index,
      'start_offset': startOffset,
      'end_offset': endOffset,
      'fragments': fragments.map((e) => e.toMap()).toList(),
    };
  }

  factory Page.fromMap(Map<String, dynamic> map) {
    return Page(
      index: map['index'] as int,
      startOffset: map['start_offset'] as int,
      endOffset: map['end_offset'] as int,
      fragments: (map['fragments'] as List<dynamic>)
          .map((e) => Fragment.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}

sealed class Fragment {
  final String blockId;

  const Fragment(this.blockId);

  Map<String, dynamic> toMap();

  factory Fragment.fromMap(Map<String, dynamic> map) {
    final type = map['type'] as String;
    return switch (type) {
      'text' => TextFragment.fromMap(map),
      'image' => ImageFragment.fromMap(map),
      'space' => SpaceFragment.fromMap(map),
      _ => throw ArgumentError('Unknown fragment type: $type'),
    };
  }
}

class TextFragment extends Fragment {
  final int start;
  final int end;
  final int globalStart;
  final int globalEnd;
  final double? measuredHeight;

  const TextFragment({
    required String blockId,
    required this.start,
    required this.end,
    required this.globalStart,
    required this.globalEnd,
    this.measuredHeight,
  }) : super(blockId);

  @override
  Map<String, dynamic> toMap() {
    return {
      'type': 'text',
      'block_id': blockId,
      'start': start,
      'end': end,
      'global_start': globalStart,
      'global_end': globalEnd,
      if (measuredHeight != null) 'measured_height': measuredHeight,
    };
  }

  factory TextFragment.fromMap(Map<String, dynamic> map) {
    return TextFragment(
      blockId: map['block_id'] as String,
      start: map['start'] as int,
      end: map['end'] as int,
      globalStart: map['global_start'] as int,
      globalEnd: map['global_end'] as int,
      measuredHeight: map['measured_height'] == null
          ? null
          : (map['measured_height'] as num).toDouble(),
    );
  }
}

class ImageFragment extends Fragment {
  final double? measuredHeight;

  const ImageFragment({
    required String blockId,
    this.measuredHeight,
  }) : super(blockId);

  @override
  Map<String, dynamic> toMap() {
    return {
      'type': 'image',
      'block_id': blockId,
      if (measuredHeight != null) 'measured_height': measuredHeight,
    };
  }

  factory ImageFragment.fromMap(Map<String, dynamic> map) {
    return ImageFragment(
      blockId: map['block_id'] as String,
      measuredHeight: map['measured_height'] == null
          ? null
          : (map['measured_height'] as num).toDouble(),
    );
  }
}

class SpaceFragment extends Fragment {
  final double height;

  const SpaceFragment({required String blockId, required this.height})
      : super(blockId);

  @override
  Map<String, dynamic> toMap() {
    return {
      'type': 'space',
      'block_id': blockId,
      'height': height,
    };
  }

  factory SpaceFragment.fromMap(Map<String, dynamic> map) {
    return SpaceFragment(
      blockId: map['block_id'] as String,
      height: (map['height'] as num).toDouble(),
    );
  }
}
