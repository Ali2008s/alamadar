import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:almadar/data/entertainment_models.dart';

class EntertainmentService {
  static const String _baseUrl = 'https://admin.dramaramadan.net/api';

  Future<Map<String, dynamic>> fetchHomeData() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/home/config.php'));
      if (response.statusCode == 200) {
        final Map<String, dynamic> json = jsonDecode(response.body);
        if (json['status'] == 'success') {
          final data = json['data'];

          final banners = (data['banners'] as List? ?? [])
              .map((b) => DramaBanner.fromJson(b))
              .toList();

          final sections = (data['sections'] as List? ?? [])
              .map((s) => DramaSection.fromJson(s))
              .toList();

          final countries = (data['browse_countries'] as List? ?? [])
              .map((c) => DramaCountry.fromJson(c))
              .toList();

          return {
            'banners': banners,
            'sections': sections,
            'countries': countries,
          };
        }
      }
      throw Exception('Failed to load home data');
    } catch (e) {
      rethrow;
    }
  }

  Future<EpisodeDetails> fetchEpisodeDetails(int id) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/episodes/show.php?id=$id'),
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> json = jsonDecode(response.body);
        if (json['status'] == 'success') {
          return EpisodeDetails.fromJson(json);
        }
      }
      throw Exception('Failed to load episode details');
    } catch (e) {
      rethrow;
    }
  }

  Future<SeriesDetails> fetchSeriesDetails(int id) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/series/show.php?id=$id'),
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> json = jsonDecode(response.body);
        if (json['status'] == 'success') {
          return SeriesDetails.fromJson(json);
        }
      }
      throw Exception('Failed to load series details');
    } catch (e) {
      rethrow;
    }
  }

  Future<List<DramaItem>> fetchEpisodes(int seasonId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/episodes/index.php?season_id=$seasonId'),
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> json = jsonDecode(response.body);
        if (json['status'] == 'success') {
          final data = json['data'] as List? ?? [];
          return data.map((i) => DramaItem.fromJson(i)).toList();
        }
      }
      throw Exception('Failed to load episodes');
    } catch (e) {
      rethrow;
    }
  }

  Future<List<DramaItem>> searchSeries(String query) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$_baseUrl/series/search.php?query=${Uri.encodeComponent(query)}',
        ),
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> json = jsonDecode(response.body);
        if (json['status'] == 'success') {
          final data = json['data'] as List? ?? [];
          return data.map((i) => DramaItem.fromJson(i)).toList();
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<DramaItem>> fetchSeriesByCountry(String countryCode) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/series/index.php?country_code=$countryCode'),
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> json = jsonDecode(response.body);
        if (json['status'] == 'success') {
          final data = json['data'] as List? ?? [];
          return data.map((i) => DramaItem.fromJson(i)).toList();
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}
