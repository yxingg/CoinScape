import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:flutter/widgets.dart';

// This script is intended to be run with `dart run tool/test_file_sync.dart` inside the project root.
// It boots a minimal Flutter embedding context required for some packages like path_provider.
// The script will load the app's saved config (LocalConfigService or SharedPreferences fallback)
// and call FileSyncManager.instance.pushAll(cfg) to run a test push.

import '../lib/services/file_sync.dart' as file_sync;
import '../lib/services/api_service.dart';
import '../lib/services/local_config_service.dart';

Future<Map<String, dynamic>> _loadWebDavConfigFromLocal() async {
  try {
    final cfg = await LocalConfigService.load();
    if (cfg.containsKey('webDavUrl')) {
      return {
        'url': cfg['webDavUrl'] as String? ?? '',
        'username': cfg['webDavUser'] as String? ?? '',
        'password': cfg['webDavPassword'] as String? ?? '',
        'remote_path': cfg['webDavRemotePath'] as String? ?? '',
      };
    }
  } catch (_) {}
  // fallback: try reading settings from environment variables
  final envUrl = Platform.environment['WEBDAV_URL'] ?? '';
  return {
    'url': envUrl,
    'username': Platform.environment['WEBDAV_USER'] ?? '',
    'password': Platform.environment['WEBDAV_PASSWORD'] ?? '',
    'remote_path': Platform.environment['WEBDAV_REMOTE_PATH'] ?? '',
  };
}

Future<int> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print('Loading WebDAV config from local settings...');
  final cfg = await _loadWebDavConfigFromLocal();
  if ((cfg['url'] as String).isEmpty) {
    print('No WebDAV url found in local config or environment. Set WEBDAV_URL env var or save in app settings.');
    return 2;
  }

  print('WebDAV URL: ${cfg['url']}');
  print('Starting FileSyncManager pushAll (test mode)...');

  try {
    final res = await file_sync.FileSyncManager.instance.pushAll(cfg);
    print('pushAll result:');
    print(JsonEncoder.withIndent('  ').convert(res));
  } catch (e, st) {
    print('pushAll threw: $e');
    print(st);
    return 1;
  }

  print('Done.');
  return 0;
}
