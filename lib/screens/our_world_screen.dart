import 'package:flutter/material.dart';
import 'package:almadar/core/theme.dart';
import 'package:almadar/services/data_service.dart';
import 'package:almadar/data/models.dart';
import 'package:provider/provider.dart';
import 'package:almadar/widgets/app_image.dart';
import 'package:almadar/widgets/tv_interactive.dart';
import 'package:almadar/screens/our_world_content_screen.dart';
import 'dart:ui';
import 'dart:async';

class OurWorldScreen extends StatefulWidget {
  const OurWorldScreen({super.key});

  @override
  State<OurWorldScreen> createState() => _OurWorldScreenState();
}

class _OurWorldScreenState extends State<OurWorldScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = "";

  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  // Lazy Loading & Search State
  Timer? _debounce;
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearchLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      // Empty or implement other logic if necessary
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    setState(() => _searchQuery = query);

    if (_debounce?.isActive ?? false) _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults.clear();
        _isSearchLoading = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 600), () {
      _performGlobalSearch(query.trim());
    });
  }

  Future<void> _performGlobalSearch(String query) async {
    setState(() => _isSearchLoading = true);
    final service = Provider.of<DataService>(context, listen: false);

    try {
      // Concurrently fetch the first snapshot of all three types with search query
      final results = await Future.wait([
        service.getOurWorldContent('channels', searchQuery: query).first,
        service.getOurWorldContent('movies', searchQuery: query).first,
        service.getOurWorldContent('series', searchQuery: query).first,
      ]).timeout(const Duration(seconds: 15));

      final channelItems = results[0];
      final movieItems = results[1];
      final seriesItems = results[2];

      final combined = [...channelItems, ...movieItems, ...seriesItems];

      if (mounted) {
        setState(() {
          _searchResults = combined;
          _isSearchLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSearchLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // 🎭 Modern Background Mesh
          Positioned(
            top: -150,
            right: -100,
            child: _buildGlowSphere(AppColors.accentBlue, 400),
          ),
          Positioned(
            bottom: -150,
            left: -100,
            child: _buildGlowSphere(AppColors.accentPink, 400),
          ),

          SafeArea(
            child: Column(
              children: [
                _buildModernHeader(),
                Expanded(
                  child: _isSearching && _searchQuery.isNotEmpty
                      ? _buildGlobalSearchResults()
                      : TabBarView(
                          controller: _tabController,
                          physics: const BouncingScrollPhysics(),
                          children: [
                            _KeepAliveWrapper(child: _buildCategoryGrid('live')),
                            _KeepAliveWrapper(child: _buildCategoryGrid('movies')),
                            _KeepAliveWrapper(child: _buildCategoryGrid('series')),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlowSphere(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.12),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
        child: Container(),
      ),
    );
  }

  Widget _buildModernHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 5),
      child: Column(
        children: [
          // Row 1: Logo & Title and Search Toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _isSearching
                    ? _buildSearchField()
                    : Text(
                        'عالمنا المميز',
                        key: const ValueKey('title'),
                        style: const TextStyle(
                          fontFamily: 'AppFont',
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
              ),
              if (!_isSearching)
                TVInteractive(
                  onTap: () => setState(() => _isSearching = true),
                  borderRadius: BorderRadius.circular(15),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white10),
                    ),
                    child: const Icon(
                      Icons.search_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          // Row 2: Premium Segmented TabBar
          Container(
            height: 50,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.white10),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.white.withOpacity(0.15),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accentBlue.withOpacity(0.2),
                    blurRadius: 8,
                  ),
                ],
              ),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
              tabs: const [
                Tab(child: Text('البث المباشر', style: TextStyle(fontFamily: 'AppFont'))),
                Tab(child: Text('الأفلام', style: TextStyle(fontFamily: 'AppFont'))),
                Tab(child: Text('المسلسلات', style: TextStyle(fontFamily: 'AppFont'))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      key: const ValueKey('search'),
      width: MediaQuery.of(context).size.width - 40,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.accentBlue.withOpacity(0.3)),
      ),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'ابحث عن فيلم، مسلسل أو قناة...',
          hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.accentBlue,
          ),
          border: InputBorder.none,
          suffixIcon: IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white54),
            onPressed: () => setState(() {
              _isSearching = false;
              _searchQuery = "";
              _searchController.clear();
            }),
          ),
        ),
        onChanged: _onSearchChanged,
      ),
    );
  }

  Widget _buildCategoryGrid(String type) {
    final service = Provider.of<DataService>(context, listen: false);

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: service.getOurWorldCategories(type),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return _buildShimmerGrid();

        final items = snapshot.data ?? [];
        if (items.isEmpty) return _buildNoResults();

        final bool isTV = AppTheme.isTV(context);
        if (isTV) {
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(15, 20, 15, 20),
            physics: const BouncingScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              childAspectRatio: 1.5,
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final cat = items[index];
              return _buildCategoryCard(cat, type, index);
            },
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20),
          physics: const BouncingScrollPhysics(),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final cat = items[index];
            return _buildExtendedCategoryCard(cat, type, index);
          },
        );
      },
    );
  }

  Widget _buildCategoryCard(Map<String, dynamic> cat, String type, int index) {
    return TVInteractive(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OurWorldContentScreen(
              categoryId: cat['id'].toString(),
              categoryName: cat['name'] ?? '',
              type: type,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white.withOpacity(0.04),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              cat['name'] ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'AppFont',
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExtendedCategoryCard(
    Map<String, dynamic> cat,
    String type,
    int index,
  ) {
    return TVInteractive(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OurWorldContentScreen(
              categoryId: cat['id'].toString(),
              categoryName: cat['name'] ?? '',
              type: type,
            ),
          ),
        );
      },
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
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Icon(
                        Icons.movie_creation_outlined,
                        color: AppColors.accentBlue,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            cat['name'] ?? '',
                            style: const TextStyle(
                              fontFamily: 'AppFont',
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.right,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'استكشف محتوى ${cat['name']}',
                            style: const TextStyle(
                              fontFamily: 'AppFont',
                              fontSize: 14,
                              color: Colors.white38,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ],
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

  Widget _buildPremiumCard(Map<String, dynamic> item, String type, int index) {
    return TVInteractive(
      onTap: () => _handleItemTap(item, type),
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(18),
      child: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white10, width: 0.5),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    AppImage(
                      imageUrl: item['logo'] ?? item['stream_icon'] ?? '',
                      fit: BoxFit.cover,
                      borderRadius: 18,
                    ),
                    Positioned.fill(
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black87],
                            stops: [0.6, 1.0],
                          ),
                        ),
                      ),
                    ),
                    if (type == 'live')
                      Positioned(
                        top: 10,
                        left: 10,
                        child: _buildBadge('LIVE', Colors.red),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              item['name'] ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'AppFont',
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.9),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildShimmerGrid() {
    return const Center(
      child: CircularProgressIndicator(
        color: AppColors.accentBlue,
        strokeWidth: 2,
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: FadeIn(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.movie_filter_rounded,
              color: Colors.white.withOpacity(0.1),
              size: 80,
            ),
            const SizedBox(height: 15),
            Text(
              'لا يوجد نتائج تطابق بحثك',
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleItemTap(Map<String, dynamic> item, String type) {
    if (type == 'live' || type == 'movie') {
      final channel = Channel(
        id: item['id'] ?? '',
        name: item['name'] ?? '',
        logoUrl: item['logo'] ?? '',
        categoryId: 'our_world',
        sources: [
          VideoSource(
            quality: 'Auto',
            url: item['url'] ?? '',
            drmType: item['drmType'],
            drmKey: item['drmKey'],
            drmLicenseUrl: item['drmLicenseUrl'],
            headers: item['headers'] != null
                ? Map<String, String>.from(item['headers'] as Map)
                : null,
          ),
        ],
      );
      Navigator.pushNamed(
        context,
        '/player',
        arguments: {'channel': channel, 'isLive': type == 'live'},
      );
    } else {
      Navigator.pushNamed(
        context,
        '/our_world_series_details',
        arguments: item,
      );
    }
  }

  Widget _buildGlobalSearchResults() {
    if (_isSearchLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppColors.accentBlue),
            const SizedBox(height: 15),
            Text(
              'جاري البحث والتحميل...',
              style: TextStyle(
                fontFamily: 'AppFont',
                color: Colors.white.withOpacity(0.6),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) return _buildNoResults();

    final bool isTV = AppTheme.isTV(context);
    if (isTV) {
      return GridView.builder(
        padding: const EdgeInsets.all(15),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 6,
          childAspectRatio: 0.68,
          crossAxisSpacing: 15,
          mainAxisSpacing: 18,
        ),
        itemCount: _searchResults.length,
        itemBuilder: (context, index) {
          final item = _searchResults[index];
          String type = _inferType(item);
          return _buildPremiumCard(item, type, index);
        },
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(15),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final item = _searchResults[index];
        final type = _inferType(item);
        return _buildExtendedPremiumCard(item, type, index);
      },
    );
  }

  String _inferType(Map<String, dynamic> item) {
    final url = (item['url'] ?? '').toString();
    if (url.contains('/live/') || !url.contains('.')) return 'live';
    if (url.contains('/movie/')) return 'movie';
    return 'series';
  }

  Widget _buildExtendedPremiumCard(
    Map<String, dynamic> item,
    String type,
    int index,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: TVInteractive(
        onTap: () => _handleItemTap(item, type),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 180,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(20)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              fit: StackFit.expand,
              children: [
                AppImage(
                  imageUrl: item['logo'] ?? item['stream_icon'] ?? '',
                  fit: BoxFit.cover,
                  borderRadius: 20,
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.9),
                        Colors.black.withOpacity(0.2),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 15,
                  right: 15,
                  left: 15,
                  child: Row(
                    children: [
                      if (type == 'live') _buildBadge('LIVE', Colors.red),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item['name'] ?? '',
                          style: const TextStyle(
                            fontFamily: 'AppFont',
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const Positioned(
                  top: 15,
                  left: 15,
                  child: CircleAvatar(
                    backgroundColor: Colors.black45,
                    child: Icon(Icons.play_arrow_rounded, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _KeepAliveWrapper extends StatefulWidget {
  final Widget child;
  const _KeepAliveWrapper({required this.child});

  @override
  State<_KeepAliveWrapper> createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<_KeepAliveWrapper>
    with AutomaticKeepAliveClientMixin {
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }

  @override
  bool get wantKeepAlive => true;
}

class FadeIn extends StatelessWidget {
  final Widget child;
  const FadeIn({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 600),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Opacity(opacity: value, child: child);
      },
      child: child,
    );
  }
}
