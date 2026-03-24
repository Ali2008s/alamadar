import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:almadar/core/theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:almadar/screens/home_screen.dart';
import 'package:almadar/screens/entertainment_screen.dart';
import 'package:almadar/screens/our_world_screen.dart';
import 'package:almadar/screens/match_schedule_screen.dart';
import 'package:almadar/screens/news_screen.dart';
import 'package:almadar/screens/maintenance_screen.dart';
import 'package:provider/provider.dart';
import 'package:almadar/services/data_service.dart';
import 'package:almadar/data/admin_models.dart';
import 'package:almadar/widgets/update_dialog.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:almadar/main.dart';
import 'dart:ui';

class MainScreen extends StatefulWidget {
  final int initialIndex;
  const MainScreen({super.key, this.initialIndex = 0});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with SingleTickerProviderStateMixin {
  late int _selectedIndex;
  bool _isRailExtended = false;
  late PageController _pageController;

  final List<Widget> _screens = [
    const HomeScreen(),
    const EntertainmentScreen(),
    const OurWorldScreen(),
    const MatchScheduleScreen(),
    const NewsScreen(),
  ];

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return;
    setState(() {
      _selectedIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutQuart,
    );
  }

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _selectedIndex);

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    _listenForNotifications();
    _listenForConfigChanges();

