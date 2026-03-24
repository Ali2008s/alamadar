import 'package:flutter/material.dart';
import 'package:almadar/services/data_service.dart';
import 'package:almadar/screens/maintenance_screen.dart';
import 'package:provider/provider.dart';
import 'dart:async';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  bool _initDone = false;
  bool _isBlocked = false;
  bool _proceeded = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1900),
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.05,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _controller.forward();

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _checkIfCanProceed();
      }
    });

    _initializeApp();
  }

  Future<void> _initializeApp() async {
    final dataService = Provider.of<DataService>(context, listen: false);

    // Increment downloads count (unique per device)
    try {
      final deviceId = await dataService.getDeviceId();
      await dataService.logNewInstall(deviceId);
    } catch (e) {
      debugPrint("Log install error: $e");
    }

    try {
      final config = await dataService.getAppConfig().first.timeout(
            const Duration(seconds: 5),
            onTimeout: () => throw TimeoutException("Splash Config Timeout"),
          );

      if (!mounted) return;

      if (config.isMaintenance) {
        setState(() => _isBlocked = true);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => MaintenanceScreen(config: config)),
        );
        return;
      }

      // We skip version check here to avoid double dialogs. 
      // MainScreen will handle any needed updates after we proceed.
      setState(() => _initDone = true);
      _checkIfCanProceed();
    } catch (e) {
      debugPrint("Init error (Auto-proceeding): $e");
      if (mounted) {
        setState(() => _initDone = true);
        _checkIfCanProceed();
      }
    }
  }

  void _checkIfCanProceed() {
    if (_initDone && _controller.isCompleted && !_isBlocked && !_proceeded) {
      _proceedToHome();
    }
  }

  void _proceedToHome() {
    if (mounted && !_proceeded) {
      _proceeded = true;
      Navigator.pushReplacementNamed(context, '/');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.0,
                colors: [Color(0xFF1A1A1A), Color(0xFF000000)],
              ),
            ),
          ),
          Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 180,
                          height: 180,
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withOpacity(0.1),
                                blurRadius: 50,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.asset(
                              'assets/images/logo.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                        const Text(
                          'عالمنا',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 2,
                            shadows: [
                              Shadow(
                                color: Colors.black54,
                                offset: Offset(2, 2),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: const Column(
                children: [
                  Text(
                    'برمجة بواسطة شركة arix',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 14,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Powered by arix',
                    style: TextStyle(
                      color: Colors.white24,
                      fontSize: 12,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
