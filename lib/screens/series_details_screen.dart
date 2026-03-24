import 'package:flutter/material.dart';
import 'package:almadar/core/theme.dart';
import 'package:almadar/services/entertainment_service.dart';
import 'package:almadar/data/entertainment_models.dart';
import 'package:almadar/data/models.dart';
import 'package:almadar/screens/player_screen.dart';
import 'package:almadar/widgets/app_image.dart';
import 'package:almadar/widgets/tv_interactive.dart';
import 'package:almadar/services/persistence_service.dart';
import 'dart:ui';

class SeriesDetailsScreen extends StatefulWidget {
  final int id;
  const SeriesDetailsScreen({super.key, required this.id});

  @override
  State<SeriesDetailsScreen> createState() => _SeriesDetailsScreenState();
}

class _SeriesDetailsScreenState extends State<SeriesDetailsScreen>
    with SingleTickerProviderStateMixin {
  final EntertainmentService _service = EntertainmentService();
  late Future<SeriesDetails> _details;
  late Future<List<DramaItem>> _episodes;
  int _selectedSeasonIndex = 0;
  List<DramaItem> _episodeList = [];
  bool _storyExpanded = false;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();

    _details = _service.fetchSeriesDetails(widget.id);
    _details.then((d) {
      if (d.seasons.isNotEmpty) {
        setState(() {
          _episodes = _service.fetchEpisodes(d.seasons[0].id).then((list) {
            _episodeList = list;
            return list;
          });
        });
      }
    });
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _onSeasonChanged(Season season, int index) {
    setState(() {
      _selectedSeasonIndex = index;
      _episodes = _service.fetchEpisodes(season.id).then((list) {
        _episodeList = list;
        return list;
      });
    });
  }

  Future<void> _playEpisode(DramaItem ep, {int? episodeIndex}) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppColors.accentBlue),
      ),
    );

    try {
      final details = await _service.fetchEpisodeDetails(ep.id);
      if (!mounted) return;
      Navigator.pop(context);

      final sources = details.watchLinks
          .map((l) => VideoSource(quality: l.quality, url: l.url))
          .toList();

      if (sources.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا توجد روابط لهذه الحلقة')),
        );
        return;
      }

      final progressId = 'ep_${details.id}';

      final channel = Channel(
        id: 'entertainment_${details.id}',
        name: '${details.seriesTitle} - حلقة ${details.episodeNumber}',
        logoUrl: 'https://admin.dramaramadan.net${details.thumbnail}',
        categoryId: 'entertainment',
        sources: sources,
      );

      final panelEntries = _episodeList.asMap().entries.map((entry) {
        final idx = entry.key;
        final e = entry.value;
        return PlayerPanelEntry(
          id: 'ep_${e.id}',
          title: 'الحلقة ${e.episodeNumber}',
          onTap: () => _playEpisode(e, episodeIndex: idx),
        );
      }).toList();

      final currentEpIdx =
          episodeIndex ?? _episodeList.indexWhere((e) => e.id == ep.id);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PlayerScreen(
            channel: channel,
            isLive: false,
            progressId: progressId,
            panelEntries: panelEntries,
            panelTitle: 'الحلقات',
            currentEpisodeIndex: currentEpIdx,
            onNextEpisode: (nextIdx) {
              if (nextIdx < _episodeList.length) {
                Navigator.pop(context);
                _playEpisode(_episodeList[nextIdx], episodeIndex: nextIdx);
              }
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: FutureBuilder<SeriesDetails>(
          future: _details,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.accentBlue),
              );
            }
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'خطأ: ${snapshot.error}',
                  style: const TextStyle(color: Colors.white),
                ),
              );
            }

            final s = snapshot.data!;
            return FadeTransition(
              opacity: _fadeAnim,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  _buildCinematicHeader(s),
                  SliverToBoxAdapter(child: _buildInfoSection(s)),
                  if ((s.seasons.length) > 1)
                    SliverToBoxAdapter(child: _buildSeasonBar(s.seasons)),
                  SliverToBoxAdapter(child: _buildEpisodeHeader()),
                  _buildEpisodesList(),
                  const SliverToBoxAdapter(child: SizedBox(height: 60)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCinematicHeader(SeriesDetails s) {
    return SliverAppBar(
      expandedHeight: MediaQuery.of(context).size.height * 0.48,
      pinned: true,
      backgroundColor: Colors.black,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Banner image
            AppImage(
              imageUrl:
                  'https://admin.dramaramadan.net${s.banner.isNotEmpty ? s.banner : s.poster}',
              fit: BoxFit.cover,
            ),
            // Gradient overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.3),
                    Colors.transparent,
                    Colors.black.withOpacity(0.85),
                    Colors.black,
                  ],
                  stops: const [0.0, 0.3, 0.75, 1.0],
                ),
              ),
            ),
            // Bottom info
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    s.title,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      shadows: [Shadow(blurRadius: 12, color: Colors.black)],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _buildTag(s.status, AppColors.accentBlue),
                      if (s.releaseYear.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        _buildTag(s.releaseYear, Colors.white24),
                      ],
                      if (s.country.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        _buildTag(s.country, Colors.white24),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(String text, Color bg) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoSection(SeriesDetails s) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Play button
          TVInteractive(
            onTap: () {
              if (_episodeList.isNotEmpty) {
                _playEpisode(_episodeList.first, episodeIndex: 0);
              }
            },
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                gradient: AppColors.accentGradient,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accentBlue.withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.play_arrow_rounded, color: Colors.white, size: 26),
                  SizedBox(width: 8),
                  Text(
                    'شاهد الآن',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Story
          if (s.story.isNotEmpty) ...[
            GestureDetector(
              onTap: () => setState(() => _storyExpanded = !_storyExpanded),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    s.story,
                    textAlign: TextAlign.right,
                    maxLines: _storyExpanded ? null : 3,
                    overflow: _storyExpanded
                        ? TextOverflow.visible
                        : TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      height: 1.7,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _storyExpanded ? 'عرض أقل' : 'عرض المزيد',
                    style: TextStyle(
                      color: AppColors.accentBlue.withOpacity(0.9),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }

  Widget _buildSeasonBar(List<Season> seasons) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Text(
            'المواسم',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: seasons.asMap().entries.map((entry) {
                final idx = entry.key;
                final season = entry.value;
                final isSelected = _selectedSeasonIndex == idx;
                return Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: TVInteractive(
                    onTap: () => _onSeasonChanged(season, idx),
                    borderRadius: BorderRadius.circular(10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        gradient: isSelected ? AppColors.accentGradient : null,
                        color: isSelected ? null : Colors.white12,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'الموسم ${season.seasonNumber}',
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white54,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildEpisodeHeader() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            'الحلقات',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(width: 8),
          Icon(
            Icons.video_library_rounded,
            color: AppColors.accentBlue,
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildEpisodesList() {
    return FutureBuilder<List<DramaItem>>(
      future: _episodes,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(color: AppColors.accentBlue),
              ),
            ),
          );
        }
        final episodes = snap.data ?? [];
        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => _buildEpisodeCard(episodes[index], index),
            childCount: episodes.length,
          ),
        );
      },
    );
  }

  Widget _buildEpisodeCard(DramaItem ep, int index) {
    return FutureBuilder<int>(
      future: PersistenceService.getWatchProgress('ep_${ep.id}'),
      builder: (context, snapProg) {
        final savedProgress = snapProg.data ?? 0;
        final hasProgress = savedProgress > 10000;

        return TVInteractive(
          onTap: () => _playEpisode(ep, episodeIndex: index),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.07)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          // Episode thumbnail
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                AppImage(
                                  imageUrl:
                                      'https://admin.dramaramadan.net${ep.poster}',
                                  width: AppTheme.isTV(context) ? 160 : 110,
                                  height: AppTheme.isTV(context) ? 95 : 70,
                                  fit: BoxFit.cover,
                                  borderRadius: 10,
                                ),
                                Container(
                                  width: AppTheme.isTV(context) ? 160 : 110,
                                  height: AppTheme.isTV(context) ? 95 : 70,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.35),
                                  ),
                                ),
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: Colors.white.withOpacity(
                                    0.15,
                                  ),
                                  child: const Icon(
                                    Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          // Episode info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'الحلقة ${ep.episodeNumber}',
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                if (hasProgress)
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      const Text(
                                        'متابعة المشاهدة',
                                        style: TextStyle(
                                          color: AppColors.accentBlue,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(
                                        Icons.play_circle_rounded,
                                        color: AppColors.accentBlue,
                                        size: 14,
                                      ),
                                    ],
                                  )
                                else
                                  const Text(
                                    'شاهد الآن بجودة عالية',
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      color: Colors.white38,
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      // Progress bar
                      if (hasProgress)
                        FutureBuilder<int>(
                          future: PersistenceService.getWatchDuration(
                            'ep_${ep.id}',
                          ),
                          builder: (context, durSnap) {
                            final duration = durSnap.data ?? 0;
                            if (duration <= 0) return const SizedBox.shrink();
                            final ratio = (savedProgress / duration).clamp(
                              0.0,
                              1.0,
                            );
                            return Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: ratio,
                                  backgroundColor: Colors.white10,
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                        AppColors.accentBlue,
                                      ),
                                  minHeight: 3,
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
