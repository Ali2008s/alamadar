import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:almadar/services/data_service.dart';
import 'package:almadar/data/models.dart';
import 'package:almadar/core/theme.dart';
import 'package:almadar/widgets/app_image.dart';
import 'package:almadar/widgets/tv_interactive.dart';
import 'package:almadar/screens/player_screen.dart';
import 'dart:ui';
import 'dart:math';

class CategoryScreen extends StatefulWidget {
  final Category category;

  const CategoryScreen({super.key, required this.category});

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen>
    with TickerProviderStateMixin {
  String _searchQuery = "";
  bool _isSearching = false;

  @override
  Widget build(BuildContext context) {
    final dataService = Provider.of<DataService>(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          _buildBackgroundGlow(),
          CustomScrollView(
            slivers: [_buildAppBar(), _buildChannelsGrid(dataService)],
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundGlow() {
    return Positioned(
      top: -100,
      right: -50,
      child: Container(
        width: 300,
        height: 300,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.accentBlue.withOpacity(0.05),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
          child: Container(),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      pinned: true,
      backgroundColor: AppColors.background.withOpacity(0.9),
      title: _isSearching
          ? TextField(
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'ابحث عن قناة...',
                border: InputBorder.none,
                hintStyle: TextStyle(color: Colors.white38),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            )
          : Text(
              widget.category.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: Icon(_isSearching ? Icons.close : Icons.search),
          onPressed: () => setState(() {
            _isSearching = !_isSearching;
            if (!_isSearching) _searchQuery = "";
          }),
        ),
      ],
    );
  }

  Widget _buildChannelsGrid(DataService service) {
    return StreamBuilder<List<Channel>>(
      stream: service.getChannels(widget.category.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildShimmerGrid();
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: EdgeInsets.only(top: 100),
                child: Text(
                  'لا توجد قنوات في هذا القسم',
                  style: TextStyle(color: Colors.white38, fontSize: 16),
                ),
              ),
            ),
          );
        }

        final channels = snapshot.data!
            .where(
              (c) => c.name.toLowerCase().contains(_searchQuery.toLowerCase()),
            )
            .toList();

        if (channels.isEmpty && _searchQuery.isNotEmpty) {
          return const SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: EdgeInsets.only(top: 100),
                child: Text(
                  'لم يتم العثور على نتائج للبحث',
                  style: TextStyle(color: Colors.white38, fontSize: 16),
                ),
              ),
            ),
          );
        }

        final bool isTV = AppTheme.isTV(context);
        if (isTV) {
          return SliverPadding(
            padding: const EdgeInsets.all(15),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6,
                mainAxisSpacing: 15,
                crossAxisSpacing: 15,
                childAspectRatio: 1.0,
              ),
              delegate: SliverChildBuilderDelegate((context, index) {
                final channel = channels[index];
                return _AnimatedChannelCard(
                  channel: channel,
                  index: index,
                  onTap: () => _handleChannelTap(channel, channels),
                );
              }, childCount: channels.length),
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final channel = channels[index];
              return _buildExtendedChannelCard(channel, index, channels);
            }, childCount: channels.length),
          ),
        );
      },
    );
  }

  void _handleChannelTap(Channel channel, List<Channel> allChannels) {
    final panelEntries = allChannels.map((ch) {
      return PlayerPanelEntry(
        id: ch.id,
        title: ch.name,
        onTap: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => PlayerScreen(
                channel: ch,
                isLive: true,
                panelEntries: allChannels
                    .map(
                      (c) => PlayerPanelEntry(
                        id: c.id,
                        title: c.name,
                        onTap: () {},
                      ),
                    )
                    .toList(),
                panelTitle: 'القنوات',
              ),
            ),
          );
        },
      );
    }).toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          channel: channel,
          isLive: true,
          panelEntries: panelEntries,
          panelTitle: 'القنوات',
        ),
      ),
    );
  }

  Widget _buildExtendedChannelCard(
    Channel channel,
    int index,
    List<Channel> allChannels,
  ) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 300 + (index % 10 * 50)),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 15),
        child: TVInteractive(
          onTap: () => _handleChannelTap(channel, allChannels),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                const SizedBox(width: 15),
                const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white24,
                  size: 16,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    channel.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Container(
                    width: 70,
                    height: 70,
                    color: Colors.white.withOpacity(0.03),
                    child: AppImage(
                      imageUrl: channel.logoUrl,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(width: 15),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Shimmer loading skeleton grid
  Widget _buildShimmerGrid() {
    return SliverPadding(
      padding: const EdgeInsets.all(15),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 15,
          crossAxisSpacing: 15,
          childAspectRatio: 0.75,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => _ShimmerCard(index: index),
          childCount: 12,
        ),
      ),
    );
  }
}

// Animated channel card with staggered entrance animation
class _AnimatedChannelCard extends StatefulWidget {
  final Channel channel;
  final int index;
  final VoidCallback onTap;

  const _AnimatedChannelCard({
    required this.channel,
    required this.index,
    required this.onTap,
  });

  @override
  State<_AnimatedChannelCard> createState() => _AnimatedChannelCardState();
}

class _AnimatedChannelCardState extends State<_AnimatedChannelCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _scaleAnimation = Tween<double>(
      begin: 0.9,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    // Staggered delay based on index
    Future.delayed(Duration(milliseconds: min(widget.index * 50, 300)), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isTV = AppTheme.isTV(context);
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: TVInteractive(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(15),
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.white10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: AppImage(
                        imageUrl: widget.channel.logoUrl,
                        fit: isTV ? BoxFit.contain : BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.channel.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: isTV ? 10 : 12,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Shimmer skeleton card for loading state
class _ShimmerCard extends StatefulWidget {
  final int index;
  const _ShimmerCard({required this.index});

  @override
  State<_ShimmerCard> createState() => _ShimmerCardState();
}

class _ShimmerCardState extends State<_ShimmerCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return Column(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  gradient: LinearGradient(
                    begin: Alignment(-1.0 + 2.0 * _shimmerController.value, 0),
                    end: Alignment(1.0 + 2.0 * _shimmerController.value, 0),
                    colors: [
                      Colors.white.withOpacity(0.03),
                      Colors.white.withOpacity(0.08),
                      Colors.white.withOpacity(0.03),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 10,
              width: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                gradient: LinearGradient(
                  begin: Alignment(-1.0 + 2.0 * _shimmerController.value, 0),
                  end: Alignment(1.0 + 2.0 * _shimmerController.value, 0),
                  colors: [
                    Colors.white.withOpacity(0.03),
                    Colors.white.withOpacity(0.08),
                    Colors.white.withOpacity(0.03),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
