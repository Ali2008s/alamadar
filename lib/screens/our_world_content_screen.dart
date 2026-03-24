import 'package:flutter/material.dart';
import 'package:almadar/core/theme.dart';
import 'package:almadar/services/data_service.dart';
import 'package:provider/provider.dart';
import 'package:almadar/widgets/app_image.dart';
import 'package:almadar/widgets/tv_interactive.dart';
import 'package:almadar/screens/player_screen.dart';
import 'package:almadar/data/models.dart';
import 'dart:ui';

class OurWorldContentScreen extends StatefulWidget {
  final String categoryId;
  final String categoryName;
  final String type; // 'live', 'movies', 'series'

  const OurWorldContentScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
    required this.type,
  });

  @override
  State<OurWorldContentScreen> createState() => _OurWorldContentScreenState();
}

class _OurWorldContentScreenState extends State<OurWorldContentScreen> {
  String _searchQuery = "";
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            // Glassmorphism spheres
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
                  Expanded(child: _buildContentGrid()),
                ],
              ),
            ),
          ],
        ),
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
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _isSearching
                      ? _buildSearchField()
                      : Text(
                          widget.categoryName,
                          key: const ValueKey('title'),
                          style: TextStyle(
                            fontFamily: 'AppFont',
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            foreground: Paint()
                              ..shader = AppColors.accentGradient.createShader(
                                const Rect.fromLTWH(0.0, 0.0, 200.0, 70.0),
                              ),
                          ),
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
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      key: const ValueKey('search'),
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
          hintText: 'ابحث...',
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
        onChanged: (v) => setState(() => _searchQuery = v),
      ),
    );
  }

  Widget _buildContentGrid() {
    final service = Provider.of<DataService>(context, listen: false);

    // Convert 'live', 'movies', 'series' to 'channels', 'movies', 'series' for API call
    String endpointType = widget.type;
    if (widget.type == 'live') endpointType = 'channels';

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: service.getOurWorldContent(
        endpointType,
        categoryId: widget.categoryId,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());

        final allItems = snapshot.data ?? [];
        final filteredItems = allItems
            .where(
              (item) => (item['name'] ?? '').toString().toLowerCase().contains(
                _searchQuery.toLowerCase(),
              ),
            )
            .toList();

        if (filteredItems.isEmpty)
          return const Center(
            child: Text(
              'لا توجد عناصر مطابقة',
              style: TextStyle(color: Colors.white),
            ),
          );

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(15, 10, 15, 20),
          physics: const BouncingScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: AppTheme.isTV(context) ? 6 : 3,
            childAspectRatio: widget.type == 'live' ? 0.9 : 0.68,
            crossAxisSpacing: 15,
            mainAxisSpacing: 18,
          ),
          itemCount: filteredItems.length,
          itemBuilder: (context, index) {
            final item = filteredItems[index];
            return _buildPremiumCard(item, widget.type, index);
          },
        );
      },
    );
  }

  Widget _buildPremiumCard(Map<String, dynamic> item, String type, int index) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 300 + (index % 10 * 50)),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Opacity(opacity: value, child: child),
        );
      },
      child: TVInteractive(
        onTap: () => _handleItemTap(item, type),
        padding: EdgeInsets.zero,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: Colors.white.withOpacity(0.04), // Glass background
            border: Border.all(color: Colors.white10, width: 0.5),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Column(
                children: [
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        AppImage(
                          imageUrl: item['logo'] ?? item['stream_icon'] ?? '',
                          fit: BoxFit.cover,
                          borderRadius: 0,
                        ),
                        // Shadow Overlay
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
                            top: 8,
                            left: 8,
                            child: _buildBadge('LIVE', Colors.red),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                    ),
                    child: Text(
                      item['name'] ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'AppFont',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.8),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  void _handleItemTap(Map<String, dynamic> item, String type) {
    if (type == 'series') {
      // Navigate to series details
      Navigator.pushNamed(
        context,
        '/our_world_series_details',
        arguments: item,
      );
      return;
    }

    // Build VideoSource from item fields
    final rawUrl = item['url'] ?? item['streamUrl'] ?? '';
    if (rawUrl.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('الرابط غير متاح')));
      return;
    }

    Map<String, String>? headers;
    if (item['headers'] is Map) {
      headers = Map<String, String>.from(item['headers'] as Map);
    }

    final channel = Channel(
      id: item['id']?.toString() ?? '',
      name: item['name']?.toString() ?? '',
      logoUrl: item['logo'] ?? item['stream_icon'] ?? '',
      categoryId: 'our_world',
      sources: [
        VideoSource(
          quality: 'Auto',
          url: rawUrl,
          drmType: item['drmType']?.toString(),
          drmKey: item['drmKey']?.toString(),
          drmLicenseUrl: item['drmLicenseUrl']?.toString(),
          headers: headers,
        ),
      ],
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(channel: channel, isLive: type == 'live'),
      ),
    );
  }
}
