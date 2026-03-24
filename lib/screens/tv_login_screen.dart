import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:almadar/core/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:almadar/services/data_service.dart';
import 'package:almadar/services/auth_service.dart';

import 'package:almadar/core/security_utils.dart';

class TVLoginScreen extends StatefulWidget {
  const TVLoginScreen({super.key});

  @override
  State<TVLoginScreen> createState() => _TVLoginScreenState();
}

class _TVLoginScreenState extends State<TVLoginScreen> {
  final List<String> _code = [];
  String _serverCode = "1122";
  int _displayCodeLength = 4; // Display exactly 4 boxes as requested
  String _message = "الرجاء إدخال كود الدخول للمتابعة";
  bool _isInit = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      _loadServerCode();
      _isInit = true;
    }
  }

  void _loadServerCode() {
    final dataService = Provider.of<DataService>(context, listen: false);
    dataService.getSecuritySettings().listen((settings) async {
      if (mounted) {
        String rawCode = (settings['userCode'] ?? "1122").toString().trim();

        // Determine display length (if it's plain text like "1122")
        int length = 4;
        if (rawCode.length <= 8 && !rawCode.contains(RegExp(r'[a-zA-Z]'))) {
          length = rawCode.length;
        }

        setState(() {
          _serverCode = rawCode;
          _displayCodeLength = length;
        });
      }
    });
  }

  void _onNumberTap(String number) {
    if (_code.length < _displayCodeLength) {
      setState(() {
        _code.add(number);
        if (_code.length == _displayCodeLength) {
          _verifyCode();
        }
      });
    }
  }

  void _onBackspace() {
    if (_code.isNotEmpty) {
      setState(() {
        _code.removeLast();
      });
    }
  }

  Future<void> _verifyCode() async {
    final inputCode = _code.join();
    final dataService = Provider.of<DataService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);

    setState(() => _message = "جاري التحقق...");

    // 1. Check direct equality or decrypted equality with Master Code
    bool isMasterMatch = inputCode == _serverCode;
    if (!isMasterMatch && _serverCode.length > 10) {
      final decrypted = await SecurityUtils.decrypt(_serverCode);
      if (inputCode == decrypted.trim()) {
        isMasterMatch = true;
      }
    }

    if (isMasterMatch) {
      await _finalizeLogin(authService);
      return;
    }

    // 2. Try validating as a subscription code
    final deviceId = await dataService.getDeviceId();
    final (isValidSub, _) = await dataService.validateActivationCode(
      inputCode,
      deviceId,
    );

    if (isValidSub) {
      await _finalizeLogin(authService);
    } else {
      setState(() {
        _code.clear();
        _message = "الكود غير صحيح، حاول مرة أخرى";
      });
    }
  }

  Future<void> _finalizeLogin(AuthService authService) async {
    // Standard procedure: Sign in with default user for RTDB access
    await authService.signIn('hmwshy402@gmail.com', 'y8m@8vZa7Qj8svh');

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);

    if (mounted) {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          final key = event.logicalKey;
          if (key.keyId >= LogicalKeyboardKey.digit0.keyId &&
              key.keyId <= LogicalKeyboardKey.digit9.keyId) {
            _onNumberTap(
              (key.keyId - LogicalKeyboardKey.digit0.keyId).toString(),
            );
            return KeyEventResult.handled;
          } else if (key == LogicalKeyboardKey.backspace) {
            _onBackspace();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Row(
          children: [
            // Left Side: Branding
            Expanded(
              flex: 2,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.accentBlue.withOpacity(0.1),
                      Colors.black,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.asset('assets/images/logo.jpg', width: 120),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'عالمنا TV',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Right Side: Keypad
            Expanded(
              flex: 3,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _message,
                    style: const TextStyle(color: Colors.white70, fontSize: 18),
                  ),
                  const SizedBox(height: 30),

                  // Code Display
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_displayCodeLength, (index) {
                      bool isFilled = index < _code.length;
                      return Container(
                        width: 50,
                        height: 50,
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isFilled
                                ? AppColors.accentBlue
                                : Colors.white10,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: isFilled
                              ? Container(
                                  width: 15,
                                  height: 15,
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                )
                              : null,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 50),
                  _buildKeyboard(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyboard() {
    final List<String> keys = [
      "1",
      "2",
      "3",
      "4",
      "5",
      "6",
      "7",
      "8",
      "9",
      "C",
      "0",
      "DEL",
    ];
    return SizedBox(
      width: 400,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: keys.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
        ),
        itemBuilder: (context, index) {
          final key = keys[index];
          return _KeyboardKey(
            label: key,
            onTap: () {
              if (key == "C") {
                setState(() => _code.clear());
              } else if (key == "DEL") {
                _onBackspace();
              } else {
                _onNumberTap(key);
              }
            },
          );
        },
      ),
    );
  }
}

class _KeyboardKey extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  const _KeyboardKey({required this.label, required this.onTap});

  @override
  State<_KeyboardKey> createState() => _KeyboardKeyState();
}

class _KeyboardKeyState extends State<_KeyboardKey> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (val) => setState(() => _isFocused = val),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.select) {
            widget.onTap();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          decoration: BoxDecoration(
            color: _isFocused
                ? AppColors.accentBlue
                : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
            boxShadow: _isFocused
                ? [
                    BoxShadow(
                      color: AppColors.accentBlue.withOpacity(0.5),
                      blurRadius: 10,
                    ),
                  ]
                : [],
          ),
          child: Center(
            child: Text(
              widget.label,
              style: TextStyle(
                color: _isFocused ? Colors.white : Colors.white70,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
