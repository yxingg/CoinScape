import 'dart:async';

import 'package:flutter/material.dart';
import 'package:coinscape/timeline/timeline_calculator.dart';

/// TimelineController
/// 共享状态：ScrollController + ValueNotifier（currentDate / thumbRelative）
class TimelineController {
  final ScrollController scrollController;
  final TimelineCalculator calculator;
  final ValueNotifier<String> currentDate = ValueNotifier<String>('');
  final ValueNotifier<double> thumbRelative = ValueNotifier<double>(0.0);

  final Duration throttleDuration;
  Timer? _throttleTimer;
  double? _pendingOffset;

  TimelineController({
    ScrollController? scrollController,
    required this.calculator,
    this.throttleDuration = const Duration(milliseconds: 16),
  }) : scrollController = scrollController ?? ScrollController() {
    this.scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!scrollController.hasClients) return;
    final offset = scrollController.offset;
    final key = calculator.offsetToDate(offset);
    if (currentDate.value != key) currentDate.value = key;
    final rel = (calculator.totalContentHeight <= 0) ? 0.0 : (offset / calculator.totalContentHeight);
    thumbRelative.value = rel.clamp(0.0, 1.0).toDouble();
  }

  /// 在拖拽中使用的 jumpTo（节流），避免短时间大量 jumpTo 导致 UI 卡顿。
  void jumpToOffsetThrottled(double offset) {
    _pendingOffset = (offset).clamp(0.0, calculator.totalContentHeight) as double;
    if (_throttleTimer == null || !_throttleTimer!.isActive) {
      _doJump();
      _throttleTimer = Timer(throttleDuration, _throttleTimerHandler);
    }
  }

  void _throttleTimerHandler() {
    if (_pendingOffset != null) {
      _doJump();
      _pendingOffset = null;
    }
    _throttleTimer?.cancel();
    _throttleTimer = null;
  }

  void _doJump() {
    if (!scrollController.hasClients) return;
    final off = _pendingOffset ?? scrollController.offset;
    try {
      scrollController.jumpTo(off);
    } catch (_) {}
  }

  Future<void> animateToDate(String dateKey, {Duration duration = const Duration(milliseconds: 360), Curve curve = Curves.easeOut}) async {
    final target = dateToOffsetSafe(dateKey);
    if (!scrollController.hasClients) return;
    await scrollController.animateTo(target, duration: duration, curve: curve);
  }

  double dateToOffsetSafe(String dateKey) => calculator.dateToOffset(dateKey);

  void dispose() {
    try {
      scrollController.removeListener(_onScroll);
    } catch (_) {}
    _throttleTimer?.cancel();
    currentDate.dispose();
    thumbRelative.dispose();
  }
}
