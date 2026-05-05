import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/series_list_drawer.dart';
import 'coin_list_screen.dart';


/// 控制侧边栏显示/隐藏的全局 Provider
final sidebarVisibleProvider = StateProvider<bool>((ref) => true);

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSidebarVisible = ref.watch(sidebarVisibleProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;

        if (isWide) {
          // ==============================
          // 宽屏 (Web / 桌面端) 渲染结构：
          // ------------------------------
          // | 侧边栏 (280px) |  内容展示区  |
          // ==============================
          return Scaffold(
            body: Row(
              children: [
                if (isSidebarVisible)
                  SizedBox(
                    width: 280,
                    child: Material(
                      elevation: 1,
                      child: SeriesListDrawer(onClose: () {
                        ref.read(sidebarVisibleProvider.notifier).state = false;
                      }),
                    ),
                  ),
                if (isSidebarVisible)
                  const VerticalDivider(width: 1, thickness: 1, color: Colors.black12),
                Expanded(
                  child: CoinListScreen(
                    isWide: true,
                    onToggleSidebar: () {
                      ref.read(sidebarVisibleProvider.notifier).state = !isSidebarVisible;
                    },
                  ),
                ),
              ],
            ),
          );
        } else {
          // ==============================
          // 窄屏 (移动端 Android/iOS) 渲染结构：
          // ------------------------------
          // | AppBar 带汉堡包弹出 Drawer |
          // |      纪念币列表主区域      |
          // ==============================
          final scaffoldKey = GlobalKey<ScaffoldState>();
          return Scaffold(
            key: scaffoldKey,
            drawer: const Drawer(
              child: SeriesListDrawer(),
            ),
            body: CoinListScreen(
              isWide: false,
              onToggleSidebar: () {
                scaffoldKey.currentState?.openDrawer();
              },
            ),
          );
        }
      },
    );
  }
}
