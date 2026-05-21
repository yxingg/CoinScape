import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:drift/drift.dart' as drift;
import '../database/database.dart';
import '../providers/ui_providers.dart';
import '../providers/coin_providers.dart';
import '../providers/settings_provider.dart';
import '../widgets/coin_image_widget.dart';
import '../widgets/global_image_viewer.dart';
import '../widgets/timeline_scrubber_wrapper.dart';
import '../timeline/timeline.dart';
import 'coin_edit_screen.dart';
import 'settings_screen.dart';
import '../utils/export_helper.dart';
import '../utils/pdf_helper.dart';
import '../utils/logger.dart';
import '../services/sync_service.dart';
import '../providers/sync_providers.dart';
import '../models/sync_models.dart';
import '../utils/dialog_helper.dart';


class CoinListScreen extends ConsumerStatefulWidget {
  final bool isWide;
  final VoidCallback? onToggleSidebar;

  const CoinListScreen({super.key, required this.isWide, this.onToggleSidebar});

  @override
  ConsumerState<CoinListScreen> createState() => _CoinListScreenState();
}

class _CoinListScreenState extends ConsumerState<CoinListScreen> {
  bool _isSelectionMode = false;
  late bool _imageView;
  final Set<String> _selectedCoinIds = {};
  final ScrollController _scrollController = ScrollController();
  TimelineController? _timelineController;
  int _currentTimelineIndex = 0;
  int? _hoveredTimelineIndex;
  // 缓存上一次用于计算的 timeline 参数，避免重复创建
  String? _lastBucketsKey;
  int? _lastItemsPerRow;
  double? _lastItemHeight;
  double? _lastVSpacing;
  double? _lastHeaderHeight;

  // 时间轴三层状态控制
  double _timelineOpacity = 0.35; // 默认隐藏态（半透明）
  bool _isTimelineActive = false; // 是否处于活跃态
  String? _dragTooltipText;       // 拖拽/悬停时显示的 Tooltip 文本
  bool _showDragTooltip = false;  // 是否显示 Tooltip
  double? _tooltipOffsetY;        // Tooltip 的 Y 轴位置
  Timer? _timelineHideTimer;      // 自动隐藏定时器

