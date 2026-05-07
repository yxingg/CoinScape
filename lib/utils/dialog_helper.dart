import 'package:flutter/material.dart';

class DialogHelper {
  /// 显示一个统一的确认对话框
  /// 
  /// 设计为圆角边框，使用Material 3的主题色调与阴影
  static Future<bool?> showConfirmDialog({
    required BuildContext context,
    required String title,
    required String content,
    String confirmText = '确认',
    String cancelText = '取消',
    bool isDestructive = false,
  }) async {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 8,
        shadowColor: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.1),
        backgroundColor: Theme.of(context).colorScheme.surface,
        surfaceTintColor: Theme.of(context).colorScheme.surfaceTint,
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        content: Text(
          content,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: Text(cancelText),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: isDestructive
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).colorScheme.primary,
              foregroundColor: isDestructive
                  ? Theme.of(context).colorScheme.onError
                  : Theme.of(context).colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: Text(confirmText),
          ),
        ],
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  /// 显示一个统一的SnackBar提示（用于成功消息）- 右上角显示
  static void showSuccessSnackBar(BuildContext context, String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    final snackBar = SnackBar(
      content: Row(
        children: [
          Icon(
            Icons.check_circle,
            color: Theme.of(context).colorScheme.onPrimary,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ],
      ),
      backgroundColor: Theme.of(context).colorScheme.primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      duration: const Duration(seconds: 3),
      margin: const EdgeInsets.only(top: 20, right: 20, left: 20),
      dismissDirection: DismissDirection.horizontal,
    );
    
    // 使用ScaffoldMessengerState的showSnackBar方法显示在顶部
    messenger.showSnackBar(snackBar);
  }

  /// 显示一个统一的SnackBar警告（用于警告消息）- 右上角显示
  static void showWarningSnackBar(BuildContext context, String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    final snackBar = SnackBar(
      content: Row(
        children: [
          Icon(
            Icons.warning_amber,
            color: Theme.of(context).colorScheme.onErrorContainer,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ],
      ),
      backgroundColor: Theme.of(context).colorScheme.errorContainer,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      duration: const Duration(seconds: 4),
      margin: const EdgeInsets.only(top: 20, right: 20, left: 20),
      dismissDirection: DismissDirection.horizontal,
    );
    
    messenger.showSnackBar(snackBar);
  }

  /// 显示一个统一的SnackBar错误（用于错误消息）- 右上角显示
  static void showErrorSnackBar(BuildContext context, String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    final snackBar = SnackBar(
      content: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: Theme.of(context).colorScheme.onError,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ],
      ),
      backgroundColor: Theme.of(context).colorScheme.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      duration: const Duration(seconds: 4),
      margin: const EdgeInsets.only(top: 20, right: 20, left: 20),
      dismissDirection: DismissDirection.horizontal,
    );
    
    messenger.showSnackBar(snackBar);
  }

  /// 显示一个统一的进度SnackBar（用于长时间操作）- 右上角显示
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showProgressSnackBar(
    BuildContext context,
    String message,
  ) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    final snackBar = SnackBar(
      content: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
        ],
      ),
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      duration: const Duration(days: 1), // 长时间显示，需要手动dismiss
      margin: const EdgeInsets.only(top: 20, right: 20, left: 20),
      dismissDirection: DismissDirection.horizontal,
    );
    
    return messenger.showSnackBar(snackBar);
  }

  /// 显示一个可自定义内容的对话框
  static Future<T?> showCustomDialog<T>({
    required BuildContext context,
    required String title,
    required Widget content,
    List<Widget>? actions,
  }) async {
    return showDialog<T>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 8,
        shadowColor: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.1),
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        content: content,
        actions: actions,
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  /// 显示一个统一的底部模态菜单
  static Future<T?> showBottomMenu<T>({
    required BuildContext context,
    required List<Widget> items,
    String? title,
  }) async {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: false,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      elevation: 8,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (title != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                const Divider(height: 24),
              ],
              ...items,
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  /// 显示一个简单的菜单项
  static Widget menuItem({
    required IconData icon,
    required String title,
    String? subtitle,
    Color? iconColor,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
    );
  }

  /// 显示一个顶部Toast消息（替代SnackBar，真正显示在右上角）
  static void showTopToast(BuildContext context, {
    required String message,
    required IconData icon,
    required Color backgroundColor,
    required Color iconColor,
    Duration duration = const Duration(seconds: 3),
  }) {
    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 20,
        right: 20,
        left: 20,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: iconColor, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    
    overlay.insert(overlayEntry);
    
    Future.delayed(duration, () {
      overlayEntry.remove();
    });
  }

  /// 显示一个统一的顶部Toast（用于成功消息）- 真正右上角显示
  static void showSuccessToast(BuildContext context, String message) {
    showTopToast(
      context,
      message: message,
      icon: Icons.check_circle,
      backgroundColor: Theme.of(context).colorScheme.primary,
      iconColor: Theme.of(context).colorScheme.onPrimary,
    );
  }

  /// 显示一个统一的顶部Toast（用于警告消息）- 真正右上角显示
  static void showWarningToast(BuildContext context, String message) {
    showTopToast(
      context,
      message: message,
      icon: Icons.warning_amber,
      backgroundColor: Theme.of(context).colorScheme.errorContainer,
      iconColor: Theme.of(context).colorScheme.onErrorContainer,
    );
  }

  /// 显示一个统一的顶部Toast（用于错误消息）- 真正右上角显示
  static void showErrorToast(BuildContext context, String message) {
    showTopToast(
      context,
      message: message,
      icon: Icons.error_outline,
      backgroundColor: Theme.of(context).colorScheme.error,
      iconColor: Theme.of(context).colorScheme.onError,
    );
  }
}