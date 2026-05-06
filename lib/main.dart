import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/home_screen.dart';
import 'providers/sync_providers.dart';
import 'utils/logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化日志系统
  await AppLogger.init();
  AppLogger.info('APP', '应用启动中...');

  // 捕获 Flutter 框架错误
  FlutterError.onError = (FlutterErrorDetails details) {
    AppLogger.error('APP', 'FlutterError: ${details.exceptionAsString()}', details.stack);
    FlutterError.presentError(details);
  };

  // 捕获未处理的异步/平台错误
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    AppLogger.error('APP', 'Uncaught platform error: $error', stack);
    return false;
  };

  // 避免构建异常时整页白屏
  ErrorWidget.builder = (FlutterErrorDetails details) {
    AppLogger.error('APP', 'ErrorWidget: ${details.exceptionAsString()}', details.stack);
    return Material(
      color: Colors.white,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Application crashed during rendering.\n\n${details.exceptionAsString()}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
        ),
      ),
    );
  };

  runZonedGuarded(() async {
    // 禁用 Web 环境下浏览器的默认右键菜单
    if (kIsWeb) {
      BrowserContextMenu.disableContextMenu();
    }

    // 初始化 SharedPreferences
    final prefs = await SharedPreferences.getInstance();

    runApp(
      // 引入 Riverpod 的 ProviderScope，并注入已初始化的 prefs
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const CoinManagerApp(),
      ),
    );
  }, (Object error, StackTrace stack) {
    AppLogger.error('APP', 'runZonedGuarded error: $error', stack);
  });
}

class CoinManagerApp extends StatelessWidget {
  const CoinManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '纪念币收藏管理',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueGrey,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}