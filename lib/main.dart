import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/home_screen.dart';
import 'providers/sync_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
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