import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/coin_providers.dart';
import '../providers/ui_providers.dart';
import '../database/database.dart';
import '../screens/series_edit_screen.dart';
import '../widgets/coin_image_widget.dart';
import '../widgets/global_image_viewer.dart';
import '../utils/export_helper.dart';
import '../utils/pdf_helper.dart';
import '../providers/settings_provider.dart';
import '../services/sync_service.dart';
import 'package:printing/printing.dart';

class SeriesListDrawer extends ConsumerStatefulWidget {
  final VoidCallback? onClose;

  const SeriesListDrawer({super.key, this.onClose});

  @override
  ConsumerState<SeriesListDrawer> createState() => _SeriesListDrawerState();
}

class _SeriesListDrawerState extends ConsumerState<SeriesListDrawer> {
  bool _isSelectionMode = false;
  final Set<String> _selectedSeriesIds = {};

  Future<void> _showSeriesImages(SeriesData series) async {
    final repo = ref.read(coinRepositoryProvider);
    final images = await repo.getSeriesImages(series.id);
    if (!mounted) return;
    final paths = images.map((e) => e.imagePath).toList();
    if (paths.isEmpty) return;
    if (!mounted) return;
    GlobalImageViewer.show(
      context,
      imagePaths: paths,
      title: series.name,
    );
  }

