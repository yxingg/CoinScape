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
  String _lastDateKey = '';
  late AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 160));
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _onDragStart(DragStartDetails d) {
    setState(() => _active = true);
    _anim.forward();
  }

  void _onDragUpdate(DragUpdateDetails d, BoxConstraints constraints) {
    final localY = d.localPosition.dy.clamp(0.0, constraints.maxHeight);
    final rel = (localY / constraints.maxHeight).clamp(0.0, 1.0);
    final targetOffset = rel * widget.controller.calculator.totalContentHeight;
    widget.controller.jumpToOffsetThrottled(targetOffset);

    final key = widget.controller.calculator.offsetToDate(targetOffset);
    if (key != _lastDateKey) {
      HapticFeedback.selectionClick();
      _lastDateKey = key;
      widget.controller.currentDate.value = key;
    }
  }

  void _onDragEnd(DragEndDetails d) {
    setState(() => _active = false);
    _anim.reverse();
    _lastDateKey = '';
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: LayoutBuilder(builder: (context, constraints) {
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onVerticalDragStart: _onDragStart,
          onVerticalDragUpdate: (d) => _onDragUpdate(d, constraints),
          onVerticalDragEnd: _onDragEnd,
          child: Stack(
            alignment: Alignment.centerRight,
            children: [
              // track
              AnimatedOpacity(
                opacity: _active ? 1.0 : 0.5,
                duration: const Duration(milliseconds: 200),
                child: Container(width: widget.trackWidth, color: Colors.black26),
              ),

              // thumb
              Positioned(
                right: 6,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: _active ? widget.trackWidth * 1.6 : widget.trackWidth,
                  height: 48,
                  decoration: BoxDecoration(color: Colors.white30, borderRadius: BorderRadius.circular(24)),
                ),
              ),

              // floating bubble
              ValueListenableBuilder<double>(
                valueListenable: widget.controller.thumbRelative,
                builder: (context, rel, _) {
                  final bubbleTop = (rel * constraints.maxHeight) - 24.0;
                  final clampedTop = bubbleTop.clamp(8.0, constraints.maxHeight - 48.0);
                  return Positioned(
                    top: clampedTop,
                    right: widget.trackWidth + 12,
                    child: ValueListenableBuilder<String>(
                      valueListenable: widget.controller.currentDate,
                      builder: (context, val, __) {
                        final visible = _active;
                        return AnimatedOpacity(
                          duration: const Duration(milliseconds: 120),
                          opacity: visible ? 1.0 : 0.0,
                          child: Material(
                            color: Colors.transparent,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(8)),
                              child: Text(val, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
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
  }
}
