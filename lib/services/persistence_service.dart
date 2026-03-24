import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class PersistenceService {
  static const String _favKey = 'favorites_list';
  static const String _historyKey = 'history_list';
  static const String _watchProgressKey = 'watch_progress';

  // --- Favorites ---
  static Future<List<Map<String, dynamic>>> getFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_favKey);
    if (data == null) return [];
    return List<Map<String, dynamic>>.from(json.decode(data));
  }

  static Future<void> toggleFavorite(Map<String, dynamic> item) async {
    final prefs = await SharedPreferences.getInstance();
    final favs = await getFavorites();
    final index = favs.indexWhere((element) => element['id'] == item['id']);
    if (index >= 0) {
      favs.removeAt(index);
    } else {
      favs.add(item);
    }
    await prefs.setString(_favKey, json.encode(favs));
  }

  static Future<bool> isFavorite(String id) async {
    final favs = await getFavorites();
    return favs.any((element) => element['id'] == id);
  }

  // --- History ---
  static Future<List<Map<String, dynamic>>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_historyKey);
    if (data == null) return [];
    return List<Map<String, dynamic>>.from(json.decode(data));
  }

  static Future<void> addToHistory(Map<String, dynamic> item) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await getHistory();
    history.removeWhere((element) => element['id'] == item['id']);
    history.insert(0, item);
    if (history.length > 20) history.removeLast();
    await prefs.setString(_historyKey, json.encode(history));
  }

  // --- Watch Progress (Resume Playback) ---
  /// Save current watch progress for a content ID
  static Future<void> saveWatchProgress(
    String contentId,
    int positionMs,
    int durationMs,
  ) async {
    if (positionMs <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_watchProgressKey);
    Map<String, dynamic> progressMap = {};
    if (data != null) {
      progressMap = Map<String, dynamic>.from(json.decode(data));
    }
    // Only save if more than 10 seconds watched and not near the end (>95%)
    final double ratio = durationMs > 0 ? positionMs / durationMs : 0;
    if (positionMs > 10000 && ratio < 0.95) {
      progressMap[contentId] = {
        'position': positionMs,
        'duration': durationMs,
        'savedAt': DateTime.now().millisecondsSinceEpoch,
      };
    } else if (ratio >= 0.95) {
      // Clear progress when near end (episode finished)
      progressMap.remove(contentId);
    }
    await prefs.setString(_watchProgressKey, json.encode(progressMap));
  }

  /// Get saved watch progress position for a content ID
  static Future<int> getWatchProgress(String contentId) async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_watchProgressKey);
    if (data == null) return 0;
    final Map<String, dynamic> progressMap = Map<String, dynamic>.from(
      json.decode(data),
    );
    final progress = progressMap[contentId];
    if (progress == null) return 0;
    return (progress['position'] as int?) ?? 0;
  }

  /// Get saved duration for a content ID
  static Future<int> getWatchDuration(String contentId) async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_watchProgressKey);
    if (data == null) return 0;
    final Map<String, dynamic> progressMap = Map<String, dynamic>.from(
      json.decode(data),
    );
    final progress = progressMap[contentId];
    if (progress == null) return 0;
    return (progress['duration'] as int?) ?? 0;
  }

  /// Clear watch progress for a content ID
  static Future<void> clearWatchProgress(String contentId) async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_watchProgressKey);
    if (data == null) return;
    final Map<String, dynamic> progressMap = Map<String, dynamic>.from(
      json.decode(data),
    );
    progressMap.remove(contentId);
    await prefs.setString(_watchProgressKey, json.encode(progressMap));
  }

  // --- Premium Unlock ---
  static const String _premiumKey = 'is_premium_unlocked';

  static Future<bool> isPremiumUnlocked() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_premiumKey) ?? false;
  }

  static Future<void> setPremiumUnlocked(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_premiumKey, value);
  }
}
