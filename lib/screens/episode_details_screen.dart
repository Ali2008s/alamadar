import 'package:flutter/material.dart';
import 'package:almadar/core/theme.dart';
import 'package:almadar/services/entertainment_service.dart';
import 'package:almadar/data/entertainment_models.dart';
import 'package:almadar/data/models.dart'; // For Channel and VideoSource
import 'package:almadar/screens/player_screen.dart';
import 'package:almadar/widgets/app_image.dart';

class EpisodeDetailsScreen extends StatefulWidget {
  final int id;
  const EpisodeDetailsScreen({super.key, required this.id});

  @override
  State<EpisodeDetailsScreen> createState() => _EpisodeDetailsScreenState();
}

class _EpisodeDetailsScreenState extends State<EpisodeDetailsScreen> {
  final EntertainmentService _service = EntertainmentService();
  late Future<EpisodeDetails> _details;

  @override
  void initState() {
    super.initState();
    _details = _service.fetchEpisodeDetails(widget.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: FutureBuilder<EpisodeDetails>(
        future: _details,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 60),
                  const SizedBox(height: 16),
                  Text(
                    'خطأ: ${snapshot.error}',
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            );
          }

          final details = snapshot.data!;

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 250,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      AppImage(
                        imageUrl:
                            'https://admin.dramaramadan.net${details.thumbnail}',
                        fit: BoxFit.cover,
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withOpacity(0.9),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        details.seriesTitle,
                        style: const TextStyle(
                          color: AppColors.accentBlue,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.right,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'الحلقة ${details.episodeNumber}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                        ),
                        textAlign: TextAlign.right,
                      ),
                      if (details.description != null &&
                          details.description!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          details.description!,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ],
                      const SizedBox(height: 30),
                      const Text(
                        'سيرفرات المشاهدة',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.right,
                      ),
                      const Divider(color: Colors.white24),
                      const SizedBox(height: 10),
                      ...details.watchLinks.map(
                        (link) => _buildWatchButton(link, details),
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

  Widget _buildWatchButton(WatchLink link, EpisodeDetails details) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.cardBg,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: const BorderSide(color: AppColors.accentBlue, width: 0.5),
        ),
        onPressed: () {
          // Pass all available watch links as sources for in-player switching
          final sources = details.watchLinks
              .map((l) => VideoSource(quality: l.quality, url: l.url))
              .toList();

          final channel = Channel(
            id: 'entertainment_${details.id}',
            name: '${details.seriesTitle} - حلقة ${details.episodeNumber}',
            logoUrl: 'https://admin.dramaramadan.net${details.thumbnail}',
            categoryId: 'entertainment',
            sources: sources,
          );

          // Initial source index should be the one selected
          final initialIndex = details.watchLinks.indexOf(link);

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PlayerScreen(
                channel: channel,
                initialSourceIndex: initialIndex,
                isLive: false,
              ),
            ),
          );
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(link.quality, style: const TextStyle(color: Colors.white54)),
            Row(
              children: [
                Text(
                  link.serverName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 10),
                const Icon(Icons.play_circle_fill, color: AppColors.accentBlue),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
