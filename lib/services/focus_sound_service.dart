import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class FocusSoundService {
  FocusSoundService._internal();

  static final FocusSoundService _instance = FocusSoundService._internal();
  static FocusSoundService get instance => _instance;

  static Future<void> play({double volume = 1.0}) => _instance._play(volume: volume);

  final SoLoud _soLoud = SoLoud.instance;
  AudioSource? _audioSource;
  SoundHandle? _lastHandle;
  bool _initialized = false;
  File? _cachedAssetFile;
  String? _cachedAssetKey;

  bool enabled = true;
  final Duration _minInterval = const Duration(milliseconds: 60);
  DateTime? _lastPlay;

  String assetPath = 'assets/sounds/nav_sound.wav';

  Future<void> init({String? overrideAssetPath}) async {
    if (_initialized) return;
    if (overrideAssetPath != null) assetPath = overrideAssetPath;

    try {
      if (!_soLoud.isInitialized) {
        await _soLoud.init();
      }

      final assetFile = await _ensureLocalAssetFile();
      if (assetFile == null) {
        throw Exception('FocusSoundService: failed to prepare asset file.');
      }

      _audioSource = await _soLoud.loadFile(assetFile.path);
      _initialized = true;
    } catch (e, st) {
      debugPrint('FocusSoundService.init failed: $e\n$st');
      enabled = false;
      _initialized = false;
    }
  }

  Future<void> _play({double volume = 1.0}) async {
    if (!enabled) return;

    final now = DateTime.now();
    if (_lastPlay != null && now.difference(_lastPlay!) < _minInterval) {
      return; 
    }
    _lastPlay = now;

    try {
      if (!_initialized) {
        await init().catchError((_) {});
      }

      if (_audioSource == null) return;

      _lastHandle = await _soLoud.play(_audioSource!, volume: volume);
    } catch (e, st) {
      debugPrint('FocusSoundService._play error: $e\n$st');
    }
  }

  Future<File?> _ensureLocalAssetFile() async {
    try {
      if (_cachedAssetFile != null && _cachedAssetKey == assetPath) {
        if (await _cachedAssetFile!.exists()) {
          return _cachedAssetFile;
        }
      }

      final bytes = await rootBundle.load(assetPath);
      final tempDir = await getTemporaryDirectory();
      final focusDir = Directory(p.join(tempDir.path, 'focus_sound_cache'));
      if (!await focusDir.exists()) {
        await focusDir.create(recursive: true);
      }

      final filePath = p.join(focusDir.path, p.basename(assetPath));
      final file = File(filePath);
      await file.writeAsBytes(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        flush: true,
      );

      _cachedAssetFile = file;
      _cachedAssetKey = assetPath;
      return file;
    } catch (e, st) {
      debugPrint('FocusSoundService._ensureLocalAssetFile error: $e\n$st');
      return null;
    }
  }

  Future<void> stop() async {
    try {
      final handle = _lastHandle;
      if (handle == null) return;
      final valid = _soLoud.getIsValidVoiceHandle(handle);
      if (valid) {
        await _soLoud.stop(handle);
      }
      _lastHandle = null;
    } catch (e, st) {
      debugPrint('FocusSoundService.stop error: $e\n$st');
    }
  }

  Future<void> dispose() async {
    try {
      if (_lastHandle != null) {
        try {
          if (_soLoud.getIsValidVoiceHandle(_lastHandle!)) {
            await _soLoud.stop(_lastHandle!);
          }
        } catch (_) {}
        _lastHandle = null;
      }

      if (_audioSource != null) {
        await _soLoud.disposeSource(_audioSource!);
        _audioSource = null;
      }

      if (_cachedAssetFile != null) {
        try {
          if (await _cachedAssetFile!.exists()) {
            await _cachedAssetFile!.delete();
          }
        } catch (_) {}
        _cachedAssetFile = null;
        _cachedAssetKey = null;
      }

      if (_soLoud.isInitialized) {
        _soLoud.deinit();
      }
      _initialized = false;
    } catch (e, st) {
      debugPrint('FocusSoundService.dispose error: $e\n$st');
    }
  }
}
