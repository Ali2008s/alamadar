import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:almadar/core/theme.dart';
import 'package:almadar/services/xo_service.dart';
import 'package:almadar/services/auth_service.dart';
import 'package:almadar/screens/auth_ui_screen.dart';
import 'package:almadar/widgets/tv_interactive.dart';
import 'dart:ui';
import 'xo_game_screen.dart';

class XOLobbyScreen extends StatefulWidget {
  const XOLobbyScreen({super.key});

  @override
  State<XOLobbyScreen> createState() => _XOLobbyScreenState();
}

class _XOLobbyScreenState extends State<XOLobbyScreen> {
  final TextEditingController _roomController = TextEditingController();
  bool _isLoading = false;
  int _selectedRounds = 3;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuth();
    });
  }

  void _checkAuth() {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (authService.user == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AuthUIScreen()),
      );
    } else {
      Provider.of<XOService>(context, listen: false).initializePlayer(
        authService.user!.uid,
        authService.user!.displayName ?? 'مستخدم',
      );
    }
  }

  Future<void> _createRoom() async {
    setState(() => _isLoading = true);
    final xoService = Provider.of<XOService>(context, listen: false);
    try {
      await xoService.createRoom(_selectedRounds);
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const XOGameScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('حدث خطأ أثناء إنشاء الغرفة')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _joinRoom(String code) async {
    if (code.trim().isEmpty) return;
    setState(() => _isLoading = true);

    final xoService = Provider.of<XOService>(context, listen: false);
    try {
      bool joined = await xoService.joinRoom(code.trim());
      if (joined) {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const XOGameScreen()),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('الغرفة غير موجودة أو ممتلئة')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('حدث خطأ في الاتصال')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _playBot() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const XOGameScreen(isBotMode: true)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'تحدي XO أونلاين',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Consumer<XOService>(
        builder: (context, xoService, _) {
          if (xoService.playerName == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return Stack(
            children: [
              // Background decorations
              Positioned(
                top: -100,
                right: -100,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0x1A00E5FF),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                    child: Container(),
                  ),
                ),
              ),
              Positioned(
                bottom: -100,
                left: -100,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0x1AFF00E5),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                    child: Container(),
                  ),
                ),
              ),

              SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'مرحباً ${xoService.playerName}',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'المتصلين حالياً: ${xoService.onlineCount} 🟢',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),

                      // Create Room Section
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'إعدادات غرفتك',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  'عدد جولات الفوز: ',
                                  style: TextStyle(color: Colors.white70),
                                ),
                                DropdownButton<int>(
                                  dropdownColor: AppColors.cardBg,
                                  value: _selectedRounds,
                                  items: [1, 3, 5, 10].map((int val) {
                                    return DropdownMenuItem<int>(
                                      value: val,
                                      child: Text(
                                        '$val جولات',
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null)
                                      setState(() => _selectedRounds = val);
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 15),
                            TVInteractive(
                              onTap: _isLoading ? null : _createRoom,
                              borderRadius: BorderRadius.circular(15),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 20,
                                ),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [AppColors.accentBlue, Colors.blue],
                                  ),
                                  borderRadius: BorderRadius.circular(15),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.accentBlue.withOpacity(
                                        0.3,
                                      ),
                                      blurRadius: 10,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: _isLoading
                                    ? const Center(
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.add_circle_outline,
                                            color: Colors.white,
                                            size: 28,
                                          ),
                                          SizedBox(width: 10),
                                          Text(
                                            'إنشاء الغرفة',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Join Room
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'الانضمام لغرفة',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 15),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _roomController,
                                    keyboardType: TextInputType.number,
                                    maxLength: 6,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      letterSpacing: 5,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    decoration: InputDecoration(
                                      counterText: '',
                                      hintText: 'الكود (6 أرقام)',
                                      hintStyle: TextStyle(
                                        color: Colors.white.withOpacity(0.3),
                                        fontSize: 16,
                                        letterSpacing: 0,
                                      ),
                                      filled: true,
                                      fillColor: Colors.black26,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide.none,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 15),
                                TVInteractive(
                                  onTap: () => _joinRoom(_roomController.text),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 15,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.accentPink,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Text(
                                      'انضمام',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Bot Mode
                      TVInteractive(
                        onTap: _playBot,
                        borderRadius: BorderRadius.circular(15),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            border: Border.all(color: Colors.white24),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.smart_toy, color: Colors.white70),
                              SizedBox(width: 10),
                              Text(
                                'العب ضد الذكاء الاصطناعي',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),

                      // Public Rooms
                      const Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'الغرف العامة',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                      StreamBuilder<Map<dynamic, dynamic>>(
                        stream: xoService.getPublicRooms(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData || snapshot.data!.isEmpty) {
                            return Container(
                              padding: const EdgeInsets.all(20),
                              alignment: Alignment.center,
                              child: const Text(
                                'لا توجد غرف عامة حالياً',
                                style: TextStyle(color: Colors.white54),
                              ),
                            );
                          }

                          final rooms = snapshot.data!;
                          return ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: rooms.length,
                            itemBuilder: (context, index) {
                              final roomId = rooms.keys.elementAt(index);
                              final room = rooms[roomId];
                              if (room['state'] != 'waiting')
                                return const SizedBox.shrink();

                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                child: ListTile(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  tileColor: Colors.white.withOpacity(0.05),
                                  leading: const CircleAvatar(
                                    backgroundColor: AppColors.accentBlue,
                                    child: Icon(
                                      Icons.person,
                                      color: Colors.white,
                                    ),
                                  ),
                                  title: Text(
                                    room['hostName'] ?? 'مجهول',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: const Text(
                                    'غرفة بانتظار لاعب...',
                                    style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 12,
                                    ),
                                  ),
                                  trailing: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.accentBlue,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    onPressed: () =>
                                        _joinRoom(roomId.toString()),
                                    child: const Text(
                                      'دخول',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
