import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database.dart';

/// 管理当前 UI 选中的系列（作用于全局范围，左右侧联动）
final selectedSeriesProvider = StateProvider<SeriesData?>((ref) => null);
