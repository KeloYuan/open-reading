// 文件说明：HTML 到 FlowDoc 的转换器，把 HTML 结构归一化到阅读文档模型。
// 技术要点：ReaderCore、HTML 解析、Flutter。

import 'package:flutter/material.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import 'flow_doc.dart';

class HtmlToFlowDocConverter {
  static final RegExp _multiWhitespace = RegExp(r'\s+');
  int _blockSeed = 0;

  FlowDoc convert(
    String htmlContent, {
    String? stylesheetText,
  }) {
    final document = html_parser.parse(htmlContent);
    final resolver = _CssStyleResolver(parseCss: _parseCss);

    resolver.addStylesheet(stylesheetText);
    for (final styleElement in document.querySelectorAll('style')) {
      resolver.addStylesheet(styleElement.text);
    }

    final root = document.body ?? document.documentElement;
    if (root == null) {
      return const FlowDoc(blocks: []);
    }

    final blocks = <Block>[];
    for (final node in root.nodes) {
      _visitBlockNode(node, blocks, const BlockStyle(), resolver);
    }

    return FlowDoc(blocks: blocks);
  }

  void _visitBlockNode(
    dom.Node node,
    List<Block> blocks,
    BlockStyle inherited,
    _CssStyleResolver resolver,
  ) {
    if (node is dom.Text) {
      final text = _normalizeInlineText(node.text);
      if (text.trim().isNotEmpty) {
        blocks.add(
          ParagraphBlock(
            id: _nextId('p'),
            inlines: [TextInline(text.trim())],
            style: _paragraphStyle(inherited),
          ),
        );
      }
      return;
    }

    if (node is! dom.Element) {
      return;
    }

    final tag = node.localName?.toLowerCase() ?? '';
    if (_ignoredTags.contains(tag)) {
      return;
    }

    final style = inherited
        .merge(resolver.styleFor(node))
        .merge(_parseCss(node.attributes['style']))
        .merge(_parseLegacyAttributes(node));

    if (tag == 'br') {
      blocks.add(SpaceBlock(id: _nextId('space'), height: 8, style: style));
      return;
    }

    if (tag == 'img' || tag == 'image') {
      final src = _resolveImageSrc(node);
      if (src.isNotEmpty) {
        blocks.add(
          ImageBlock(
            id: _nextId('img'),
            src: src,
            alt: node.attributes['alt'],
            width: _parseDouble(node.attributes['width']),
            height: _parseDouble(node.attributes['height']),
            style: style,
          ),
        );
      }
      return;
    }

    if (tag == 'p') {
      final inlines = _collectInlines(
        node,
        bold: false,
        italic: false,
        resolver: resolver,
      );
      if (_hasInlineContent(inlines)) {
        blocks.add(
          ParagraphBlock(
            id: _nextId('p'),
            inlines: inlines,
            style: _paragraphStyle(style),
          ),
        );
      }
      return;
    }

    final headingMatch = RegExp(r'^h([1-6])$').firstMatch(tag);
    if (headingMatch != null) {
      final level = int.parse(headingMatch.group(1)!);
      final inlines = _collectInlines(
        node,
        bold: true,
        italic: false,
        resolver: resolver,
      );
      if (_hasInlineContent(inlines)) {
        blocks.add(
          HeadingBlock(
            id: _nextId('h$level'),
            level: level,
            inlines: inlines,
            style: _headingStyle(level, style),
          ),
        );
      }
      return;
    }

    if (tag == 'blockquote') {
      final inlines = _collectInlines(
        node,
        bold: false,
        italic: false,
        resolver: resolver,
      );
      if (_hasInlineContent(inlines)) {
        blocks.add(
          ParagraphBlock(
            id: _nextId('quote'),
            inlines: inlines,
            style: _quoteStyle(style),
          ),
        );
      }
      return;
    }

    if (tag == 'ul' || tag == 'ol') {
      _visitList(node, blocks, style, resolver, ordered: tag == 'ol');
      return;
    }

    if (tag == 'li') {
      final inlines = _collectInlines(
        node,
        bold: false,
        italic: false,
        resolver: resolver,
        skipNestedLists: true,
      );
      if (_hasInlineContent(inlines)) {
        blocks.add(
          ParagraphBlock(
            id: _nextId('li'),
            inlines: [const TextInline('• '), ...inlines],
            style: _listItemStyle(style),
          ),
        );
      }
      for (final child in node.children) {
        final childTag = child.localName?.toLowerCase();
        if (childTag == 'ul' || childTag == 'ol') {
          _visitList(
            child,
            blocks,
            _listItemStyle(style),
            resolver,
            ordered: childTag == 'ol',
          );
        }
      }
      return;
    }

    if (tag == 'hr') {
      blocks.add(
        SpaceBlock(
          id: _nextId('hr-space'),
          height: 14,
          style:
              style.merge(const BlockStyle(margin: EdgeInsets.only(bottom: 8))),
        ),
      );
      return;
    }

    if (_textContainerTags.contains(tag) && !_containsBlockDescendant(node)) {
      final inlines = _collectInlines(
        node,
        bold: false,
        italic: false,
        resolver: resolver,
      );
      if (_hasInlineContent(inlines)) {
        blocks.add(
          ParagraphBlock(
            id: _nextId('p'),
            inlines: inlines,
            style: _paragraphStyle(style),
          ),
        );
      }
      return;
    }

    for (final child in node.nodes) {
      _visitBlockNode(child, blocks, style, resolver);
    }
  }

