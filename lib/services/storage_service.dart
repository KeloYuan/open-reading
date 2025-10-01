import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static StorageService? _instance;
  static StorageService get instance {
    _instance ??= StorageService._internal();
    return _instance!;
  }
  
  StorageService._internal();

  Future<String?> getString(String key) async {
    if (kIsWeb) {
      // Web平台使用内存存储作为回退方案
      return _webStorage[key];
    } else {
      // 移动平台使用SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key);
    }
  }

  Future<void> setString(String key, String value) async {
    if (kIsWeb) {
      // Web平台使用内存存储作为回退方案
      _webStorage[key] = value;
    } else {
      // 移动平台使用SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    }
  }

  Future<void> remove(String key) async {
    if (kIsWeb) {
      _webStorage.remove(key);
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    }
  }

  Future<void> clear() async {
    if (kIsWeb) {
      _webStorage.clear();
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    }
  }

  // Web平台的内存存储
  static final Map<String, String> _webStorage = {};
}