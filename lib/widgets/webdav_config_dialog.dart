import 'dart:ui';

import 'package:flutter/material.dart';

import '../services/sync/webdav_sync_service.dart';
import 'side_toast.dart';

/// WebDAV配置对话框
class WebDavConfigDialog extends StatefulWidget {
  const WebDavConfigDialog({super.key});

  @override
  State<WebDavConfigDialog> createState() => _WebDavConfigDialogState();
}

class _WebDavConfigDialogState extends State<WebDavConfigDialog> {
  static const List<int> _syncIntervals = [5, 10, 15, 30, 60, 120, 240, 720];

  final _formKey = GlobalKey<FormState>();
  final _serverUrlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final WebDavSyncService _syncService = WebDavSyncService();

  bool _isPasswordVisible = false;
  bool _isWorking = false;
  bool _autoSync = true;
  int _syncInterval = 30;
  String? _statusMessage;
  bool _statusIsError = false;

  @override
  void initState() {
    super.initState();
    _loadExistingConfig();
  }

  void _loadExistingConfig() {
    if (_syncService.isConfigured) {
      _serverUrlController.text = _syncService.serverUrl;
      _usernameController.text = _syncService.username;
    }
    _autoSync = _syncService.autoSync;
    _syncInterval = _syncService.syncInterval;
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final targetWidth = screenWidth >= 1200
        ? 900.0
        : screenWidth >= 960
            ? 820.0
            : screenWidth >= 760
                ? 700.0
                : screenWidth - 20;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
      child: Dialog(
        backgroundColor: Colors.transparent,
        shadowColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 18),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
            child: Container(
              width: targetWidth,
              constraints: BoxConstraints(maxHeight: screenHeight * 0.9),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _getDialogSurfaceColor(),
                    _getDialogSurfaceColor().withValues(alpha: 0.7),
                  ],
                ),
                border: Border.all(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.55),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.16),
                    blurRadius: 28,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildHeader(),
                    _buildForm(),
                    if (_statusMessage != null) _buildStatusBanner(),
                    _buildActions(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.cloud_sync, color: Colors.blue, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'WebDAV 配置',
                  style: TextStyle(
                    color: _getTextColor(),
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '配置服务器后可同步书籍、书签、进度和书源',
                  style: TextStyle(color: _getSubtitleColor(), fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _buildTextField(
              controller: _serverUrlController,
              label: '服务器地址',
              hint: 'https://example.com/webdav/',
              icon: Icons.link,
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.isEmpty) {
                  return '请输入服务器地址';
                }
                final uri = Uri.tryParse(text);
                if (uri == null ||
                    !(uri.scheme == 'http' || uri.scheme == 'https')) {
                  return '请输入有效的 http/https 地址';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            _buildTextField(
              controller: _usernameController,
              label: '用户名',
              hint: '输入用户名',
              icon: Icons.person,
              validator: (value) {
                if (value?.trim().isEmpty ?? true) {
                  return '请输入用户名';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            _buildTextField(
              controller: _passwordController,
              label: '密码',
              hint: _syncService.isConfigured ? '留空表示保持不变' : '输入密码',
              icon: Icons.lock,
              isPassword: true,
              validator: (value) {
                if (_syncService.isConfigured) {
                  return null;
                }
                if (value?.trim().isEmpty ?? true) {
                  return '请输入密码';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            _buildSyncPreferenceCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncPreferenceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _getFieldBackgroundColor(),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.55),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.schedule, color: _getIconColor(), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '自动同步',
                  style: TextStyle(
                    color: _getTextColor(),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Switch(
                value: _autoSync,
                onChanged: _isWorking
                    ? null
                    : (value) {
                        setState(() {
                          _autoSync = value;
                        });
                      },
              ),
            ],
          ),
          Text(
            _autoSync ? '按间隔自动同步，仍可手动同步' : '关闭后仅支持手动同步',
            style: TextStyle(color: _getSubtitleColor(), fontSize: 12),
          ),
          if (_autoSync) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _syncIntervals.map((minutes) {
                final selected = minutes == _syncInterval;
                return ChoiceChip(
                  label: Text('$minutes 分钟'),
                  selected: selected,
                  onSelected: _isWorking
                      ? null
                      : (_) {
                          setState(() {
                            _syncInterval = minutes;
                          });
                        },
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBanner() {
    final color = _statusIsError ? Colors.red : Colors.green;
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(
            _statusIsError ? Icons.error_outline : Icons.check_circle_outline,
            color: color,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _statusMessage ?? '',
              style: TextStyle(color: color, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword && !_isPasswordVisible,
      validator: validator,
      style: TextStyle(color: _getTextColor()),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: _getIconColor()),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                  color: _getIconColor(),
                ),
                onPressed: () {
                  setState(() {
                    _isPasswordVisible = !_isPasswordVisible;
                  });
                },
              )
            : null,
        labelStyle: TextStyle(color: _getSubtitleColor()),
        hintStyle: TextStyle(color: _getSubtitleColor()),
        filled: true,
        fillColor: _getFieldBackgroundColor(),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.blue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
      ),
    );
  }

  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isWorking ? null : _testConnection,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: _getIconColor()),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isWorking
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text('测试连接', style: TextStyle(color: _getTextColor())),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isWorking ? null : _saveConfiguration,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('保存配置'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: _isWorking ? null : () => Navigator.pop(context),
                  child: Text(
                    '取消',
                    style: TextStyle(color: _getSubtitleColor()),
                  ),
                ),
              ),
              if (_syncService.isConfigured) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: TextButton(
                    onPressed: _isWorking ? null : _clearConfiguration,
                    child: const Text(
                      '清除配置',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isWorking = true;
      _statusMessage = null;
    });

    final success = await _syncService.testConnectionWith(
      serverUrl: _serverUrlController.text.trim(),
      username: _usernameController.text.trim(),
      password: _passwordController.text.trim(),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isWorking = false;
      _statusIsError = !success;
      _statusMessage = success
          ? '连接测试成功'
          : (_syncService.lastErrorMessage.isNotEmpty
              ? _syncService.lastErrorMessage
              : '连接测试失败');
    });

    showSideToast(context, _statusMessage!);
  }

  Future<void> _saveConfiguration() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isWorking = true;
      _statusMessage = null;
    });

    final success = await _syncService.configure(
      serverUrl: _serverUrlController.text.trim(),
      username: _usernameController.text.trim(),
      password: _passwordController.text.trim(),
      autoSync: _autoSync,
      syncInterval: _syncInterval,
    );

    if (!mounted) {
      return;
    }

    if (success) {
      showSideToast(context, 'WebDAV 配置已保存');
      Navigator.pop(context, true);
      return;
    }

    setState(() {
      _isWorking = false;
      _statusIsError = true;
      _statusMessage = _syncService.lastErrorMessage.isNotEmpty
          ? _syncService.lastErrorMessage
          : '保存失败，请检查配置后重试';
    });
    showSideToast(context, _statusMessage!);
  }

  Future<void> _clearConfiguration() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认清除'),
        content: const Text('确定要清除 WebDAV 配置吗？这将删除同步设置。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('清除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _syncService.clearConfiguration();
      if (!mounted) return;
      showSideToast(context, 'WebDAV 配置已清除');
      Navigator.pop(context, true);
    }
  }

  Color _getDialogSurfaceColor() {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xCC1A1E2A)
        : const Color(0xCCF6FAFF);
  }

  Color _getTextColor() {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : Colors.black87;
  }

  Color _getSubtitleColor() {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.grey[300]!
        : Colors.black.withValues(alpha: 0.62);
  }

  Color _getIconColor() {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.grey[400]!
        : Colors.grey[600]!;
  }

  Color _getFieldBackgroundColor() {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.white.withValues(alpha: 0.52);
  }
}