  void _visitList(
    dom.Element list,
    List<Block> blocks,
    BlockStyle inherited,
    _CssStyleResolver resolver, {
    required bool ordered,
  }) {
    var order = 0;
    for (final child in list.children) {
      final tag = child.localName?.toLowerCase() ?? '';
      if (tag != 'li') {
        _visitBlockNode(child, blocks, inherited, resolver);
        continue;
      }

      order += 1;
      final style = inherited
          .merge(resolver.styleFor(child))
          .merge(_parseCss(child.attributes['style']))
          .merge(_parseLegacyAttributes(child));
      final inlines = _collectInlines(
        child,
        bold: false,
        italic: false,
        resolver: resolver,
        skipNestedLists: true,
      );
      if (_hasInlineContent(inlines)) {
        final prefix = ordered ? '$order. ' : '• ';
        blocks.add(
          ParagraphBlock(
            id: _nextId(ordered ? 'ol' : 'ul'),
            inlines: [TextInline(prefix), ...inlines],
            style: _listItemStyle(style),
          ),
        );
      }

      for (final nested in child.children) {
        final nestedTag = nested.localName?.toLowerCase();
        if (nestedTag == 'ul' || nestedTag == 'ol') {
          _visitList(
            nested,
            blocks,
            _listItemStyle(style),
            resolver,
            ordered: nestedTag == 'ol',
          );
        }
      }
    }
  }

  List<InlineNode> _collectInlines(
    dom.Node root, {
    required bool bold,
    required bool italic,
    required _CssStyleResolver resolver,
    String? href,
    bool skipNestedLists = false,
  }) {
    final result = <InlineNode>[];

    void walk(
      dom.Node node, {
      required bool currentBold,
      required bool currentItalic,
      String? currentHref,
    }) {
      if (node is dom.Text) {
        final normalized = _normalizeInlineText(node.text);
        if (normalized.trim().isNotEmpty) {
          result.add(
            TextInline(
              normalized,
              bold: currentBold,
              italic: currentItalic,
              href: currentHref,
            ),
          );
        }
        return;
      }

      if (node is! dom.Element) {
        return;
      }

      final name = node.localName?.toLowerCase() ?? '';
      if (_ignoredTags.contains(name)) {
        return;
      }
      if (skipNestedLists && (name == 'ul' || name == 'ol')) {
        return;
      }
      if (name == 'br') {
        result.add(const TextInline('\n'));
        return;
      }
      if (name == 'img' || name == 'image') {
        return;
      }

      final css = resolver
          .styleFor(node)
          .merge(_parseCss(node.attributes['style']))
          .merge(_parseLegacyAttributes(node));
      final nextBold = currentBold ||
          name == 'strong' ||
          name == 'b' ||
          css.fontWeight == FontWeight.bold ||
          css.fontWeight == FontWeight.w700;
      final nextItalic = currentItalic ||
          name == 'em' ||
          name == 'i' ||
          css.fontStyle == FontStyle.italic;
      final nextHref = name == 'a' ? node.attributes['href'] : currentHref;

      for (final child in node.nodes) {
        walk(
          child,
          currentBold: nextBold,
          currentItalic: nextItalic,
          currentHref: nextHref,
        );
      }
    }

    walk(root, currentBold: bold, currentItalic: italic, currentHref: href);
    return _sanitizeInlines(result);
  }

