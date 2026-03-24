class DramaBanner {
  final int id;
  final int seriesId;
  final String title;
  final String poster;
  final String banner;
  final String story;
  final List<String> genres;

  DramaBanner({
    required this.id,
    required this.seriesId,
    required this.title,
    required this.poster,
    required this.banner,
    required this.story,
    required this.genres,
  });

  factory DramaBanner.fromJson(Map<String, dynamic> json) {
    return DramaBanner(
      id: json['id'] ?? 0,
      seriesId: json['series_id'] ?? 0,
      title: json['title_ar'] ?? json['title_en'] ?? '',
      poster: json['poster'] ?? '',
      banner: json['banner'] ?? '',
      story: json['story'] ?? '',
      genres: json['genres'] != null ? List<String>.from(json['genres']) : [],
    );
  }
}

class DramaSection {
  final int id;
  final String type;
  final String title;
  final List<DramaItem> items;

  DramaSection({
    required this.id,
    required this.type,
    required this.title,
    required this.items,
  });

  factory DramaSection.fromJson(Map<String, dynamic> json) {
    var list = json['items'] as List? ?? [];
    return DramaSection(
      id: json['id'] ?? 0,
      type: json['section_type'] ?? '',
      title: json['title_ar'] ?? json['title_en'] ?? '',
      items: list.map((i) => DramaItem.fromJson(i)).toList(),
    );
  }
}

class DramaCountry {
  final int id;
  final String code;
  final String name;

  DramaCountry({required this.id, required this.code, required this.name});

  factory DramaCountry.fromJson(Map<String, dynamic> json) {
    return DramaCountry(
      id: json['id'] ?? 0,
      code: json['country_code'] ?? '',
      name: json['country_name'] ?? '',
    );
  }

  String get flagUrl => 'https://flagcdn.com/w80/${code.toLowerCase()}.png';
}

class DramaItem {
  final int id;
  final String title;
  final String? story;
  final String poster;
  final String banner;
  final String? releaseYear;
  final int? episodeCount;
  final int? episodeNumber;
  final String? seriesTitle;

  DramaItem({
    required this.id,
    required this.title,
    this.story,
    required this.poster,
    required this.banner,
    this.releaseYear,
    this.episodeCount,
    this.episodeNumber,
    this.seriesTitle,
  });

  factory DramaItem.fromJson(Map<String, dynamic> json) {
    return DramaItem(
      id: json['id'] ?? 0,
      title: json['title_ar'] ?? json['series_title'] ?? json['title'] ?? '',
      story: json['story'],
      poster:
          json['poster'] ?? json['series_poster'] ?? json['thumbnail'] ?? '',
      banner: json['banner'] ?? json['series_banner'] ?? '',
      releaseYear: json['release_year'],
      episodeCount: json['episode_count'],
      episodeNumber: json['episode_number'],
      seriesTitle: json['series_title'],
    );
  }
}

class EpisodeDetails {
  final int id;
  final int episodeNumber;
  final String? title;
  final String? description;
  final String thumbnail;
  final String seriesTitle;
  final String seriesPoster;
  final List<WatchLink> watchLinks;

  EpisodeDetails({
    required this.id,
    required this.episodeNumber,
    this.title,
    this.description,
    required this.thumbnail,
    required this.seriesTitle,
    required this.seriesPoster,
    required this.watchLinks,
  });

  factory EpisodeDetails.fromJson(Map<String, dynamic> json) {
    var data = json['data'];
    var links = data['watch_links'] as List? ?? [];
    return EpisodeDetails(
      id: data['id'] ?? 0,
      episodeNumber: data['episode_number'] ?? 0,
      title: data['title'],
      description: data['description'],
      thumbnail: data['thumbnail'] ?? '',
      seriesTitle: data['series_title'] ?? '',
      seriesPoster: data['series_poster'] ?? '',
      watchLinks: links.map((l) => WatchLink.fromJson(l)).toList(),
    );
  }
}

class WatchLink {
  final int id;
  final String serverName;
  final String url;
  final String quality;

  WatchLink({
    required this.id,
    required this.serverName,
    required this.url,
    required this.quality,
  });

  factory WatchLink.fromJson(Map<String, dynamic> json) {
    return WatchLink(
      id: json['id'] ?? 0,
      serverName: json['server_name'] ?? '',
      url: json['url'] ?? '',
      quality: json['quality'] ?? '',
    );
  }
}

class SeriesDetails {
  final int id;
  final String title;
  final String story;
  final String poster;
  final String banner;
  final String releaseYear;
  final String country;
  final String status;
  final List<Season> seasons;

  SeriesDetails({
    required this.id,
    required this.title,
    required this.story,
    required this.poster,
    required this.banner,
    required this.releaseYear,
    required this.country,
    required this.status,
    required this.seasons,
  });

  factory SeriesDetails.fromJson(Map<String, dynamic> json) {
    var data = json['data'];
    var seasonsList = data['seasons'] as List? ?? [];
    return SeriesDetails(
      id: data['id'] ?? 0,
      title: data['title_ar'] ?? data['title_en'] ?? '',
      story: data['story'] ?? '',
      poster: data['poster'] ?? '',
      banner: data['banner'] ?? '',
      releaseYear: data['release_year'] ?? '',
      country: data['country_name'] ?? data['country'] ?? '',
      status: data['status'] ?? '',
      seasons: seasonsList.map((s) => Season.fromJson(s)).toList(),
    );
  }
}

class Season {
  final int id;
  final int seasonNumber;
  final int episodesCount;

  Season({
    required this.id,
    required this.seasonNumber,
    required this.episodesCount,
  });

  factory Season.fromJson(Map<String, dynamic> json) {
    return Season(
      id: json['id'] ?? 0,
      seasonNumber: json['season_number'] ?? 0,
      episodesCount: json['episodes_count'] ?? 0,
    );
  }
}
