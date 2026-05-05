import 'dart:async';
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
import 'coin_edit_screen.dart';
import 'settings_screen.dart';
import '../utils/export_helper.dart';
import '../utils/pdf_helper.dart';
import '../services/sync_service.dart';
import '../providers/sync_providers.dart';
import '../models/sync_models.dart';


class CoinListScreen extends ConsumerStatefulWidget {
  final bool isWide;
  final VoidCallback? onToggleSidebar;

  const CoinListScreen({super.key, required this.isWide, this.onToggleSidebar});

  @override
  ConsumerState<CoinListScreen> createState() => _CoinListScreenState();
}

class _CoinListScreenState extends ConsumerState<CoinListScreen> {
  bool _isSelectionMode = false;
  bool _imageView = false;
  final Set<String> _selectedCoinIds = {};
  final ScrollController _scrollController = ScrollController();
  int _currentTimelineIndex = 0;
  int? _hoveredTimelineIndex;

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
    _scrollController.addListener(_onScrollChanged);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScrollChanged);
    _scrollController.dispose();
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
    // 分组标题约 36px + 每个纪念币约 56px (ListTile 默认高度)
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
            : CoinImageWidget(
                imagePath: coin.firstImagePath,
                width: 50, height: 50,
                enablePreview: true,
                previewTitle: coin.name,
              ),
        title: Text(coin.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('年份: ${coin.year ?? '未知'} | 收藏量: ${coin.quantity ?? 0} ${coin.quantityUnit ?? ''} | 单价: ￥${coin.unitPrice ?? 0}'),
        trailing: _isSelectionMode ? null : IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
          onPressed: () => _confirmDeleteCoin(context, ref, coin.id, coin.name),
        ),
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
                child: CoinImageWidget(
                  imagePath: coin.firstImagePath,
                  width: double.infinity,
                  height: 120,
                  enablePreview: true,
                  previewTitle: coin.name,
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
    String? selectedSeriesId,
  ) {
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
            // 该组的网格
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
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
          Widget listContent;
          if (_imageView) {
            listContent = _buildGroupedImageGrid(
              coins, groups, sortedKeys, seriesMap, selectedSeries?.id,
            );
          } else {
            listContent = _buildGroupedDetailList(
              coins, groups, sortedKeys, seriesMap, selectedSeries?.id,
            );
          }

          // 更新当前滚动位置对应的时间段索引
          _updateCurrentIndex(sortedKeys, groups);

          // 两种视图都显示时间轴
          return Row(
            children: [
              Expanded(child: listContent),
              // 右侧时间轴
              _buildTimeline(coins, groups, sortedKeys),
            ],
          );

      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('加载失败: $err')),
    );

    // 独立 Fab
    Widget? fab = FloatingActionButton.extended(
            onPressed: () {
               debugPrint('FAB Clicked! Navigating to CoinEditScreen for series: ${selectedSeries?.id}');
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
              // 添加到系列
              IconButton(
                icon: const Icon(Icons.bookmark_add),
                tooltip: '添加到系列',
                onPressed: () => _showAddToSeriesDialog(context, ref),
              ),
              // 从所有系列移除
              IconButton(
                icon: const Icon(Icons.bookmark_remove),
                tooltip: '从所有系列移除',
                onPressed: () => _confirmRemoveFromAllSeries(context, ref),
              ),
              IconButton(
                icon: const Icon(Icons.picture_as_pdf),
                tooltip: '生成 PDF',
                onPressed: () => _generatePdf(context, ref),
              ),
              IconButton(
                icon: const Icon(Icons.ios_share),
                tooltip: '导出 CCM 数据包',
                onPressed: () => _exportSelectedCoins(context, ref),
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
              onPressed: () => setState(() => _imageView = !_imageView),
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
            onPressed: () => setState(() => _imageView = !_imageView),
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
  Future<void> _showAddToSeriesDialog(BuildContext context, WidgetRef ref) async {
    if (_selectedCoinIds.isEmpty) return;
    final series = await ref.read(coinRepositoryProvider).db.select(ref.read(coinRepositoryProvider).db.series).get();
    if (!context.mounted) return;

    final selectedSeriesIds = <String>{};
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('添加到系列'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
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
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('确认添加'),
            ),
          ],
        ),
      ),
    );

    if (result == true && selectedSeriesIds.isNotEmpty) {
      await ref.read(coinRepositoryProvider).addCoinsToSeries(
        _selectedCoinIds.toList(),
        selectedSeriesIds.toList(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已将 ${_selectedCoinIds.length} 枚纪念币添加到 ${selectedSeriesIds.length} 个系列')),
        );
        setState(() {
          _isSelectionMode = false;
          _selectedCoinIds.clear();
        });
      }
    }
  }

  /// 确认从所有系列移除
  Future<void> _confirmRemoveFromAllSeries(BuildContext context, WidgetRef ref) async {
    if (_selectedCoinIds.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('从所有系列移除'),
        content: Text('确定要将选中的 ${_selectedCoinIds.length} 枚纪念币从所有系列中移除吗？纪念币本身不会被删除。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('确认移除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(coinRepositoryProvider).removeCoinsFromAllSeries(_selectedCoinIds.toList());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已将 ${_selectedCoinIds.length} 枚纪念币从所有系列中移除')),
        );
        setState(() {
          _isSelectionMode = false;
          _selectedCoinIds.clear();
        });
      }
    }
  }

  Future<void> _generatePdf(BuildContext context, WidgetRef ref) async {
    if (_selectedCoinIds.isEmpty) return;

    final db = ref.read(coinRepositoryProvider).db;
    final coins = await db.select(db.coins).get();
    final selectedCoins = coins.where((c) => _selectedCoinIds.contains(c.id)).toList();

    final settings = ref.read(settingsProvider);
      final seriesSections = <PdfSeriesSection>[];

      final links = await db.select(db.coinSeriesLink).get();
      final series = await db.select(db.series).get();
      final seriesMap = {for (final s in series) s.id: s.name};

      final selectedSeries = ref.read(selectedSeriesProvider);
      if (selectedSeries != null) {
        seriesSections.add(PdfSeriesSection(title: selectedSeries.name, coins: selectedCoins));
      } else {
        final grouped = <String, List<Coin>>{};
        final coinById = {for (final c in selectedCoins) c.id: c};

        for (final link in links) {
          final coin = coinById[link.coinId];
          if (coin == null) continue;
          final title = seriesMap[link.seriesId] ?? '未分组';
          grouped.putIfAbsent(title, () => []).add(coin);
        }

        final taggedCoinIds = links.map((e) => e.coinId).toSet();
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
              chineseFontId: settings.chineseFontId,
              englishFontId: settings.englishFontId,
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

  Future<void> _exportSelectedCoins(BuildContext context, WidgetRef ref) async {
    if (_selectedCoinIds.isEmpty) return;
    
    final messenger = ScaffoldMessenger.of(context);
    try {
      messenger.showSnackBar(const SnackBar(content: Text('正在打包...')));
      
      final db = ref.read(coinRepositoryProvider).db;
      final coins = await db.select(db.coins).get();
      final selectedCoins = coins.where((c) => _selectedCoinIds.contains(c.id)).toList();
      
      final links = await db.select(db.coinSeriesLink).get();
      final selectedLinks = links.where((l) => _selectedCoinIds.contains(l.coinId)).toList();

      final allCoinImages = await db.select(db.coinImages).get();
      final selectedCoinImages = allCoinImages.where((i) => _selectedCoinIds.contains(i.coinId)).toList();
      
      final seriesIds = selectedLinks.map((l) => l.seriesId).toSet();
      final series = await db.select(db.series).get();
      final selectedSeries = series.where((s) => seriesIds.contains(s.id)).toList();
      final allSeriesImages = await db.select(db.seriesImages).get();
      final selectedSeriesImages = allSeriesImages.where((i) => seriesIds.contains(i.seriesId)).toList();
      
      final zipBytes = await generateBackupDataBytes(
        selectedSeries,
        selectedCoins,
        selectedLinks,
        selectedCoinImages,
        selectedSeriesImages,
      );
      
      await exportFileAndShare(zipBytes, 'export.ccm');
      
      if (mounted) {
        setState(() {
          _isSelectionMode = false;
          _selectedCoinIds.clear();
        });
      }
      
    } catch (e) {
      debugPrint(e.toString());
      messenger.showSnackBar(SnackBar(content: Text('导出失败: $e')));
    }
  }

  /// 显示云同步菜单
  void _showCloudSyncMenu() {
    final config = ref.read(webDavConfigProvider);
    if (!config.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先在设置中配置 WebDAV 同步')),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.cloud_upload),
              title: const Text('云端备份 (Push)'),
              subtitle: const Text('将本地数据上传到云端'),
              onTap: () {
                Navigator.pop(ctx);
                _pushToCloud();
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.cloud_download),
              title: const Text('拉取合并 (Pull)'),
              subtitle: const Text('从云端下载并合并到本地'),
              onTap: () {
                Navigator.pop(ctx);
                _pullFromCloud();
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 云端备份上传
  Future<void> _pushToCloud() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);
    try {
      final config = ref.read(webDavConfigProvider);
      final service = SyncService(url: config.url, user: config.user, password: config.password);
      final repo = ref.read(coinRepositoryProvider);
      final series = await repo.db.select(repo.db.series).get();
      final coins = await repo.db.select(repo.db.coins).get();
      final links = await repo.db.select(repo.db.coinSeriesLink).get();
      final coinImages = await repo.db.select(repo.db.coinImages).get();
      final seriesImages = await repo.db.select(repo.db.seriesImages).get();
      await service.pushBackup(series, coins, links, coinImages, seriesImages);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('云端备份成功！')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('云端备份失败: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  /// 拉取合并下载
  Future<void> _pullFromCloud() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);
    try {
      final config = ref.read(webDavConfigProvider);
      final service = SyncService(url: config.url, user: config.user, password: config.password);
      final data = await service.pullBackup();
      if (mounted) {
        await _mergeCloudData(data);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('拉取合并成功！')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('拉取合并失败: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  /// 合并云端数据到本地
  Future<void> _mergeCloudData(SyncData data) async {
    final repo = ref.read(coinRepositoryProvider);
    final db = repo.db;

    final incomingSeries = data.series.map((e) => SeriesData.fromJson(e)).toList();
    final incomingCoins = data.coins.map((e) => Coin.fromJson(e)).toList();
    final incomingLinks = data.links.map((e) => CoinSeriesLinkData.fromJson(e)).toList();
    final incomingCoinImages = data.coinImages.map((e) => CoinImage.fromJson(e)).toList();
    final incomingSeriesImages = data.seriesImages.map((e) => SeriesImage.fromJson(e)).toList();

    final existingSeries = await db.select(db.series).get();
    final existingSeriesIds = existingSeries.map((e) => e.id).toSet();
    final existingCoins = await db.select(db.coins).get();
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
        await db.update(db.series).replace(s);
      } else {
        await db.into(db.series).insert(s);
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
        await db.update(db.coins).replace(c);
      } else {
        await db.into(db.coins).insert(c);
      }
    }

    for (final l in incomingLinks) {
      await db.into(db.coinSeriesLink).insert(l, mode: drift.InsertMode.insertOrIgnore);
    }
    for (final img in incomingCoinImages) {
      await db.into(db.coinImages).insert(img, mode: drift.InsertMode.insertOrReplace);
    }
    for (final img in incomingSeriesImages) {
      await db.into(db.seriesImages).insert(img, mode: drift.InsertMode.insertOrReplace);
    }
  }

  Future<String?> _askConflict(String entityType, String entityName) async {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('发现冲突'),
        content: Text('检测到本地已存在 $entityType: "$entityName"。\n请选择如何处理：'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, 'skip'), child: const Text('跳过')),
          TextButton(onPressed: () => Navigator.pop(ctx, 'skip_all'), child: const Text('全部跳过')),
          TextButton(onPressed: () => Navigator.pop(ctx, 'overwrite'), child: const Text('覆盖本地')),
          TextButton(onPressed: () => Navigator.pop(ctx, 'overwrite_all'), child: const Text('全部覆盖')),
        ],
      ),
    );
  }

  void _confirmDeleteCoin(BuildContext context, WidgetRef ref, String coinId, String coinName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除确认'),
        content: Text('确定要永久删除纪念币 "$coinName" 吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await ref.read(coinRepositoryProvider).deleteCoin(coinId);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}
