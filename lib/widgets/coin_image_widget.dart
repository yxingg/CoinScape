import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class CoinImageWidget extends StatelessWidget {
  final String? imagePath;
  final Uint8List? imageBytes;
  final double width;
  final double height;
  final BoxFit fit;
  final bool enablePreview;
  final String? previewTitle;

  const CoinImageWidget({
    super.key,
    this.imagePath,
    this.imageBytes,
    this.width = 64,
    this.height = 64,
    this.fit = BoxFit.contain,
    this.enablePreview = false,
    this.previewTitle,
  });

  @override
  Widget build(BuildContext context) {
    final child = _buildImage();

    if (!enablePreview) {
      return child;
    }

    return GestureDetector(
      onTap: () => _openPreview(context),
      child: child,
    );
  }

  Widget _buildImage() {
    // 1. 如果新选了图片放在了内存里，优先加载
    if (imageBytes != null) {
      return Image.memory(imageBytes!, width: width, height: height, fit: fit);
    }

    if (imagePath == null || imagePath!.isEmpty) {
      return _buildPlaceholder();
    }

    // 2. 根据平台处理逻辑
    if (kIsWeb) {
      if (imagePath!.startsWith('base64:')) {
        try {
          final bytes = base64Decode(imagePath!.substring(7));
          return Image.memory(bytes, width: width, height: height, fit: fit);
        } catch (e) {
          return _buildPlaceholder();
        }
      }
      return _buildPlaceholder();
    } else {
      // 原生环境：组装完整路径
      return FutureBuilder<Directory>(
        future: getApplicationDocumentsDirectory(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            final file = File(p.join(snapshot.data!.path, imagePath!.replaceAll('/', p.separator)));
            if (file.existsSync()) {
              return Image.file(file, width: width, height: height, fit: fit);
            } else {
              return _buildPlaceholder();
            }
          }
          return SizedBox(width: width, height: height, child: const Center(child: CircularProgressIndicator()));
        },
      );
    }
  }

  void _openPreview(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(child: Text(previewTitle ?? '图片预览', style: Theme.of(ctx).textTheme.titleMedium)),
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 8),
              Flexible(
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4,
                  child: _buildImage(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.image_not_supported, size: width * 0.5, color: Colors.grey.shade400),
    );
  }
}
