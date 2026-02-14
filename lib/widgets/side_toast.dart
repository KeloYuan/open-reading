import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

OverlayEntry? _activeSideToastEntry;

void showSideToast(
  BuildContext context,
  String message, {
  Color? backgroundColor,
  Color? textColor,
  Duration duration = const Duration(seconds: 3),
  IconData? icon,
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;

  _activeSideToastEntry?.remove();
  _activeSideToastEntry = null;

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => _SideToast(
      message: message,
      backgroundColor: backgroundColor,
      textColor: textColor,
      duration: duration,
      icon: icon,
      onDismissed: () {
        if (identical(_activeSideToastEntry, entry)) {
          _activeSideToastEntry = null;
        }
        entry.remove();
      },
    ),
  );
  _activeSideToastEntry = entry;
  overlay.insert(entry);
}

class _SideToast extends StatefulWidget {
  final String message;
  final Color? backgroundColor;
  final Color? textColor;
  final Duration duration;
  final IconData? icon;
  final VoidCallback onDismissed;

  const _SideToast({
    required this.message,
    required this.backgroundColor,
    required this.textColor,
    required this.duration,
    required this.icon,
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
  Timer? _autoDismissTimer;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      reverseDuration: const Duration(milliseconds: 180),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.18),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeIn,
    );
    _controller.forward();
    if (widget.duration > Duration.zero) {
      _autoDismissTimer = Timer(widget.duration, _dismissWithAnimation);
    }
  }

  Future<void> _dismissWithAnimation() async {
    if (_dismissed) return;
    _dismissed = true;
    _autoDismissTimer?.cancel();
    if (mounted) {
      await _controller.reverse();
    }
    widget.onDismissed();
  }

  void _dismissImmediately() {
    if (_dismissed) return;
    _dismissed = true;
    _autoDismissTimer?.cancel();
    widget.onDismissed();
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final topInset = MediaQuery.of(context).padding.top;
    final background =
        widget.backgroundColor ?? scheme.surface.withValues(alpha: 0.82);
    final foreground = widget.textColor ?? scheme.onSurface;
    final icon = widget.icon ?? Icons.notifications_rounded;

    return Positioned(
      top: topInset + 10,
      left: 12,
      right: 12,
      child: Align(
        alignment: Alignment.topCenter,
        child: Dismissible(
          key: UniqueKey(),
          direction: DismissDirection.up,
          onDismissed: (_) => _dismissImmediately(),
          child: SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Material(
                  color: Colors.transparent,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                      child: Container(
                        decoration: BoxDecoration(
                          color: background,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.22),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.14),
                              blurRadius: 24,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                          child: Row(
                            children: [
                              Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: scheme.primary.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child:
                                    Icon(icon, size: 17, color: scheme.primary),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  widget.message,
                                  style: TextStyle(
                                    color: foreground,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    height: 1.25,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.close_rounded,
                                  size: 18,
                                  color: foreground.withValues(alpha: 0.75),
                                ),
                                splashRadius: 18,
                                onPressed: _dismissWithAnimation,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
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
