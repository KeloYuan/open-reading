part of 'settings_page.dart';

extension _SettingsPageCoverActions on _SettingsPageState {
  void _showRestartDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.restart_alt, color: Colors.orange),
            SizedBox(width: 8),
            Text('需要重启应用'),
          ],
        ),
        content: const Text('书源功能的开启/关闭需要重启应用才能生效。\n\n是否现在重启应用？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('稍后'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Flutter 在 iOS 上不推荐主动退出应用，统一提示用户手动重启。
              _showInfoPopup('请手动重启应用以应用设置');
            },
            child: const Text('重启'),
          ),
        ],
      ),
    );
  }

  void _showInfoPopup(String message) {
    showSideToast(context, message);
  }
}
