import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/webdav/webdav_sync_service.dart';

/// WebDAV配置对话框
class WebDavConfigDialog extends StatefulWidget {
  const WebDavConfigDialog({super.key});

  @override
  State<WebDavConfigDialog> createState() => _WebDavConfigDialogState();
}

class _WebDavConfigDialogState extends State<WebDavConfigDialog> {
  final _formKey = GlobalKey<FormState>();
  final _serverUrlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _basePathController = TextEditingController(text: '/xxread/');

  final WebDavSyncService _syncService = WebDavSyncService();
  bool _isPasswordVisible = false;
  bool _isConfiguring = false;

  @override
  void initState() {
    super.initState();
    _loadExistingConfig();
  }

  void _loadExistingConfig() {
    if (_syncService.isConfigured) {
      _serverUrlController.text = _syncService.serverUrl;
      _usernameController.text = _syncService.username;
      _basePathController.text = _syncService.basePath;
    }
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _basePathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _getDialogBackgroundColor(),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [_buildHeader(), _buildForm(), _buildActions()],
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
                  'WebDAV配置',
                  style: TextStyle(
                    color: _getTextColor(),
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '设置云端同步服务',
                  style: TextStyle(color: _getSubtitleColor(), fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _buildTextField(
              controller: _serverUrlController,
              label: '服务器地址',
              hint: 'https://example.com/webdav',
              icon: Icons.link,
              validator: (value) {
                if (value?.isEmpty ?? true) {
                  return '请输入服务器地址';
                }
                if (!value!.startsWith('http')) {
                  return '请输入有效的URL';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _usernameController,
              label: '用户名',
              hint: '输入用户名',
              icon: Icons.person,
              validator: (value) {
                if (value?.isEmpty ?? true) {
                  return '请输入用户名';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _passwordController,
              label: '密码',
              hint: '输入密码',
              icon: Icons.lock,
              isPassword: true,
              validator: (value) {
                if (_syncService.isConfigured) {
                  // 如果已配置且密码为空，使用现有密码
                  return null;
                }
                if (value?.isEmpty ?? true) {
                  return '请输入密码';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _basePathController,
              label: '基础路径（可选）',
              hint: '/xxread/',
              icon: Icons.folder,
            ),
          ],
        ),
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
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // 状态显示
          if (_syncService.status == SyncStatus.error) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _syncService.errorMessage,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // 操作按钮
          Row(
            children: [
              // 测试连接按钮
              Expanded(
                child: OutlinedButton(
                  onPressed: _isConfiguring ? null : _testConnection,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: _getIconColor()),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isConfiguring
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text('测试连接', style: TextStyle(color: _getTextColor())),
                ),
              ),
              const SizedBox(width: 12),

              // 保存按钮
              Expanded(
                child: ElevatedButton(
                  onPressed: _isConfiguring ? null : _saveConfiguration,
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

          // 取消和清除按钮
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
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
                    onPressed: _clearConfiguration,
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
      _isConfiguring = true;
    });

    try {
      final password = _passwordController.text.isNotEmpty
          ? _passwordController.text
          : ''; // 如果已配置，可能需要现有密码

      final success = await _syncService.configure(
        serverUrl: _serverUrlController.text.trim(),
        username: _usernameController.text.trim(),
        password: password,
        basePath: _basePathController.text.trim().isEmpty
            ? '/xxread/'
            : _basePathController.text.trim(),
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('连接测试成功！'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('连接测试失败: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isConfiguring = false;
        });
      }
    }
  }

  Future<void> _saveConfiguration() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isConfiguring = true;
    });

    try {
      final password = _passwordController.text.isNotEmpty
          ? _passwordController.text
          : ''; // 如果已配置，可能需要现有密码

      final success = await _syncService.configure(
        serverUrl: _serverUrlController.text.trim(),
        username: _usernameController.text.trim(),
        password: password,
        basePath: _basePathController.text.trim().isEmpty
            ? '/xxread/'
            : _basePathController.text.trim(),
      );

      if (success && mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('WebDAV配置已保存'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存配置失败: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isConfiguring = false;
        });
      }
    }
  }

  Future<void> _clearConfiguration() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认清除'),
        content: const Text('确定要清除WebDAV配置吗？这将删除所有同步设置。'),
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
      if (mounted) {
        Navigator.pop(context, false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('WebDAV配置已清除')));
      }
    }
  }

  // 主题颜色辅助方法
  Color _getDialogBackgroundColor() {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.grey[900]!
        : Colors.white;
  }

  Color _getTextColor() {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : Colors.black87;
  }

  Color _getSubtitleColor() {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.grey[400]!
        : Colors.grey[600]!;
  }

  Color _getIconColor() {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.grey[400]!
        : Colors.grey[600]!;
  }

  Color _getFieldBackgroundColor() {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.grey[800]!
        : Colors.grey[100]!;
  }
}
