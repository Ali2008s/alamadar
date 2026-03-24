import 'package:flutter/material.dart';
import 'package:almadar/core/theme.dart';
import 'package:almadar/widgets/gradient_text.dart';
import 'package:almadar/services/entertainment_service.dart';
import 'package:almadar/data/entertainment_models.dart';
import 'package:almadar/screens/country_series_screen.dart';
import 'package:almadar/screens/section_items_screen.dart';
import 'package:almadar/widgets/app_image.dart';
import 'package:almadar/widgets/tv_interactive.dart';
import 'dart:ui';

class EntertainmentScreen extends StatefulWidget {
  const EntertainmentScreen({super.key});

  @override
  State<EntertainmentScreen> createState() => _EntertainmentScreenState();
}

class _EntertainmentScreenState extends State<EntertainmentScreen> {
  final EntertainmentService _service = EntertainmentService();
  late Future<Map<String, dynamic>> _homeData;

  @override
  void initState() {
    super.initState();
    _homeData = _service.fetchHomeData();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            // 🎭 Cinematic Glow (Back to app official dynamic theme)
            Positioned(
              top: -150,
              right: -100,
              child: _buildGlow(AppColors.accentBlue.withOpacity(0.08), 400),
            ),
            Positioned(
              bottom: -150,
              left: -100,
              child: _buildGlow(AppColors.accentPink.withOpacity(0.08), 400),
            ),

            CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildModernAppBar(),
                FutureBuilder<Map<String, dynamic>>(
                  future: _homeData,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SliverFillRemaining(
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.accentBlue,
                          ),
                        ),
                      );
                    }
                    if (snapshot.hasError) {
                      return const SliverFillRemaining(
                        child: Center(child: Text('حدث خطأ في تحميل البيانات')),
                      );
                    }

                    final banners =
                        snapshot.data!['banners'] as List<DramaBanner>;
                    final sections =
                        snapshot.data!['sections'] as List<DramaSection>;
                    final countries =
                        snapshot.data!['countries'] as List<DramaCountry>;

                    return SliverList(
                      delegate: SliverChildListDelegate([
                        if (banners.isNotEmpty) _buildBanners(banners),
                        if (countries.isNotEmpty)
                          _buildHorizontalCountries(countries),
                        ...sections.map((section) => _buildSection(section)),
                        const SizedBox(height: 120),
                      ]),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlow(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
        child: Container(),
      ),
    );
  }

  Widget _buildModernAppBar() {
    return SliverAppBar(
      automaticallyImplyLeading: false, // 🚫 Removed Back Icon
      floating: true,
      pinned: true,
      expandedHeight: 110,
      backgroundColor: AppColors.background.withOpacity(0.8),
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: Padding(
          padding: const EdgeInsets.fromLTRB(20, 50, 20, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 🏷️ Correct App Name
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const GradientText(
                    'عالمنا الترفيهي',
                    gradient: AppColors.accentGradient,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                  ),
                  Text(
                    'استمتع بأحدث العروض',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              // 🔍 Clean Search Box
              TVInteractive(
                onTap: () => showSearch(
                  context: context,
                  delegate: EntertainmentSearchDelegate(_service),
                ),
                borderRadius: BorderRadius.circular(15),
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
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
        ),
      ),
    );
  }

  Widget _buildBanners(List<DramaBanner> banners) {
    return Container(
      height: 260,
      margin: const EdgeInsets.symmetric(vertical: 20),
      child: PageView.builder(
        itemCount: banners.length,
        controller: PageController(viewportFraction: 0.9),
        itemBuilder: (context, index) {
          final banner = banners[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: TVInteractive(
              onTap: () => Navigator.pushNamed(
                context,
                '/series_details',
                arguments: banner.seriesId,
              ),
              padding: EdgeInsets.zero,
              borderRadius: BorderRadius.circular(25),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(25),
                    child: AppImage(
                      imageUrl:
                          'https://admin.dramaramadan.net${banner.banner}',
                      fit: BoxFit.cover,
                      borderRadius: 25,
                    ),
                  ),
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black87,
                            Colors.transparent,
                            Colors.transparent,
                          ],
                          stops: [0.0, 0.4, 1.0],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 20,
                    right: 20,
                    left: 20,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.1),
                            ),
                          ),
                          child: Text(
                            banner.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                            textAlign: TextAlign.right,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSection(DramaSection section) {
    if (section.items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 35, 20, 15),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                section.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              TVInteractive(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SectionItemsScreen(
                      title: section.title,
                      items: section.items,
                    ),
                  ),
                ),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    'عرض الكل',
                    style: TextStyle(
                      color: AppColors.accentBlue.withOpacity(0.8),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            itemCount: section.items.length,
            itemBuilder: (context, index) {
              final item = section.items[index];
              return _buildDramaCard(item);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDramaCard(DramaItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: TVInteractive(
        onTap: () => Navigator.pushNamed(
          context,
          item.episodeNumber != null ? '/episode_details' : '/series_details',
          arguments: item.id,
        ),
        padding: EdgeInsets.zero,
        borderRadius: BorderRadius.circular(12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 140,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04), // Base background
              borderRadius: BorderRadius.circular(12),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 1. Poster Image covering the whole card
                AppImage(
                  imageUrl: 'https://admin.dramaramadan.net${item.poster}',
                  fit: BoxFit.cover,
                  borderRadius: 12,
                ),
                // 2. Gradient Overlay for text readability
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.4),
                          Colors.black.withOpacity(0.95),
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                ),
                // 3. Title at the bottom
                Positioned(
                  bottom: 12,
                  left: 10,
                  right: 10,
                  child: Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black,
                          blurRadius: 4,
                        )
                      ]
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHorizontalCountries(List<DramaCountry> countries) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 20),
      child: SizedBox(
        height: 45,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: countries.length,
          itemBuilder: (context, index) {
            final country = countries[index];
            return Padding(
              padding: const EdgeInsets.only(left: 10),
              child: TVInteractive(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CountrySeriesScreen(country: country),
                  ),
                ),
                borderRadius: BorderRadius.circular(12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.15),
                        ),
                      ),
                      child: Text(
                        country.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class EntertainmentSearchDelegate extends SearchDelegate {
  final EntertainmentService service;
  EntertainmentSearchDelegate(this.service);

  @override
  String get searchFieldLabel => 'بحث...';

  @override
  ThemeData appBarTheme(BuildContext context) {
    return Theme.of(context).copyWith(
      appBarTheme: AppBarTheme(backgroundColor: AppColors.background),
      inputDecorationTheme: const InputDecorationTheme(
        border: InputBorder.none,
        hintStyle: TextStyle(color: Colors.white24),
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) => [
    IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
  ];
  @override
  Widget? buildLeading(BuildContext context) => IconButton(
    icon: const Icon(Icons.arrow_back),
    onPressed: () => close(context, null),
  );

  @override
  Widget buildResults(BuildContext context) => _search(context);
  @override
  Widget buildSuggestions(BuildContext context) => _search(context);

  Widget _search(BuildContext context) {
    if (query.trim().isEmpty) return const SizedBox.shrink();
    return Directionality(
      textDirection: TextDirection.rtl,
      child: FutureBuilder<List<DramaItem>>(
        future: service.searchSeries(query),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(
              child: CircularProgressIndicator(color: AppColors.accentBlue),
            );
          final results = snapshot.data ?? [];
          if (results.isEmpty)
            return const Center(
              child: Text(
                'لا توجد نتائج',
                style: TextStyle(color: Colors.white24),
              ),
            );
          return GridView.builder(
            padding: const EdgeInsets.all(20),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.65,
              mainAxisSpacing: 15,
              crossAxisSpacing: 15,
            ),
            itemCount: results.length,
            itemBuilder: (context, index) {
              final item = results[index];
              return TVInteractive(
                onTap: () => Navigator.pushNamed(
                  context,
                  '/series_details',
                  arguments: item.id,
                ),
                padding: EdgeInsets.zero,
                borderRadius: BorderRadius.circular(15),
                child: Column(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: AppImage(
                          imageUrl:
                              'https://admin.dramaramadan.net${item.poster}',
                          fit: BoxFit.cover,
                          borderRadius: 15,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
