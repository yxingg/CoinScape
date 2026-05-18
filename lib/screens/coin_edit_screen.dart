import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' as drift;

import '../database/database.dart';
import '../providers/coin_providers.dart';
import '../services/image_service.dart';
import '../widgets/coin_image_widget.dart';
import '../utils/logger.dart';
import '../utils/dialog_helper.dart';

class CoinEditScreen extends ConsumerStatefulWidget {
  final String? seriesId;
  final Coin? coin; // 不为空则处于编辑模式

  const CoinEditScreen({super.key, this.seriesId, this.coin});

  @override
  ConsumerState<CoinEditScreen> createState() => _CoinEditScreenState();
}

class _CoinEditScreenState extends ConsumerState<CoinEditScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameCtrl;
  late TextEditingController _yearCtrl;
  late TextEditingController _faceValueCtrl;
  late TextEditingController _materialCtrl;
  late TextEditingController _weightCtrl;
  late TextEditingController _diameterCtrl;
  late TextEditingController _mintageCtrl;
  late TextEditingController _mintCtrl;
  late TextEditingController _gradeCtrl;
  late TextEditingController _unitPriceCtrl;
  late TextEditingController _quantityCtrl;
  late TextEditingController _quantityUnitCtrl;
  late TextEditingController _commentsCtrl;

  DateTime? _collectionTime;

  final List<String> _imagePaths = [];
  final Set<String> _selectedSeriesIds = {};
  final Map<String, Uint8List> _imageBytesMap = {};  // 为每张图片保存字节数据

  @override
  void initState() {
    super.initState();
    final c = widget.coin;
    _nameCtrl = TextEditingController(text: c?.name ?? '');
    _yearCtrl = TextEditingController(text: c?.year?.toString() ?? '');
    _faceValueCtrl = TextEditingController(text: c?.faceValue?.toString() ?? '');
    _materialCtrl = TextEditingController(text: c?.material ?? '');
    _weightCtrl = TextEditingController(text: c?.weight?.toString() ?? '');
    _diameterCtrl = TextEditingController(text: c?.diameter?.toString() ?? '');
    _mintageCtrl = TextEditingController(text: c?.mintage ?? '');
    _mintCtrl = TextEditingController(text: c?.mint ?? '');
    _gradeCtrl = TextEditingController(text: c?.grade ?? '');
    _unitPriceCtrl = TextEditingController(text: c?.unitPrice?.toString() ?? '');
    _quantityCtrl = TextEditingController(text: c?.quantity?.toString() ?? '1');
    _quantityUnitCtrl = TextEditingController(text: c?.quantityUnit ?? '枚');
    _commentsCtrl = TextEditingController(text: c?.comments ?? '');

    _collectionTime = c?.collectionTime;

    if (c?.firstImagePath != null && c!.firstImagePath!.isNotEmpty) {
      _imagePaths.add(c.firstImagePath!);
    }

    if (widget.seriesId != null && widget.seriesId!.isNotEmpty) {
      _selectedSeriesIds.add(widget.seriesId!);
    }

    _loadInitialTagsAndImages();
  }

  Future<void> _loadInitialTagsAndImages() async {
    final c = widget.coin;
    if (c == null) return;
    final repo = ref.read(coinRepositoryProvider);
    final tagIds = await repo.getSeriesIdsForCoin(c.id);
    final imgs = await repo.getCoinImages(c.id);
    if (!mounted) return;
    setState(() {
      _selectedSeriesIds
        ..clear()
        ..addAll(tagIds);
      _imagePaths
        ..clear()
        ..addAll(imgs.map((e) => e.imagePath));
      if (_imagePaths.isEmpty && c.firstImagePath != null && c.firstImagePath!.isNotEmpty) {
        _imagePaths.add(c.firstImagePath!);
      }
      if (widget.seriesId != null && widget.seriesId!.isNotEmpty) {
        _selectedSeriesIds.add(widget.seriesId!);
      }
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _yearCtrl.dispose();
    _faceValueCtrl.dispose();
    _materialCtrl.dispose();
    _weightCtrl.dispose();
    _diameterCtrl.dispose();
    _mintageCtrl.dispose();
    _mintCtrl.dispose();
    _gradeCtrl.dispose();
    _unitPriceCtrl.dispose();
    _quantityCtrl.dispose();
    _quantityUnitCtrl.dispose();
    _commentsCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final data = await ImageService.pickImages();
    if (data.isNotEmpty) {
      AppLogger.info(logPrefixUI, '选择了 ${data.length} 张图片');
      setState(() {
        for (final img in data) {
          if (img.path != null && img.path!.isNotEmpty) {
            _imagePaths.add(img.path!);
            // 保存这张图片的字节数据
            if (img.bytes != null) {
              _imageBytesMap[img.path!] = img.bytes!;
              AppLogger.debug(logPrefixUI, '图片已添加到编辑器: ${img.path!}, 字节数据: ${img.bytes!.length} bytes');
            }
          }
        }
      });
    } else {
      AppLogger.debug(logPrefixUI, '没有选择任何图片');
    }
  }

  void _moveImageLeft(int index) {
    if (index <= 0) return;
    setState(() {
      final item = _imagePaths.removeAt(index);
      _imagePaths.insert(index - 1, item);
    });
  }

  void _moveImageRight(int index) {
    if (index >= _imagePaths.length - 1) return;
    setState(() {
      final item = _imagePaths.removeAt(index);
      _imagePaths.insert(index + 1, item);
    });
  }

  void _removeImageAt(int index) {
    setState(() {
      _imagePaths.removeAt(index);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final repo = ref.read(coinRepositoryProvider);
    final isEdit = widget.coin != null;
    final coinId = isEdit ? widget.coin!.id : const Uuid().v4();

    final companion = CoinsCompanion(
      id: drift.Value(coinId),
      name: drift.Value(_nameCtrl.text.trim()),
      year: drift.Value(int.tryParse(_yearCtrl.text.trim())),
      faceValue: drift.Value(double.tryParse(_faceValueCtrl.text.trim())),
      material: drift.Value(_materialCtrl.text.trim()),
      weight: drift.Value(double.tryParse(_weightCtrl.text.trim())),
      diameter: drift.Value(double.tryParse(_diameterCtrl.text.trim())),
      mintage: drift.Value(_mintageCtrl.text.trim()),
      mint: drift.Value(_mintCtrl.text.trim()),
      grade: drift.Value(_gradeCtrl.text.trim()),
      unitPrice: drift.Value(double.tryParse(_unitPriceCtrl.text.trim())),
      quantity: drift.Value(int.tryParse(_quantityCtrl.text.trim())),
      quantityUnit: drift.Value(_quantityUnitCtrl.text.trim()),
      comments: drift.Value(_commentsCtrl.text.trim()),
      firstImagePath: drift.Value(_imagePaths.isNotEmpty ? _imagePaths.first : null),
      collectionTime: drift.Value(_collectionTime),
      createdAt: drift.Value(widget.coin?.createdAt ?? DateTime.now()),

    );

    if (isEdit) {
      await repo.updateCoin(companion);
    } else {
      await repo.insertCoin(companion);
    }

    await repo.setCoinSeriesTags(coinId, _selectedSeriesIds.toList());
    await repo.replaceCoinImages(coinId, _imagePaths);

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.coin != null ? '纪念币详情' : '添加纪念币'),
        actions: [
          if (widget.coin != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: () => _confirmDeleteCoin(ref),
              tooltip: '删除纪念币',
            ),
          IconButton(icon: const Icon(Icons.check), onPressed: _save),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ===== 图片区域 =====
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(
                        width: 160,
                        height: 160,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CoinImageWidget(
                              imagePath: _imagePaths.isNotEmpty ? _imagePaths.first : null,
                              imageBytes: _imagePaths.isNotEmpty ? _imageBytesMap[_imagePaths.first] : null,
                              width: 160,
                              height: 160,
                              enablePreview: _imagePaths.isNotEmpty,
                              previewTitle: _nameCtrl.text.isNotEmpty ? _nameCtrl.text : '图片预览',
                              imagePaths: _imagePaths,
                              imageBytesMap: _imageBytesMap,
                            ),
                            Container(
                              width: 160, height: 160,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300, width: 1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Center(child: Icon(Icons.camera_alt, color: Colors.grey, size: 40)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('添加多张图片'),
                ),
              ),
              if (_imagePaths.isNotEmpty)
                SizedBox(
                  height: 180,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _imagePaths.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final path = _imagePaths[i];
                      return Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: i == 0 ? theme.colorScheme.primary : Colors.grey.shade300),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Column(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: CoinImageWidget(
                                    imagePath: path,
                                    imageBytes: _imageBytesMap[path],
                                    width: 160,
                                    height: 120,
                                    fit: BoxFit.cover,
                                    enablePreview: true,
                                    previewTitle: _nameCtrl.text.isNotEmpty ? _nameCtrl.text : '图片预览',
                                    imagePaths: _imagePaths,
                                    imageBytesMap: _imageBytesMap,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.arrow_left, size: 18),
                                    onPressed: () => _moveImageLeft(i),
                                    tooltip: '左移',
                                  ),
                                  Text(i == 0 ? '封面' : '#${i + 1}', style: TextStyle(fontSize: 11, color: i == 0 ? theme.colorScheme.primary : Colors.grey)),
                                  IconButton(
                                    icon: const Icon(Icons.arrow_right, size: 18),
                                    onPressed: () => _moveImageRight(i),
                                    tooltip: '右移',
                                  ),
                                ],
                              ),
                              TextButton(
                                onPressed: () => _removeImageAt(i),
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(0, 20),
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text('删除', style: TextStyle(fontSize: 11, color: Colors.redAccent)),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 16),

              // ===== 系列标签 =====
              ref.watch(seriesListProvider).when(
                    data: (series) => Card(
                      elevation: 1,
                      margin: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.bookmark, size: 18, color: theme.colorScheme.primary),
                                const SizedBox(width: 8),
                                const Text('系列标签', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              ],
                            ),
                            const Divider(height: 20),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: series
                                  .map(
                                    (s) => FilterChip(
                                      label: Text(s.name),
                                      selected: _selectedSeriesIds.contains(s.id),
                                      onSelected: (on) {
                                        setState(() {
                                          if (on) {
                                            _selectedSeriesIds.add(s.id);
                                          } else {
                                            _selectedSeriesIds.remove(s.id);
                                          }
                                        });
                                      },
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
              const SizedBox(height: 16),

              // ===== 基本信息卡片 =====
              Card(
                elevation: 1,
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, size: 18, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          const Text('基本信息', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        ],
                      ),
                      const Divider(height: 20),
                      TextFormField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(labelText: '纪念币名称 *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.abc)),
                        validator: (v) => v == null || v.trim().isEmpty ? '名称不能为空' : null,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: TextFormField(
                            controller: _yearCtrl,
                            decoration: const InputDecoration(labelText: '年份', border: OutlineInputBorder(), prefixIcon: Icon(Icons.calendar_today, size: 20)),
                            keyboardType: TextInputType.number,
                          )),
                          const SizedBox(width: 16),
                          Expanded(child: TextFormField(
                            controller: _faceValueCtrl,
                            decoration: const InputDecoration(labelText: '面值', suffixText: ' 元', border: OutlineInputBorder(), prefixIcon: Icon(Icons.monetization_on, size: 20)),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          )),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _materialCtrl,
                        decoration: const InputDecoration(labelText: '材质', border: OutlineInputBorder(), prefixIcon: Icon(Icons.science_outlined, size: 20)),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _mintCtrl,
                        decoration: const InputDecoration(labelText: '造币厂', border: OutlineInputBorder(), prefixIcon: Icon(Icons.factory_outlined, size: 20)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ===== 收藏信息卡片 =====
              Card(
                elevation: 1,
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.collections_bookmark, size: 18, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          const Text('收藏信息', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        ],
                      ),
                      const Divider(height: 20),
                      // 收藏时间
                      InkWell(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _collectionTime ?? DateTime.now(),
                            firstDate: DateTime(1900),
                            lastDate: DateTime.now(),
                            helpText: '选择收藏日期',
                          );
                          if (date != null) {
                            setState(() {
                              _collectionTime = date;
                            });
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: '收藏时间',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.calendar_month, size: 20),
                            suffixIcon: Icon(Icons.arrow_drop_down),
                          ),
                          child: Text(
                            _collectionTime != null
                                ? '${_collectionTime!.year}-${_collectionTime!.month.toString().padLeft(2, '0')}-${_collectionTime!.day.toString().padLeft(2, '0')}'
                                : '点击选择日期',
                            style: TextStyle(
                              color: _collectionTime != null ? null : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: TextFormField(
                            controller: _quantityCtrl,
                            decoration: const InputDecoration(labelText: '收藏数量', border: OutlineInputBorder(), prefixIcon: Icon(Icons.numbers, size: 20)),
                            keyboardType: TextInputType.number,
                          )),
                          const SizedBox(width: 16),
                          Expanded(child: TextFormField(
                            controller: _quantityUnitCtrl,
                            decoration: const InputDecoration(labelText: '单位', hintText: '枚/卷', border: OutlineInputBorder()),
                          )),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _unitPriceCtrl,
                        decoration: const InputDecoration(labelText: '收藏购入单价', suffixText: ' 元/单位', border: OutlineInputBorder(), prefixIcon: Icon(Icons.attach_money, size: 20)),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _gradeCtrl,
                        decoration: const InputDecoration(labelText: '评级分数/机构', border: OutlineInputBorder(), prefixIcon: Icon(Icons.star_outline, size: 20)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ===== 物理参数卡片 =====
              Card(
                elevation: 1,
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.straighten, size: 18, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          const Text('物理参数', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        ],
                      ),
                      const Divider(height: 20),
                      Row(
                        children: [
                          Expanded(child: TextFormField(
                            controller: _weightCtrl,
                            decoration: const InputDecoration(labelText: '重量', suffixText: ' g', border: OutlineInputBorder(), prefixIcon: Icon(Icons.monitor_weight_outlined, size: 20)),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          )),
                          const SizedBox(width: 16),
                          Expanded(child: TextFormField(
                            controller: _diameterCtrl,
                            decoration: const InputDecoration(labelText: '直径', suffixText: ' mm', border: OutlineInputBorder(), prefixIcon: Icon(Icons.circle_outlined, size: 20)),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          )),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _mintageCtrl,
                        decoration: const InputDecoration(labelText: '总发行量', border: OutlineInputBorder(), prefixIcon: Icon(Icons.bar_chart_outlined, size: 20)),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _commentsCtrl,
                        decoration: const InputDecoration(
                          labelText: '文字简评',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                          prefixIcon: Padding(
                            padding: EdgeInsets.only(bottom: 64),
                            child: Icon(Icons.notes, size: 20),
                          ),
                        ),
                        maxLines: 4,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteCoin(WidgetRef ref) async {
    final coin = widget.coin;
    if (coin == null) return;
    
    final confirmed = await DialogHelper.showConfirmDialog(
      context: context,
      title: '删除确认',
      content: '确定要永久删除纪念币 "${coin.name}" 吗？此操作不可撤销。',
      confirmText: '删除',
      isDestructive: true,
    );

    if (confirmed != true) return;

    try {
      await ref.read(coinRepositoryProvider).deleteCoin(coin.id);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e, stack) {
      AppLogger.error(logPrefixUI, '删除纪念币失败: $e\n$stack');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('删除失败: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
