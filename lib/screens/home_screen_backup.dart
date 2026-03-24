import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:almadar/services/data_service.dart';
import 'package:almadar/services/auth_service.dart';
import 'package:almadar/core/theme.dart';
import 'package:almadar/data/models.dart';
import 'package:almadar/services/persistence_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:ui';
import 'dart:async';
import 'package:flutter/foundation.dart' hide Category;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PageController _heroController = PageController();
  int _currentHeroPage = 0;
  Timer? _heroTimer;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Ticker animation
  late ScrollController _tickerController;
  Timer? _tickerTimer;

  @override
  void initState() {
    super.initState();
    _startHeroTimer();
    _tickerController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startTicker());
  }

  @override
  void dispose() {
    _heroTimer?.cancel();
    _tickerTimer?.cancel();
    _heroController.dispose();
    _tickerController.dispose();
    super.dispose();
  }

  void _startHeroTimer() {
    _heroTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_heroController.hasClients) {
        _currentHeroPage = (_currentHeroPage + 1) % 3;
        _heroController.animateToPage(
          _currentHeroPage,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOutBack,
        );
      }
    });
  }

  void _startTicker() {
    _tickerTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (_tickerController.hasClients) {
        double maxScroll = _tickerController.position.maxScrollExtent;
        double currentScroll = _tickerController.offset;
        if (currentScroll >= maxScroll) {
          _tickerController.jumpTo(0);
        } else {
          _tickerController.jumpTo(currentScroll + 1);
        }
      }
    });
  }
  @override
  Widget build(BuildContext context) {
    final dataService = Provider.of<DataService>(context);
    final authService = Provider.of<AuthService>(context);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('المدار TV'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.accentBlue.withValues(alpha: 0.1), Colors.transparent],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => showSearch(
              context: context,
              delegate: ChannelSearchDelegate(dataService),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // Perform any refresh logic if needed
        },
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHeroCarousel(dataService)),
            SliverToBoxAdapter(child: _buildHistorySection()),
            SliverToBoxAdapter(child: _buildFavoritesSection()),
            SliverToBoxAdapter(child: _buildLiveChannelsSection(dataService)),
            SliverToBoxAdapter(child: _buildSectionHeader('الأقسام', Icons.grid_view)),
            _buildCategoriesGrid(dataService),
            const SliverToBoxAdapter(child: SizedBox(height: 50)),
          ],
        ),
      ),
      endDrawer: _buildPremiumDrawer(context, authService),
    );
  }

  Widget _buildCategoryTile(Category cat) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/category', arguments: cat),
      child: Container(
        height: 100,
        margin: const EdgeInsets.only(bottom: 15),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white10),
        ),
        child: Stack(
          children: [
            // Image on the Left
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: ClipRRect(
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(15),
                ),
                child: cat.iconUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: cat.iconUrl,
                        width: 120,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        width: 120,
                        color: Colors.white10,
                        child: const Icon(Icons.category, color: Colors.white24),
                      ),
              ),
            ),
            // Title in the Center
            Align(
              alignment: Alignment.center,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 130),
                child: Text(
                  cat.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            // Arrow on the Right
            const Positioned(
              right: 20,
              top: 0,
              bottom: 0,
              child: Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCarousel(DataService service) {
    return StreamBuilder<List<Channel>>(
      stream: service.getAllChannels(),
      builder: (context, snapshot) {
        final items = snapshot.data?.take(5).toList() ?? [];
        if (items.isEmpty) return const SizedBox.shrink();

        return Container(
          height: 220,
          margin: const EdgeInsets.symmetric(vertical: 15),
          child: PageView.builder(
            controller: _heroController,
            itemCount: items.length,
            onPageChanged: (v) => setState(() => _currentHeroPage = v),
            itemBuilder: (context, index) {
              final ch = items[index];
              return AnimatedScale(
                scale: _currentHeroPage == index ? 1.0 : 0.9,
                duration: const Duration(milliseconds: 500),
                child: GestureDetector(
                  onTap: () =>
                      Navigator.pushNamed(context, '/player', arguments: ch),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                      image: DecorationImage(
                        image: NetworkImage(ch.logoUrl),
                        fit: BoxFit.cover,
                      ),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(25),
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withValues(alpha: 0.9),
                            Colors.transparent,
                          ],
                          begin: Alignment.bottomCenter,
                          end: Alignment.center,
                        ),
                      ),
                      padding: const EdgeInsets.all(20),
                      alignment: Alignment.bottomRight,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accentBlue.withValues(
                                alpha: 0.2,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'محتوى مميز',
                              style: TextStyle(
                                color: AppColors.accentBlue,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            ch.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 10),
          Icon(icon, color: AppColors.accentBlue, size: 20),
        ],
      ),
    );
  }

  Widget _buildHistorySection() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: PersistenceService.getHistory(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty)
          return const SizedBox.shrink();
        return Column(
          children: [
            _buildSectionHeader('المشاهدة مؤخراً', Icons.history),
            _buildHorizontalList(snapshot.data!),
          ],
        );
      },
    );
  }

  Widget _buildFavoritesSection() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: PersistenceService.getFavorites(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty)
          return const SizedBox.shrink();
        return Column(
          children: [
            _buildSectionHeader('المفضلة', Icons.favorite),
            _buildHorizontalList(snapshot.data!),
          ],
        );
      },
    );
  }

  Widget _buildLiveChannelsSection(DataService service) {
    return StreamBuilder<List<Channel>>(
      stream: service.getAllChannels(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty)
          return const SizedBox.shrink();
        final channels = snapshot.data!
            .where((c) => c.categoryId != 'matches')
            .take(12)
            .toList();

        return Column(
          children: [
            _buildSectionHeader('القنوات المباشرة', Icons.live_tv),
            Container(
              height: 140,
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 15),
                itemCount: channels.length,
                itemBuilder: (context, index) {
                  final ch = channels[index];
                  return GestureDetector(
                    onTap: () =>
                        Navigator.pushNamed(context, '/player', arguments: ch),
                    child: Container(
                      width: 120,
                      margin: const EdgeInsets.only(left: 15),
                      child: Column(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                color: Colors.white.withValues(alpha: 0.05),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.1),
                                ),
                                image: DecorationImage(
                                  image: NetworkImage(ch.logoUrl),
                                  fit: BoxFit.cover,
                                ),
                              ),
                              child: Center(
                                child: Opacity(
                                  opacity: 0.3,
                                  child: Icon(
                                    Icons.play_circle_fill,
                                    color: Colors.white,
                                    size: 30,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            ch.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHorizontalList(List<Map<String, dynamic>> items) {
    return Container(
      height: 120,
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return GestureDetector(
            onTap: () {
              final ch = Channel(
                id: item['id'],
                name: item['name'],
                logoUrl: item['logo'],
                categoryId: 'history',
                sources: [VideoSource(quality: 'Auto', url: item['url'])],
              );
              Navigator.pushNamed(context, '/player', arguments: ch);
            },
            child: Container(
              width: 100,
              margin: const EdgeInsets.only(left: 12),
              child: Column(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                        image: DecorationImage(
                          image: NetworkImage(item['logo']),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    item['name'],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10, color: Colors.white70),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCategoriesGrid(DataService service) {
    return StreamBuilder<List<Category>>(
      stream: service.getCategories(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SliverToBoxAdapter(
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final cats = snapshot.data!;

        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 15,
              crossAxisSpacing: 15,
              childAspectRatio: 1.5,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              final cat = cats[index];
              final colors = [
                [Colors.blue, Colors.blueAccent],
                [Colors.purple, Colors.deepPurpleAccent],
                [Colors.orange, Colors.deepOrangeAccent],
                [Colors.green, Colors.lightGreenAccent],
                [Colors.red, Colors.pinkAccent],
                [Colors.teal, Colors.cyanAccent],
              ];
              final cardColor = colors[index % colors.length];

              return GestureDetector(
                onTap: () =>
                    Navigator.pushNamed(context, '/category', arguments: cat),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: LinearGradient(
                      colors: [
                        cardColor[0].withValues(alpha: 0.2),
                        cardColor[1].withValues(alpha: 0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: cardColor[0].withValues(alpha: 0.2),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      Positioned(
                        right: -15,
                        bottom: -15,
                        child: Icon(
                          Icons.tv,
                          size: 90,
                          color: cardColor[0].withValues(alpha: 0.1),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: cardColor[0].withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: cat.iconUrl.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: cat.iconUrl,
                                      height: 25,
                                      color: Colors.white,
                                    )
                                  : Icon(
                                      Icons.category,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              cat.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'مشاهدة المحتوى',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.white.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }, childCount: cats.length),
          ),
        );
      },
    );
  }

  Widget _buildSpecialCard(
    String title,
    String sub,
    IconData icon,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(15),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.accentBlue, Colors.indigoAccent],
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: AppColors.accentBlue.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(
              Icons.arrow_back_ios_new,
              color: Colors.white70,
              size: 16,
            ),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  sub,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(width: 20),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 30),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumDrawer(BuildContext context, AuthService auth) {
    return Drawer(
      backgroundColor: AppColors.background,
      child: Column(
        children: [
          _buildDrawerHeader(),
          const SizedBox(height: 10),
          _buildDrawerItem(
            Icons.movie_filter,
            'الترفيه والسينما',
            () => Navigator.pushNamed(context, '/entertainment'),
          ),
          _buildDrawerItem(
            Icons.public,
            'عالمنا',
            () => Navigator.pushNamed(context, '/our_world'),
          ),
          _buildDrawerItem(Icons.favorite, 'المفضلة الخاصة بي', () {}),
          _buildDrawerItem(Icons.history, 'سجل المشاهدة', () {}),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Divider(color: Colors.white10),
          ),
          _buildDrawerItem(
            Icons.speed,
            ' الموقع الإلكتروني',
            () => _launchURL('http://alammna.rf.gd/'),
          ),
          _buildDrawerItem(
            Icons.support_agent,
            'تواصل مع الدعم الفني',
            () => _launchURL('https://t.me/IIIlIIv'),
          ),
          _buildDrawerItem(Icons.share, 'مشاركة التطبيق مع الأصدقاء', () {}),
          const Spacer(),
          Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(15),
            ),
            child: _buildDrawerItem(Icons.logout, 'تسجيل الخروج', () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('isLoggedIn', false);
              auth.signOut();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            }),
          ),
          const Text(
            'Version 1.1.0 Premium Edition',
            style: TextStyle(color: Colors.white24, fontSize: 10),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader() {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.accentBlue, Colors.indigo],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white10,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.tv, size: 50, color: Colors.white),
          ),
          SizedBox(height: 15),
          Text(
            'المدار TV',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1.5,
            ),
          ),
          Text(
            'نظام المدار المتكامل للمشاهدة',
            style: TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70, size: 22),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white, fontSize: 14),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: Colors.white10,
        size: 16,
      ),
      onTap: onTap,
    );
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $url');
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
    return AppTheme.darkTheme.copyWith(
      inputDecorationTheme: const InputDecorationTheme(
        border: InputBorder.none,
        hintStyle: TextStyle(color: Colors.white38),
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) => [
    IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ""),
  ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
    icon: const Icon(Icons.arrow_back),
    onPressed: () => close(context, null),
  );

  @override
  Widget buildResults(BuildContext context) => _buildResults();

  @override
  Widget buildSuggestions(BuildContext context) => _buildResults();

  Widget _buildResults() {
    return StreamBuilder<List<Channel>>(
      stream: dataService.getAllChannels(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final results = snapshot.data!
            .where((c) => c.name.toLowerCase().contains(query.toLowerCase()))
            .toList();
        return ListView.builder(
          itemCount: results.length,
          itemBuilder: (context, index) {
            final ch = results[index];
            return ListTile(
              leading: Image.network(
                ch.logoUrl,
                width: 40,
                height: 40,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.tv),
              ),
              title: Text(ch.name),
              onTap: () =>
                  Navigator.pushNamed(context, '/player', arguments: ch),
            );
          },
        );
      },
    );
  }
}
