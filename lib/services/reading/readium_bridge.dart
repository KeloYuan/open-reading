import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class ReadiumBridge {
  static const MethodChannel _channel =
      MethodChannel('com.niki.xxread/readium');

  static Future<bool> isAvailable() async {
    try {
      final available = await _channel.invokeMethod<bool>('isAvailable');
      return available ?? false;
    } on PlatformException catch (e) {
      debugPrint(
          'ReadiumBridge.isAvailable PlatformException: ${e.code} ${e.message}');
      return false;
    } on MissingPluginException {
      debugPrint('ReadiumBridge.isAvailable MissingPluginException');
      return false;
    } catch (e) {
      debugPrint('ReadiumBridge.isAvailable error: $e');
      return false;
    }
  }

  static Future<bool> openEpub({
    required String filePath,
    required String title,
    required String author,
  }) async {
    try {
      final opened = await _channel.invokeMethod<bool>(
        'openEpub',
        {
          'filePath': filePath,
          'title': title,
          'author': author,
        },
      );
      return opened ?? false;
    } on PlatformException catch (e) {
      debugPrint(
          'ReadiumBridge.openEpub PlatformException: ${e.code} ${e.message}');
      return false;
    } on MissingPluginException {
      debugPrint('ReadiumBridge.openEpub MissingPluginException');
      return false;
    } catch (e) {
      debugPrint('ReadiumBridge.openEpub error: $e');
      return false;
    }
  }
}
