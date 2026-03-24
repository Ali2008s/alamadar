import 'package:almadar/core/security_utils.dart';

class Category {
  final String id;
  final String name;
  final String iconUrl;
  final int order;

  Category({
    required this.id,
    required this.name,
    required this.iconUrl,
    this.order = 9999,
  });

  factory Category.fromMap(Map<dynamic, dynamic> map, String id) {
    return Category(
      id: id,
      name: (map['name'] ?? '').toString(),
      iconUrl: (map['iconUrl'] ?? map['icon'] ?? '').toString(),
      order: (map['order'] as num?)?.toInt() ?? 9999,
    );
  }

  Map<String, dynamic> toMap() {
    return {'name': name, 'iconUrl': iconUrl, 'order': order};
  }
}

class Channel {
  final String id;
  final String name;
  final String logoUrl;
  final String categoryId;
  final bool isFavorite;
  final List<VideoSource> sources;
  final int order;

  Channel({
    required this.id,
    required this.name,
    required this.logoUrl,
    required this.categoryId,
    this.isFavorite = false,
    this.sources = const [],
    this.order = 9999,
  });

  static Future<Channel> fromMap(Map<dynamic, dynamic> map, String id) async {
    var rawSources = map['sources'];
    List<VideoSource> parsedSources = [];

    if (rawSources is List) {
      for (var s in rawSources) {
        if (s != null) {
          parsedSources.add(
            await VideoSource.fromMap(Map<dynamic, dynamic>.from(s)),
          );
        }
      }
    } else if (rawSources is Map) {
      for (var entry in rawSources.entries) {
        if (entry.value != null) {
          parsedSources.add(
            await VideoSource.fromMap(Map<dynamic, dynamic>.from(entry.value)),
          );
        }
      }
    } else if (map['streamUrl'] != null &&
        map['streamUrl'].toString().isNotEmpty) {
      // Fallback for old data
      parsedSources.add(
        VideoSource(quality: 'Auto', url: map['streamUrl'].toString()),
      );
    }

    return Channel(
      id: id,
      name: (map['name'] ?? '').toString(),
      logoUrl: (map['logoUrl'] ?? map['logo'] ?? '').toString(),
      categoryId: (map['categoryId'] ?? map['category_id'] ?? '').toString(),
      sources: parsedSources,
      order: (map['order'] as num?)?.toInt() ?? 9999,
    );
  }

  Future<Map<String, dynamic>> toMap() async {
    return {
      'name': name,
      'logoUrl': logoUrl,
      'categoryId': categoryId,
      'sources': await Future.wait(sources.map((s) => s.toMap()).toList()),
      'order': order,
    };
  }
}

class VideoSource {
  final String quality;
  final String url;
  final Map<String, String>? headers;
  // DRM fields
  final String? drmType; // 'widevine', 'clearkey', or null
  final String? drmLicenseUrl; // License server URL for Widevine
  final String? drmKey; // Key for ClearKey (hex "keyId:key")

  VideoSource({
    required this.quality,
    required this.url,
    this.headers,
    this.drmType,
    this.drmLicenseUrl,
    this.drmKey,
  });

  bool get hasDrm => drmType != null && drmType!.isNotEmpty;

  static Future<VideoSource> fromMap(Map<dynamic, dynamic> map) async {
    return VideoSource(
      quality: (map['quality'] ?? 'Auto').toString(),
      url: await SecurityUtils.decrypt((map['url'] ?? '').toString()),
      headers: map['headers'] != null
          ? Map<String, String>.from(map['headers'] as Map)
          : null,
      drmType: map['drmType']?.toString(),
      drmLicenseUrl: await SecurityUtils.decrypt(
        map['drmLicenseUrl']?.toString() ?? '',
      ),
      drmKey: await SecurityUtils.decrypt(map['drmKey']?.toString() ?? ''),
    );
  }

  Future<Map<String, dynamic>> toMap() async {
    return {
      'quality': quality,
      'url': await SecurityUtils.encrypt(url),
      if (headers != null) 'headers': headers,
      if (drmType != null) 'drmType': drmType,
      if (drmLicenseUrl != null)
        'drmLicenseUrl': await SecurityUtils.encrypt(drmLicenseUrl!),
      if (drmKey != null) 'drmKey': await SecurityUtils.encrypt(drmKey!),
    };
  }
}

class DynamicApiSourceConfig {
  final String id;
  final String apiUrl;
  final String httpMethod;
  final Map<String, dynamic> customHeaders;
  final String customBody;
  final String rootJsonPath;
  final String titleMapping;
  final String logoMapping;
  final String streamUrlMapping;
  final String categoryMapping;
  final String descriptionMapping;
  final String searchApiUrl;
  final bool paginationSupport;
  final int cacheDurationHours;
  final bool isActive;

  final String drmTypeMapping;
  final String drmLicenseUrlMapping;
  final String userAgent;
  final String referer;
  final bool requiresPaidSubscription;
  final List<String> allowedDeviceTypes;
  final String familyPin;
  final bool forceLandscape;
  final String videoFormatOverride;
  final String multiQualityMapping;
  final String subtitleUrlMapping;
  final List<String> geoBlockedCountries;
  final bool blockVpn;
  final bool preventScreenRecord;
  final bool enablePlaybackSaver;
  final bool autoPlayNext;

  final String tabName;
  final String tabIcon;
  final String tabColorHex;
  final String presentationMode;
  final int gridColumns;
  final double imageAspectRatio;
  final bool useGlassmorphism;
  final bool sortAlphabetically;
  final bool sortByLatest;