    // Dialogs will be triggered in sequence within _listenForConfigChanges or after init.
    // We removed the automatic timed call for Telegram invite from here.
  }

  StreamSubscription? _maintenanceSubscription;
  bool _maintenancePushed = false;
  bool _isUpdateDialogShowing = false;
  static bool _sessionUpdateDialogShown = false; // Prevents re-showing optional updates in one session
  String? _lastTargetVersion;

  void _listenForConfigChanges() {
    final dataService = Provider.of<DataService>(context, listen: false);
    _maintenanceSubscription = dataService.getAppConfig().listen((config) {
      if (!mounted) return;

      debugPrint(
        "ConfigUpdate: Recv config v${config.currentVersion}, Force=${config.forceUpdate}, Maintenance=${config.isMaintenance}",
      );

      // ── Maintenance (Same as before but cleaner) ───────────────────────────
      if (config.isMaintenance && !_maintenancePushed) {
        _maintenancePushed = true;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MaintenanceScreen(config: config),
            fullscreenDialog: true,
          ),
        );
      } else if (!config.isMaintenance && _maintenancePushed) {
        _maintenancePushed = false;
        Navigator.of(context, rootNavigator: true).maybePop();
      }

      // ── Hyper-Reliable Update Logic ──────────────────────────────────────────
      _handleUpdateDetection(config);
    });
  }

  Future<void> _handleUpdateDetection(AppConfig config) async {
    try {
      final info = await PackageInfo.fromPlatform();
      final localVer = info.version.trim();
      final localFull = "${info.version}+${info.buildNumber}".trim();
      final targetVer = config.currentVersion.trim();

      // Detection logic: Compare against both 1.0.0 and 1.0.0+1
      bool needsUpdate = (targetVer != localVer && targetVer != localFull);

      if (needsUpdate) {
        bool shouldShowNow = false;

        if (config.forceUpdate) {
          // If forced, we ALWAYS show it if not already showing,
          // or if the version changed while we were showing an old forced dialog.
          if (!_isUpdateDialogShowing || _lastTargetVersion != targetVer) {
            shouldShowNow = true;
          }
        } else {
          // If optional, show ONLY ONCE per session to avoid annoying the user
          if (!_isUpdateDialogShowing && !_sessionUpdateDialogShown && _lastTargetVersion != targetVer) {
            shouldShowNow = true;
          }
        }

        if (shouldShowNow && mounted) {
          _lastTargetVersion = targetVer;
          _showUpdateDialog(config);
        }
      } else {
        debugPrint(
          "UpdateLogic: Versions match. Target:$targetVer Local:$localVer",
        );
        // NO update needed, show Telegram invitation now
        _checkTelegramInvitation();
      }
    } catch (e) {
      debugPrint("Update Detection Error: $e");
      // If update check fails, we can show Telegram invite
      _checkTelegramInvitation();
    }
  }

  // Unused field removed

  void _showUpdateDialog(AppConfig config) {
    if (_isUpdateDialogShowing) {
      navigatorKey.currentState?.pop();
    }

    _isUpdateDialogShowing = true;
    if (!config.forceUpdate) {
      _sessionUpdateDialogShown = true; // Mark as shown for the session
    }

    // Future.delayed ensures the context is fully ready
    Future.delayed(const Duration(milliseconds: 500), () {
      final context = navigatorKey.currentContext;
      if (context == null) return;

      showDialog(
        context: context,
        barrierDismissible: !config.forceUpdate,
        useRootNavigator: true,
        builder: (context) => UpdateDialog(
          updateUrl: config.updateUrl,
          isForce: config.forceUpdate,
          notes: config.updateNotes,
          isWebLink: config.isForceUrl,
        ),
      ).then((_) {
        _isUpdateDialogShowing = false;
        // After update dialog is closed (if optional), show Telegram invitation
        _checkTelegramInvitation();
      });
    });
  }

  void _showNotificationDialog(String title, String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 10),
            const Icon(
              Icons.notification_important,
              color: AppColors.accentBlue,
            ),
          ],
        ),
        content: Text(
          message,
          textAlign: TextAlign.right,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'إغلاق',
              style: TextStyle(color: AppColors.accentBlue),
            ),
          ),
        ],
      ),
    );
  }

  static bool _sessionDialogShown = false;

  Future<void> _checkTelegramInvitation() async {
    if (!_sessionDialogShown) {
      _showTelegramDialog();
      _sessionDialogShown = true;
    }
  }

  void _showTelegramDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (context) => Stack(
        children: [
          // Blurry background effect
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(color: Colors.black.withOpacity(0.3)),
            ),
          ),
          Center(
            child: Container(
              width: 280,
              margin: const EdgeInsets.symmetric(horizontal: 40),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.blue.withOpacity(0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.telegram_rounded,
                      color: Colors.blue,
                      size: 45,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'انضم لتيليجرام',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'تابع آخر التحديثات والقنوات المضافة حصرياً',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text(
                              'إخفاء',
                              style: TextStyle(color: Colors.white38),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _launchURL('https://t.me/airx4');
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              padding: const EdgeInsets.symmetric(vertical: 0),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              'انضمام',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchURL(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  StreamSubscription? _notificationSubscription;

  @override
  void dispose() {
    _pageController.dispose();
    _notificationSubscription?.cancel();
    _maintenanceSubscription?.cancel();
    super.dispose();
  }

  void _listenForNotifications() {
    final database = FirebaseDatabase.instance.ref('notifications');
    _notificationSubscription = database.onValue.listen((event) {
      if (event.snapshot.value != null) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        final bool isActive = data['active'] ?? false;
        final String message = data['message'] ?? '';
        // final int timestamp = data['timestamp'] ?? 0;

        // Simple logic to prevent multiple dialogs for same old notification
        // In a real app, track last seen timestamp in SharedPreferences
        if (isActive && message.isNotEmpty) {
          _showNotificationDialog('تنبيه من الإدارة', message);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isTV = AppTheme.isTV(context);

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        _showExitDialog();
      },
      child: Scaffold(
        body: Row(
          children: [
            if (isTV) _buildTVNavigationRail(),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: _screens,
              ),
            ),
          ],
        ),
        bottomNavigationBar: isTV ? null : _buildMobileBottomNav(),
      ),
    );
  }

  Widget _buildTVNavigationRail() {
    return NavigationRail(
      extended: _isRailExtended,
      selectedIndex: _selectedIndex,
      onDestinationSelected: (index) => setState(() => _selectedIndex = index),
      backgroundColor: const Color(0xFF0F0F0F),
      labelType: _isRailExtended
          ? NavigationRailLabelType.none
          : NavigationRailLabelType.all,
      leading: Column(
        children: [
          IconButton(
            icon: Icon(
              _isRailExtended ? Icons.menu_open_rounded : Icons.menu_rounded,
              color: Colors.white,
            ),
            onPressed: () => setState(() => _isRailExtended = !_isRailExtended),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accentBlue.withOpacity(0.2),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: Image.asset('assets/images/logo.jpg', fit: BoxFit.cover),
              ),
            ),
          ),
        ],
      ),
      selectedIconTheme: const IconThemeData(
        color: AppColors.accentBlue,
        size: 32,
      ),
      unselectedIconTheme: const IconThemeData(color: Colors.white54, size: 28),
      selectedLabelTextStyle: const TextStyle(
        color: AppColors.accentBlue,
        fontWeight: FontWeight.bold,
      ),
      unselectedLabelTextStyle: const TextStyle(color: Colors.white54),
      destinations: const [
        NavigationRailDestination(
          icon: Icon(Icons.tv_rounded),
          label: Text('الرئيسية'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.movie_filter_rounded),
          label: Text('الترفيه'),
        ),
        NavigationRailDestination(
          icon: ImageIcon(
            AssetImage('assets/images/placeholder.png'),
            size: 34,
          ),
          selectedIcon: ImageIcon(
            AssetImage('assets/images/placeholder.png'),
            size: 38,
            color: AppColors.accentBlue,
          ),
          label: Text('عالمنا'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.stadium_rounded),
          label: Text('المباريات'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.newspaper_rounded),
          label: Text('الأخبار'),
        ),
      ],
    );
  }

  Widget _buildMobileBottomNav() {
    const items = [
      _NavItem(icon: Icons.tv_rounded, label: 'الرئيسية'),
      _NavItem(icon: Icons.movie_filter_rounded, label: 'الترفيه'),
      _NavItem(icon: null, label: 'عالمنا'),
      _NavItem(icon: Icons.stadium_rounded, label: 'المباريات'),
      _NavItem(icon: Icons.newspaper_rounded, label: 'الأخبار'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(
          top: BorderSide(
            color: AppColors.accentBlue.withOpacity(0.1),
            width: 0.5,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Container(
          height: 65,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: List.generate(items.length, (i) {
              final item = items[i];
              final bool selected = _selectedIndex == i;
              return Expanded(
                child: InkWell(
                  onTap: () => _onItemTapped(i),
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutBack,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Animated Scale for Icon
                        TweenAnimationBuilder<double>(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeOutBack,
                          tween: Tween(begin: 1.0, end: selected ? 1.2 : 1.0),
                          builder: (context, scale, child) {
                            return Transform.scale(
                              scale: scale,
                              child: item.icon == null
                                  ? ImageIcon(
                                      const AssetImage(
                                          'assets/images/placeholder.png'),
                                      size: 26,
                                      color: selected
                                          ? AppColors.accentBlue
                                          : Colors.white54,
                                    )
                                  : Icon(
                                      item.icon,
                                      size: 24,
                                      color: selected
                                          ? AppColors.accentBlue
                                          : Colors.white54,
                                    ),
                            );
                          },
                        ),
                        const SizedBox(height: 4),
                        // Animated Switcher for Label
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          reverseDuration: const Duration(milliseconds: 100),
                          transitionBuilder: (child, animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0, 0.2),
                                  end: Offset.zero,
                                ).animate(animation),
                                child: child,
                              ),
                            );
                          },
                          child: selected
                              ? Text(
                                  item.label,
                                  key: ValueKey('label_$i'),
                                  style: const TextStyle(
                                    fontFamily: 'AppFont',
                                    color: AppColors.accentBlue,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : const SizedBox(
                                  key: ValueKey('empty'),
                                  height: 0,
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  void _showExitDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('خروج', style: TextStyle(color: Colors.white)),
        content: const Text(
          'هل أنت متأكد من رغبتك في الخروج؟',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء', style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            onPressed: () => SystemNavigator.pop(),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('خروج', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  final IconData? icon;
  final String label;
  const _NavItem({this.icon, required this.label});
}
