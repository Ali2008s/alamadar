import 'package:firebase_database/firebase_database.dart';
import 'package:almadar/data/models.dart';
import 'package:almadar/data/admin_models.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'package:almadar/core/security_utils.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class DataService {
  final FirebaseDatabase _db = FirebaseDatabase.instance;

  // --- Security & Apps Settings ---

  // Get current device ID
  Future<String> getDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    String id = 'unknown_device';
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      id = androidInfo.id;
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      id = iosInfo.identifierForVendor ?? 'unknown_ios';
    } else if (Platform.isWindows) {
      final windowsInfo = await deviceInfo.windowsInfo;
      id = windowsInfo.deviceId;
    }
    // Sanitize for Firebase paths: Remove characters that cause errors
    return id.replaceAll(RegExp(r'[.#$\[\]/]'), '_');
  }

  // Fetch security settings
  Stream<Map<String, dynamic>> getSecuritySettings() {
    return _db.ref('settings/security').onValue.asyncMap((event) async {
      final data = event.snapshot.value as Map<dynamic, dynamic>? ?? {};
      return {
        'adminEmail': data['adminEmail'] ?? 'hmwshy402@gmail.com',
        'adminPassword': await SecurityUtils.decrypt(
          data['adminPassword'] ?? '',
        ),
        'userCode': await SecurityUtils.decrypt(data['userCode'] ?? '9999'),
        'isUserLoginAllowed': data['isUserLoginAllowed'] ?? true,
        'authorizedDeviceId': data['authorizedDeviceId'] ?? '',
      };
    }).asBroadcastStream();
  }

  /// Returns (isValid, codeId)
  Future<(bool, String?)> validateActivationCode(
    String code,
    String deviceId,
  ) async {
    final snapshot = await _db.ref('activation_codes').get();
    if (!snapshot.exists) return (false, null);

    final data = snapshot.value as Map<dynamic, dynamic>;
    for (final entry in data.entries) {
      final val = entry.value as Map<dynamic, dynamic>;
      
      // Decrypt stored code to compare
      final decryptedCode = await SecurityUtils.decrypt(val['code'] ?? '');
      if (decryptedCode == code.trim().toUpperCase()) {
        
        // 1. Calculate expiry if not set (first use)
        final int durationDays = val['durationDays'] ?? 30; // Default 30 days
        final now = DateTime.now().millisecondsSinceEpoch;
        
        if (val['isUsed'] == true) {
          if (val['usedByDevice'] != deviceId) return (false, null);
          
          // Check if already expired
          final expiry = val['expiryDate'] ?? 0;
          if (expiry > 0 && now > expiry) return (false, null);
          
          return (true, entry.key.toString());
        }

        // Mark as used and set expiry
        final expiryDate = now + (durationDays * 24 * 60 * 60 * 1000);
        
        await _db.ref('activation_codes/${entry.key}').update({
          'isUsed': true,
          'usedByDevice': deviceId,
          'usedAt': now,
          'expiryDate': expiryDate,
        });

        // Track unique device
        await _db.ref('activated_devices/$deviceId').set({
          'code': SecurityUtils.encrypt(code),
          'activatedAt': now,
          'expiryDate': expiryDate,
          'lastSeen': now,
        });
        
        return (true, entry.key.toString());
      }
    }
    return (false, null);
  }

  // Update presence to track "Active Now" users
  Future<void> updateUserPresence(String deviceId) async {
    try {
      await _db.ref('activated_devices/$deviceId').update({
        'lastSeen': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (_) {}
  }

  // Admin Stats for Dashboard (Secured to Admin Email)
  Stream<Map<String, dynamic>> getAdminStats(String? userEmail) {
    if (userEmail != 'hmwshy402@gmail.com') return const Stream.empty();
    
    final devicesRef = _db.ref('activated_devices');
    final channelsRef = _db.ref('channels');

    return FirebaseDatabase.instance.ref().child('activated_devices').onValue.asyncMap((event) async {
       final devicesSnap = await devicesRef.get();
       final channelsSnap = await channelsRef.get();
       
       final activatedDevices = devicesSnap.value as Map? ?? {};
       final channelsCount = channelsSnap.children.length;
       
       final now = DateTime.now().millisecondsSinceEpoch;
       int onlineCount = 0;
       activatedDevices.forEach((key, val) {
         final lastSeen = (val as Map)['lastSeen'] ?? 0;
         if (now - lastSeen < (5 * 60 * 1000)) {
           onlineCount++;
         }
       });

       return {
         'totalDevices': activatedDevices.length,
         'onlineUsers': onlineCount,
         'totalChannels': channelsCount,
         'totalRegisteredUsers': (await _db.ref('users').get()).children.length,
       };
    });
  }

  // --- App Download & User Stats ---
  
  // Increment total downloads (unique per device)
  Future<void> logNewInstall(String deviceId) async {
    final ref = _db.ref('stats/installs/$deviceId');
    final snap = await ref.get();
    
    if (!snap.exists) {
      // Use ServerValue.timestamp as a simple flag
      await ref.set(ServerValue.timestamp);
    }
  }

  // Stream for public download count (unique recorded installs)
  Stream<int> getDownloadCount() {
    return _db.ref('stats/installs').onValue.map((event) {
      if (event.snapshot.value == null) return 0;
      return event.snapshot.children.length;
    });
  }

  // Track activation status for a device with expiry check
  Stream<bool> getActivationStatus(String deviceId) {
    return _db.ref('activated_devices/$deviceId').onValue.map((event) {
      if (!event.snapshot.exists) return false;
      
      final data = event.snapshot.value as Map<dynamic, dynamic>;
      final expiry = data['expiryDate'] ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      
      // Update presence while checking status
      updateUserPresence(deviceId);
      
      if (expiry > 0 && now > expiry) return false;
      return true;
    }).asBroadcastStream();
  }

  // App Config Stream (Maintenance, Updates)
  Stream<AppConfig> getAppConfig() {
    return _db.ref('settings/config').onValue.asyncMap((event) async {
      final data = event.snapshot.value as Map<dynamic, dynamic>? ?? {};
      return await AppConfig.fromMap(data);
    }).asBroadcastStream();
  }

  // --- Categories ---
  Stream<List<Category>> getCategories() {
    return _db.ref('categories').onValue.map((event) {
      final value = event.snapshot.value;
      List<Category> categories = [];

      if (value is Map) {
        value.forEach((key, val) {
          if (val != null) {
            categories.add(
              Category.fromMap(Map<String, dynamic>.from(val), key.toString()),
            );
          }
        });
      } else if (value is List) {
        for (int i = 0; i < value.length; i++) {
          if (value[i] != null) {
            categories.add(
              Category.fromMap(
                Map<String, dynamic>.from(value[i]),
                i.toString(),
              ),
            );
          }
        }
      }
      // Sort by 'order' field if exists, otherwise keep insertion order
      categories.sort((a, b) => a.order.compareTo(b.order));
      return categories;
    }).asBroadcastStream();
  }

  // --- Channels ---
  Stream<List<Channel>> getChannels(String categoryId) {
    return _db.ref('channels').onValue.asyncMap((event) async {
      final value = event.snapshot.value;
      List<Channel> channels = [];
      if (value == null) return <Channel>[];

      Future<void> processItem(dynamic key, dynamic val) async {
        if (val == null) return;
        try {
          final map = Map<dynamic, dynamic>.from(val);
          // Check both 'categoryId' and 'category_id' to be safe
          final dbCatId = (map['categoryId'] ?? map['category_id'])
              ?.toString()
              .trim();
          final targetCatId = categoryId.trim();

          // Match found
          if (dbCatId != null && dbCatId == targetCatId) {
            channels.add(
              await Channel.fromMap(
                Map<String, dynamic>.from(val),
                key.toString(),
              ),
            );
          }
        } catch (e) {
          // If one item fails, don't crash the whole screen
        }
      }

      if (value is Map) {
        for (var entry in value.entries) {
          await processItem(entry.key, entry.value);
        }
      } else if (value is List) {
        for (int i = 0; i < value.length; i++) {
          await processItem(i, value[i]);
        }
      }
      // Sort channels by 'order' field if available
      channels.sort((a, b) => a.order.compareTo(b.order));
      return channels;
    }).asBroadcastStream();
  }

  Stream<List<Channel>> getAllChannels() {
    return _db.ref('channels').onValue.asyncMap((event) async {
      final value = event.snapshot.value;
      List<Channel> channels = [];

      if (value is Map) {
        for (var entry in value.entries) {
          channels.add(
            await Channel.fromMap(
              Map<String, dynamic>.from(entry.value),
              entry.key.toString(),
            ),
          );
        }
      } else if (value is List) {
        for (int i = 0; i < value.length; i++) {
          if (value[i] != null) {
            channels.add(
              await Channel.fromMap(
                Map<String, dynamic>.from(value[i]),
                i.toString(),
              ),
            );
          }
        }
      }
      return channels;
    }).asBroadcastStream();
  }

  // --- Xtream Caching ---
  final Map<String, List<Map<String, dynamic>>> _xtreamCategoriesCache = {};
  final Map<String, List<Map<String, dynamic>>> _xtreamContentCache = {};
  String? _lastXtreamAccountHash;

  // --- Our World ---
  Stream<List<Map<String, dynamic>>> getOurWorldCategories(String type) {
    return Stream.fromFuture(
      _fetchOurWorldCategories(type),
    ).asBroadcastStream();
  }

  Future<List<Map<String, dynamic>>> _fetchOurWorldCategories(
    String type,
  ) async {
    try {
      final account = await getActiveXtreamAccount().first;
      if (account == null) {
        return [];
      }

      final currentHash = "${account['host']}_${account['username']}";
      if (_lastXtreamAccountHash != currentHash) {
        _xtreamCategoriesCache.clear();
        _xtreamContentCache.clear();
        _lastXtreamAccountHash = currentHash;
      }

      final cacheKey = type;
      if (_xtreamCategoriesCache.containsKey(cacheKey)) {
        return _xtreamCategoriesCache[cacheKey]!;
      }

      String action = '';
      if (type == 'live')
        action = 'get_live_categories';
      else if (type == 'movies')
        action = 'get_vod_categories';
      else if (type == 'series')
        action = 'get_series_categories';

      final url =
          "${account['host']}/player_api.php?username=${account['username']}&password=${account['password']}&action=$action";
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final result = data
            .map(
              (e) => {
                'id': e['category_id']?.toString() ?? '',
                'name': e['category_name']?.toString() ?? '',
              },
            )
            .toList();

        _xtreamCategoriesCache[cacheKey] = result;
        return result;
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  Stream<List<Map<String, dynamic>>> getOurWorldContent(
    String type, {
    String? categoryId,
    String? searchQuery,
  }) {
    return Stream.fromFuture(
      _fetchOurWorldContent(
        type,
        categoryId: categoryId,
        searchQuery: searchQuery,
      ),
    ).asBroadcastStream();
  }

  Future<List<Map<String, dynamic>>> _fetchOurWorldContent(
    String type, {
    String? categoryId,
    String? searchQuery,
  }) async {
    try {
      final account = await getActiveXtreamAccount().first;
      if (account == null) {
        return [];
      }

      final currentHash = "${account['host']}_${account['username']}";
      if (_lastXtreamAccountHash != currentHash) {
        _xtreamCategoriesCache.clear();
        _xtreamContentCache.clear();
        _lastXtreamAccountHash = currentHash;
      }

      final cacheKey = "${type}_${categoryId ?? 'all'}";

      // If performing a global search (categoryId == null && searchQuery != null)
      // We will fetch ALL content (which is cached) and then filter it locally

      if (_xtreamContentCache.containsKey(cacheKey)) {
        final cachedData = _xtreamContentCache[cacheKey]!;
        if (searchQuery != null && searchQuery.isNotEmpty) {
          final q = searchQuery.toLowerCase();
          final filtered = cachedData
              .where(
                (item) => (item['name'] as String).toLowerCase().contains(q),
              )
              .toList();
          return filtered.take(50).toList(); // Limit to top 50 matches
        }
        return cachedData;
      }

      String action = '';
      if (type == 'live' || type == 'channels')
        action = 'get_live_streams';
      else if (type == 'movies' || type == 'movie')
        action = 'get_vod_streams';
      else if (type == 'series')
        action = 'get_series';

      String url =
          "${account['host']}/player_api.php?username=${account['username']}&password=${account['password']}&action=$action";
      if (categoryId != null && categoryId != 'all') {
        url += "&category_id=$categoryId";
      }

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final mappedData = data.map((e) {
          String id = '';
          if (action == 'get_live_streams' || action == 'get_vod_streams') {
            id = e['stream_id']?.toString() ?? '';
          } else {
            id = e['series_id']?.toString() ?? '';
          }

          String name = (e['name'] ?? e['title'] ?? '').toString();
          String extension =
              e['container_extension'] ??
              (type == 'series' ? 'mp4' : (type == 'live' ? '' : 'mp4'));
          String streamType = type == 'live' || type == 'channels'
              ? 'live'
              : (type == 'movies' || type == 'movie' ? 'movie' : 'series');
          String streamUrl = '';

          if (streamType == 'live') {
            // Standard live format: host/user/pass/id
            streamUrl =
                "${account['host']}/${account['username']}/${account['password']}/$id";
            // Optional: if specific extensions are rigidly required by the user's provider for live, you can append `.$extension`.
            // But usually Xtream API Live Streams are requested dynamically.
          } else {
            streamUrl =
                "${account['host']}/$streamType/${account['username']}/${account['password']}/$id.$extension";
          }

          return {
            'id': id,
            'name': name,
            'logo': e['stream_icon'] ?? e['cover'] ?? '',
            'url': streamUrl,
            'category_id': e['category_id']?.toString() ?? categoryId,
          };
        }).toList();

        // Save to cache
        _xtreamContentCache[cacheKey] = mappedData;

        // If performing a global search (categoryId == null && searchQuery != null)
        // filter the data locally before returning to avoid overloading UI with 10k+ items
        if (searchQuery != null && searchQuery.isNotEmpty) {
          final q = searchQuery.toLowerCase();
          final filtered = mappedData
              .where(
                (item) => (item['name'] as String).toLowerCase().contains(q),
              )
              .toList();
          // Limit to top 50 matches per category to save UI memory
          return filtered.take(50).toList();
        }

        return mappedData;
      } else {
        return [];
      }
    } catch (e) {
      // If network fails, try to return cache if it exists as fallback
      final cacheKey = "${type}_${categoryId ?? 'all'}";
      if (_xtreamContentCache.containsKey(cacheKey)) {
        return _xtreamContentCache[cacheKey]!;
      }
      return [];
    }
  }

  Stream<Map<String, dynamic>?> getActiveXtreamAccount() {
    return _db.ref('xtream_accounts').onValue.asyncMap((event) async {
      final value = event.snapshot.value;
      if (value == null || value is! Map) return null;
      
      final data = Map<dynamic, dynamic>.from(value);
      if (data.isEmpty) return null;
      
      final firstRaw = data.values.first;
      if (firstRaw == null || firstRaw is! Map) return null;
      
      final first = Map<String, dynamic>.from(firstRaw);
      return {
        ...first,
        'host': await SecurityUtils.decrypt(first['host'] ?? ''),
        'username': await SecurityUtils.decrypt(first['username'] ?? ''),
        'password': await SecurityUtils.decrypt(first['password'] ?? ''),
      };
    }).asBroadcastStream();
  }

  // --- Settings / Ticker ---
  Stream<String> getTickerText() {
    return _db.ref('settings/general/tickerText').onValue.map((event) {
      return event.snapshot.value?.toString() ?? '';
    }).asBroadcastStream();
  }
}
