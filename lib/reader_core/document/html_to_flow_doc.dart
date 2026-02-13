import 'package:flutter/material.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import 'flow_doc.dart';

class HtmlToFlowDocConverter {
  int _blockSeed = 0;

  FlowDoc convert(String htmlContent) {
    final document = html_parser.parse(htmlContent);
    final root = document.body ?? document.documentElement;
    if (root == null) {
      return const FlowDoc(blocks: []);
    }

    final blocks = <Block>[];
    for (final node in root.nodes) {
      _visitBlockNode(node, blocks, const BlockStyle());
    }

    return FlowDoc(blocks: blocks);
  }

  void _visitBlockNode(
      dom.Node node, List<Block> blocks, BlockStyle inherited) {
    if (node is dom.Text) {
      final text = node.text.trim();
      if (text.isNotEmpty) {
        blocks.add(
          ParagraphBlock(
            id: _nextId('p'),
            inlines: [TextInline(text)],
            style: inherited,
          ),
        );
      }
      return;
    }

    if (node is! dom.Element) {
      return;
    }

    final tag = node.localName?.toLowerCase() ?? '';
    final style = inherited.merge(_parseCss(node.attributes['style']));

    if (tag == 'br') {
      blocks.add(SpaceBlock(id: _nextId('space'), height: 8, style: style));
      return;
    }

    if (tag == 'img') {
      blocks.add(
        ImageBlock(
          id: _nextId('img'),
          src: node.attributes['src'] ?? '',
          alt: node.attributes['alt'],
          width: _parseDouble(node.attributes['width']),
          height: _parseDouble(node.attributes['height']),
          style: style,
        ),
      );
      return;
    }

    if (tag == 'p') {
      final inlines = _collectInlines(node, bold: false, italic: false);
      blocks.add(
          ParagraphBlock(id: _nextId('p'), inlines: inlines, style: style));
      return;
    }

    final headingMatch = RegExp(r'^h([1-6])$').firstMatch(tag);
    if (headingMatch != null) {
      final level = int.parse(headingMatch.group(1)!);
      final inlines = _collectInlines(node, bold: true, italic: false);
      blocks.add(
        HeadingBlock(
          id: _nextId('h$level'),
          level: level,
          inlines: inlines,
          style: style,
        ),
      );
      return;
    }

    for (final child in node.nodes) {
      _visitBlockNode(child, blocks, style);
    }
  }

  List<InlineNode> _collectInlines(
    dom.Node root, {
    required bool bold,
    required bool italic,
    String? href,
  }) {
    final result = <InlineNode>[];

    void walk(dom.Node node,
        {required bool currentBold,
        required bool currentItalic,
        String? currentHref}) {
      if (node is dom.Text) {
        final text = node.text;
        if (text.isNotEmpty) {
          result.add(
            TextInline(
              text,
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
      if (name == 'br') {
        result.add(const TextInline('\n'));
        return;
      }
      if (name == 'img') {
        return;
      }

      final localCss = _parseCss(node.attributes['style']);
      final nextBold = currentBold ||
          name == 'strong' ||
          localCss.fontWeight == FontWeight.bold ||
          localCss.fontWeight == FontWeight.w700;
      final nextItalic = currentItalic ||
          name == 'em' ||
          localCss.fontStyle == FontStyle.italic;
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
    if (result.isEmpty) {
      return [const TextInline('')];
    }
    return result;
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
    if (weightValue == 'bold' || weightValue == '700') {
      fontWeight = FontWeight.bold;
    }

    FontStyle? fontStyle;
    if (map['font-style'] == 'italic') {
      fontStyle = FontStyle.italic;
    }

    final lineHeight = _parseCssSize(map['line-height']);
    final textIndent = _parseCssSize(map['text-indent']);
    final marginValue = _parseCssSize(map['margin']);

    EdgeInsets? margin;
    if (marginValue != null) {
      margin = EdgeInsets.all(marginValue);
    }

    return BlockStyle(
      textAlign: textAlign,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      lineHeight: lineHeight,
      textIndent: textIndent,
      margin: margin,
    );
  }

  double? _parseCssSize(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    final normalized = value.replaceAll('px', '').trim();
    return double.tryParse(normalized);
  }

  double? _parseDouble(String? value) {
    if (value == null || value.isEmpty) return null;
    return double.tryParse(value.replaceAll('px', '').trim());
  }

  String _nextId(String prefix) {
    _blockSeed += 1;
    return '$prefix-$_blockSeed';
  }
}
