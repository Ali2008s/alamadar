import 'package:almadar/screens/xo_lobby_screen.dart';
import 'package:almadar/screens/support_chat_screen.dart';
import 'package:almadar/screens/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:almadar/services/data_service.dart';
import 'package:almadar/services/auth_service.dart';
import 'package:almadar/core/theme.dart';
import 'package:almadar/data/models.dart';
import 'package:almadar/widgets/app_image.dart';
import 'package:almadar/widgets/tv_interactive.dart';
import 'package:almadar/services/persistence_service.dart';
import 'package:almadar/screens/premium_categories_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:marquee/marquee.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:async';
import 'dart:ui';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isPremiumUnlocked = false;
  StreamSubscription? _premiumSub;

  @override
  void initState() {
    super.initState();
    _checkPremiumStatus();
    _setupPremiumListener();
  }

  @override
  void dispose() {
    _premiumSub?.cancel();
    super.dispose();
  }

  Future<void> _checkPremiumStatus() async {
    final unlocked = await PersistenceService.isPremiumUnlocked();
    if (mounted) setState(() => _isPremiumUnlocked = unlocked);
  }

  void _setupPremiumListener() async {
    final dataService = Provider.of<DataService>(context, listen: false);
    final deviceId = await dataService.getDeviceId();

    _premiumSub = dataService.getActivationStatus(deviceId).listen((
      isActivated,
    ) {
      if (_isPremiumUnlocked && !isActivated) {
        // Status was unlocked but now activation is gone
        _handleSubscriptionExpired();
      }
    });
  }

  void _handleSubscriptionExpired() async {
    await PersistenceService.setPremiumUnlocked(false);
    if (!mounted) return;

    setState(() => _isPremiumUnlocked = false);

    // Do NOT pop all routes — user might be in the player or another screen.
    // Just update state and show a dialog when they return to HomeScreen.
    _showExpiredDialog();
  }

  void _showExpiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 10),
            Text(
              'تنبيه',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: const Text(
          'انتهت صلاحية اشتراكك يرجى مراسلة الدعم الفني لتجديد الاشتراك',
          style: TextStyle(color: Colors.white70, fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'حسنًا',
              style: TextStyle(color: AppColors.accentBlue),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dataService = Provider.of<DataService>(context);
    final authService = Provider.of<AuthService>(context);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'عالمنا',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded, size: 28),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 26),
            onPressed: () {
              setState(() {}); // Triggers a rebuild of the main streams
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('جاري تحديث البيانات...'), duration: Duration(seconds: 1)),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.search_rounded, size: 26),
            onPressed: () => showSearch(
              context: context,
              delegate: ChannelSearchDelegate(dataService),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildMarquee(dataService),
          _buildDownloadCounter(dataService),
          _buildXOBanner(),
          Expanded(
            child: StreamBuilder<List<Category>>(
              stream: dataService.getCategories(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildShimmerCategories();
                }
                final categories = snapshot.data ?? [];
                if (categories.isEmpty) {
                  return const Center(
                    child: Text(
                      'لا توجد أقسام حالياً',
                      style: TextStyle(color: Colors.white54),
                    ),
                  );
                }
                final bool isTV = AppTheme.isTV(context);
                return ListView.builder(
                  padding: EdgeInsets.symmetric(
                    horizontal: isTV ? 80 : 15,
                    vertical: 20,
                  ),
                  itemCount: categories.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) return _buildPremiumTile();
                    final cat = categories[index - 1];
                    return TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: Duration(milliseconds: 300 + (index * 80)),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) {
                        return Opacity(
                          opacity: value,
                          child: Transform.translate(
                            offset: Offset(0, 20 * (1 - value)),
                            child: child,
                          ),
                        );
                      },
                      child: _buildCategoryTile(cat),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      drawer: _buildDrawer(context, authService),
    );
  }

  Widget _buildMarquee(DataService service) {
    return StreamBuilder<String>(
      stream: service.getTickerText(),
      builder: (context, snapshot) {
        final text = snapshot.data ?? '';
        if (text.isEmpty) return const SizedBox.shrink();
        return Container(
          height: 35,
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 5),
          decoration: BoxDecoration(
            color: AppColors.accentBlue.withOpacity(0.1),
            border: Border.symmetric(
              horizontal: BorderSide(
                color: AppColors.accentBlue.withOpacity(0.2),
                width: 0.5,
              ),
            ),
          ),
          child: Marquee(
            key: ValueKey(text),
            text: text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            scrollAxis: Axis.horizontal,
            crossAxisAlignment: CrossAxisAlignment.center,
            blankSpace: 50.0,
            velocity: 40.0,
            pauseAfterRound: const Duration(seconds: 1),
            showFadingOnlyWhenScrolling: true,
            fadingEdgeStartFraction: 0.1,
            fadingEdgeEndFraction: 0.1,
            startPadding: 10.0,
          ),
        );
      },
    );
  }

  Widget _buildXOBanner() {
    return TVInteractive(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const XOLobbyScreen()),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      borderRadius: BorderRadius.circular(15),
      child: Container(
        width: double.infinity,
        height: 60,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          gradient: const LinearGradient(
            colors: [Color(0xFF8A2387), Color(0xFFE94057), Color(0xFFF27121)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE94057).withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            const Positioned(
              right: -20,
              top: -20,
              child: Icon(
                Icons.sports_esports,
                size: 100,
                color: Colors.white10,
              ),
            ),
            Row(
              children: [
                const SizedBox(width: 20),
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.white24,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.videogame_asset, color: Colors.white),
                ),
                const SizedBox(width: 15),
                const Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'تحدي XO أونلاين',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'العب وتحدى أصدقائك الآن!',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white54,
                  size: 16,
                ),
                const SizedBox(width: 15),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumTile() {
    return TVInteractive(
      onTap: () {
        if (_isPremiumUnlocked) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PremiumCategoriesScreen()),
          );
        } else {
          _showPremiumActivationDialog();
        }
      },
      padding: const EdgeInsets.only(bottom: 15),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF1E1E2C),
              AppColors.accentBlue.withOpacity(0.6),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.accentBlue.withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.accentBlue.withOpacity(0.2),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Opacity(
                opacity: 0.2,
                child: Image.asset(
                  'assets/images/placeholder.png',
                  fit: BoxFit.cover,
                  width: 150,
                ),
              ),
            ),
            Row(
              children: [
                const SizedBox(width: 20),
                if (!_isPremiumUnlocked)
                  GestureDetector(
                    onTap: _showPremiumActivationDialog,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      margin: const EdgeInsets.only(right: 20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFE50914),
                            Color(0xFFB20710),
                          ], // Netflix red
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'فتح',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'عالمنا بلس',
                        style: TextStyle(
                          fontFamily: 'AppFont',
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isPremiumUnlocked
                            ? 'أنت الآن تتمتع بوصول كامل'
                            : 'افتح بوابة المتعة اللامحدودة!',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber.withOpacity(0.4),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Icon(
                    _isPremiumUnlocked
                        ? Icons.check_circle_rounded
                        : Icons.lock_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showPremiumActivationDialog() {
    final TextEditingController codeController = TextEditingController();

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.92),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, anim1, anim2) {
        return FadeTransition(
          opacity: anim1,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.9, end: 1.0).animate(
              CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
            ),
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: Stack(
                children: [
                  // Animated background glow
                  Positioned(
                    top: -100,
                    right: -100,
                    child: Container(
                      width: 300,
                      height: 300,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.accentBlue.withOpacity(0.15),
                      ),
                    ),
                  ),
                  
                  Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(30),
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 450),
                        padding: const EdgeInsets.all(30),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A2E).withOpacity(0.8),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.5),
                              blurRadius: 40,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(30),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Logo and Badge
                                Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Container(
                                      width: 100,
                                      height: 100,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          colors: [
                                            AppColors.accentBlue.withOpacity(0.3),
                                            Colors.transparent,
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                      ),
                                    ),
                                    Image.asset(
                                      'assets/images/logo.png',
                                      width: 70,
                                      height: 70,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 25),
                                
                                // Premium Title
                                ShaderMask(
                                  shaderCallback: (bounds) => const LinearGradient(
                                    colors: [Color(0xFFFFD700), Color(0xFFFFA500), Color(0xFFFF8C00)],
                                  ).createShader(bounds),
                                  child: const Text(
                                    'عالمنا بلس',
                                    style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  'استمتع بتجربة مشاهدة لا حدود لها',
                                  style: TextStyle(
                                    color: Colors.white60,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 40),
                                
                                // Elegant Input Field
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.1),
                                    ),
                                  ),
                                  child: TextField(
                                    controller: codeController,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 4,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'أدخل قسيمة الاشتراك',
                                      hintStyle: TextStyle(
                                        color: Colors.white.withOpacity(0.2),
                                        fontSize: 15,
                                        letterSpacing: 0,
                                      ),
                                      border: InputBorder.none,
                                      contentPadding: const EdgeInsets.symmetric(vertical: 20),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 35),
                                
                                // Premium Action Button
                                Container(
                                  width: double.infinity,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFFE50914), Color(0xFF9B070D)],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFE50914).withOpacity(0.3),
                                        blurRadius: 15,
                                        offset: const Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton(
                                    onPressed: () async {
                                      final code = codeController.text.trim();
                                      if (code.isEmpty) return;

                                      final dataService = Provider.of<DataService>(context, listen: false);
                                      final deviceId = await dataService.getDeviceId();
                                      
                                      // Show loading
                                      showDialog(
                                        context: context,
                                        barrierDismissible: false,
                                        builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.white)),
                                      );

                                      final (isValid, _) = await dataService.validateActivationCode(code, deviceId);
                                      
                                      if (context.mounted) Navigator.pop(context); // Close loading

                                      if (isValid) {
                                        await PersistenceService.setPremiumUnlocked(true);
                                        if (context.mounted) {
                                          setState(() => _isPremiumUnlocked = true);
                                          Navigator.pop(context);
                                          _showSuccessCelebration();
                                        }
                                      } else {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              backgroundColor: const Color(0xFFE50914),
                                              content: const Text('عذراً، هذه القسيمة غير صالحة أو تم استخدامها مسبقاً', textAlign: TextAlign.center),
                                              behavior: SnackBarBehavior.floating,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            ),
                                          );
                                        }
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                    ),
                                    child: const Text(
                                      'تفعيل الآن',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                
                                // Secondary Close Button
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: Text(
                                    'رجوع',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.4),
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                
                                const Divider(height: 40, color: Colors.white10),
                                
                                GestureDetector(
                                  onTap: () => _launchURL('https://t.me/uunQI'),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.telegram, color: AppColors.accentBlue, size: 20),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'ليس لديك قسيمة؟ اطلبها الآن',
                                        style: TextStyle(
                                          color: AppColors.accentBlue,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showSuccessCelebration() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.green.shade800,
        duration: const Duration(seconds: 4),
        content: const Row(
          children: [
            Icon(Icons.stars, color: Colors.white),
            SizedBox(width: 15),
            Expanded(child: Text('مبروك! تم تفعيل عالمنا بلس بنجاح. مشاهدة ممتعة!')),
          ],
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildCategoryTile(Category cat) {
    return TVInteractive(
      onTap: () => Navigator.pushNamed(context, '/category', arguments: cat),
      padding: const EdgeInsets.only(bottom: 20),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // Abstract background glow
              Positioned(
                bottom: -30,
                left: -30,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.accentBlue.withOpacity(0.1),
                  ),
                ),
              ),
              // Content Row
              Row(
                children: [
                  const SizedBox(width: 25),
                  const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white24,
                    size: 18,
                  ),
                  const Spacer(),
                  // Text Info
                  Expanded(
                    flex: 3,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          cat.name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'AppFont',
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accentBlue.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'استعرض القسم',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.accentBlue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 25),
                  // Icon
                  Container(
                    width: 75,
                    height: 75,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: AppImage(imageUrl: cat.iconUrl, fit: BoxFit.contain),
                  ),
                  const SizedBox(width: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerCategories() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      itemCount: 6,
      itemBuilder: (context, index) {
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 1500),
          builder: (context, value, child) {
            return Container(
              height: 100,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                gradient: LinearGradient(
                  begin: Alignment(
                    -1.0 + 3.0 * ((value + index * 0.1) % 1.0),
                    0,
                  ),
                  end: Alignment(1.0 + 3.0 * ((value + index * 0.1) % 1.0), 0),
                  colors: [
                    Colors.white.withOpacity(0.03),
                    Colors.white.withOpacity(0.07),
                    Colors.white.withOpacity(0.03),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDrawer(BuildContext context, AuthService auth) {
    return Drawer(
      backgroundColor: Colors.transparent,
      elevation: 0,
      width: MediaQuery.of(context).size.width * 0.8,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0F0F0F),
          borderRadius: BorderRadius.horizontal(right: Radius.circular(30)),
          boxShadow: [
            BoxShadow(color: Colors.black87, blurRadius: 40, spreadRadius: 0),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(20, 50, 20, 30),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.accentBlue.withOpacity(0.15),
                      Colors.transparent,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white54,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.accentBlue,
                          width: 2,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(50),
                        child: Image.asset(
                          'assets/images/logo.jpg',
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      'عالمنا',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const Text(
                      'تطبيقك الشامل للترفيه والقنوات',
                      style: TextStyle(fontSize: 12, color: Colors.white38),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  children: [
                    _buildDrawerItem(
                      context,
                      icon: Icons.movie_filter_rounded,
                      title: 'الترفيه والسينما',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, '/entertainment');
                      },
                    ),
                    _buildDrawerItem(
                      context,
                      icon: Icons.public_rounded,
                      title: 'عالمنا (Movies & Series)',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, '/our_world');
                      },
                    ),
                    _buildDrawerItem(
                      context,
                      icon: Icons.sports_soccer_rounded,
                      title: 'جدول المباريات',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, '/matches');
                      },
                    ),
                    const Divider(
                      color: Colors.white10,
                      height: 40,
                      indent: 20,
                      endIndent: 20,
                    ),
                    _buildDrawerItem(
                      context,
                      icon: Icons.web_rounded,
                      title: 'الموقع الإلكتروني',
                      onTap: () => _launchURL('http://alammna.rf.gd/'),
                    ),
                    _buildDrawerItem(
                      context,
                      icon: Icons.telegram_rounded,
                      title: 'قناتنا على تيليجرام',
                      onTap: () => _launchURL('https://t.me/airx4'),
                    ),
                    _buildDrawerItem(
                      context,
                      icon: Icons.share_rounded,
                      title: 'مشاركة التطبيق',
                      onTap: () {
                        Share.share(
                          'تطبيق عالمنا لمشاهدة القنوات والترفيه، حمله الآن من هنا: http://alammna.rf.gd/',
                        );
                      },
                    ),
                    _buildDrawerItem(
                      context,
                      icon: Icons.gamepad_rounded,
                      title: 'تحدي XO',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const XOLobbyScreen(),
                          ),
                        );
                      },
                    ),
                    _buildDrawerItem(
                      context,
                      icon: Icons.support_agent_rounded,
                      title: 'مجموعة الدعم',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SupportChatScreen(),
                          ),
                        );
                      },
                    ),
                    _buildDrawerItem(
                      context,
                      icon: Icons.person_rounded,
                      title: 'تعديل الملف الشخصي',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ProfileScreen(),
                          ),
                        );
                      },
                    ),
                    const Divider(
                      color: Colors.white10,
                      height: 40,
                      indent: 20,
                      endIndent: 20,
                    ),
                    _buildDrawerItem(
                      context,
                      icon: Icons.logout_rounded,
                      title: 'تسجيل الخروج',
                      color: Colors.redAccent,
                      onTap: () async {
                        final auth = Provider.of<AuthService>(
                          context,
                          listen: false,
                        );
                        await auth.signOut();
                        if (context.mounted) {
                          Navigator.pushReplacementNamed(context, '/login');
                        }
                      },
                    ),
                  ],
                ),
              ),

              // Footer
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Text(
                      'برمجة شركة arix',
                      style: TextStyle(color: Colors.white24, fontSize: 13),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'اصدار 1.0.0',
                      style: TextStyle(
                        color: AppColors.accentBlue.withOpacity(0.3),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color color = AppColors.accentBlue,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(15),
      ),
      child: ListTile(
        leading: Icon(icon, color: color, size: 22),
        title: Text(
          title,
          style: TextStyle(
            color: color == AppColors.accentBlue ? Colors.white : color,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios_rounded,
          color: Colors.white10,
          size: 14,
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );
  }

  Widget _buildDownloadCounter(DataService dataService) {
    return StreamBuilder<int>(
      stream: dataService.getDownloadCount(),
      initialData: 5012,
      builder: (context, snapshot) {
        // Add a realistic base offset so count reflects total installs including pre-firebase era
        const int baseInstalls = 5000;
        final count = baseInstalls + (snapshot.data ?? 0);
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          color: Colors.black.withOpacity(0.3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.download_for_offline_rounded, color: AppColors.accentBlue, size: 20),
              const SizedBox(width: 8),
              const Text(
                'إجمالي عدد تحميلات التطبيق:',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.accentBlue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.accentBlue.withOpacity(0.5), width: 1),
                ),
                child: Text(
                  count.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _launchURL(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }
}

class ChannelSearchDelegate extends SearchDelegate {
  final DataService dataService;
  ChannelSearchDelegate(this.dataService);

  @override
  String get searchFieldLabel => 'بحث عن قناة...';

  @override
  ThemeData appBarTheme(BuildContext context) {
    return ThemeData(
      appBarTheme: const AppBarTheme(backgroundColor: AppColors.background),
      inputDecorationTheme: const InputDecorationTheme(
        hintStyle: TextStyle(color: Colors.white38),
      ),
      textTheme: const TextTheme(titleLarge: TextStyle(color: Colors.white)),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults();
  }

  Widget _buildSearchResults() {
    if (query.isEmpty) return Container(color: AppColors.background);

    return Container(
      color: AppColors.background,
      child: StreamBuilder<List<Channel>>(
        stream: dataService.getAllChannels(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final results = snapshot.data!
              .where((c) => c.name.toLowerCase().contains(query.toLowerCase()))
              .toList();

          return ListView.builder(
            itemCount: results.length,
            itemBuilder: (context, index) {
              final ch = results[index];
              return ListTile(
                leading: AppImage(
                  imageUrl: ch.logoUrl,
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  borderRadius: 8,
                ),
                title: Text(
                  ch.name,
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () {
                  close(context, null);
                  Navigator.pushNamed(context, '/player', arguments: ch);
                },
              );
            },
          );
        },
      ),
    );
  }
}
