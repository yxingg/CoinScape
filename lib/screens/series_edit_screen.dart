import 'dart:typed_data';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../database/database.dart';
import '../providers/coin_providers.dart';
import '../services/image_service.dart';
import '../widgets/coin_image_widget.dart';
import '../utils/logger.dart';

class SeriesEditScreen extends ConsumerStatefulWidget {
  final SeriesData? series;

  const SeriesEditScreen({super.key, this.series});

  @override
  ConsumerState<SeriesEditScreen> createState() => _SeriesEditScreenState();
}

class _SeriesEditScreenState extends ConsumerState<SeriesEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _descCtrl;

  final List<String> _imagePaths = [];
  final Map<String, Uint8List> _imageBytesMap = {};  // 为每张图片保存字节数据

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.series?.name ?? '');
    _descCtrl = TextEditingController(text: widget.series?.description ?? '');
    _loadSeriesImages();
  }

  Future<void> _loadSeriesImages() async {
    final s = widget.series;
    if (s == null) return;
    final imgs = await ref.read(coinRepositoryProvider).getSeriesImages(s.id);
    if (!mounted) return;
    setState(() {
      _imagePaths
        ..clear()
        ..addAll(imgs.map((e) => e.imagePath));
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _addImages() async {
    final imgs = await ImageService.pickImages();
    if (imgs.isEmpty) {
      AppLogger.debug(logPrefixUI, '系列编辑: 没有选择任何图片');
      return;
    }
    AppLogger.info(logPrefixUI, '系列编辑: 选择了 ${imgs.length} 张图片');
    setState(() {
      for (final i in imgs) {
        if (i.path != null && i.path!.isNotEmpty) {
          _imagePaths.add(i.path!);
          // 保存这张图片的字节数据
          if (i.bytes != null) {
            _imageBytesMap[i.path!] = i.bytes!;
            AppLogger.debug(logPrefixUI, '系列图片已添加: ${i.path!}, 字节数据: ${i.bytes!.length} bytes');
          }
        }
      }
    });
  }

  void _moveLeft(int i) {
    if (i <= 0) return;
    setState(() {
      final item = _imagePaths.removeAt(i);
      _imagePaths.insert(i - 1, item);
    });
  }

  void _moveRight(int i) {
    if (i >= _imagePaths.length - 1) return;
    setState(() {
      final item = _imagePaths.removeAt(i);
      _imagePaths.insert(i + 1, item);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final repo = ref.read(coinRepositoryProvider);
    final isEdit = widget.series != null;
    final id = isEdit ? widget.series!.id : const Uuid().v4();

    final companion = SeriesCompanion(
      id: drift.Value(id),
      name: drift.Value(_nameCtrl.text.trim()),
      description: drift.Value(_descCtrl.text.trim()),
      createdAt: isEdit ? drift.Value(widget.series!.createdAt) : drift.Value(DateTime.now()),
    );

    if (isEdit) {
      await repo.updateSeries(companion);
    } else {
      await repo.insertSeries(companion);
    }

    await repo.replaceSeriesImages(id, _imagePaths);

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.series == null ? '添加系列' : '系列详情'),
        actions: [
          IconButton(onPressed: _save, icon: const Icon(Icons.check)),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: CoinImageWidget(
                  imagePath: _imagePaths.isNotEmpty ? _imagePaths.first : null,
                  imageBytes: _imagePaths.isNotEmpty ? _imageBytesMap[_imagePaths.first] : null,
                  width: 140,
                  height: 140,
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _addImages,
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('添加系列图片'),
              ),
              if (_imagePaths.isNotEmpty)
                SizedBox(
                  height: 120,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _imagePaths.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      return Container(
                        width: 120,
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          border: Border.all(color: i == 0 ? Colors.blue : Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Expanded(
                              child: CoinImageWidget(
                                imagePath: _imagePaths[i],
                                imageBytes: _imageBytesMap[_imagePaths[i]],
                                width: 108,
                                height: 72,
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                IconButton(onPressed: () => _moveLeft(i), icon: const Icon(Icons.arrow_left, size: 18)),
                                Text(i == 0 ? '封面' : '#${i + 1}', style: const TextStyle(fontSize: 11)),
                                IconButton(onPressed: () => _moveRight(i), icon: const Icon(Icons.arrow_right, size: 18)),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: '系列名称 *', border: OutlineInputBorder()),
                validator: (v) => v == null || v.trim().isEmpty ? '系列名称不能为空' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descCtrl,
                maxLines: 4,
                decoration: const InputDecoration(labelText: '系列介绍', border: OutlineInputBorder(), alignLabelWithHint: true),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
