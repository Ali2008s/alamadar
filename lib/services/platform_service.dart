import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class PlatformService {
  static const MethodChannel _channel = MethodChannel('com.almadar.security');

  /// Enables or disables display cutout support (drawing behind the notch).
  /// This is only applicable to Android.
  static Future<void> setDisplayCutoutMode(bool enabled) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod('setDisplayCutoutMode', enabled);
    } on PlatformException catch (e) {
      print("Error setting display cutout mode: ${e.message}");
    } catch (e) {
      print("Unknown error setting display cutout mode: $e");
    }
  }
}
