import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../services/api_service.dart';
import 'global_image_viewer.dart';

class CoinImageWidget extends StatelessWidget {
  final String? imagePath;
  final Uint8List? imageBytes;
  final double width;
  final double height;
  final BoxFit fit;
  final bool enablePreview;
  final String? previewTitle;
  final List<String>? imagePaths;
  final Map<String, Uint8List>? imageBytesMap;
  final bool useThumbnail;

  const CoinImageWidget({
    super.key,
    this.imagePath,
    this.imageBytes,
    this.width = 64,
    this.height = 64,
    this.fit = BoxFit.contain,
    this.enablePreview = false,
    this.previewTitle,
    this.imagePaths,
    this.imageBytesMap,
    this.useThumbnail = true,
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

  void _openPreview(BuildContext context) {
    final hasGallery = imagePaths != null && imagePaths!.length > 1;
    GlobalImageViewer.show(
      context,
      imagePaths: hasGallery ? imagePaths : (imagePath != null ? [imagePath!] : null),
      imageBytes: hasGallery
          ? imageBytesMap
          : (imageBytes != null ? {imagePath ?? '': imageBytes!} : null),
      initialIndex: 0,
      title: previewTitle,
    );
  }

  Widget _buildImage() {
    if (imageBytes != null) {
      return Image.memory(imageBytes!, width: width, height: height, fit: fit);
    }

    if (imagePath == null || imagePath!.isEmpty) {
      return _buildPlaceholder();
    }

    if (kIsWeb) {
      if (imagePath!.startsWith('base64:')) {
        try {
          final bytes = base64Decode(imagePath!.substring(7));
          return Image.memory(bytes, width: width, height: height, fit: fit);
        } catch (e) {
          return _buildPlaceholder();
        }
      }
      final imageUrl = useThumbnail
          ? ApiService.getThumbnailUrl(
              imagePath!,
              width: width.isInfinite ? null : width.toInt(),
              height: height.isInfinite ? null : height.toInt(),
            )
          : ApiService.getImageUrl(imagePath!);
      return Image.network(
        imageUrl,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return SizedBox(
            width: width,
            height: height,
            child: Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                    : null,
              ),
            ),
          );
        },
      );
    } else {
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
