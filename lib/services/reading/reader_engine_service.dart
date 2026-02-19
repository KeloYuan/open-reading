import 'package:shared_preferences/shared_preferences.dart';

class ReaderEngineService {
  static const String _useReadiumForEpubKey = 'use_readium_for_epub_v1';

  static Future<bool> useReadiumForEpub() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_useReadiumForEpubKey) ?? false;
  }

  static Future<void> setUseReadiumForEpub(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_useReadiumForEpubKey, enabled);
  }
}