  List<InlineNode> _sanitizeInlines(List<InlineNode> inlines) {
    if (inlines.isEmpty) {
      return [const TextInline('')];
    }

    final merged = <TextInline>[];
    for (final inline in inlines) {
      if (inline is! TextInline) {
        continue;
      }
      if (merged.isEmpty) {
        merged.add(inline);
        continue;
      }
      final last = merged.last;
      final shouldMerge = last.bold == inline.bold &&
          last.italic == inline.italic &&
          last.href == inline.href;
      if (shouldMerge) {
        merged[merged.length - 1] = TextInline(
          '${last.text}${inline.text}',
          bold: last.bold,
          italic: last.italic,
          href: last.href,
        );
      } else {
        merged.add(inline);
      }
    }

    if (merged.isEmpty) {
      return [const TextInline('')];
    }

    final sanitized = <InlineNode>[];
    for (var i = 0; i < merged.length; i++) {
      var text = merged[i].text;
      if (i == 0) {
        text = text.replaceFirst(RegExp(r'^\s+'), '');
      }
      if (i == merged.length - 1) {
        text = text.replaceFirst(RegExp(r'\s+$'), '');
      }
      if (text.isEmpty) {
        continue;
      }
      sanitized.add(
        TextInline(
          text,
          bold: merged[i].bold,
          italic: merged[i].italic,
          href: merged[i].href,
        ),
      );
    }

    return sanitized.isEmpty ? [const TextInline('')] : sanitized;
  }

