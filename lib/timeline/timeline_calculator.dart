import 'package:coinscape/timeline/timeline_models.dart';

/// TimelineCalculator
///
/// 根据后端的按月桶（buckets）以及前端网格布局信息，计算每个桶的像素高度
/// 并提供 O(1)/O(log M) 的映射方法：日期键 -> 像素偏移，像素偏移 -> 日期键。
class TimelineCalculator {
  final List<TimelineBucket> buckets;
  final int itemsPerRow;
  final double itemHeight;
  final double vSpacing;
  final double headerHeight;
  final double topPadding;
  final double bottomPadding;

  late final List<double> _bucketPrefixPx;
  late final List<double> _bucketHeights;
  late final Map<String, int> bucketMap;
  late final double totalContentHeight;

  TimelineCalculator({
    required this.buckets,
    required this.itemsPerRow,
    required this.itemHeight,
    required this.vSpacing,
    required this.headerHeight,
    this.topPadding = 0.0,
    this.bottomPadding = 0.0,
  }) {
    _computePrefix();
  }

  void _computePrefix() {
    _bucketPrefixPx = List.filled(buckets.length, 0.0);
    _bucketHeights = List.filled(buckets.length, 0.0);
    bucketMap = <String, int>{};

    double acc = topPadding;
    for (int i = 0; i < buckets.length; i++) {
      bucketMap[buckets[i].key] = i;
      _bucketPrefixPx[i] = acc;
      final int rows = (buckets[i].count + itemsPerRow - 1) ~/ itemsPerRow;
      final double bucketH = headerHeight + rows * itemHeight + (rows > 1 ? (rows - 1) * vSpacing : 0.0);
      _bucketHeights[i] = bucketH;
      acc += bucketH;
    }
    totalContentHeight = acc + bottomPadding;
  }

  /// 将日期键（"YYYY-MM"）转换为内容区像素偏移（bucket 顶部）。
  /// [alignInBucket] 允许在桶内按比例对齐（0.0 顶部，1.0 底部）。
  double dateToOffset(String dateKey, {double alignInBucket = 0.0}) {
    final idx = bucketMap[dateKey];
    if (idx == null) return 0.0;
    final base = _bucketPrefixPx[idx];
    return base + alignInBucket.clamp(0.0, 1.0) * _bucketHeights[idx];
  }

  /// 将内容区像素偏移转换为所属的日期键（"YYYY-MM"）——使用二分查找，复杂度 O(log M)。
  String offsetToDate(double offset) {
    if (buckets.isEmpty) return '';
    offset = offset.clamp(0.0, totalContentHeight);
    int lo = 0, hi = _bucketPrefixPx.length - 1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      final start = _bucketPrefixPx[mid];
      final end = start + _bucketHeights[mid];
      if (offset < start) {
        hi = mid - 1;
      } else if (offset >= end) {
        lo = mid + 1;
      } else {
        return buckets[mid].key;
      }
    }
    final idx = lo.clamp(0, buckets.length - 1);
    return buckets[idx].key;
  }

  // 公开用于布局与可视化的只读 API
  List<TimelineBucket> getBucketList() => buckets;
  double bucketTopPxByIndex(int idx) => _bucketPrefixPx[idx];
  double bucketHeightByIndex(int idx) => _bucketHeights[idx];
}
