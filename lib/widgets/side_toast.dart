import 'package:flutter/material.dart';

void showSideToast(
  BuildContext context,
  String message, {
  Color? backgroundColor,
  Color? textColor,
  Duration duration = const Duration(seconds: 2),
}) {
  final overlay = Overlay.of(context);

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => _SideToast(
      message: message,
      backgroundColor: backgroundColor,
      textColor: textColor,
      duration: duration,
      onDismissed: () => entry.remove(),
    ),
  );
  overlay.insert(entry);
}

class _SideToast extends StatefulWidget {
  final String message;
  final Color? backgroundColor;
  final Color? textColor;
  final Duration duration;
  final VoidCallback onDismissed;

  const _SideToast({
    required this.message,
    required this.backgroundColor,
    required this.textColor,
    required this.duration,
    required this.onDismissed,
  });

  @override
  State<_SideToast> createState() => _SideToastState();
}

class _SideToastState extends State<_SideToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
      reverseDuration: const Duration(milliseconds: 180),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.6, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );
    _controller.forward();
    Future.delayed(widget.duration, () async {
      if (!mounted) return;
      await _controller.reverse();
      if (mounted) {
        widget.onDismissed();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final topInset = MediaQuery.of(context).padding.top;
    final background = widget.backgroundColor ?? scheme.surfaceContainerHigh;
    final foreground = widget.textColor ?? scheme.onSurface;

    return Positioned(
      top: topInset + 16,
      right: 12,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            color: background,
            elevation: 2,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 260),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Text(
                  widget.message,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
