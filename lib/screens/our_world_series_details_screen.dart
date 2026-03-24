import 'package:flutter/material.dart';
import 'package:almadar/core/theme.dart';
import 'package:almadar/services/data_service.dart';
import 'package:almadar/data/models.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:almadar/widgets/app_image.dart';

class OurWorldSeriesDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> series;
  const OurWorldSeriesDetailsScreen({super.key, required this.series});

  @override
  State<OurWorldSeriesDetailsScreen> createState() =>
      _OurWorldSeriesDetailsScreenState();
}

class _OurWorldSeriesDetailsScreenState
    extends State<OurWorldSeriesDetailsScreen> {
  Map<String, dynamic>? _details;
  bool _isLoading = true;
  int _selectedSeason = 1;

  @override
  void initState() {
    super.initState();
    _fetchSeriesInfo();
  }

  Future<void> _fetchSeriesInfo() async {
    final service = Provider.of<DataService>(context, listen: false);
    final account = await service.getActiveXtreamAccount().first;
    if (account == null) return;

    final url =
        "${account['host']}/player_api.php?username=${account['username']}&password=${account['password']}&action=get_series_info&series_id=${widget.series['id']}";

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        setState(() {
          _details = json.decode(response.body);
          _isLoading = false;
          if (_details?['episodes'] != null &&
              _details!['episodes'].isNotEmpty) {
            _selectedSeason =
                int.tryParse(_details!['episodes'].keys.first) ?? 1;
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                _buildAppBar(),
                SliverToBoxAdapter(child: _buildInfoSection()),
                SliverToBoxAdapter(child: _buildSeasonFilter()),
                _buildEpisodesList(),
              ],
            ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 300,
      pinned: true,
      backgroundColor: AppColors.background,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            AppImage(imageUrl: widget.series['logo'] ?? '', fit: BoxFit.cover),
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black, Colors.transparent],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection() {
    final info = _details?['info'] ?? {};
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.series['name'] ?? '',
            style: const TextStyle(
              fontFamily: 'AppFont',
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (info['rating'] != null) ...[
                const Icon(Icons.star, color: Colors.amber, size: 16),
                const SizedBox(width: 4),
                Text(
                  info['rating'].toString(),
                  style: const TextStyle(color: Colors.amber),
                ),
                const SizedBox(width: 15),
              ],
              Text(
                info['releaseDate'] ?? info['release_date'] ?? '',
                style: const TextStyle(color: Colors.white54),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            info['plot'] ?? 'لا يوجد وصف متاح.',
            style: const TextStyle(color: Colors.white70, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildSeasonFilter() {
    final episodes = _details?['episodes'] as Map<String, dynamic>? ?? {};
    if (episodes.isEmpty) return const SizedBox.shrink();
    final seasons = episodes.keys.toList();

    return Container(
      height: 40,
      margin: const EdgeInsets.only(bottom: 20),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: seasons.length,
        itemBuilder: (context, index) {
          final s = seasons[index];
          final isSelected = _selectedSeason == int.tryParse(s);
          return GestureDetector(
            onTap: () => setState(() => _selectedSeason = int.tryParse(s) ?? 1),
            child: Container(
              margin: const EdgeInsets.only(left: 10),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.accentBlue : Colors.white10,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'الموسم $s',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEpisodesList() {
    final episodesMap = _details?['episodes'] as Map<String, dynamic>? ?? {};
    final currentSeasonEpisodes =
        episodesMap[_selectedSeason.toString()] as List? ?? [];

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final ep = currentSeasonEpisodes[index];
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: SizedBox(
              width: 80,
              child: AppImage(
                imageUrl:
                    ep['info']?['movie_image'] ?? widget.series['logo'] ?? '',
                fit: BoxFit.cover,
                borderRadius: 8,
              ),
            ),
            title: Text(
              ep['title'] ?? 'الحلقة ${ep['episode_num'] ?? index + 1}',
              style: const TextStyle(fontFamily: 'AppFont', fontSize: 14),
            ),
            subtitle: Text(
              'جودة: ${ep['container_extension'] ?? 'MP4'}',
              style: const TextStyle(fontSize: 12, color: Colors.white38),
            ),
            onTap: () => _playEpisode(ep),
          ),
        );
      }, childCount: currentSeasonEpisodes.length),
    );
  }

  Future<void> _playEpisode(Map<String, dynamic> ep) async {
    final service = Provider.of<DataService>(context, listen: false);
    final account = await service.getActiveXtreamAccount().first;
    if (account == null) return;

    final url =
        "${account['host']}/series/${account['username']}/${account['password']}/${ep['id']}.${ep['container_extension'] ?? 'mp4'}";

    final channel = Channel(
      id: ep['id'].toString(),
      name:
          widget.series['name'] +
          " - " +
          (ep['title'] ?? 'الحلقة ${ep['episode_num']}'),
      logoUrl: widget.series['logo'] ?? '',
      categoryId: 'our_world_series',
      sources: [VideoSource(quality: 'Auto', url: url)],
    );
    Navigator.pushNamed(
      context,
      '/player',
      arguments: {'channel': channel, 'isLive': false},
    );
  }
}
