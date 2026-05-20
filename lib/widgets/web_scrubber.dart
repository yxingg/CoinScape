import 'package:flutter/material.dart';
import 'package:coinscape/timeline/timeline_controller.dart';

class WebScrubber extends StatefulWidget {
  final TimelineController controller;
  final double width;

  const WebScrubber({Key? key, required this.controller, this.width = 140}) : super(key: key);

  @override
  _WebScrubberState createState() => _WebScrubberState();
}

class _WebScrubberState extends State<WebScrubber> {
  int? _hoverIndex;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final buckets = widget.controller.calculator.getBucketList();
    return RepaintBoundary(
      child: LayoutBuilder(builder: (context, constraints) {
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            width: widget.width,
            color: Colors.transparent,
            child: Stack(
              children: [
                // labels placed proportionally along the track
                for (int i = 0; i < buckets.length; i++)
                  _buildLabel(context, i, buckets[i], constraints.maxHeight),

                // draggable thumb
                ValueListenableBuilder<double>(
                  valueListenable: widget.controller.thumbRelative,
                  builder: (context, rel, _) {
                    final top = (rel * constraints.maxHeight).clamp(4.0, constraints.maxHeight - 24.0);
                    return Positioned(
                      top: top - 12.0,
                      right: 6,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onVerticalDragStart: (_) => setState(() => _dragging = true),
                        onVerticalDragUpdate: (d) {
                          final localY = d.localPosition.dy.clamp(0.0, constraints.maxHeight);
                          final rel2 = (localY / constraints.maxHeight).clamp(0.0, 1.0);
                          final targetOffset = rel2 * widget.controller.calculator.totalContentHeight;
                          widget.controller.jumpToOffsetThrottled(targetOffset);
                        },
                        onVerticalDragEnd: (_) => setState(() => _dragging = false),
                        child: Container(
                          width: 12,
                          height: 24,
                          decoration: BoxDecoration(color: Colors.white70, borderRadius: BorderRadius.circular(6)),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildLabel(BuildContext context, int index, dynamic bucket, double maxHeight) {
    final key = bucket.key as String;
    final topPx = widget.controller.calculator.dateToOffset(key);
    final rel = (widget.controller.calculator.totalContentHeight <= 0) ? 0.0 : (topPx / widget.controller.calculator.totalContentHeight);
    final labelTop = (rel * maxHeight).clamp(4.0, maxHeight - 28.0);

    return Positioned(
      top: labelTop - 10.0,
      right: 20,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hoverIndex = index),
        onExit: (_) => setState(() => _hoverIndex = null),
        child: GestureDetector(
          onTap: () => widget.controller.animateToDate(key),
          child: ValueListenableBuilder<String>(
            valueListenable: widget.controller.currentDate,
            builder: (context, currentKey, _) {
              final bool active = currentKey == key || _hoverIndex == index;
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                decoration: BoxDecoration(
                  color: active ? Colors.blueAccent.withOpacity(0.9) : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(key, style: TextStyle(fontSize: 12, color: active ? Colors.white : Colors.black87)),
              );
            },
          ),
        ),
      ),
    );
  }
}
