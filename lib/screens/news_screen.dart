import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import 'package:flutter_html/flutter_html.dart';
import 'package:almadar/core/theme.dart';
import 'package:shimmer/shimmer.dart';
import 'package:google_fonts/google_fonts.dart';

// ──────────────────────────────────────────────────────────────────────────────
// Models
// ──────────────────────────────────────────────────────────────────────────────

class NewsCategory {
  final int id;
  final String name;
  final String imageUrl;

  const NewsCategory({
    required this.id,
    required this.name,
    required this.imageUrl,
  });

  factory NewsCategory.fromJson(Map<String, dynamic> json) {
    return NewsCategory(
      id: json['category_id'] as int,
      name: json['category_name'] as String,
      imageUrl: (json['category_image'] as String? ?? '')
          .replaceAll('//', '/')
          .replaceFirst(':/', '://'),
    );
  }
}

class NewsArticle {
  final int id;
  final String title;
  final String thumbnailUrl;
  final String imageUrl;

  const NewsArticle({
    required this.id,
    required this.title,
    required this.thumbnailUrl,
    required this.imageUrl,
  });

  factory NewsArticle.fromJson(Map<String, dynamic> json) {
    return NewsArticle(
      id: json['article_id'] as int,
      title: json['article_title'] as String? ?? '',
      thumbnailUrl: json['article_thumbnail'] as String? ?? '',
      imageUrl: json['article_image'] as String? ?? '',
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// API Service
// ──────────────────────────────────────────────────────────────────────────────

class _NewsApi {
  static const String _base = 'https://api.alkora.app/v2/articles';
  static const Map<String, String> _params = {
    'version_code': '49',
    'version_name': '2.2.9',
    'platform': '0',
  };

  static Future<Map<String, dynamic>> _get(String url,
      [Map<String, String>? extra]) async {
    final uri = Uri.parse(url).replace(queryParameters: {
      ..._params,
      if (extra != null) ...extra,
    });
    final response = await http.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode == 200) {
      return json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    }
    throw Exception('HTTP ${response.statusCode}');
  }

  static Future<List<NewsCategory>> fetchCategories() async {
    final data = await _get(_base);
    return (data['categories'] as List? ?? [])
        .map((e) => NewsCategory.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<List<NewsArticle>> fetchArticlesByCategory(int categoryId) async {
    final data = await _get(_base, {'category_id': '$categoryId'});
    return ((data['articles']?['data']) as List? ?? [])
        .map((e) => NewsArticle.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<Map<String, dynamic>> fetchArticleDetail(int articleId) async {
    final uri = Uri.parse('$_base/$articleId').replace(queryParameters: _params);
    final response = await http.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode == 200) {
      return json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    }
    throw Exception('HTTP ${response.statusCode}');
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// NewsScreen – Premium News Category Hub
// ──────────────────────────────────────────────────────────────────────────────

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  bool _loading = true;
  String? _error;
  List<NewsCategory> _categories = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final cats = await _NewsApi.fetchCategories();
      if (mounted) {
        setState(() {
          _categories = cats;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildStickyHeader(),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              sliver: _buildBody(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStickyHeader() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShaderMask(
              shaderCallback: (bounds) =>
                  AppColors.accentGradient.createShader(bounds),
              child: Text(
                'الأخبار',
                style: GoogleFonts.cairo(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'الفئات',
              style: GoogleFonts.cairo(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: Colors.white.withOpacity(0.35),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              height: 4,
              width: 55,
              decoration: BoxDecoration(
                gradient: AppColors.accentGradient,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accentBlue.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return _buildSkeletonLoader();
    if (_error != null) return SliverToBoxAdapter(child: _buildErrorWidget());

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, i) {
          return _CategoryPremiumCard(
            category: _categories[i],
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CategoryArticlesScreen(category: _categories[i]),
                ),
              );
            },
          );
        },
        childCount: _categories.length,
      ),
    );
  }

  Widget _buildSkeletonLoader() {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (_, __) => Shimmer.fromColors(
          baseColor: Colors.white.withOpacity(0.04),
          highlightColor: Colors.white.withOpacity(0.09),
          period: const Duration(milliseconds: 2800), // Sleepy, very slow shimmer
          child: Container(
            height: 110,
            margin: const EdgeInsets.only(bottom: 18),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(28),
            ),
          ),
        ),
        childCount: 5,
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 100),
        child: Column(
          children: [
            const Icon(Icons.wifi_off_rounded, color: Colors.white10, size: 85),
            const SizedBox(height: 20),
            Text(
              'تعذر تحميل الأقسام حالياً',
              style: GoogleFonts.cairo(color: Colors.white38, fontSize: 17),
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: _loadCategories,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentBlue.withOpacity(0.12),
                foregroundColor: AppColors.accentBlue,
                side: const BorderSide(color: AppColors.accentBlue, width: 1.8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                elevation: 0,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Text('تحديث',
                    style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Strong Premium Category Card Widget
// ──────────────────────────────────────────────────────────────────────────────

class _CategoryPremiumCard extends StatelessWidget {
  final NewsCategory category;
  final VoidCallback onTap;

  const _CategoryPremiumCard({required this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          splashColor: AppColors.accentBlue.withOpacity(0.1),
          highlightColor: AppColors.accentBlue.withOpacity(0.05),
          child: Container(
            height: 110,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Colors.white.withOpacity(0.07),
                width: 1.3,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.55),
                  blurRadius: 25,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Row(
              children: [
                // Modern Image Box with Glow
                Container(
                  width: 82,
                  height: 82,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accentBlue.withOpacity(0.1),
                        blurRadius: 10,
                        spreadRadius: -2,
                      ),
                    ],
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.accentBlue.withOpacity(0.2),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: CachedNetworkImage(
                      imageUrl: category.imageUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => const Icon(Icons.newspaper_rounded,
                          color: Colors.white12, size: 30),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                // Text Content
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.name,
                        style: GoogleFonts.cairo(
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'إقرأ آخر مستجدات ${category.name}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.cairo(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.3),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                // iOS-Style Circular Arrow
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: AppColors.accentBlue,
                    size: 16,
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

// ──────────────────────────────────────────────────────────────────────────────
// Category Articles Screen
// ──────────────────────────────────────────────────────────────────────────────

class CategoryArticlesScreen extends StatefulWidget {
  final NewsCategory category;
  const CategoryArticlesScreen({super.key, required this.category});

  @override
  State<CategoryArticlesScreen> createState() => _CategoryArticlesScreenState();
}

class _CategoryArticlesScreenState extends State<CategoryArticlesScreen> {
  List<NewsArticle> _articles = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadArticles();
  }

  Future<void> _loadArticles() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final arts = await _NewsApi.fetchArticlesByCategory(widget.category.id);
      if (mounted) {
        setState(() {
          _articles = arts;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.category.name,
            style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 21)),
        backgroundColor: AppColors.background,
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return _buildArticleSkeleton();
    if (_error != null) {
      return Center(
          child: Text('حدث خطأ في جلب المقالات', style: GoogleFonts.cairo()));
    }
    if (_articles.isEmpty) {
      return Center(
          child:
              Text('لا تتوفر أخبار حالياً', style: GoogleFonts.cairo(color: Colors.white12)));
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 18,
        mainAxisSpacing: 18,
        childAspectRatio: 0.74,
      ),
      itemCount: _articles.length,
      itemBuilder: (context, i) => _ArticleGridCard(
        article: _articles[i],
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => NewsDetailScreen(article: _articles[i]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildArticleSkeleton() {
    return Shimmer.fromColors(
      baseColor: Colors.white.withOpacity(0.04),
      highlightColor: Colors.white.withOpacity(0.08),
      period: const Duration(milliseconds: 2500),
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.74,
        ),
        itemCount: 6,
        itemBuilder: (_, __) => Container(
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(26),
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Modern Article Card
// ──────────────────────────────────────────────────────────────────────────────

class _ArticleGridCard extends StatelessWidget {
  final NewsArticle article;
  final VoidCallback onTap;

  const _ArticleGridCard({required this.article, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.07), width: 1.1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 42,
                child: Hero(
                  tag: 'art_hero_${article.id}',
                  child: CachedNetworkImage(
                    imageUrl: article.thumbnailUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) =>
                        Container(color: Colors.white.withOpacity(0.04)),
                  ),
                ),
              ),
              Expanded(
                flex: 30,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        article.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: GoogleFonts.cairo(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Colors.white.withOpacity(0.95),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// NewsDetailScreen – Ultra-Premium iOS Look
// ──────────────────────────────────────────────────────────────────────────────

class NewsDetailScreen extends StatefulWidget {
  final NewsArticle article;
  const NewsDetailScreen({super.key, required this.article});

  @override
  State<NewsDetailScreen> createState() => _NewsDetailScreenState();
}

class _NewsDetailScreenState extends State<NewsDetailScreen> {
  bool _loading = true;
  String? _error;
  String? _fullHtml;
  List<NewsArticle> _related = [];

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final data = await _NewsApi.fetchArticleDetail(widget.article.id);
      if (mounted) {
        final items = data['article_items'] as List? ?? [];
        String buffer = "";
        for (var item in items) {
          if (item is Map && item.containsKey('content')) {
            buffer += item['content'] as String;
          }
        }

        final relatedList = data['similar_articles'] as List? ?? [];
        final List<NewsArticle> relatedArts = relatedList
            .map((e) => NewsArticle.fromJson(e as Map<String, dynamic>))
            .toList();

        setState(() {
          _fullHtml = buffer.isNotEmpty ? buffer : null;
          _related = relatedArts;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 360,
            pinned: true,
            stretch: true,
            backgroundColor: AppColors.background,
            leading: Padding(
              padding: const EdgeInsets.all(10.0),
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 18),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Hero(
                tag: 'art_hero_${widget.article.id}',
                child: CachedNetworkImage(
                  imageUrl: widget.article.imageUrl,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.article.title,
                    textAlign: TextAlign.right,
                    style: GoogleFonts.cairo(
                      fontSize: 27,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.3,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Container(
                        height: 5,
                        width: 48,
                        decoration: BoxDecoration(
                          gradient: AppColors.accentGradient,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accentBlue.withOpacity(0.2),
                              blurRadius: 5,
                            )
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        'منذ قليل',
                        style: GoogleFonts.cairo(
                            color: Colors.white.withOpacity(0.22),
                            fontSize: 14,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 35),
                  _buildContent(),
                  if (!_loading && _related.isNotEmpty) ...[
                    const SizedBox(height: 60),
                    _buildSectionHeader('أخبار مقترحة'),
                    const SizedBox(height: 24),
                    _buildRelatedGrid(),
                  ],
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return Shimmer.fromColors(
        baseColor: Colors.white.withOpacity(0.06),
        highlightColor: Colors.white.withOpacity(0.12),
        period: const Duration(milliseconds: 2000),
        child: Column(
          children: List.generate(
              7,
              (index) => Container(
                    height: 22,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(10)),
                  )),
        ),
      );
    }

    if (_error != null || _fullHtml == null) {
      return Center(
          child: Text('عذراً، تعذر تحميل نص الخبر',
              style: GoogleFonts.cairo(color: Colors.white54)));
    }

    return Html(
      data: _fullHtml!,
      style: {
        "body": Style(
          fontFamily: 'Cairo', // Cleanest iOS-like Arabic font
          color: Colors.white.withOpacity(0.88),
          fontSize: FontSize(18.5),
          textAlign: TextAlign.right,
          direction: TextDirection.rtl,
          lineHeight: const LineHeight(1.85),
          padding: HtmlPaddings.zero,
          margin: Margins.zero,
        ),
        "img": Style(
          width: Width(100, Unit.percent),
          padding: HtmlPaddings.symmetric(vertical: 26),
        ),
        "p": Style(
          margin: Margins.only(bottom: 24),
        ),
        "strong": Style(
          color: Colors.white,
          fontWeight: FontWeight.w900,
        ),
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.cairo(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 3,
          width: 35,
          decoration: const BoxDecoration(
            gradient: AppColors.accentGradient,
          ),
        ),
      ],
    );
  }

  Widget _buildRelatedGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 18,
        mainAxisSpacing: 18,
        childAspectRatio: 0.74,
      ),
      itemCount: _related.length.clamp(0, 4),
      itemBuilder: (context, i) => _ArticleGridCard(
        article: _related[i],
        onTap: () {
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              transitionDuration: const Duration(milliseconds: 600),
              pageBuilder: (context, animation, secondaryAnimation) =>
                  NewsDetailScreen(article: _related[i]),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(
                  opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
                  child: child,
                );
              },
            ),
          );
        },
      ),
    );
  }
}
