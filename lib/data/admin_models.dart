import 'package:almadar/core/security_utils.dart';

class AdminUser {
  final String id;
  final String email;
  final String name;
  final bool canManageChannels;
  final bool canManageCategories;
  final bool canManageSettings;
  final bool canManageOurWorld;
  final bool isActive;

  AdminUser({
    required this.id,
    required this.email,
    required this.name,
    this.canManageChannels = false,
    this.canManageCategories = false,
    this.canManageSettings = false,
    this.canManageOurWorld = false,
    this.isActive = true,
  });

  factory AdminUser.fromMap(Map<dynamic, dynamic> map, String id) {
    return AdminUser(
      id: id,
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      canManageChannels: map['canManageChannels'] ?? false,
      canManageCategories: map['canManageCategories'] ?? false,
      canManageSettings: map['canManageSettings'] ?? false,
      canManageOurWorld: map['canManageOurWorld'] ?? false,
      isActive: map['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'name': name,
      'canManageChannels': canManageChannels,
      'canManageCategories': canManageCategories,
      'canManageSettings': canManageSettings,
      'canManageOurWorld': canManageOurWorld,
      'isActive': isActive,
    };
  }
}

class XtreamAccount {
  final String id;
  final String name;
  final String host;
  final String username;
  final String password;
  final bool isActive;

  XtreamAccount({
    required this.id,
    required this.name,
    required this.host,
    required this.username,
    required this.password,
    this.isActive = true,
  });

  factory XtreamAccount.fromMap(Map<dynamic, dynamic> map, String id) {
    return XtreamAccount(
      id: id,
      name: map['name'] ?? '',
      host: map['host'] ?? '',
      username: map['username'] ?? '',
      password: map['password'] ?? '',
      isActive: map['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'host': host,
      'username': username,
      'password': password,
      'isActive': isActive,
    };
  }
}

class AppConfig {
  final String currentVersion;
  final String updateUrl;
  final bool isMaintenance;
  final bool forceUpdate;
  final String maintenanceMessage;
  final String updateNotes;
  final String maintenanceEndTime;
  final bool isForceUrl;

  AppConfig({
    required this.currentVersion,
    required this.updateUrl,
    this.isMaintenance = false,
    this.forceUpdate = false,
    this.maintenanceMessage =
        'التطبيق في وضع الصيانة حالياً. يرجى العودة لاحقاً.',
    this.updateNotes = '',
    this.maintenanceEndTime = '',
    this.isForceUrl = false,
  });

  static Future<AppConfig> fromMap(Map<dynamic, dynamic> map) async {
    return AppConfig(
      currentVersion: map['currentVersion'] ?? '1.0.0',
      updateUrl: await SecurityUtils.decrypt(map['updateUrl'] ?? ''),
      isMaintenance: map['isMaintenance'] ?? false,
      forceUpdate: map['forceUpdate'] ?? false,
      maintenanceMessage:
          map['maintenanceMessage'] ??
          'التطبيق في وضع الصيانة حالياً. يرجى العودة لاحقاً.',
      updateNotes: map['updateNotes'] ?? '',
      maintenanceEndTime: map['maintenanceEndTime'] ?? '',
      isForceUrl: map['isForceUrl'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'currentVersion': currentVersion,
      'updateUrl': updateUrl,
      'isMaintenance': isMaintenance,
      'forceUpdate': forceUpdate,
      'maintenanceMessage': maintenanceMessage,
      'updateNotes': updateNotes,
      'maintenanceEndTime': maintenanceEndTime,
      'isForceUrl': isForceUrl,
    };
  }
}
