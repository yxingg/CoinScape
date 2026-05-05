import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> exportFileAndShare(Uint8List bytes, String fileName, {String mimeType = 'application/octet-stream'}) async {
  final tempDir = await getTemporaryDirectory();
  final tempFile = File('${tempDir.path}/$fileName');
  await tempFile.writeAsBytes(bytes);
  
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(tempFile.path)],
    ),
  );
}