  // 云同步状态
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _imageView = ref.read(settingsProvider).imageViewMode;
    _scrollController.addListener(_onScrollChanged);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScrollChanged);
    _scrollController.dispose();
    _timelineController?.dispose();
    _timelineHideTimer?.cancel();
    super.dispose();
  }

  /// 重置自动隐藏定时器：交互/滚动后延迟 2s 进入隐藏态
  void _resetTimelineTimer() {
    _timelineHideTimer?.cancel();
    setState(() {
      _isTimelineActive = true;
      _timelineOpacity = 1.0;
    });
    _timelineHideTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isTimelineActive = false;
          _timelineOpacity = 0.35;
          _showDragTooltip = false;
        });
      }
    });
  }

  /// 格式化 Tooltip 文本
  String _getTooltipText(String key) {
    return '$key年';
  }

  /// 滚动监听：滚动时立即完全显示 + 重置定时器
  void _onScrollChanged() {
    if (!_scrollController.hasClients) return;
    _resetTimelineTimer();
  }

  /// 根据当前滚动偏移更新当前所在的时间段索引
  void _updateCurrentIndex(List<String> sortedKeys, Map<String, List<Coin>> groups) {
    if (!_scrollController.hasClients || sortedKeys.isEmpty) return;
    final offset = _scrollController.offset;
    double cumulativeOffset = 0;
    for (int i = 0; i < sortedKeys.length; i++) {
      final key = sortedKeys[i];
      final groupHeight = _getGroupHeight(key, groups);
      if (offset >= cumulativeOffset && offset < cumulativeOffset + groupHeight) {

        if (_currentTimelineIndex != i) {
          setState(() {
            _currentTimelineIndex = i;
          });
        }
        return;
      }
      cumulativeOffset += groupHeight;
    }
    // 如果滚动到底部之后，设置为最后一个
    if (_currentTimelineIndex != sortedKeys.length - 1) {
      setState(() {
        _currentTimelineIndex = sortedKeys.length - 1;
      });
    }
  }

  /// 估算一个分组的高度
  double _getGroupHeight(String key, Map<String, List<Coin>> groups) {
    final coins = groups[key]!;
    // 如果是图片视图且已知每行项数，使用与 Grid 对应的高度估算
    if (_imageView && _lastItemsPerRow != null && _lastItemHeight != null) {
      final rows = (coins.length + _lastItemsPerRow! - 1) ~/ _lastItemsPerRow!;
      final vSpacing = _lastVSpacing ?? 0.0;
      final header = _lastHeaderHeight ?? 36.0;
      return header + rows * (_lastItemHeight ?? 160.0) + (rows > 1 ? (rows - 1) * vSpacing : 0.0);
    }
    // 详情列表：分组标题约 36px + 每个纪念币约 56px (ListTile 默认高度)
    return 36.0 + coins.length * 56.0;
  }

  /// 计算滚动到指定分组索引的偏移量
  double _getOffsetForGroup(int targetIndex, List<String> sortedKeys, Map<String, List<Coin>> groups) {
    double offset = 0;
    for (int i = 0; i < targetIndex; i++) {
      offset += _getGroupHeight(sortedKeys[i], groups);
    }
    return offset;
  }

  void _ensureTimelineController(
    List<TimelineBucket> buckets,
    int itemsPerRow,
    double itemHeight,
    double vSpacing,
    double headerHeight,
  ) {
    final bucketsKey = buckets.map((b) => '${b.key}:${b.count}').join('|');
    final changed = bucketsKey != _lastBucketsKey || itemsPerRow != _lastItemsPerRow || itemHeight != _lastItemHeight || vSpacing != _lastVSpacing || headerHeight != _lastHeaderHeight;
    if (!changed && _timelineController != null) return;

    try {
      _timelineController?.dispose();
    } catch (_) {}

    if (buckets.isEmpty) {
      _timelineController = null;
    } else {
      final calculator = TimelineCalculator(
        buckets: buckets,
        itemsPerRow: itemsPerRow,
        itemHeight: itemHeight,
        vSpacing: vSpacing,
        headerHeight: headerHeight,
      );
      _timelineController = TimelineController(scrollController: _scrollController, calculator: calculator);
    }

    _lastBucketsKey = bucketsKey;
    _lastItemsPerRow = itemsPerRow;
    _lastItemHeight = itemHeight;
    _lastVSpacing = vSpacing;
    _lastHeaderHeight = headerHeight;
  }



  /// 将纪念币按年份分组
  Map<String, List<Coin>> _groupCoinsByMonth(List<Coin> coins) {
    final groups = <String, List<Coin>>{};
    for (final coin in coins) {
      final time = coin.collectionTime ?? coin.createdAt;
      final key = '${time.year}';
      groups.putIfAbsent(key, () => []).add(coin);
    }
    return groups;
  }

  /// 获取排序后的年月键（降序）
  List<String> _getSortedGroupKeys(Map<String, List<Coin>> groups) {
    return groups.keys.toList()..sort((a, b) => b.compareTo(a));
  }

  /// 显示指定纪念币的全部图片画廊
  Future<void> _showCoinImages(Coin coin) async {
    final repo = ref.read(coinRepositoryProvider);
    final images = await repo.getCoinImages(coin.id);
    if (!mounted) return;
    final paths = images.map((e) => e.imagePath).toList();
    if (paths.isEmpty && coin.firstImagePath != null) {
      paths.add(coin.firstImagePath!);
    }
    if (paths.isEmpty) return;
    if (!mounted) return;
    GlobalImageViewer.show(
      context,
      imagePaths: paths,
      title: coin.name,
    );
  }

  /// 构建单个纪念币卡片（详情模式）
  Widget _buildDetailCoinItem(Coin coin, bool isSelected, Color bgColor, Map<String, String> seriesMap, String? selectedSeriesId) {
    return Container(
      color: bgColor,
      child: ListTile(
        selected: isSelected,
        selectedTileColor: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
        leading: _isSelectionMode
            ? Checkbox(
                value: isSelected,
                onChanged: (val) {
                  setState(() {
                    if (val == true) {
                      _selectedCoinIds.add(coin.id);
                    } else {
                      _selectedCoinIds.remove(coin.id);
                    }
                  });
                },
              )
            : GestureDetector(
                onTap: () => _showCoinImages(coin),
                child: CoinImageWidget(
                  imagePath: coin.firstImagePath,
                  width: 50, height: 50,
                ),
              ),
        title: Text(coin.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('年份: ${coin.year ?? '未知'} | 收藏量: ${coin.quantity ?? 0} ${coin.quantityUnit ?? ''} | 单价: ￥${coin.unitPrice ?? 0}'),
        trailing: null,
        onLongPress: () {
          if (!_isSelectionMode) {
            setState(() {
              _isSelectionMode = true;
              _selectedCoinIds.add(coin.id);
            });
          }
        },
        onTap: () {
          if (_isSelectionMode) {
            setState(() {
              if (isSelected) {
                _selectedCoinIds.remove(coin.id);
              } else {
                _selectedCoinIds.add(coin.id);
              }
            });
          } else {
            Navigator.push(context, MaterialPageRoute(
              builder: (ctx) => CoinEditScreen(seriesId: selectedSeriesId, coin: coin),
            ));
          }
        },
      ),
    );
  }

  /// 构建单个纪念币卡片（图片模式）
  Widget _buildImageCoinItem(Coin coin, bool isSelected, Map<String, String> seriesMap, String? selectedSeriesId) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onLongPress: () {
        if (!_isSelectionMode) {
          setState(() {
            _isSelectionMode = true;
            _selectedCoinIds.add(coin.id);
          });
        }
      },
      onTap: () {
        if (_isSelectionMode) {
          setState(() {
            if (isSelected) {
              _selectedCoinIds.remove(coin.id);
            } else {
              _selectedCoinIds.add(coin.id);
            }
          });
        } else {
          Navigator.push(context, MaterialPageRoute(
            builder: (ctx) => CoinEditScreen(seriesId: selectedSeriesId, coin: coin),
          ));
        }
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: GestureDetector(
                  onTap: () => _showCoinImages(coin),
                  child: CoinImageWidget(
                    imagePath: coin.firstImagePath,
                    width: double.infinity,
                    height: 120,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(coin.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            FutureBuilder<List<String>>(
              future: ref.read(coinRepositoryProvider).getSeriesIdsForCoin(coin.id),
              builder: (context, snapshot) {
                final ids = snapshot.data ?? const <String>[];
                if (ids.isEmpty) {
                  return const SizedBox(height: 16);
                }
                return Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: ids.take(2).map((id) {
                      final label = seriesMap[id] ?? '未命名';
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(label, style: const TextStyle(fontSize: 10)),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 构建分组后的详情列表
  Widget _buildGroupedDetailList(
    List<Coin> coins,
    Map<String, List<Coin>> groups,
    List<String> sortedKeys,
    Map<String, String> seriesMap,
    String? selectedSeriesId,
  ) {
    // 为每个组分配交替背景色
    final groupColors = [
      Colors.white,
      Colors.grey.shade50,
    ];

    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          for (int g = 0; g < sortedKeys.length; g++)
            ..._buildDetailGroup(
              sortedKeys[g],
              groups[sortedKeys[g]]!,
              coins,
              groupColors[g % groupColors.length],
              seriesMap,
              selectedSeriesId,
            ),
        ],
      ),
    );

  }

  /// 构建单个详情分组的标题和内容
  List<Widget> _buildDetailGroup(
    String key,
    List<Coin> groupCoins,
    List<Coin> allCoins,
    Color bgColor,
    Map<String, String> seriesMap,
    String? selectedSeriesId,
  ) {
    final widgets = <Widget>[];

    // 分组标题（无底色，仅主题色字体）
    widgets.add(
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Text(
          key,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );

    // 组内纪念币
    for (final coin in groupCoins) {
      final isSelected = _selectedCoinIds.contains(coin.id);
      widgets.add(_buildDetailCoinItem(coin, isSelected, bgColor, seriesMap, selectedSeriesId));
    }

    return widgets;
  }


  /// 构建分组后的图片网格
  Widget _buildGroupedImageGrid(
    List<Coin> coins,
    Map<String, List<Coin>> groups,
    List<String> sortedKeys,
    Map<String, String> seriesMap,
    String? selectedSeriesId, {
    required int itemsPerRow,
  }) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.all(12),
        children: [
          for (final key in sortedKeys) ...[
            // 分组标题
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Text(
                key,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            // 该组的网格（使用传入的 itemsPerRow）
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: itemsPerRow,
                mainAxisSpacing: 12.0,
                crossAxisSpacing: 12.0,
                childAspectRatio: 0.9,
              ),
              itemCount: groups[key]!.length,
              itemBuilder: (_, index) {
                final coin = groups[key]![index];
                final isSelected = _selectedCoinIds.contains(coin.id);
                return _buildImageCoinItem(coin, isSelected, seriesMap, selectedSeriesId);
              },
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );

  }

  @override
  Widget build(BuildContext context) {

    final selectedSeries = ref.watch(selectedSeriesProvider);
    final seriesAsync = ref.watch(seriesListProvider);

    final coinsAsync = selectedSeries == null
        ? ref.watch(allCoinsProvider)
        : ref.watch(coinsBySeriesProvider(selectedSeries.id));

    Widget bodyContent;
    bodyContent = coinsAsync.when(
      data: (coins) {
          final seriesMap = seriesAsync.maybeWhen(

            data: (seriesList) => {for (final s in seriesList) s.id: s.name},
            orElse: () => <String, String>{},
          );
          if (coins.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(selectedSeries == null ? '还没有纪念币。' : '当前 "${selectedSeries.name}" 中还没有纪念币。',
                      style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(
                        builder: (ctx) => CoinEditScreen(seriesId: selectedSeries?.id),
                      ));
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('马上添加纪念币'),
                  ),
                ],
              ),
            );
          }

          // 按年月分组
          final groups = _groupCoinsByMonth(coins);
          final sortedKeys = _getSortedGroupKeys(groups);

          // 构建主内容（两种视图都带分组）
          Widget listContent = const SizedBox.shrink();

          // 更新当前滚动位置对应的时间段索引
          _updateCurrentIndex(sortedKeys, groups);

          // 构建 Timeline buckets
          final buckets = sortedKeys.map((k) {
            final count = groups[k]?.length ?? 0;
            final year = int.tryParse(k) ?? 0;
            return TimelineBucket(
              key: k,
              year: year,
              month: 1,
              count: count,
              startIndex: 0,
              startTs: 0,
              endTs: 0,
            );
          }).toList();

          // 两种视图都显示时间轴：使用 LayoutBuilder 为主内容计算宽度并传入 itemsPerRow
          return Row(
            children: [
              Expanded(
                child: LayoutBuilder(builder: (ctx, constraints) {
                  final availableWidth = constraints.maxWidth;
                  const desiredItemWidth = 160.0;
                  const spacing = 12.0;
                  final itemsPerRow = (availableWidth / (desiredItemWidth + spacing)).floor().clamp(1, 10);

                  // 为 timeline 准备 controller（使用不同视图下的 itemHeight）
                  final itemHeight = _imageView ? 160.0 : 56.0;
                  _ensureTimelineController(buckets, itemsPerRow, itemHeight, 12.0, 36.0);

                  if (_imageView) {
                    return _buildGroupedImageGrid(coins, groups, sortedKeys, seriesMap, selectedSeries?.id, itemsPerRow: itemsPerRow);
                  }
                  return _buildGroupedDetailList(coins, groups, sortedKeys, seriesMap, selectedSeries?.id);
                }),
              ),

              // 右侧 scrubber（使用 TimelineController）
              if (_timelineController != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(width: kIsWeb ? 140 : 48, child: TimelineScrubberWrapper(controller: _timelineController!)),
                ),
            ],
          );

      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('加载失败: $err')),
    );

    // 独立 Fab
    Widget? fab = FloatingActionButton.extended(
            onPressed: () {
               AppLogger.methodCall('CoinListScreen', 'onFabPressed', params: {'seriesId': selectedSeries?.id});
               Navigator.push(context, MaterialPageRoute(
                 builder: (ctx) => CoinEditScreen(seriesId: selectedSeries?.id),
               ));
            },
            icon: const Icon(Icons.add),
            label: const Text('添加纪念币'),
          );

    // 构建 AppBar
    AppBar? buildAppBar() {
      if (_isSelectionMode) {
        return AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              setState(() {
                _isSelectionMode = false;
                _selectedCoinIds.clear();
              });
            },
          ),
          title: Text('已选择 ${_selectedCoinIds.length} 项'),
          actions: [
            if (_selectedCoinIds.isNotEmpty) ...[
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                tooltip: '删除选中纪念币',
                onPressed: () => _confirmBatchDeleteCoins(ref),
              ),
              // 添加到系列
              IconButton(
                icon: const Icon(Icons.bookmark_add),
                tooltip: '添加到系列',
                onPressed: () => _showAddToSeriesDialog(ref),
              ),
              // 从所有系列移除
              IconButton(
                icon: const Icon(Icons.bookmark_remove),
                tooltip: '从所有系列移除',
                onPressed: () => _confirmRemoveFromAllSeries(ref),
              ),
              IconButton(
                icon: const Icon(Icons.picture_as_pdf),
                tooltip: '生成 PDF',
                onPressed: () => _generatePdf(context, ref),
              ),
              IconButton(
                icon: const Icon(Icons.ios_share),
                tooltip: '导出 CCM 数据包',
                onPressed: () => _exportSelectedCoins(ref),
              ),
            ],
          ],
        );
      }
      
      if (widget.isWide) {
        return AppBar(
          leading: widget.onToggleSidebar != null
              ? IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: widget.onToggleSidebar,
                  tooltip: '切换侧边栏',
                )
              : null,
          title: Text(selectedSeries?.name ?? '全部纪念币'),
          actions: [
            IconButton(
              onPressed: () {
                final newValue = !_imageView;
                setState(() => _imageView = newValue);
                ref.read(settingsProvider.notifier).update((s) => s.copyWith(imageViewMode: newValue));
              },
              icon: Icon(_imageView ? Icons.view_list : Icons.grid_view),
              tooltip: _imageView ? '切换到详细信息' : '切换到图片展示',
            ),
            IconButton(
              icon: const Icon(Icons.cloud_sync),
              tooltip: '云同步',
              onPressed: _showCloudSyncMenu,
            ),
            IconButton(
              icon: const Icon(Icons.settings),
              tooltip: '设置',
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(
                  builder: (ctx) => const SettingsScreen(),
                ));
              },
            ),
          ],
          elevation: 0,
        );
      }

      return AppBar(
        leading: widget.onToggleSidebar != null
            ? IconButton(
                icon: const Icon(Icons.menu),
                onPressed: widget.onToggleSidebar,
                tooltip: '打开侧边栏',
              )
            : null,
        title: Text(selectedSeries?.name ?? '全部纪念币'),
        actions: [
          IconButton(
            onPressed: () {
                final newValue = !_imageView;
                setState(() => _imageView = newValue);
                ref.read(settingsProvider.notifier).update((s) => s.copyWith(imageViewMode: newValue));
              },
            icon: Icon(_imageView ? Icons.view_list : Icons.grid_view),
            tooltip: _imageView ? '切换到详细信息' : '切换到图片展示',
          ),
          IconButton(
            icon: const Icon(Icons.cloud_sync),
            tooltip: '云同步',
            onPressed: _showCloudSyncMenu,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: '设置',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(
                builder: (ctx) => const SettingsScreen(),
              ));
            },
          ),
        ],
      );
    }

    final appBar = buildAppBar();

    return Scaffold(
      appBar: appBar,
      body: bodyContent,
      floatingActionButton: _isSelectionMode ? null : fab,
    );
  }

  /// 构建右侧时间轴 — 自适应式侧边时间流索引
  /// 三层状态：活跃态(Active) / 延迟显示态(Delayed-Active) / 隐藏态(Passive)
  /// 交互：滚动同步、点击跳转、拖拽滑动、悬浮反馈、触觉反馈
  Widget _buildTimeline(List<Coin> coins, Map<String, List<Coin>> groups, List<String> sortedKeys) {
    if (sortedKeys.isEmpty) return const SizedBox(width: 0);

    final primaryColor = Theme.of(context).colorScheme.primary;
    final surfaceColor = Theme.of(context).colorScheme.surface;

    return AnimatedOpacity(

      duration: const Duration(milliseconds: 400),
      opacity: _timelineOpacity,
      child: Container(
        width: 64,
        decoration: BoxDecoration(
          border: Border(left: BorderSide(
            color: _isTimelineActive ? Colors.grey.shade300 : Colors.grey.shade100,
            width: 1,
          )),
        ),
        child: GestureDetector(
          onVerticalDragStart: (details) {
            _resetTimelineTimer();
            setState(() {
              _showDragTooltip = true;
              _isTimelineActive = true;
              _timelineOpacity = 1.0;
            });
            // 触觉反馈
            HapticFeedback.mediumImpact();
          },
          onVerticalDragUpdate: (details) {
            if (!_scrollController.hasClients) return;
            _resetTimelineTimer();
            final maxScroll = _scrollController.position.maxScrollExtent;
            final minScroll = _scrollController.position.minScrollExtent;
            final delta = -details.delta.dy;
            final newOffset = (_scrollController.offset + delta).clamp(minScroll, maxScroll);
            _scrollController.jumpTo(newOffset);

            // 计算当前拖拽位置对应的时间段索引
            final box = context.findRenderObject() as RenderBox?;
            if (box != null) {
              final localY = details.localPosition.dy;
              final itemHeight = 48.0;
              final index = (localY / itemHeight).floor().clamp(0, sortedKeys.length - 1);
              setState(() {
                _dragTooltipText = _getTooltipText(sortedKeys[index]);
                _tooltipOffsetY = localY;
              });
              // 经过主要刻度时触发触觉反馈
              if (index != _currentTimelineIndex) {
                HapticFeedback.selectionClick();
              }
            }
          },
          onVerticalDragEnd: (_) {
            _resetTimelineTimer();
          },
          child: Stack(
            children: [
              // 时间轴刻度列表
              ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: sortedKeys.length,
                itemBuilder: (context, index) {
                  final key = sortedKeys[index];
                  final isCurrent = index == _currentTimelineIndex;
                  final isHovered = index == _hoveredTimelineIndex;
                  // 隐藏态：只显示轴线 + 小圆点，不显示文字
                  final showLabel = _isTimelineActive || isCurrent;

                  return MouseRegion(
                    onEnter: (_) {
                      setState(() {
                        _hoveredTimelineIndex = index;
                        _showDragTooltip = true;
                        _dragTooltipText = _getTooltipText(key);
                      });
                      _resetTimelineTimer();
                    },
                    onExit: (_) {
                      setState(() {
                        _hoveredTimelineIndex = null;
                        if (!_isTimelineActive) {
                          _showDragTooltip = false;
                        }
                      });
                    },
                    child: GestureDetector(
                      onTap: () {
                        _resetTimelineTimer();
                        final offset = _getOffsetForGroup(index, sortedKeys, groups);
                        _scrollController.animateTo(
                          offset,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                        HapticFeedback.lightImpact();
                      },
                      child: SizedBox(
                        height: 48,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // 轴线（垂直线）
                            Positioned(
                              left: 12,
                              top: 0,
                              bottom: 0,
                              child: Container(
                                width: 2,
                                color: isCurrent
                                    ? primaryColor.withValues(alpha: 0.4)
                                    : Colors.grey.shade200,
                              ),
                            ),
                            // 刻度标记（圆点）
                            Positioned(
                              left: 7,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: isCurrent ? 14 : 10,
                                height: isCurrent ? 14 : 10,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isCurrent
                                      ? primaryColor
                                      : (isHovered ? primaryColor.withValues(alpha: 0.6) : Colors.grey.shade300),
                                  border: isCurrent
                                      ? Border.all(color: surfaceColor, width: 2)
                                      : null,
                                  boxShadow: isCurrent
                                      ? [BoxShadow(color: primaryColor.withValues(alpha: 0.3), blurRadius: 4)]
                                      : null,
                                ),
                              ),
                            ),
                            // 年月标签（隐藏态时仅当前项显示）
                            if (showLabel)
                              Positioned(
                                left: 28,
                                child: Text(
                                  key,
                                  style: TextStyle(
                                    fontSize: isCurrent ? 11 : 10,
                                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                    color: isCurrent
                                        ? primaryColor
                                        : (isHovered ? primaryColor.withValues(alpha: 0.7) : Colors.grey.shade500),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              // Tooltip 浮层（拖拽/悬停时显示）
              if (_showDragTooltip && _dragTooltipText != null && _tooltipOffsetY != null)
                Positioned(
                  left: 0,
                  top: (_tooltipOffsetY! - 14).clamp(0.0, double.infinity),
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      decoration: BoxDecoration(
                        color: primaryColor,
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 4),
                        ],
                      ),
                      child: Text(
                        _dragTooltipText!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }



  /// 显示"添加到系列"对话框
  Future<void> _showAddToSeriesDialog(WidgetRef ref) async {
    if (_selectedCoinIds.isEmpty) return;
    final repo = ref.read(coinRepositoryProvider);
    final series = await repo.getAllSeries();
    if (!mounted) return;

    final selectedSeriesIds = <String>{};
    final result = await DialogHelper.showCustomDialog<bool>(
      context: context,
      title: '添加到系列',
      content: SizedBox(
        width: double.maxFinite,
        child: StatefulBuilder(
          builder: (ctx, setDialogState) => ListView(
            shrinkWrap: true,
            children: series.map((s) => CheckboxListTile(
              title: Text(s.name),
              value: selectedSeriesIds.contains(s.id),
              onChanged: (val) {
                setDialogState(() {
                  if (val == true) {
                    selectedSeriesIds.add(s.id);
                  } else {
                    selectedSeriesIds.remove(s.id);
                  }
                });
              },
            )).toList(),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('确认添加'),
        ),
      ],
    );

    if (result == true && selectedSeriesIds.isNotEmpty) {
      await repo.addCoinsToSeries(
        _selectedCoinIds.toList(),
        selectedSeriesIds.toList(),
      );
      if (!mounted) return;
      DialogHelper.showSuccessSnackBar(context, '已将 ${_selectedCoinIds.length} 枚纪念币添加到 ${selectedSeriesIds.length} 个系列');
      setState(() {
        _isSelectionMode = false;
        _selectedCoinIds.clear();
      });
    }
  }

  /// 确认从所有系列移除
  Future<void> _confirmRemoveFromAllSeries(WidgetRef ref) async {
    if (_selectedCoinIds.isEmpty) return;
    final confirmed = await DialogHelper.showConfirmDialog(
      context: context,
      title: '从所有系列移除',
      content: '确定要将选中的 ${_selectedCoinIds.length} 枚纪念币从所有系列中移除吗？纪念币本身不会被删除。',
      confirmText: '确认移除',
      isDestructive: true,
    );

    if (confirmed == true) {
      await ref.read(coinRepositoryProvider).removeCoinsFromAllSeries(_selectedCoinIds.toList());
      if (!mounted) return;
      DialogHelper.showSuccessSnackBar(context, '已将 ${_selectedCoinIds.length} 枚纪念币从所有系列中移除');
      setState(() {
        _isSelectionMode = false;
        _selectedCoinIds.clear();
      });
    }
  }

  Future<void> _generatePdf(BuildContext context, WidgetRef ref) async {
    if (_selectedCoinIds.isEmpty) return;

    final repo = ref.read(coinRepositoryProvider);
    final allCoins = await repo.getAllCoins();
    final selectedCoins = allCoins.where((c) => _selectedCoinIds.contains(c.id)).toList();

    final settings = ref.read(settingsProvider);
    final seriesSections = <PdfSeriesSection>[];

    final allSeries = await repo.getAllSeries();
    final seriesMap = {for (final s in allSeries) s.id: s.name};

    final selectedSeries = ref.read(selectedSeriesProvider);
    if (selectedSeries != null) {
      seriesSections.add(PdfSeriesSection(title: selectedSeries.name, coins: selectedCoins));
    } else {
      final grouped = <String, List<Coin>>{};

      // Get links for all selected coins
      for (final coin in selectedCoins) {
        final ids = await repo.getSeriesIdsForCoin(coin.id);
        for (final sid in ids) {
          final title = seriesMap[sid] ?? '未分组';
          grouped.putIfAbsent(title, () => []).add(coin);
        }
      }

      final taggedCoinIds = grouped.values.expand((l) => l).map((c) => c.id).toSet();
      final untagged = selectedCoins.where((c) => !taggedCoinIds.contains(c.id)).toList();
      if (untagged.isNotEmpty) {
        grouped.putIfAbsent('未分组', () => []).addAll(untagged);
      }

      seriesSections.addAll(grouped.entries.map((e) => PdfSeriesSection(title: e.key, coins: e.value)));
      if (seriesSections.isEmpty) {
        seriesSections.add(PdfSeriesSection(title: '纪念币', coins: selectedCoins));
      }
    }

    if (context.mounted) {
      Navigator.push(context, MaterialPageRoute(
        builder: (ctx) => Scaffold(
          appBar: AppBar(title: const Text('PDF 预览')),
          body: PdfPreview(
            build: (format) => generateCoinsPdf(
              selectedCoins,
              chineseFontId: settings.pdfChineseFontId,
              englishFontId: settings.pdfEnglishFontId,
              seriesSections: seriesSections,
            ),
            allowSharing: true,
            allowPrinting: true,
          ),
        ),
      ));
      
      setState(() {
        _isSelectionMode = false;
        _selectedCoinIds.clear();
      });
    }
  }

  Future<void> _exportSelectedCoins(WidgetRef ref) async {
    if (_selectedCoinIds.isEmpty) return;

    ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? progressController;
    try {
      progressController = DialogHelper.showProgressSnackBar(context, '正在打包...');
      
      final repo = ref.read(coinRepositoryProvider);
      final allCoins = await repo.getAllCoins();
      final selectedCoins = allCoins.where((c) => _selectedCoinIds.contains(c.id)).toList();
      
      // Build links and related data using repo methods
      final selectedLinks = <CoinSeriesLinkData>[];
      final selectedCoinImages = <CoinImage>[];
      final selectedSeriesSet = <String>{};
      
      for (final coin in selectedCoins) {
        final seriesIds = await repo.getSeriesIdsForCoin(coin.id);
        for (final sid in seriesIds) {
          selectedLinks.add(CoinSeriesLinkData(coinId: coin.id, seriesId: sid));
          selectedSeriesSet.add(sid);
        }
        final images = await repo.getCoinImages(coin.id);
        selectedCoinImages.addAll(images);
      }
      
      final allSeries = await repo.getAllSeries();
      final selectedSeries = allSeries.where((s) => selectedSeriesSet.contains(s.id)).toList();
      
      final selectedSeriesImages = <SeriesImage>[];
      for (final s in selectedSeries) {
        final images = await repo.getSeriesImages(s.id);
        selectedSeriesImages.addAll(images);
      }
      
      final zipBytes = await generateBackupDataBytes(
        selectedSeries,
        selectedCoins,
        selectedLinks,
        selectedCoinImages,
        selectedSeriesImages,
      );
      
      await exportFileAndShare(zipBytes, 'export.ccm');
      
      // 关闭进度条
      progressController.close();

      if (!mounted) return;
      DialogHelper.showSuccessSnackBar(context, '导出成功，文件已保存');
      setState(() {
        _isSelectionMode = false;
        _selectedCoinIds.clear();
      });
      
    } catch (e) {
      AppLogger.error(logPrefixUI, '导出失败: $e');
      // 关闭进度条
      if (progressController != null && mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }
      if (mounted) DialogHelper.showErrorSnackBar(context, '导出失败: $e');
    }
  }

  /// 显示云同步菜单
  void _showCloudSyncMenu() {
    final config = ref.read(webDavConfigProvider);
    if (!config.isValid) {
      DialogHelper.showWarningSnackBar(context, '请先在设置中配置 WebDAV 同步');
      return;
    }
    DialogHelper.showBottomMenu(
      context: context,
      title: '云同步操作',
      items: [
        DialogHelper.menuItem(
          icon: Icons.cloud_upload,
          title: '云端备份 (Push)',
          subtitle: '将本地数据上传到云端',
          onTap: () {
            if (_isSyncing) return;
            Navigator.pop(context);
            _pushToCloud();
          },
        ),
        const Divider(),
        DialogHelper.menuItem(
          icon: Icons.cloud_download,
          title: '拉取合并 (Pull)',
          subtitle: '从云端下载并合并到本地',
          onTap: () {
            if (_isSyncing) return;
            Navigator.pop(context);
            _pullFromCloud();
          },
        ),
      ],
    );
  }

  /// 云端备份上传
Future<void> _pushToCloud() async {
    if (!ref.read(webDavConfigProvider).isValid) {
      if (mounted) {
        DialogHelper.showWarningSnackBar(context, '请先配置 WebDAV');
      }
      return;
    }

    setState(() => _isSyncing = true);
    try {
      final service = SyncService.fromConfig(ref);
      final repo = ref.read(coinRepositoryProvider);
      final series = await repo.getAllSeries();
      final coins = await repo.getAllCoins();
      
      // Build links, coinImages, seriesImages using repo methods
      final links = <CoinSeriesLinkData>[];
      final coinImages = <CoinImage>[];
      final seriesImageList = <SeriesImage>[];
      
      for (final coin in coins) {
        final ids = await repo.getSeriesIdsForCoin(coin.id);
        for (final sid in ids) {
          links.add(CoinSeriesLinkData(coinId: coin.id, seriesId: sid));
        }
        final images = await repo.getCoinImages(coin.id);
        coinImages.addAll(images);
      }
      
      for (final s in series) {
        final images = await repo.getSeriesImages(s.id);
        seriesImageList.addAll(images);
      }
      
      await service.pushBackup(series, coins, links, coinImages, seriesImageList);
      if (mounted) {
        DialogHelper.showSuccessSnackBar(context, '云端备份成功！');
      }
    } catch (e) {
      if (mounted) {
        DialogHelper.showErrorSnackBar(context, '云端备份失败: $e');
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  /// 拉取合并下载
Future<void> _pullFromCloud() async {
    if (!ref.read(webDavConfigProvider).isValid) {
      if (mounted) {
        DialogHelper.showWarningSnackBar(context, '请先配置 WebDAV');
      }
      return;
    }

    setState(() => _isSyncing = true);
    try {
      final service = SyncService.fromConfig(ref);
      final data = await service.pullBackup();
      if (mounted) {
        await _mergeCloudData(data);
      }
      if (mounted) {
        DialogHelper.showSuccessSnackBar(context, '拉取合并成功！');
      }
    } catch (e) {
      if (mounted) {
        DialogHelper.showErrorSnackBar(context, '拉取合并失败: $e');
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  /// 合并云端数据到本地
  Future<void> _mergeCloudData(SyncData data) async {
    final repo = ref.read(coinRepositoryProvider);

    final incomingSeries = data.series.map((e) => SeriesData.fromJson(e)).toList();
    final incomingCoins = data.coins.map((e) => Coin.fromJson(e)).toList();
    final incomingLinks = data.links.map((e) => CoinSeriesLinkData.fromJson(e)).toList();
    final incomingCoinImages = data.coinImages.map((e) => CoinImage.fromJson(e)).toList();
    final incomingSeriesImages = data.seriesImages.map((e) => SeriesImage.fromJson(e)).toList();

    final existingSeries = await repo.getAllSeries();
    final existingSeriesIds = existingSeries.map((e) => e.id).toSet();
    final existingCoins = await repo.getAllCoins();
    final existingCoinsIds = existingCoins.map((e) => e.id).toSet();

    bool overwriteAllConflicts = false;
    bool skipAllConflicts = false;

    for (final s in incomingSeries) {
      if (existingSeriesIds.contains(s.id)) {
        if (!overwriteAllConflicts && !skipAllConflicts) {
          final res = await _askConflict('冲突的系列', s.name);
          if (res == 'overwrite_all') overwriteAllConflicts = true;
          if (res == 'skip_all') skipAllConflicts = true;
          if (res == 'skip' || res == 'skip_all') continue;
        } else if (skipAllConflicts) {
          continue;
        }
        await repo.updateSeries(SeriesCompanion(
          id: drift.Value(s.id),
          name: drift.Value(s.name),
          description: drift.Value(s.description),
          createdAt: drift.Value(s.createdAt),
        ));
      } else {
        await repo.insertSeries(SeriesCompanion(
          id: drift.Value(s.id),
          name: drift.Value(s.name),
          description: drift.Value(s.description),
          createdAt: drift.Value(s.createdAt),
        ));
      }
    }

    overwriteAllConflicts = false;
    skipAllConflicts = false;

    for (final c in incomingCoins) {
      if (existingCoinsIds.contains(c.id)) {
        if (!overwriteAllConflicts && !skipAllConflicts) {
          final res = await _askConflict('冲突的纪念币', c.name);
          if (res == 'overwrite_all') overwriteAllConflicts = true;
          if (res == 'skip_all') skipAllConflicts = true;
          if (res == 'skip' || res == 'skip_all') continue;
        } else if (skipAllConflicts) {
          continue;
        }
        await repo.updateCoin(CoinsCompanion(
          id: drift.Value(c.id),
          name: drift.Value(c.name),
          year: drift.Value(c.year),
          faceValue: drift.Value(c.faceValue),
          material: drift.Value(c.material),
          weight: drift.Value(c.weight),
          diameter: drift.Value(c.diameter),
          mintage: drift.Value(c.mintage),
          mint: drift.Value(c.mint),
          grade: drift.Value(c.grade),
          unitPrice: drift.Value(c.unitPrice),
          quantity: drift.Value(c.quantity),
          quantityUnit: drift.Value(c.quantityUnit),
          collectionTime: drift.Value(c.collectionTime),
          createdAt: drift.Value(c.createdAt),
          comments: drift.Value(c.comments),
          firstImagePath: drift.Value(c.firstImagePath),
        ));
      } else {
        await repo.insertCoin(CoinsCompanion(
          id: drift.Value(c.id),
          name: drift.Value(c.name),
          year: drift.Value(c.year),
          faceValue: drift.Value(c.faceValue),
          material: drift.Value(c.material),
          weight: drift.Value(c.weight),
          diameter: drift.Value(c.diameter),
          mintage: drift.Value(c.mintage),
          mint: drift.Value(c.mint),
          grade: drift.Value(c.grade),
          unitPrice: drift.Value(c.unitPrice),
          quantity: drift.Value(c.quantity),
          quantityUnit: drift.Value(c.quantityUnit),
          collectionTime: drift.Value(c.collectionTime),
          createdAt: drift.Value(c.createdAt),
          comments: drift.Value(c.comments),
          firstImagePath: drift.Value(c.firstImagePath),
        ));
      }
    }

    for (final l in incomingLinks) {
      await repo.linkCoinToSeries(l.coinId, l.seriesId);
    }
    for (final img in incomingCoinImages) {
      await repo.replaceCoinImages(img.coinId, [img.imagePath]);
    }
    for (final img in incomingSeriesImages) {
      await repo.replaceSeriesImages(img.seriesId, [img.imagePath]);
    }
  }

  Future<String?> _askConflict(String entityType, String entityName) async {
    return DialogHelper.showCustomDialog<String>(
      context: context,
      title: '发现冲突',
      content: Text('检测到本地已存在 $entityType: "$entityName"。\n请选择如何处理：'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, 'skip'), child: const Text('跳过')),
        TextButton(onPressed: () => Navigator.pop(context, 'skip_all'), child: const Text('全部跳过')),
        TextButton(onPressed: () => Navigator.pop(context, 'overwrite'), child: const Text('覆盖本地')),
        TextButton(onPressed: () => Navigator.pop(context, 'overwrite_all'), child: const Text('全部覆盖')),
      ],
    );
  }

  void _confirmBatchDeleteCoins(WidgetRef ref) async {
    final count = _selectedCoinIds.length;
    final confirmed = await DialogHelper.showConfirmDialog(
      context: context,
      title: '批量删除确认',
      content: '确定要永久删除选中的 $count 枚纪念币吗？此操作不可撤销。',
      confirmText: '删除',
      isDestructive: true,
    );

    if (confirmed == true) {
      await ref.read(coinRepositoryProvider).deleteCoinsBatch(_selectedCoinIds.toList());
      if (!mounted) return;
      setState(() {
        _isSelectionMode = false;
        _selectedCoinIds.clear();
      });
      DialogHelper.showSuccessSnackBar(context, '已删除 $count 枚纪念币');
    }
  }
}
