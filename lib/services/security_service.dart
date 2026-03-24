import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class SecurityService {
  static const MethodChannel _channel = MethodChannel('com.almadar.security');

  /// Returns true if the device is identified as compromised (piracy apps, root, or SSL interception tools).
  static Future<bool> isDeviceCompromised() async {
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      final bool isCompromised = await _channel.invokeMethod('checkSecurity');
      return isCompromised;
    } on PlatformException catch (e) {
      print("Security Check Error: ${e.message}");
      // If we can't run the check, we err on the side of caution?
      // Or just return false to avoid blocking legitimate users if something breaks.
      return false;
    } catch (e) {
      return false;
    }
  }
}
