import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:coinscape/timeline/timeline_controller.dart';

class MobileScrubber extends StatefulWidget {
  final TimelineController controller;
  final double trackWidth;

  const MobileScrubber({Key? key, required this.controller, this.trackWidth = 28}) : super(key: key);

  @override
  _MobileScrubberState createState() => _MobileScrubberState();
}

class _MobileScrubberState extends State<MobileScrubber> with SingleTickerProviderStateMixin {
  bool _active = false;
  String _lastMonthKey = '';
  double? _lastHapticOffset;

  late AnimationController _anim;
  late Animation<double> _thumbWidthAnim;
  late Animation<double> _bubbleScaleAnim;
  late Animation<double> _bubbleFadeAnim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _thumbWidthAnim = Tween<double>(begin: 4.0, end: 12.0).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));
    _bubbleScaleAnim = Tween<double>(begin: 0.88, end: 1.0).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutBack));
    _bubbleFadeAnim = CurvedAnimation(parent: _anim, curve: Curves.easeInOut);

    // Keep animated state in sync when controller's external isActive toggles
    widget.controller.isActive.addListener(_handleExternalActive);
  }

  @override
  void didUpdateWidget(covariant MobileScrubber oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.isActive.removeListener(_handleExternalActive);
      widget.controller.isActive.addListener(_handleExternalActive);
    }
  }

  void _handleExternalActive() {
    // if external wants active visuals, ensure animation is in the correct state
    if (widget.controller.isActive.value) {
      _anim.forward();
    } else if (!_active) {
      _anim.reverse();
    }
  }

  @override
  void dispose() {
    widget.controller.isActive.removeListener(_handleExternalActive);
    _anim.dispose();
    super.dispose();
  }

  void _onDragStart(DragStartDetails d) {
    setState(() => _active = true);
    _anim.forward();
    // seed baseline for haptic gating
    try {
      _lastHapticOffset = widget.controller.scrollController.hasClients ? widget.controller.scrollController.offset : null;
      final cur = widget.controller.currentDate.value;
      _lastMonthKey = _monthKeyFromDateKey(cur);
    } catch (_) {}
  }

  void _onDragUpdate(DragUpdateDetails d, BoxConstraints constraints) {
    final localY = d.localPosition.dy.clamp(0.0, constraints.maxHeight);
    final rel = (localY / constraints.maxHeight).clamp(0.0, 1.0);
    final targetOffset = rel * widget.controller.calculator.totalContentHeight;

    // Respect the existing throttled jump behavior
    widget.controller.jumpToOffsetThrottled(targetOffset);

    // Immediate UI feedback
    final key = widget.controller.calculator.offsetToDate(targetOffset);
    if (widget.controller.currentDate.value != key) widget.controller.currentDate.value = key;

    // Haptic gating: only when month changes or moved beyond threshold
    final monthKey = _monthKeyFromDateKey(key);
    const double hapticPxThreshold = 40.0;
    var shouldHaptic = false;
    if (monthKey != _lastMonthKey && monthKey.isNotEmpty) {
      shouldHaptic = true;
    } else if (_lastHapticOffset == null || (targetOffset - _lastHapticOffset!).abs() >= hapticPxThreshold) {
      shouldHaptic = true;
    }

    if (shouldHaptic) {
      try {
        HapticFeedback.selectionClick();
      } catch (_) {}
      _lastMonthKey = monthKey;
      _lastHapticOffset = targetOffset;
    }
  }

  void _onDragEnd(DragEndDetails d) {
    setState(() => _active = false);
    _anim.reverse();
    _lastMonthKey = '';
    _lastHapticOffset = null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RepaintBoundary(
      child: ValueListenableBuilder<bool>(
        valueListenable: widget.controller.isActive,
        builder: (context, extActive, _) {
          final visible = extActive || _active;

          return IgnorePointer(
            ignoring: !visible,
            child: LayoutBuilder(builder: (context, constraints) {
              final collapsedWidth = 4.0;
              final thumbHeight = 48.0;

              return GestureDetector(
                behavior: HitTestBehavior.translucent,
                onVerticalDragStart: _onDragStart,
                onVerticalDragUpdate: (d) => _onDragUpdate(d, constraints),
                onVerticalDragEnd: _onDragEnd,
                child: Stack(
                  alignment: Alignment.centerRight,
                  children: [
                    // Subtle track line (right aligned)
                    AnimatedOpacity(
                      opacity: visible ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: SizedBox(
                        width: widget.trackWidth,
                        height: constraints.maxHeight,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Container(
                            margin: const EdgeInsets.only(right: 6),
                            width: collapsedWidth,
                            height: constraints.maxHeight,
                            decoration: BoxDecoration(
                              color: theme.brightness == Brightness.dark ? Colors.white24 : Colors.black26,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Thumb with micro-animation
                    Positioned(
                      right: 6,
                      child: AnimatedBuilder(
                        animation: _anim,
                        builder: (context, child) {
                          final w = _thumbWidthAnim.value;
                          final bg = Color.lerp(
                              (theme.brightness == Brightness.dark ? Colors.white24 : Colors.black26), theme.colorScheme.secondary.withOpacity(0.95), _anim.value);

                          return Container(
                            height: thumbHeight,
                            width: w,
                            decoration: BoxDecoration(
                              color: bg,
                              borderRadius: BorderRadius.circular(8.0 * (0.6 + 0.4 * _anim.value)),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(0.12 * _anim.value), blurRadius: 6 * _anim.value, offset: Offset(0, 2 * _anim.value)),
                              ],
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Grip lines (fade in when expanded)
                                Opacity(
                                  opacity: (_anim.value - 0.15).clamp(0.0, 1.0),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: List.generate(3, (i) {
                                      return Container(
                                        width: w * 0.55,
                                        height: 1.2,
                                        margin: const EdgeInsets.symmetric(vertical: 2.0),
                                        decoration: BoxDecoration(
                                          color: theme.brightness == Brightness.dark ? Colors.black.withOpacity(0.45) : Colors.white.withOpacity(0.6),
                                          borderRadius: BorderRadius.circular(1.0),
                                        ),
                                      );
                                    }),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                    // Tooltip bubble (frosted + scale+fade)
                    ValueListenableBuilder<double>(
                      valueListenable: widget.controller.thumbRelative,
                      builder: (context, rel, _) {
                        final bubbleHeight = 48.0;
                        final bubbleTop = (rel * constraints.maxHeight) - (bubbleHeight / 2);
                        final clampedTop = bubbleTop.clamp(8.0, constraints.maxHeight - bubbleHeight - 8.0);

                        return Positioned(
                          top: clampedTop,
                          right: widget.trackWidth + 12,
                          child: ValueListenableBuilder<String>(
                            valueListenable: widget.controller.currentDate,
                            builder: (context, val, __) {
                              final show = visible && val.isNotEmpty;
                              return SizedBox(
                                height: bubbleHeight,
                                child: Offstage(
                                  offstage: !show,
                                  child: ScaleTransition(
                                    scale: _bubbleScaleAnim,
                                    child: FadeTransition(
                                      opacity: _bubbleFadeAnim,
                                      child: _TooltipBubble(label: _formatLabel(val)),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ],
                ),
              );
            }),
          );
        },
      ),
    );
  }

  String _formatLabel(String key) {
    if (key.contains('-')) {
      final parts = key.split('-');
      final y = parts.isNotEmpty ? parts[0] : key;
      final m = parts.length > 1 ? parts[1] : '01';
      return '$y年 ${m.padLeft(2, '0')}月';
    }
    return '$key年';
  }

  String _monthKeyFromDateKey(String key) {
    if (key.contains('-')) {
      final parts = key.split('-');
      final y = parts.isNotEmpty ? parts[0] : key;
      final m = parts.length > 1 ? parts[1] : '01';
      return '$y-${m.padLeft(2, '0')}';
    }
    return key;
  }
}

class _TooltipBubble extends StatelessWidget {
  final String label;

  const _TooltipBubble({Key? key, required this.label}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = theme.brightness == Brightness.dark ? Colors.black.withOpacity(0.52) : Colors.black.withOpacity(0.62);
    return Material(
      color: Colors.transparent,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // frosted panel
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 10, offset: const Offset(0, 4)),
                    BoxShadow(color: Colors.white.withOpacity(0.02), blurRadius: 1, spreadRadius: 0.5),
                  ],
                ),
                child: Text(
                  label,
                  style: const TextStyle(fontFamily: 'monospace', color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
            ),
          ),

          // arrow pointer
          CustomPaint(
            size: const Size(12, 24),
            painter: _BubbleArrowPainter(color: bgColor),
          ),
        ],
      ),
    );
  }
}

class _BubbleArrowPainter extends CustomPainter {
  final Color color;
  _BubbleArrowPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();
    final h = size.height;
    final w = size.width;
    // a smooth triangular pointer pointing right, vertically centered
    path.moveTo(0, h * 0.25);
    path.quadraticBezierTo(w * 0.6, h * 0.5, 0, h * 0.75);
    path.close();
    canvas.drawShadow(path, Colors.black.withOpacity(0.18), 4.0, false);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