  bool _hasInlineContent(List<InlineNode> inlines) {
    for (final inline in inlines) {
      if (inline.text.trim().isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  bool _containsBlockDescendant(dom.Element element) {
    for (final child in element.children) {
      final tag = child.localName?.toLowerCase();
      if (tag != null && _blockLevelTags.contains(tag)) {
        return true;
      }
      if (_containsBlockDescendant(child)) {
        return true;
      }
    }
    return false;
  }

  BlockStyle _paragraphStyle(BlockStyle base) {
    return base.merge(
      const BlockStyle(
        margin: EdgeInsets.only(bottom: 8),
      ),
    );
  }

  BlockStyle _headingStyle(int level, BlockStyle base) {
    final scale = switch (level) {
      1 => 1.62,
      2 => 1.46,
      3 => 1.32,
      4 => 1.2,
      5 => 1.1,
      _ => 1.04,
    };
    final spacing = switch (level) {
      1 => 16.0,
      2 => 14.0,
      3 => 12.0,
      _ => 10.0,
    };
    return base.merge(
      BlockStyle(
        fontWeight: FontWeight.w700,
        fontSizeScale: scale,
        lineHeight: base.lineHeight ?? 1.35,
        margin: EdgeInsets.only(bottom: spacing),
      ),
    );
  }

  BlockStyle _quoteStyle(BlockStyle base) {
    return base.merge(
      const BlockStyle(
        fontStyle: FontStyle.italic,
        fontSizeScale: 0.96,
        lineHeight: 1.72,
        margin: EdgeInsets.only(bottom: 10),
      ),
    );
  }

  BlockStyle _listItemStyle(BlockStyle base) {
    return base.merge(
      const BlockStyle(
        lineHeight: 1.65,
        margin: EdgeInsets.only(bottom: 6),
      ),
    );
  }

  BlockStyle _parseLegacyAttributes(dom.Element element) {
    final align = element.attributes['align']?.toLowerCase().trim();
    TextAlign? textAlign;
    switch (align) {
      case 'left':
      case 'start':
        textAlign = TextAlign.start;
        break;
      case 'right':
      case 'end':
        textAlign = TextAlign.end;
        break;
      case 'center':
        textAlign = TextAlign.center;
        break;
      case 'justify':
        textAlign = TextAlign.justify;
        break;
      default:
        textAlign = null;
    }

    if (textAlign == null) {
      return const BlockStyle();
    }
    return BlockStyle(textAlign: textAlign);
  }

  BlockStyle _parseCss(String? cssText) {
    if (cssText == null || cssText.trim().isEmpty) {
      return const BlockStyle();
    }

    final map = <String, String>{};
    for (final pair in cssText.split(';')) {
      final idx = pair.indexOf(':');
      if (idx <= 0) continue;
      final key = pair.substring(0, idx).trim().toLowerCase();
      final value = pair.substring(idx + 1).trim().toLowerCase();
      if (key.isEmpty || value.isEmpty) {
        continue;
      }
      map[key] = value;
    }

    TextAlign? textAlign;
    final alignValue = map['text-align'];
    switch (alignValue) {
      case 'left':
      case 'start':
        textAlign = TextAlign.start;
        break;
      case 'right':
      case 'end':
        textAlign = TextAlign.end;
        break;
      case 'center':
        textAlign = TextAlign.center;
        break;
      case 'justify':
        textAlign = TextAlign.justify;
        break;
      default:
        break;
    }

    FontWeight? fontWeight;
    final weightValue = map['font-weight'];
    if (weightValue == 'bold') {
      fontWeight = FontWeight.bold;
    } else if (weightValue != null) {
      final numericWeight = int.tryParse(weightValue);
      if (numericWeight != null && numericWeight >= 600) {
        fontWeight = FontWeight.bold;
      }
    }

    FontStyle? fontStyle;
    final fontStyleValue = map['font-style'];
    if (fontStyleValue == 'italic' || fontStyleValue == 'oblique') {
      fontStyle = FontStyle.italic;
    }

    final textColor = _parseCssColor(map['color']);
    final lineHeight = _parseLineHeight(map['line-height']);
    final textIndent = _parseCssSize(map['text-indent']);
    final fontSizeScale = _parseFontSizeScale(map['font-size']);
    final letterSpacing = _parseLetterSpacing(map['letter-spacing']);
    final margin = _parseMargin(map);

    return BlockStyle(
      textAlign: textAlign,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      textColor: textColor,
      fontSizeScale: fontSizeScale,
      letterSpacing: letterSpacing,
      lineHeight: lineHeight,
      textIndent: textIndent,
      margin: margin,
    );
  }

  EdgeInsets? _parseMargin(Map<String, String> map) {
    final shorthand = map['margin'];
    var top = 0.0;
    var right = 0.0;
    var bottom = 0.0;
    var left = 0.0;
    var hasAny = false;

    if (shorthand != null && shorthand.trim().isNotEmpty) {
      final values = shorthand
          .split(RegExp(r'\s+'))
          .where((part) => part.trim().isNotEmpty)
          .toList();
      final parsed = values.map(_parseCssSize).toList();
      if (parsed.isNotEmpty && parsed.every((v) => v != null)) {
        hasAny = true;
        if (parsed.length == 1) {
          top = right = bottom = left = parsed.first!;
        } else if (parsed.length == 2) {
          top = bottom = parsed[0]!;
          right = left = parsed[1]!;
        } else if (parsed.length == 3) {
          top = parsed[0]!;
          right = left = parsed[1]!;
          bottom = parsed[2]!;
        } else {
          top = parsed[0]!;
          right = parsed[1]!;
          bottom = parsed[2]!;
          left = parsed[3]!;
        }
      }
    }

    final marginTop = _parseCssSize(map['margin-top']);
    final marginRight = _parseCssSize(map['margin-right']);
    final marginBottom = _parseCssSize(map['margin-bottom']);
    final marginLeft = _parseCssSize(map['margin-left']);

    if (marginTop != null) {
      top = marginTop;
      hasAny = true;
    }
    if (marginRight != null) {
      right = marginRight;
      hasAny = true;
    }
    if (marginBottom != null) {
      bottom = marginBottom;
      hasAny = true;
    }
    if (marginLeft != null) {
      left = marginLeft;
      hasAny = true;
    }

    if (!hasAny) {
      return null;
    }

    return EdgeInsets.fromLTRB(
      left.clamp(0.0, 28.0),
      top.clamp(0.0, 28.0),
      right.clamp(0.0, 28.0),
      bottom.clamp(0.0, 28.0),
    );
  }

  Color? _parseCssColor(String? rawColor) {
    if (rawColor == null || rawColor.trim().isEmpty) {
      return null;
    }
    final value = rawColor.trim().toLowerCase();
    if (_namedColors.containsKey(value)) {
      return _namedColors[value];
    }
    if (value.startsWith('#')) {
      final hex = value.substring(1);
      if (hex.length == 3) {
        final r = hex[0];
        final g = hex[1];
        final b = hex[2];
        final parsed = int.tryParse('ff$r$r$g$g$b$b', radix: 16);
        return parsed == null ? null : Color(parsed);
      }
      if (hex.length == 6) {
        final parsed = int.tryParse('ff$hex', radix: 16);
        return parsed == null ? null : Color(parsed);
      }
      if (hex.length == 8) {
        final parsed = int.tryParse(hex, radix: 16);
        return parsed == null ? null : Color(parsed);
      }
      return null;
    }

    final rgb = RegExp(
      r'^rgba?\(([^)]+)\)$',
      caseSensitive: false,
    ).firstMatch(value);
    if (rgb != null) {
      final parts = rgb.group(1)!.split(',').map((e) => e.trim()).toList();
      if (parts.length < 3) {
        return null;
      }
      final r = int.tryParse(parts[0]);
      final g = int.tryParse(parts[1]);
      final b = int.tryParse(parts[2]);
      if (r == null || g == null || b == null) {
        return null;
      }
      final alpha = parts.length >= 4 ? double.tryParse(parts[3]) ?? 1.0 : 1.0;
      final a = (alpha.clamp(0.0, 1.0) * 255).round();
      return Color.fromARGB(
        a,
        r.clamp(0, 255),
        g.clamp(0, 255),
        b.clamp(0, 255),
      );
    }
    return null;
  }

  double? _parseCssSize(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    final raw = value.trim().toLowerCase();
    if (raw == 'auto') {
      return null;
    }
    if (raw.endsWith('px')) {
      return double.tryParse(raw.substring(0, raw.length - 2).trim());
    }
    if (raw.endsWith('pt')) {
      final pt = double.tryParse(raw.substring(0, raw.length - 2).trim());
      if (pt == null) return null;
      return pt * (96.0 / 72.0);
    }
    if (raw.endsWith('em') || raw.endsWith('rem')) {
      final em = double.tryParse(raw.substring(0, raw.length - 2).trim());
      if (em == null) return null;
      return em * 16.0;
    }
    if (raw.endsWith('%')) {
      final percent = double.tryParse(raw.substring(0, raw.length - 1).trim());
      if (percent == null) return null;
      return (percent / 100.0) * 16.0;
    }
    return double.tryParse(raw);
  }

  double? _parseFontSizeScale(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final raw = value.trim().toLowerCase();
    final keyword = switch (raw) {
      'xx-small' => 0.72,
      'x-small' => 0.8,
      'small' => 0.9,
      'medium' => 1.0,
      'large' => 1.14,
      'x-large' => 1.3,
      'xx-large' => 1.46,
      _ => -1.0,
    };
    if (keyword > 0) {
      return keyword;
    }

    if (raw.endsWith('%')) {
      final percent = double.tryParse(raw.substring(0, raw.length - 1).trim());
      if (percent == null || !percent.isFinite || percent <= 0) {
        return null;
      }
      return (percent / 100.0).clamp(0.72, 2.4).toDouble();
    }
    if (raw.endsWith('em') || raw.endsWith('rem')) {
      final em = double.tryParse(raw.substring(0, raw.length - 2).trim());
      if (em == null || !em.isFinite || em <= 0) {
        return null;
      }
      return em.clamp(0.72, 2.4).toDouble();
    }

    final px = _parseCssSize(raw);
    if (px == null || !px.isFinite || px <= 0) {
      return null;
    }
    return (px / 16.0).clamp(0.72, 2.4).toDouble();
  }

  double? _parseLetterSpacing(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final raw = value.trim().toLowerCase();
    if (raw == 'normal') {
      return null;
    }
    if (raw.endsWith('em') || raw.endsWith('rem')) {
      final em = double.tryParse(raw.substring(0, raw.length - 2).trim());
      if (em == null || !em.isFinite) {
        return null;
      }
      return (em * 16.0).clamp(-0.6, 4.0).toDouble();
    }
    final px = _parseCssSize(raw);
    if (px == null || !px.isFinite) {
      return null;
    }
    return px.clamp(-0.6, 4.0).toDouble();
  }

  double? _parseLineHeight(String? value) {
    if (value == null) {
      return null;
    }
    final raw = value.trim().toLowerCase();
    if (raw.isEmpty || raw == 'normal') {
      return null;
    }
    if (raw.endsWith('%')) {
      final percent = double.tryParse(raw.substring(0, raw.length - 1).trim());
      if (percent == null || !percent.isFinite || percent <= 0) {
        return null;
      }
      return (percent / 100.0).clamp(0.9, 3.0).toDouble();
    }
    if (raw.endsWith('px')) {
      final px = double.tryParse(raw.substring(0, raw.length - 2).trim());
      if (px == null || !px.isFinite || px <= 0) {
        return null;
      }
      return (px / 16.0).clamp(0.9, 3.0).toDouble();
    }
    if (raw.endsWith('em') || raw.endsWith('rem')) {
      final factor = double.tryParse(raw.substring(0, raw.length - 2).trim());
      if (factor == null || !factor.isFinite || factor <= 0) {
        return null;
      }
      return factor.clamp(0.9, 3.0).toDouble();
    }
    final numeric = double.tryParse(raw);
    if (numeric == null || !numeric.isFinite || numeric <= 0) {
      return null;
    }
    if (numeric > 4.0) {
      return (numeric / 16.0).clamp(0.9, 3.0).toDouble();
    }
    return numeric.clamp(0.9, 3.0).toDouble();
  }

  double? _parseDouble(String? value) {
    if (value == null || value.isEmpty) return null;
    return double.tryParse(value.replaceAll('px', '').trim());
  }

  String _normalizeInlineText(String raw) {
    if (raw.isEmpty) {
      return '';
    }
    return raw.replaceAll(_multiWhitespace, ' ');
  }

  String _resolveImageSrc(dom.Element node) {
    final directSrc = node.attributes['src'];
    if (directSrc != null && directSrc.trim().isNotEmpty) {
      return directSrc.trim();
    }

    final href = node.attributes['href'];
    if (href != null && href.trim().isNotEmpty) {
      return href.trim();
    }

    final xlinkHref = node.attributes['xlink:href'];
    if (xlinkHref != null && xlinkHref.trim().isNotEmpty) {
      return xlinkHref.trim();
    }

    for (final entry in node.attributes.entries) {
      final key = entry.key.toString().toLowerCase();
      if (key.endsWith(':href') || key == 'href') {
        final value = entry.value.trim();
        if (value.isNotEmpty) {
          return value;
        }
      }
    }
    return '';
  }

  String _nextId(String prefix) {
    _blockSeed += 1;
    return '$prefix-$_blockSeed';
  }
}

class _CssStyleResolver {
  static final RegExp _ruleRegExp = RegExp(r'([^{}]+)\{([^}]*)\}');

  final BlockStyle Function(String? cssText) parseCss;
  final Map<String, BlockStyle> _tagStyles = <String, BlockStyle>{};
  final Map<String, BlockStyle> _classStyles = <String, BlockStyle>{};
  final Map<String, BlockStyle> _idStyles = <String, BlockStyle>{};
  final Map<String, BlockStyle> _tagClassStyles = <String, BlockStyle>{};

  _CssStyleResolver({required this.parseCss});

  void addStylesheet(String? cssText) {
    if (cssText == null || cssText.trim().isEmpty) {
      return;
    }

    final normalizedCss =
        cssText.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), ' ');
    for (final match in _ruleRegExp.allMatches(normalizedCss)) {
      final selectorText = match.group(1)?.trim() ?? '';
      final declarationText = match.group(2)?.trim() ?? '';
      if (selectorText.isEmpty || declarationText.isEmpty) {
        continue;
      }
      final style = parseCss(declarationText);
      for (final selector in selectorText.split(',')) {
        _registerSimpleSelector(selector.trim(), style);
      }
    }
  }

  BlockStyle styleFor(dom.Element element) {
    final tag = (element.localName ?? '').toLowerCase();
    final id = (element.attributes['id'] ?? '').trim().toLowerCase();
    final classNames = (element.attributes['class'] ?? '')
        .split(RegExp(r'\s+'))
        .map((part) => part.trim().toLowerCase())
        .where((part) => part.isNotEmpty)
        .toList();

    var resolved = const BlockStyle();
    final tagStyle = _tagStyles[tag];
    if (tagStyle != null) {
      resolved = resolved.merge(tagStyle);
    }

    for (final className in classNames) {
      final classStyle = _classStyles[className];
      if (classStyle != null) {
        resolved = resolved.merge(classStyle);
      }
      if (tag.isNotEmpty) {
        final tagClassStyle = _tagClassStyles['$tag.$className'];
        if (tagClassStyle != null) {
          resolved = resolved.merge(tagClassStyle);
        }
      }
    }

    if (id.isNotEmpty) {
      final idStyle = _idStyles[id];
      if (idStyle != null) {
        resolved = resolved.merge(idStyle);
      }
    }

    return resolved;
  }

  void _registerSimpleSelector(String selector, BlockStyle style) {
    if (selector.isEmpty || selector.startsWith('@')) {
      return;
    }

    final normalized = selector.toLowerCase();
    if (_isUnsupportedSelector(normalized)) {
      return;
    }

    if (normalized.startsWith('.')) {
      final className = normalized.substring(1);
      if (_isSimpleIdentifier(className)) {
        _classStyles[className] =
            (_classStyles[className] ?? const BlockStyle()).merge(style);
      }
      return;
    }

    if (normalized.startsWith('#')) {
      final id = normalized.substring(1);
      if (_isSimpleIdentifier(id)) {
        _idStyles[id] = (_idStyles[id] ?? const BlockStyle()).merge(style);
      }
      return;
    }

    final tagClass =
        RegExp(r'^([a-z][a-z0-9_-]*)\.([a-z0-9_-]+)$').firstMatch(normalized);
    if (tagClass != null) {
      final key = '${tagClass.group(1)}.${tagClass.group(2)}';
      _tagClassStyles[key] =
          (_tagClassStyles[key] ?? const BlockStyle()).merge(style);
      return;
    }

    if (RegExp(r'^[a-z][a-z0-9_-]*$').hasMatch(normalized)) {
      _tagStyles[normalized] =
          (_tagStyles[normalized] ?? const BlockStyle()).merge(style);
    }
  }

  bool _isSimpleIdentifier(String value) {
    return RegExp(r'^[a-z0-9_-]+$').hasMatch(value);
  }

  bool _isUnsupportedSelector(String selector) {
    const blockers = <String>[
      ' ',
      '>',
      '+',
      '~',
      '[',
      ':',
      '*',
      '::',
    ];
    for (final blocker in blockers) {
      if (selector.contains(blocker)) {
        return true;
      }
    }
    return false;
  }
}

const Set<String> _ignoredTags = <String>{
  'script',
  'style',
  'noscript',
};

const Set<String> _textContainerTags = <String>{
  'div',
  'section',
  'article',
  'aside',
  'main',
  'span',
  'font',
};

const Set<String> _blockLevelTags = <String>{
  'address',
  'article',
  'aside',
  'blockquote',
  'div',
  'dl',
  'fieldset',
  'figcaption',
  'figure',
  'footer',
  'form',
  'h1',
  'h2',
  'h3',
  'h4',
  'h5',
  'h6',
  'header',
  'hr',
  'li',
  'main',
  'nav',
  'ol',
  'p',
  'pre',
  'section',
  'table',
  'ul',
};

const Map<String, Color> _namedColors = <String, Color>{
  'black': Color(0xFF000000),
  'white': Color(0xFFFFFFFF),
  'red': Color(0xFFFF0000),
  'green': Color(0xFF008000),
  'blue': Color(0xFF0000FF),
  'gray': Color(0xFF808080),
  'grey': Color(0xFF808080),
  'darkgray': Color(0xFFA9A9A9),
  'darkgrey': Color(0xFFA9A9A9),
  'lightgray': Color(0xFFD3D3D3),
  'lightgrey': Color(0xFFD3D3D3),
  'navy': Color(0xFF000080),
  'teal': Color(0xFF008080),
  'olive': Color(0xFF808000),
  'maroon': Color(0xFF800000),
  'purple': Color(0xFF800080),
  'orange': Color(0xFFFFA500),
  'transparent': Color(0x00000000),
};
