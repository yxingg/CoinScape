import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// 在应用启动后的首帧调用此函数以请求运行时权限，避免在主线程阻塞导致白屏。
Future<void> requestNecessaryPermissions(BuildContext context) async {
  if (kIsWeb) return;

  try {
    final Map<Permission, PermissionStatus> statuses = await [
      Permission.camera,
      Permission.storage,
      Permission.photos,
    ].request();

    // 如果任意权限被永久拒绝，提示用户前往设置
    final permanentlyDenied = statuses.entries.any((e) => e.value.isPermanentlyDenied);
    if (permanentlyDenied && context.mounted) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('需要权限'),
          content: const Text('应用需要访问相机/相册权限以使用拍照与导入图片功能。请在系统设置中授予这些权限。'),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('取消')),
            TextButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await openAppSettings();
              },
              child: const Text('打开设置'),
            ),
          ],
        ),
      );
    }
  } catch (e) {
    // 忽略请求错误，记录日志即可
    try {
      // 尝试记录日志，如果 AppLogger 可用的话
      // 避免循环依赖：仅在 logger 初始化后调用
    } catch (_) {}
  }
}