  void _showAddOrEditDialog(BuildContext context, [SeriesData? series]) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SeriesEditScreen(series: series)),
    );
  }

  void _showDeleteConfirm(BuildContext context, SeriesData series) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除系列 "${series.name}" 吗？这只会移除相应的归类，不会删除其中的纪念币数据。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              await ref.read(coinRepositoryProvider).deleteSeries(series.id);
              if (ref.read(selectedSeriesProvider)?.id == series.id) {
                ref.read(selectedSeriesProvider.notifier).state = null;
              }
              if (ctx.mounted) {
                Navigator.pop(ctx);
              }
              scaffoldMessenger.showSnackBar(
                SnackBar(content: Text('已删除系列: ${series.name}')),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _showBatchDeleteConfirm() {
    if (_selectedSeriesIds.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('批量删除确认'),
        content: Text('确定要删除选中的 ${_selectedSeriesIds.length} 个系列吗？这只会移除相应的归类，不会删除其中的纪念币数据。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              await ref.read(coinRepositoryProvider).deleteSeriesBatch(_selectedSeriesIds.toList());
              if (ctx.mounted) {
                Navigator.pop(ctx);
              }
              setState(() {
                _isSelectionMode = false;
                _selectedSeriesIds.clear();
              });
              scaffoldMessenger.showSnackBar(
                const SnackBar(content: Text('已批量删除系列')),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  Future<void> _generatePdfForSelectedSeries() async {
    if (_selectedSeriesIds.isEmpty) return;
    final repo = ref.read(coinRepositoryProvider);
    final allSeries = await repo.getAllSeries();
    final selectedSeriesList = allSeries.where((s) => _selectedSeriesIds.contains(s.id)).toList();

    final seriesSections = <PdfSeriesSection>[];
    final allPdfCoins = <Coin>[];
    for (final s in selectedSeriesList) {
      final coins = await repo.getCoinsBySeries(s.id);
      seriesSections.add(PdfSeriesSection(title: s.name, coins: coins));
      allPdfCoins.addAll(coins);
    }

    final settings = ref.read(settingsProvider);
    if (mounted) {
      Navigator.push(context, MaterialPageRoute(
        builder: (ctx) => Scaffold(
          appBar: AppBar(title: const Text('PDF 预览')),
          body: PdfPreview(
            build: (format) => generateCoinsPdf(
              allPdfCoins,
              chineseFontId: settings.pdfChineseFontId,
              englishFontId: settings.pdfEnglishFontId,
              seriesSections: seriesSections,
            ),
            allowSharing: true,
            allowPrinting: true,
          ),
        ),
      ));
    }
  }

  Future<void> _exportCcmForSelectedSeries() async {
    if (_selectedSeriesIds.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      messenger.showSnackBar(const SnackBar(content: Text('正在打包...')));
      final repo = ref.read(coinRepositoryProvider);

      final allSeries = await repo.getAllSeries();
      final selectedSeriesList = allSeries.where((s) => _selectedSeriesIds.contains(s.id)).toList();

      final selectedLinks = <CoinSeriesLinkData>[];
      final selectedCoins = <Coin>[];
      final selectedCoinImages = <CoinImage>[];
      final selectedSeriesImages = <SeriesImage>[];

      for (final s in selectedSeriesList) {
        final coins = await repo.getCoinsBySeries(s.id);
        selectedCoins.addAll(coins);
        for (final c in coins) {
          selectedLinks.add(CoinSeriesLinkData(coinId: c.id, seriesId: s.id));
          final images = await repo.getCoinImages(c.id);
          selectedCoinImages.addAll(images);
        }
        final images = await repo.getSeriesImages(s.id);
        selectedSeriesImages.addAll(images);
      }

      final zipBytes = await generateBackupDataBytes(
        selectedSeriesList, selectedCoins, selectedLinks, selectedCoinImages, selectedSeriesImages,
      );
      await exportFileAndShare(zipBytes, 'series_export.ccm');
      if (mounted) {
        setState(() {
          _isSelectionMode = false;
          _selectedSeriesIds.clear();
        });
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('导出失败: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final seriesAsync = ref.watch(seriesListProvider);
    final selectedSeries = ref.watch(selectedSeriesProvider);
    final theme = Theme.of(context);

    return SafeArea(
      child: Column(
        children: [
          // 顶部标题栏
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(Icons.collections_bookmark,
                     color: theme.colorScheme.primary, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _isSelectionMode ? '已选择 ${_selectedSeriesIds.length} 项' : '系列管理',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (_isSelectionMode)
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      setState(() {
                        _isSelectionMode = false;
                        _selectedSeriesIds.clear();
                      });
                    },
                  )
                else if (widget.onClose != null)
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: widget.onClose,
                    tooltip: '收起侧边栏',
                  ),
              ],
            ),
          ),
          // 多选模式下的操作栏
          if (_isSelectionMode && _selectedSeriesIds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.picture_as_pdf),
                    tooltip: '生成 PDF',
                    onPressed: _generatePdfForSelectedSeries,
                  ),
                  IconButton(
                    icon: const Icon(Icons.ios_share),
                    tooltip: '导出 CCM 数据包',
                    onPressed: _exportCcmForSelectedSeries,
                  ),
                ],
              ),
            ),
          const Divider(height: 1),
          // 系列列表
          Expanded(
            child: seriesAsync.when(
              data: (list) {
                if (list.isEmpty) {
                  return const Center(child: Text('暂无系列，请点击下方添加', style: TextStyle(color: Colors.grey)));
                }
                return ListView.builder(
                  itemCount: list.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      final allSelected = selectedSeries == null;
                      return ListTile(
                        selected: allSelected,
                        leading: const Icon(Icons.all_inbox),
                        title: const Text('全部纪念币'),
                        onTap: () {
                          ref.read(selectedSeriesProvider.notifier).state = null;
                          if (MediaQuery.of(context).size.width <= 600) {
                            Navigator.of(context).pop();
                          }
                        },
                      );
                    }
                    final series = list[index - 1];
                    final isSelected = selectedSeries?.id == series.id;
                    final isChecked = _selectedSeriesIds.contains(series.id);

                    return ListTile(
                      selected: isSelected,
                      selectedTileColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
                      leading: _isSelectionMode
                          ? Checkbox(
                              value: isChecked,
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedSeriesIds.add(series.id);
                                  } else {
                                    _selectedSeriesIds.remove(series.id);
                                  }
                                });
                              },
                            )
                          : SizedBox(
                              width: 44,
                              height: 44,
                              child: FutureBuilder<String?>(
                                future: ref.read(coinRepositoryProvider).getSeriesCoverImagePath(series.id),
                                builder: (context, snapshot) {
                                  final path = snapshot.data;
                                  return GestureDetector(
                                    onTap: (path != null && path.isNotEmpty)
                                        ? () => _showSeriesImages(series)
                                        : null,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: CoinImageWidget(
                                        imagePath: path,
                                        width: 44,
                                        height: 44,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                      title: Text(series.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                      subtitle: series.description?.isNotEmpty == true
                          ? Text(
                              series.description!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            )
                          : null,
                      onTap: () {
                        if (_isSelectionMode) {
                          setState(() {
                            if (isChecked) {
                              _selectedSeriesIds.remove(series.id);
                            } else {
                              _selectedSeriesIds.add(series.id);
                            }
                          });
                        } else {
                          ref.read(selectedSeriesProvider.notifier).state = series;
                          if (MediaQuery.of(context).size.width <= 600) {
                            Navigator.of(context).pop();
                          }
                        }
                      },
                      onLongPress: () {
                        if (!_isSelectionMode) {
                          setState(() {
                            _isSelectionMode = true;
                            _selectedSeriesIds.add(series.id);
                          });
                        }
                      },
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('加载错误: $err')),
            ),
          ),
          const Divider(height: 1),
          // 底部操作按钮区域
          _buildBottomActions(selectedSeries),
        ],
      ),
    );
  }

  Widget _buildBottomActions(SeriesData? selectedSeries) {
    final theme = Theme.of(context);

    if (_isSelectionMode) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _selectedSeriesIds.isNotEmpty ? _showBatchDeleteConfirm : null,
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    label: const Text('删除选中', style: TextStyle(color: Colors.redAccent)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.redAccent),
                      minimumSize: const Size(0, 44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () => _showAddOrEditDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('添加新系列'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      );
    }

    if (selectedSeries != null) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showAddOrEditDialog(context, selectedSeries),
                    icon: Icon(Icons.edit, size: 18, color: theme.colorScheme.primary),
                    label: Text('编辑', style: TextStyle(color: theme.colorScheme.primary)),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showDeleteConfirm(context, selectedSeries),
                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                    label: const Text('删除', style: TextStyle(color: Colors.redAccent)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.redAccent),
                      minimumSize: const Size(0, 44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () => _showAddOrEditDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('添加新系列'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: FilledButton.icon(
        onPressed: () => _showAddOrEditDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('添加新系列'),
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
