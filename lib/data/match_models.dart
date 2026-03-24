class MatchEvent {
  final String id;
  final int startTime;
  final int endTime;
  final String champions;
  final String commentary;
  final String channel;
  final String status;
  final String date;
  final String team1Name;
  final String team1Logo;
  final String team2Name;
  final String team2Logo;
  final List<MatchServer> servers;

  MatchEvent({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.champions,
    required this.commentary,
    required this.channel,
    required this.status,
    required this.date,
    required this.team1Name,
    required this.team1Logo,
    required this.team2Name,
    required this.team2Logo,
    this.servers = const [],
  });

  factory MatchEvent.fromJson(
    Map<String, dynamic> json,
    String calculatedStatus,
    String calculatedDate,
  ) {
    final team1 = json['team_1'] as Map<String, dynamic>? ?? {};
    final team2 = json['team_2'] as Map<String, dynamic>? ?? {};

    final serversJson =
        json['players'] ?? json['video_links'] ?? json['links'] ?? [];
    List<MatchServer> servers = [];
    if (serversJson is List) {
      servers = serversJson.map((s) => MatchServer.fromJson(s)).toList();
    }

    return MatchEvent(
      id: json['id'].toString(),
      startTime: (json['start_time'] as num?)?.toInt() ?? 0,
      endTime: (json['end_time'] as num?)?.toInt() ?? 0,
      champions: json['champions'] ?? '',
      commentary: json['commentary'] ?? '',
      channel: json['channel'] ?? '',
      status: calculatedStatus,
      date: calculatedDate,
      team1Name: team1['name'] ?? '',
      team1Logo: team1['logo'] ?? '',
      team2Name: team2['name'] ?? '',
      team2Logo: team2['logo'] ?? '',
      servers: servers,
    );
  }
}

class MatchServer {
  final String name;
  final String url;
  final String? userAgent;
  final Map<String, String>? headers;

  MatchServer({
    required this.name,
    required this.url,
    this.userAgent,
    this.headers,
  });

  factory MatchServer.fromJson(Map<String, dynamic> json) {
    Map<String, String>? headers;
    if (json['headers'] != null && json['headers'] is Map) {
      headers = (json['headers'] as Map).map(
        (k, v) => MapEntry(k.toString(), v.toString()),
      );
    }

    return MatchServer(
      name: json['name'] ?? json['title'] ?? json['quality'] ?? 'سيرفر',
      url: json['url'] ?? json['link'] ?? json['stream_url'] ?? '',
      userAgent: json['user_agent'] ?? json['userAgent'],
      headers: headers,
    );
  }
}
