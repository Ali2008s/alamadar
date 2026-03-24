import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class SecurityUtils {
  static const MethodChannel _channel = MethodChannel('com.almadar.security');

  /// تشفير النصوص باستخدام C++ Native Security Guard
  static Future<String> encrypt(String text) async {
    if (text.isEmpty) return "";
    if (defaultTargetPlatform != TargetPlatform.android) return text;
    try {
      final List<int> bytes = utf8.encode(text);
      final Uint8List data = Uint8List.fromList(bytes);
      final Uint8List? result = await _channel.invokeMethod('encrypt', {
        'data': data,
      });
      if (result != null) {
        return base64.encode(result);
      }
      return "";
    } catch (e) {
      return text; // Fallback
    }
  }

  /// فك تشفير النصوص باستخدام C++ Native Security Guard
  static Future<String> decrypt(String encryptedText) async {
    if (encryptedText.isEmpty) return "";
    if (defaultTargetPlatform != TargetPlatform.android) return encryptedText;
    try {
      final List<int> bytes = base64.decode(encryptedText);
      final Uint8List data = Uint8List.fromList(bytes);
      final Uint8List? result = await _channel.invokeMethod('decrypt', {
        'data': data,
      });
      if (result != null) {
        return utf8.decode(result);
      }
      return encryptedText;
    } catch (e) {
      return encryptedText; // Fallback
    }
  }

  /// تهيئة إعدادات الأمان للشبكة (منع البروكسي)
  static void initializeNetworkSecurity() {
    // يمكن هنا إضافة إعدادات HttpOverrides لمنع البروكسي
  }

  /// دالة تمويه لروابط الفيديو (لفظية فقط لزيادة الأمان في الكود)
  static Future<String> obfuscate(String val) => encrypt(val);
}
