import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:almadar/data/models.dart';

class PremiumService {
  static const String _baseUrl = 'https://oneiraq.pages.dev';

  Future<List<Category>> getPremiumCategories() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/categories/categories.json'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['status'] == true && data['data'] is List) {
          return (data['data'] as List).map((cat) {
            return Category(
              id: cat['id'].toString(),
              name: cat['name'] ?? '',
              iconUrl: cat['img'] ?? '',
              order: 0,
            );
          }).toList();
        }
      }
    } catch (e) {
      print('PremiumService: Error fetching categories: $e');
    }
    return [];
  }

  Future<List<Channel>> getChannelsByCategory(String categoryId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/categories/id/$categoryId'),
      );
      if (response.statusCode == 200) {
        final List data = json.decode(utf8.decode(response.bodyBytes));
        return data.map((ch) {
          return Channel(
            id: ch['id'].toString(),
            name: ch['name'] ?? '',
            logoUrl: ch['img'] ?? '',
            categoryId: categoryId,
            sources:
                [], // To be fetched separately if needed, or we fetch all details now?
          );
        }).toList();
      }
    } catch (e) {
      print('PremiumService: Error fetching channels: $e');
    }
    return [];
  }

  Future<Channel?> getChannelDetails(String channelId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/channels/id/$channelId'),
      );
      if (response.statusCode == 200) {
        final List data = json.decode(utf8.decode(response.bodyBytes));
        final sources = data.map((s) {
          // Requirement: license is "id:key"
          // Requirement: scheme "clearkey"
          // Requirement: headers parsing

          Map<String, String>? extraHeaders;
          if (s['headers'] != null && s['headers'].toString().isNotEmpty) {
            try {
              extraHeaders = Map<String, String>.from(
                json.decode(s['headers']),
              );
            } catch (_) {}
          }

          return VideoSource(
            quality: s['name'] ?? 'Auto',
            url: s['url'] ?? '',
            headers: {
              if (s['userAgent'] != null &&
                  s['userAgent'].toString().isNotEmpty)
                'User-Agent': s['userAgent'],
              if (s['Referer'] != null && s['Referer'].toString().isNotEmpty)
                'Referer': s['Referer'],
              if (extraHeaders != null) ...extraHeaders,
            },
            drmType: s['scheme'] == 'clearkey' ? 'clearkey' : null,
            drmKey: s['license'],
          );
        }).toList();

        return Channel(
          id: channelId,
          name: '', // We should probably pass the name from the list view
          logoUrl: '',
          categoryId: '',
          sources: sources,
        );
      }
    } catch (e) {
      print('PremiumService: Error fetching details: $e');
    }
    return null;
  }
}
