import 'package:flutter/material.dart';

@immutable
class FlowDoc {
  final List<Block> blocks;

  const FlowDoc({required this.blocks});

  String toPlainText() {
    final buffer = StringBuffer();
    for (final block in blocks) {
      if (block is ParagraphBlock) {
        buffer.write(block.plainText);
      } else if (block is HeadingBlock) {
        buffer.write(block.plainText);
      } else if (block is SpaceBlock) {
        buffer.write('\n');
      }
      buffer.write('\n');
    }
    return buffer.toString();
  }
}

@immutable
class BlockStyle {
  final TextAlign? textAlign;
  final FontWeight? fontWeight;
  final FontStyle? fontStyle;
  final double? lineHeight;
  final double? textIndent;
  final EdgeInsets? margin;

  const BlockStyle({
    this.textAlign,
    this.fontWeight,
    this.fontStyle,
    this.lineHeight,
    this.textIndent,
    this.margin,
  });

  BlockStyle merge(BlockStyle? other) {
    if (other == null) return this;
    return BlockStyle(
      textAlign: other.textAlign ?? textAlign,
      fontWeight: other.fontWeight ?? fontWeight,
      fontStyle: other.fontStyle ?? fontStyle,
      lineHeight: other.lineHeight ?? lineHeight,
      textIndent: other.textIndent ?? textIndent,
      margin: other.margin ?? margin,
    );
  }
}

sealed class Block {
  final String id;
  final BlockStyle style;

  const Block({required this.id, this.style = const BlockStyle()});
}

@immutable
class ParagraphBlock extends Block {
  final List<InlineNode> inlines;

  const ParagraphBlock({
    required super.id,
    required this.inlines,
    super.style,
  });

  String get plainText => inlines.map((e) => e.text).join();
}

@immutable
class HeadingBlock extends Block {
  final int level;
  final List<InlineNode> inlines;

  const HeadingBlock({
    required super.id,
    required this.level,
    required this.inlines,
    super.style,
  });

  String get plainText => inlines.map((e) => e.text).join();
}

@immutable
class ImageBlock extends Block {
  final String src;
  final String? alt;
  final double? width;
  final double? height;

  const ImageBlock({
    required super.id,
    required this.src,
    this.alt,
    this.width,
    this.height,
    super.style,
  });
}

@immutable
class SpaceBlock extends Block {
  final double height;

  const SpaceBlock({
    required super.id,
    required this.height,
    super.style,
  });
}

sealed class InlineNode {
  final String text;

  const InlineNode(this.text);
}

@immutable
class TextInline extends InlineNode {
  final bool bold;
  final bool italic;
  final String? href;

  const TextInline(
    super.text, {
    this.bold = false,
    this.italic = false,
    this.href,
  });
}
