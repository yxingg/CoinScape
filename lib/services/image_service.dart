import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as p;

class ImageData {
  final String? path;
  final Uint8List? bytes;
  ImageData({this.path, this.bytes});
}

class ImageService {
  static final ImagePicker _picker = ImagePicker();

  static Future<List<ImageData>> pickImages() async {
    final pickedFiles = await _picker.pickMultiImage();
    if (pickedFiles.isEmpty) return [];

    final result = <ImageData>[];
    for (final file in pickedFiles) {
      if (kIsWeb) {
        final bytes = await file.readAsBytes();
        result.add(ImageData(path: 'base64:${base64Encode(bytes)}', bytes: bytes));
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final imagesDir = Directory(p.join(directory.path, 'images'));
        if (!await imagesDir.exists()) {
          await imagesDir.create(recursive: true);
        }
        final fileName = '${const Uuid().v4()}${p.extension(file.path)}';
        await File(file.path).copy(p.join(imagesDir.path, fileName));
        result.add(ImageData(path: 'images/$fileName'.replaceAll('\\', '/')));
      }
    }
    return result;
  }

  /// 唤起跨平台选择图片面板
  static Future<ImageData?> pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return null;

    if (kIsWeb) {
      // Web 端：读取流，转为 base64 保存在数据库实体字段中
      final bytes = await pickedFile.readAsBytes();
      final base64Str = base64Encode(bytes);
      // 加个辨识前缀 base64:
      return ImageData(path: 'base64:$base64Str', bytes: bytes);
    } else {
      // 原生端：读取文件，拷贝进隔离目录
      final directory = await getApplicationDocumentsDirectory();
      final imagesDir = Directory(p.join(directory.path, 'images'));
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }
      final fileName = '${const Uuid().v4()}${p.extension(pickedFile.path)}';
      await File(pickedFile.path).copy(p.join(imagesDir.path, fileName));
      
      // 需求规范：跨端存取时强制将反斜杠 \ 替换为正斜杠 /
      final relativePath = 'images/$fileName'.replaceAll('\\', '/');
      return ImageData(path: relativePath);
    }
  }
}