  final String emptyMessage;
  final bool autoRetryFailures;
  final String promotionalBannerUrl;
  final int orderIndex;

  DynamicApiSourceConfig({
    required this.id,
    this.apiUrl = '',
    this.httpMethod = 'GET',
    this.customHeaders = const {},
    this.customBody = '',
    this.rootJsonPath = '',
    this.titleMapping = '',
    this.logoMapping = '',
    this.streamUrlMapping = '',
    this.categoryMapping = '',
    this.descriptionMapping = '',
    this.searchApiUrl = '',
    this.paginationSupport = false,
    this.cacheDurationHours = 0,
    this.isActive = true,
    this.drmTypeMapping = '',
    this.drmLicenseUrlMapping = '',
    this.userAgent = '',
    this.referer = '',
    this.requiresPaidSubscription = false,
    this.allowedDeviceTypes = const ['mobile', 'tvbox'],
    this.familyPin = '',
    this.forceLandscape = false,
    this.videoFormatOverride = '',
    this.multiQualityMapping = '',
    this.subtitleUrlMapping = '',
    this.geoBlockedCountries = const [],
    this.blockVpn = false,
    this.preventScreenRecord = false,
    this.enablePlaybackSaver = false,
    this.autoPlayNext = false,
    this.tabName = 'New Tab',
    this.tabIcon = 'extension',
    this.tabColorHex = '#FFFFFF',
    this.presentationMode = 'grid',
    this.gridColumns = 3,
    this.imageAspectRatio = 0.66,
    this.useGlassmorphism = true,
    this.sortAlphabetically = false,
    this.sortByLatest = false,
    this.emptyMessage = 'لا يوجد محتوى حالياً',
    this.autoRetryFailures = true,
    this.promotionalBannerUrl = '',
    this.orderIndex = 0,
  });

  factory DynamicApiSourceConfig.fromMap(Map<dynamic, dynamic> map, String id) {
    return DynamicApiSourceConfig(
      id: id,
      apiUrl: map['apiUrl'] ?? '',
      httpMethod: map['httpMethod'] ?? 'GET',
      customHeaders: Map<String, dynamic>.from(map['customHeaders'] ?? {}),
      customBody: map['customBody'] ?? '',
      rootJsonPath: map['rootJsonPath'] ?? '',
      titleMapping: map['titleMapping'] ?? '',
      logoMapping: map['logoMapping'] ?? '',
      streamUrlMapping: map['streamUrlMapping'] ?? '',
      categoryMapping: map['categoryMapping'] ?? '',
      descriptionMapping: map['descriptionMapping'] ?? '',
      searchApiUrl: map['searchApiUrl'] ?? '',
      paginationSupport: map['paginationSupport'] ?? false,
      cacheDurationHours: map['cacheDurationHours'] ?? 0,
      isActive: map['isActive'] ?? true,
      drmTypeMapping: map['drmTypeMapping'] ?? '',
      drmLicenseUrlMapping: map['drmLicenseUrlMapping'] ?? '',
      userAgent: map['userAgent'] ?? '',
      referer: map['referer'] ?? '',
      requiresPaidSubscription: map['requiresPaidSubscription'] ?? false,
      allowedDeviceTypes: List<String>.from(
        map['allowedDeviceTypes'] ?? ['mobile', 'tvbox'],
      ),
      familyPin: map['familyPin'] ?? '',
      forceLandscape: map['forceLandscape'] ?? false,
      videoFormatOverride: map['videoFormatOverride'] ?? '',
      multiQualityMapping: map['multiQualityMapping'] ?? '',
      subtitleUrlMapping: map['subtitleUrlMapping'] ?? '',
      geoBlockedCountries: List<String>.from(map['geoBlockedCountries'] ?? []),
      blockVpn: map['blockVpn'] ?? false,
      preventScreenRecord: map['preventScreenRecord'] ?? false,
      enablePlaybackSaver: map['enablePlaybackSaver'] ?? false,
      autoPlayNext: map['autoPlayNext'] ?? false,
      tabName: map['tabName'] ?? 'New Tab',
      tabIcon: map['tabIcon'] ?? 'extension',
      tabColorHex: map['tabColorHex'] ?? '#FFFFFF',
      presentationMode: map['presentationMode'] ?? 'grid',
      gridColumns: map['gridColumns'] ?? 3,
      imageAspectRatio: (map['imageAspectRatio'] ?? 0.66).toDouble(),
      useGlassmorphism: map['useGlassmorphism'] ?? true,
      sortAlphabetically: map['sortAlphabetically'] ?? false,
      sortByLatest: map['sortByLatest'] ?? false,
      emptyMessage: map['emptyMessage'] ?? 'لا يوجد محتوى حالياً',
      autoRetryFailures: map['autoRetryFailures'] ?? true,
      promotionalBannerUrl: map['promotionalBannerUrl'] ?? '',
      orderIndex: map['orderIndex'] ?? 0,
    );
  }
}

class DynamicContentItem {
  final String title;
  final String logoUrl;
  final String streamUrl;
  final String categoryId;
  final String description;
  final String? drmType;
  final String? drmLicenseUrl;
  final List<String> multiQualities;
  final String subtitleUrl;

  DynamicContentItem({
    required this.title,
    required this.logoUrl,
    required this.streamUrl,
    this.categoryId = '',
    this.description = '',
    this.drmType,
    this.drmLicenseUrl,
    this.multiQualities = const [],
    this.subtitleUrl = '',
  });
}
