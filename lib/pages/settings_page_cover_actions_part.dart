part of 'settings_page.dart';

extension _SettingsPageCoverActions on _SettingsPageState {
  void _showRestartDialog({
    String reason = '该设置变更需要重启应用才能完全生效。',
  }) {
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
        content: Text('$reason\n\n是否现在重启应用？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('稍后'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              RestartableApp.restart(this.context);
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
