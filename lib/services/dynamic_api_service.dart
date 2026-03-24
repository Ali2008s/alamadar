import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_database/firebase_database.dart';
import 'package:almadar/data/models.dart';

class DynamicApiService {
  final FirebaseDatabase _db = FirebaseDatabase.instance;

  // Fetch all active configs from Firebase
  Stream<List<DynamicApiSourceConfig>> getActiveDynamicConfigs() {
    return _db.ref('our_world_plus/configs').onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null || data is! Map) return [];

      final list = data.entries
          .map(
            (e) => DynamicApiSourceConfig.fromMap(
              e.value as Map<dynamic, dynamic>,
              e.key.toString(),
            ),
          )
          .where((c) => c.isActive)
          .toList();

      list.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
      return list;
    });
  }

  // Helper to extract nested json value
  dynamic _extractValue(Map<String, dynamic> json, String path) {
    if (path.isEmpty) return null;
    final keys = path.split('.');
    dynamic current = json;
    for (final key in keys) {
      if (current is Map && current.containsKey(key)) {
        current = current[key];
      } else {
        return null;
      }
    }
    return current;
  }

  Future<List<DynamicContentItem>> fetchDynamicContent(
    DynamicApiSourceConfig config, {
    int page = 1,
    String query = '',
  }) async {
    try {
      String url = config.apiUrl;

      // Handle search API if provided
      if (query.isNotEmpty && config.searchApiUrl.isNotEmpty) {
        url = config.searchApiUrl.replaceAll(
          '{query}',
          Uri.encodeComponent(query),
        );
      } else if (config.paginationSupport) {
        // Simple pagination placeholder replacement
        url = url.replaceAll('{page}', page.toString());
      }

      final uri = Uri.parse(url);
      final headers = config.customHeaders.map(
        (k, v) => MapEntry(k.toString(), v.toString()),
      );

      http.Response response;
      if (config.httpMethod.toUpperCase() == 'POST') {
        response = await http.post(
          uri,
          headers: headers.isEmpty ? null : headers,
          body: config.customBody.isEmpty ? null : config.customBody,
        );
      } else {
        response = await http.get(
          uri,
          headers: headers.isEmpty ? null : headers,
        );
      }

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        List<dynamic> targetList;

        if (config.rootJsonPath.isEmpty) {
          if (decoded is List) {
            targetList = decoded;
          } else {
            return []; // Invalid root structure
          }
        } else {
          final extracted = _extractValue(decoded, config.rootJsonPath);
          if (extracted is List) {
            targetList = extracted;
          } else {
            return [];
          }
        }

        return targetList
            .map((item) {
              if (item is! Map<String, dynamic>) return null;

              String getMapped(String mapping) {
                if (mapping.isEmpty) return '';
                // Allow static fallback if not a path (e.g. if mapping is exactly "clearkey" and not found in json)
                final val = _extractValue(item, mapping);
                // If val is null, it might be a static keyword the admin wrote instead of a path.
                return val?.toString() ?? mapping;
              }

              // Strict extraction for values that must be paths
              String getStrictMapped(String mapping) {
                if (mapping.isEmpty) return '';
                return _extractValue(item, mapping)?.toString() ?? '';
              }

              List<String> qualities = [];
              if (config.multiQualityMapping.isNotEmpty) {
                final qData = _extractValue(item, config.multiQualityMapping);
                if (qData is List) {
                  qualities = qData.map((e) => e.toString()).toList();
                }
              }

              return DynamicContentItem(
                title: getStrictMapped(config.titleMapping),
                logoUrl: getStrictMapped(config.logoMapping),
                streamUrl: getStrictMapped(config.streamUrlMapping),
                categoryId: getStrictMapped(config.categoryMapping),
                description: getStrictMapped(config.descriptionMapping),
                drmType: config.drmTypeMapping.isNotEmpty
                    ? getMapped(config.drmTypeMapping)
                    : null,
                drmLicenseUrl: config.drmLicenseUrlMapping.isNotEmpty
                    ? getMapped(config.drmLicenseUrlMapping)
                    : null,
                multiQualities: qualities,
                subtitleUrl: getStrictMapped(config.subtitleUrlMapping),
              );
            })
            .where((e) => e != null && e.streamUrl.isNotEmpty)
            .cast<DynamicContentItem>()
            .toList();
      } else {
        throw Exception('API Error: ${response.statusCode}');
      }
    } catch (e) {
      // Return empty or throw depending on retry logic. Let's return empty for safe failing.
      return [];
    }
  }
}
