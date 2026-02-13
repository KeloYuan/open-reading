import 'package:flutter/material.dart';

class PageVisualPalette {
  final Color backgroundStart;
  final Color backgroundMiddle;
  final Color backgroundEnd;
  final Color card;
  final Color cardStrong;
  final Color hero;
  final Color border;
  final Color iconMuted;
  final Color textMuted;

  const PageVisualPalette({
    required this.backgroundStart,
    required this.backgroundMiddle,
    required this.backgroundEnd,
    required this.card,
    required this.cardStrong,
    required this.hero,
    required this.border,
    required this.iconMuted,
    required this.textMuted,
  });
}

class PageStyleHelper {
  static PageVisualPalette palette(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return PageVisualPalette(
      backgroundStart: Color.alphaBlend(
        scheme.primary.withValues(alpha: isDark ? 0.17 : 0.09),
        scheme.surface,
      ),
      backgroundMiddle: Color.alphaBlend(
        scheme.secondary.withValues(alpha: isDark ? 0.13 : 0.06),
        scheme.surface,
      ),
      backgroundEnd: scheme.surface,
      card: scheme.surface.withValues(alpha: isDark ? 0.78 : 0.88),
      cardStrong: scheme.surface.withValues(alpha: isDark ? 0.84 : 0.93),
      hero: Color.alphaBlend(
        scheme.primary.withValues(alpha: isDark ? 0.24 : 0.14),
        scheme.primaryContainer.withValues(alpha: isDark ? 0.40 : 0.56),
      ),
      border: scheme.outline.withValues(alpha: isDark ? 0.24 : 0.12),
      iconMuted: scheme.onSurface.withValues(alpha: isDark ? 0.82 : 0.74),
      textMuted: scheme.onSurfaceVariant.withValues(alpha: isDark ? 0.84 : 0.72),
    );
  }

  static LinearGradient backgroundGradient(BuildContext context) {
    final p = palette(context);
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomCenter,
      colors: [p.backgroundStart, p.backgroundMiddle, p.backgroundEnd],
    );
  }
}
