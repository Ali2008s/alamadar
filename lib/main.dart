import 'package:almadar/screens/splash_screen.dart';
import 'package:almadar/widgets/page_guard.dart';
import 'package:almadar/services/security_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';
import 'package:almadar/services/auth_service.dart';
import 'package:almadar/services/data_service.dart';
import 'package:almadar/services/premium_service.dart';
import 'package:almadar/services/xo_service.dart';
import 'package:almadar/screens/login_screen.dart';
import 'package:almadar/screens/category_screen.dart';
import 'package:almadar/screens/player_screen.dart';
import 'package:almadar/screens/match_schedule_screen.dart';
import 'package:almadar/screens/all_channels_screen.dart';
import 'package:almadar/screens/main_screen.dart';
import 'package:almadar/screens/entertainment_screen.dart';
import 'package:almadar/screens/our_world_screen.dart';
import 'package:almadar/screens/series_details_screen.dart';
import 'package:almadar/screens/our_world_series_details_screen.dart';
import 'package:almadar/screens/episode_details_screen.dart';
import 'package:almadar/screens/tv_login_screen.dart';
import 'package:almadar/core/theme.dart';
import 'package:almadar/core/security_utils.dart';
import 'package:almadar/data/models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:almadar/firebase_options.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

import 'package:almadar/services/focus_sound_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Force direct connection and block proxies
  SecurityUtils.initializeNetworkSecurity();

  // Security scan (Background, no loading UI)
  final isCompromised = await SecurityService.isDeviceCompromised();
  if (isCompromised) {
    // If compromised via root/banned app, exit to system natively.
    SystemNavigator.pop();
    return;
  }

  // Hide status bar and navigation bar for immersive experience
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // Default orientations - will be handled dynamically in screens
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Small delay to allow previous session's native resources to settle during Hot Restart/Multi-launch
  await Future.delayed(const Duration(milliseconds: 150));

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Initialize App Check (Enforces that only this app can access Firebase)
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.playIntegrity,
      appleProvider: AppleProvider.deviceCheck,
    );
  } catch (e) {
    debugPrint("Firebase initialization failed: $e");
  }

  // Heavy native services initialized in background to avoid blocking main UI
  // and to prevent FFI callback collisions on start
  unawaited(_initNativeServices());

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        Provider(create: (_) => DataService()),
        Provider(create: (_) => PremiumService()),
        ChangeNotifierProvider(create: (_) => XOService()),
      ],
      child: const MyApp(),
    ),
  );
}

Future<void> _initNativeServices() async {
  try {
    // 1. Initialize media_kit - Temporarily disabled to debug crash
    // MediaKit.ensureInitialized();

    // 2. Initialize Focus Sound (SoLoud) - Temporarily disabled to debug crash
    // await FocusSoundService.instance.init();
  } catch (e) {
    debugPrint("Native services initialization failed: $e");
  }
}

// Helper to keep imports clean
void unawaited(Future<void> future) {}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'عالمنا',
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar', 'AE'),
      supportedLocales: const [Locale('ar', 'AE')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        return Directionality(textDirection: TextDirection.rtl, child: child!);
      },
      initialRoute: '/splash',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/splash':
            return MaterialPageRoute(builder: (_) => const SplashScreen());
          case '/':
            return MaterialPageRoute(builder: (_) => const AuthWrapper());
          case '/login':
            return MaterialPageRoute(builder: (_) => const LoginScreen());
          case '/tv_login':
            return MaterialPageRoute(builder: (_) => const TVLoginScreen());
          case '/home':
            return MaterialPageRoute(
              builder: (_) => const PageGuard(child: MainScreen()),
            );
          case '/matches':
            return MaterialPageRoute(
              builder: (_) => const PageGuard(child: MatchScheduleScreen()),
            );
          case '/all_channels':
            return MaterialPageRoute(
              builder: (_) => const PageGuard(child: AllChannelsScreen()),
            );
          case '/series_details':
            final id = settings.arguments as int;
            return MaterialPageRoute(
              builder: (_) => SeriesDetailsScreen(id: id),
            );
          case '/our_world_series_details':
            final series = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
              builder: (_) => OurWorldSeriesDetailsScreen(series: series),
            );
          case '/episode_details':
            final id = settings.arguments as int;
            return MaterialPageRoute(
              builder: (_) => EpisodeDetailsScreen(id: id),
            );
          case '/category':
            final category = settings.arguments as Category;
            return MaterialPageRoute(
              builder: (_) =>
                  PageGuard(child: CategoryScreen(category: category)),
            );
          case '/player':
            final args = settings.arguments;
            if (args is Map<String, dynamic>) {
              return MaterialPageRoute(
                builder: (_) => PageGuard(
                  child: PlayerScreen(
                    channel: args['channel'] as Channel,
                    isLive: args['isLive'] as bool? ?? true,
                  ),
                ),
              );
            }
            final channel = args as Channel;
            return MaterialPageRoute(
              builder: (_) => PageGuard(child: PlayerScreen(channel: channel)),
            );
          case '/entertainment':
            return MaterialPageRoute(
              builder: (_) => const PageGuard(child: EntertainmentScreen()),
            );
          case '/our_world':
            return MaterialPageRoute(
              builder: (_) => const PageGuard(child: OurWorldScreen()),
            );
          default:
            return null;
        }
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _performAutoLogin();
  }

  Future<void> _performAutoLogin() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (authService.user == null) {
      try {
        await authService.signIn('hmwshy402@gmail.com', 'y8m@8vZa7Qj8svh');
      } catch (e) {
        debugPrint('Auto login error: $e');
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppColors.accentBlue),
              SizedBox(height: 20),
              Text(
                'جاري التهيئة...',
                style: TextStyle(color: Colors.white, fontSize: 18, fontFamily: 'AppFont'),
              ),
            ],
          ),
        ),
      );
    }
    return const MainScreen();
  }
}
