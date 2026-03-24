import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:almadar/data/match_models.dart';

class MatchService {
  static const String _baseUrl = "https://a2.apk-api.com/api/events";
  static const String _xorKey = "c!xZj+N9&G@Ev@vw";

  Future<List<MatchEvent>> getMatches() async {
    try {
      final response = await http.get(
        Uri.parse(_baseUrl),
        headers: {
          "Accept": "application/json",
          "User-Agent": "okhttp/4.12.0",
          "api_url": "http://ver3.yacinelive.com",
        },
      );

      if (response.statusCode == 200) {
        final String? tHeader = response.headers['t'];
        if (tHeader == null) throw Exception("Missing 't' header");

        final decodedBody = _decrypt(response.body, tHeader);
        final Map<String, dynamic> jsonMap = json.decode(decodedBody);
        final List<dynamic> data = jsonMap['data'] ?? [];

        final int currentTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;

        return data.map((item) {
          final int start = (item['start_time'] as num).toInt();
          final int end = (item['end_time'] as num).toInt();

          String status;
          if (currentTime >= start && currentTime <= end) {
            status = "جارية الآن";
          } else if (currentTime < start) {
            final date = DateTime.fromMillisecondsSinceEpoch(start * 1000);
            status = DateFormat('hh:mm a', 'en_US').format(date);
          } else {
            status = "إنتهت المباراة";
          }

          final dateObj = DateTime.fromMillisecondsSinceEpoch(start * 1000);
          final matchDate = DateFormat('EEEE d', 'en_US').format(dateObj);

          return MatchEvent.fromJson(item, status, matchDate);
        }).toList();
      }
    } catch (e) {
      print("Error fetching matches: $e");
    }
    return [];
  }

  String _decrypt(String response, String tHeader) {
    final Uint8List d = base64.decode(response.trim());
    final List<int> k = utf8.encode(_xorKey + tHeader);
    final Uint8List p = Uint8List(d.length);

    for (int i = 0; i < d.length; i++) {
      p[i] = d[i] ^ k[i % k.length];
    }

    return utf8.decode(p).replaceAll("\\/", "/");
  }

  /// Fetches servers for a specific match.
  /// Note: The user didn't specify the endpoint for servers, but typically
  /// it might be the same event endpoint or a separate details endpoint.
  /// Given the request "يجلب سيرفرات كل مباراة عند الضغط عليها", I'll assume
  /// we might need another API call. I'll mock this for now or refine if I find the endpoint.
  Future<List<MatchServer>> getMatchServers(String matchId) async {
    try {
      final response = await http.get(
        Uri.parse("https://a2.apk-api.com/api/event/$matchId"),
        headers: {
          "Accept": "application/json",
          "User-Agent": "okhttp/4.12.0",
          "api_url": "http://ver3.yacinelive.com",
          "Connection": "Keep-Alive",
        },
      );
      if (response.statusCode == 200) {
        final String? tHeader = response.headers['t'];
        if (tHeader != null) {
          final decodedBody = _decrypt(response.body, tHeader);
          final dynamic jsonMap = json.decode(decodedBody);

          if (jsonMap is! Map) return [];

          final dynamic data = jsonMap['data'] ?? jsonMap;
          List<dynamic>? players;

          if (data is List) {
            players = data;
          } else if (data is Map) {
            players =
                data['players'] ??
                data['video_links'] ??
                data['links'] ??
                data['streams'] ??
                data['video_link'];
          }

          if (players is List) {
            return players
                .map((s) => MatchServer.fromJson(s as Map<String, dynamic>))
                .where((s) => s.url.isNotEmpty)
                .toList();
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching servers for $matchId: $e");
    }
    return [];
  }
}
