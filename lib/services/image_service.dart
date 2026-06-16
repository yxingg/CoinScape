import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'api_service.dart';
import '../utils/logger.dart';

class ImageData {
  final String? path;
  final Uint8List? bytes;
  ImageData({this.path, this.bytes});
}

class ImageService {
  static final ImagePicker _picker = ImagePicker();

  static Future<List<ImageData>> pickImages() async {
    final pickedFiles = await _picker.pickMultiImage();
    if (pickedFiles.isEmpty) {
      AppLogger.debug(logPrefixImage, '用户未选择任何图片');
      return [];
    }

    AppLogger.info(logPrefixImage, '用户选择了 ${pickedFiles.length} 张图片');
    final result = <ImageData>[];
    
    for (final file in pickedFiles) {
      if (kIsWeb) {
        final bytes = await file.readAsBytes();
        AppLogger.debug(logPrefixImage, 'Web 端读取图片: ${file.name}, 大小: ${bytes.length} bytes');
        try {
          final serverPath = await ApiService.uploadImage(bytes, file.name);
          AppLogger.info(logPrefixImage, '图片上传到后端成功: $serverPath');
          result.add(ImageData(path: serverPath, bytes: bytes));
        } catch (e) {
          AppLogger.warning(logPrefixImage, '后端上传失败，回退到 base64: $e');
          result.add(ImageData(path: 'base64:${base64Encode(bytes)}', bytes: bytes));
        }
      } else {
        final bytes = await File(file.path).readAsBytes();
        AppLogger.debug(logPrefixImage, 'Native 端读取图片: ${file.name}, 大小: ${bytes.length} bytes');
        
        final directory = await getApplicationDocumentsDirectory();
        final imagesDir = Directory(p.join(directory.path, 'images'));
        if (!await imagesDir.exists()) {
          await imagesDir.create(recursive: true);
        }

        final ext = p.extension(file.path);
        final md5Hex = md5.convert(bytes).toString();
        final fileName = '$md5Hex$ext';
        final destPath = p.join(imagesDir.path, fileName);

        if (!await File(destPath).exists()) {
          await File(file.path).copy(destPath);
        }
        
        final relativePath = 'images/$fileName'.replaceAll('\\', '/');
        AppLogger.info(logPrefixImage, '图片保存本地成功: $relativePath');
        result.add(ImageData(path: relativePath, bytes: bytes));
      }
    }
    return result;
  }

  /// 唤起跨平台选择图片面板
  static Future<ImageData?> pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return null;

    if (kIsWeb) {
      final bytes = await pickedFile.readAsBytes();
      AppLogger.debug(logPrefixImage, 'Web 端读取单张图片: ${pickedFile.name}, 大小: ${bytes.length} bytes');
      try {
        final serverPath = await ApiService.uploadImage(bytes, pickedFile.name);
        AppLogger.info(logPrefixImage, '单张图片上传到后端成功: $serverPath');
        return ImageData(path: serverPath, bytes: bytes);
      } catch (e) {
        AppLogger.warning(logPrefixImage, '后端上传失败，回退到 base64: $e');
        final base64Str = base64Encode(bytes);
        return ImageData(path: 'base64:$base64Str', bytes: bytes);
      }
    } else {
      final bytes = await File(pickedFile.path).readAsBytes();
      AppLogger.debug(logPrefixImage, 'Native 端读取单张图片: ${pickedFile.name}, 大小: ${bytes.length} bytes');
      
      final directory = await getApplicationDocumentsDirectory();
      final imagesDir = Directory(p.join(directory.path, 'images'));
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }

      final ext = p.extension(pickedFile.path);
      final md5Hex = md5.convert(bytes).toString();
      final fileName = '$md5Hex$ext';
      final destPath = p.join(imagesDir.path, fileName);

      if (!await File(destPath).exists()) {
        await File(pickedFile.path).copy(destPath);
      }
      
      final relativePath = 'images/$fileName'.replaceAll('\\', '/');
      AppLogger.info(logPrefixImage, '单张图片保存本地成功: $relativePath');
      return ImageData(path: relativePath, bytes: bytes);
    }
  }
}
