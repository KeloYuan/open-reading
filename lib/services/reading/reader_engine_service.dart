import 'package:shared_preferences/shared_preferences.dart';

enum EpubLayoutEngine {
  flutter,
  foliate,
  foliateStrict,
}

class ReaderEngineService {
  static const String _epubLayoutEngineKey = 'epub_layout_engine_v2';
  static const String _legacyUseReadiumForEpubKey = 'use_readium_for_epub_v1';
  static const String _epubLayoutEngineUserSelectedKey =
      'epub_layout_engine_user_selected_v1';

  static Future<EpubLayoutEngine> getEpubLayoutEngine() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_epubLayoutEngineKey);
    final legacyUseReadium = prefs.getBool(_legacyUseReadiumForEpubKey);
    if (legacyUseReadium == true) {
      await prefs.setString(_epubLayoutEngineKey, 'flutter');
      await prefs.setBool(_epubLayoutEngineUserSelectedKey, true);
      return EpubLayoutEngine.flutter;
    }

    // Default EPUB engine: native Flutter.
    if (raw == null || raw.isEmpty) {
      await prefs.setString(_epubLayoutEngineKey, 'flutter');
      return EpubLayoutEngine.flutter;
    }

    if (raw == 'foliate') {
      return EpubLayoutEngine.foliate;
    }
    if (raw == 'foliate_strict') {
      return EpubLayoutEngine.foliateStrict;
    }

    if (raw == 'flutter') {
      final userSelected =
          prefs.getBool(_epubLayoutEngineUserSelectedKey) ?? false;
      if (!userSelected) {
        await prefs.setString(_epubLayoutEngineKey, 'flutter');
        return EpubLayoutEngine.flutter;
      }
      return EpubLayoutEngine.flutter;
    }

    await prefs.setString(_epubLayoutEngineKey, 'flutter');
    return EpubLayoutEngine.flutter;
  }

  static Future<void> setEpubLayoutEngine(EpubLayoutEngine engine) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _epubLayoutEngineKey,
      switch (engine) {
        EpubLayoutEngine.flutter => 'flutter',
        EpubLayoutEngine.foliate => 'foliate',
        EpubLayoutEngine.foliateStrict => 'foliate_strict',
      },
    );
    await prefs.setBool(_epubLayoutEngineUserSelectedKey, true);
  }

  static Future<bool> isFoliateEngineEnabledForEpub() async {
    return (await getEpubLayoutEngine()) != EpubLayoutEngine.flutter;
  }

  static Future<bool> isFoliateStrictEngineEnabledForEpub() async {
    return (await getEpubLayoutEngine()) == EpubLayoutEngine.foliateStrict;
  }
}
