import 'package:flutter/material.dart';
import 'package:almadar/services/match_service.dart';
import 'package:almadar/data/match_models.dart';
import 'package:almadar/data/models.dart';
import 'package:almadar/core/theme.dart';
import 'package:almadar/widgets/app_image.dart';
import 'package:almadar/screens/player_screen.dart';
import 'package:almadar/widgets/tv_interactive.dart';
import 'dart:ui';

class MatchScheduleScreen extends StatefulWidget {
  const MatchScheduleScreen({super.key});

  @override
  State<MatchScheduleScreen> createState() => _MatchScheduleScreenState();
}

class _MatchScheduleScreenState extends State<MatchScheduleScreen> {
  final MatchService _matchService = MatchService();
  late Future<List<MatchEvent>> _matchesFuture;

  @override
  void initState() {
    super.initState();
    _matchesFuture = _matchService.getMatches();
  }

  void _refresh() {
    setState(() {
      _matchesFuture = _matchService.getMatches();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // 🏆 Dynamic Sports Background Mesh
          Positioned(
            top: -100,
            left: -100,
            child: _buildGlowSphere(Colors.green.withOpacity(0.08), 400),
          ),
          Positioned(
            bottom: -150,
            right: -100,
            child: _buildGlowSphere(AppColors.accentBlue.withOpacity(0.1), 450),
          ),

          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildPremiumHeader(),
                FutureBuilder<List<MatchEvent>>(
                  future: _matchesFuture,
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
                    if (snapshot.hasError ||
                        !snapshot.hasData ||
                        snapshot.data!.isEmpty) {
                      return SliverFillRemaining(
                        child: _buildNoMatchesWidget(),
                      );
                    }

                    final matches = snapshot.data!;
                    final bool isTV = AppTheme.isTV(context);

                    return SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
                      sliver: isTV
                          ? SliverGrid(
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    mainAxisSpacing: 25,
                                    crossAxisSpacing: 25,
                                    childAspectRatio: 1.5,
                                  ),
                              delegate: SliverChildBuilderDelegate(
                                (context, index) => _buildPremiumMatchCard(
                                  matches[index],
                                  index,
                                ),
                                childCount: matches.length,
                              ),
                            )
                          : SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) => _buildPremiumMatchCard(
                                  matches[index],
                                  index,
                                ),
                                childCount: matches.length,
                              ),
                            ),
                    );
                  },
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
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
        child: Container(),
      ),
    );
  }

  Widget _buildPremiumHeader() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TVInteractive(
              onTap: _refresh,
              borderRadius: BorderRadius.circular(15),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white10),
                ),
                child: const Icon(
                  Icons.refresh_rounded,
                  color: Colors.white70,
                  size: 24,
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'مركز المباريات',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'بث مباشر وأهم الأحداث الرياضية',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.4),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumMatchCard(MatchEvent match, int index) {
    final bool isLive = match.status == "جارية الآن";

    return FadeIn(
      delay: Duration(milliseconds: index * 100),
      child: Container(
        margin: const EdgeInsets.only(bottom: 25),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: isLive
                  ? Colors.red.withOpacity(0.1)
                  : Colors.black.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: isLive ? Colors.red.withOpacity(0.3) : Colors.white10,
                  width: 1.5,
                ),
              ),
              child: TVInteractive(
                onTap: () => _showServerSelection(match),
                borderRadius: BorderRadius.circular(30),
                padding: EdgeInsets.zero,
                child: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          _buildChampionsHeader(match.champions),
                          const SizedBox(height: 25),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildTeamSection(
                                match.team1Name,
                                match.team1Logo,
                              ),
                              _buildScoreOrVs(match, isLive),
                              _buildTeamSection(
                                match.team2Name,
                                match.team2Logo,
                              ),
                            ],
                          ),
                          const SizedBox(height: 25),
                          _buildMatchFooter(match),
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
    );
  }

  Widget _buildChampionsHeader(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          color: AppColors.accentBlue.withOpacity(0.9),
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildTeamSection(String name, String logo) {
    return SizedBox(
      width: 90,
      child: Column(
        children: [
          Container(
            width: 75,
            height: 75,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10),
              ],
            ),
            child: AppImage(imageUrl: logo, fit: BoxFit.contain),
          ),
          const SizedBox(height: 12),
          Text(
            name,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildScoreOrVs(MatchEvent match, bool isLive) {
    return Column(
      children: [
        const Text(
          'VS',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: Colors.white10,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: isLive
                ? Colors.red.withOpacity(0.15)
                : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isLive ? Colors.red.withOpacity(0.5) : Colors.white10,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLive) ...[const PulseDot(), const SizedBox(width: 6)],
              Text(
                isLive ? 'جارية الآن' : match.date,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isLive ? Colors.red : Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMatchFooter(MatchEvent match) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildInfoItem(
            Icons.mic_rounded,
            match.commentary.isNotEmpty ? match.commentary : 'غير متوفر',
          ),
          Container(width: 1, height: 20, color: Colors.white10),
          _buildInfoItem(
            Icons.tv_rounded,
            match.channel.isNotEmpty ? match.channel : 'القناة الرياضية',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.accentBlue),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withOpacity(0.6),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildNoMatchesWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.sports_soccer_rounded,
            color: Colors.white.withOpacity(0.05),
            size: 100,
          ),
          const SizedBox(height: 20),
          const Text(
            'لا توجد مباريات حالياً في الجدول',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'سيتم تحديث القائمة عند توفر أحداث جديدة',
            style: TextStyle(color: Colors.white24, fontSize: 12),
          ),
        ],
      ),
    );
  }

  void _showServerSelection(MatchEvent match) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      pageBuilder: (context, _, __) => Container(),
      transitionBuilder: (context, anim1, anim2, child) {
        return FadeTransition(
          opacity: anim1,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.8, end: 1.0).animate(
              CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
            ),
            child: Dialog(
              backgroundColor: Colors.transparent,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(35),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    padding: const EdgeInsets.all(25),
                    decoration: BoxDecoration(
                      color: Color(0xFF1E1E1E).withOpacity(0.9),
                      borderRadius: BorderRadius.circular(35),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'اختر جودة البث',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${match.team1Name} vs ${match.team2Name}',
                          style: TextStyle(color: Colors.white38, fontSize: 13),
                        ),
                        const SizedBox(height: 25),
                        FutureBuilder<List<MatchServer>>(
                          future: match.servers.isNotEmpty
                              ? Future.value(match.servers)
                              : _matchService.getMatchServers(match.id),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Padding(
                                padding: EdgeInsets.all(40),
                                child: CircularProgressIndicator(
                                  color: AppColors.accentBlue,
                                ),
                              );
                            }
                            final servers = snapshot.data ?? [];
                            if (servers.isEmpty) {
                              return const Padding(
                                padding: EdgeInsets.all(20),
                                child: Text(
                                  'لا توجد سيرفرات متاحة الآن',
                                  style: TextStyle(color: Colors.white38),
                                ),
                              );
                            }
                            return Column(
                              children: servers.asMap().entries.map((entry) {
                                final index = entry.key;
                                final server = entry.value;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: TVInteractive(
                                    onTap: () {
                                      Navigator.pop(context);
                                      _playMatch(match, servers, index);
                                    },
                                    borderRadius: BorderRadius.circular(20),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 18,
                                        horizontal: 20,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.05),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.05),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.play_circle_outline_rounded,
                                            color: AppColors.accentBlue,
                                          ),
                                          const SizedBox(width: 15),
                                          Text(
                                            server.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          const Spacer(),
                                          const Icon(
                                            Icons.flash_on_rounded,
                                            color: Colors.amber,
                                            size: 16,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _playMatch(
    MatchEvent match,
    List<MatchServer> servers,
    int initialIndex,
  ) {
    if (servers.isEmpty) return;

    List<VideoSource> videoSources = servers.map((server) {
      final headers = <String, String>{};
      if (server.userAgent != null) headers['User-Agent'] = server.userAgent!;
      if (server.headers != null) headers.addAll(server.headers!);

      return VideoSource(
        quality: server.name,
        url: server.url,
        headers: headers.isNotEmpty ? headers : null,
      );
    }).toList();

    final channel = Channel(
      id: match.id,
      name: '${match.team1Name} vs ${match.team2Name}',
      logoUrl: match.team1Logo,
      sources: videoSources,
      categoryId: 'matches',
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          channel: channel,
          initialSourceIndex: initialIndex,
          isLive: true,
        ),
      ),
    );
  }
}

class FadeIn extends StatelessWidget {
  final Widget child;
  final Duration delay;
  const FadeIn({super.key, required this.child, this.delay = Duration.zero});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 600),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class PulseDot extends StatefulWidget {
  const PulseDot({super.key});

  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
