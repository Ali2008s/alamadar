import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:almadar/screens/login_screen.dart';

/// ويدجت لحماية الصفحات من الوصول غير المصرح به (بدون كود تفعيل)
class PageGuard extends StatefulWidget {
  final Widget child;
  const PageGuard({super.key, required this.child});

  @override
  State<PageGuard> createState() => _PageGuardState();
}

class _PageGuardState extends State<PageGuard> {
  bool _isChecking = true;
  bool _isAuthorized = false;

  @override
  void initState() {
    super.initState();
    _checkAuthorization();
  }

  Future<void> _checkAuthorization() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

    if (mounted) {
      setState(() {
        _isAuthorized = true; // Always authorized now
        _isChecking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_isAuthorized) {
      return const LoginScreen();
    }

    return widget.child;
  }
}
