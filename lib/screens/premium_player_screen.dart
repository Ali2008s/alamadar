import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:almadar/services/premium_service.dart';
import 'package:almadar/widgets/native_video_player.dart';
import 'package:almadar/core/theme.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:almadar/widgets/tv_interactive.dart';

class PremiumPlayerScreen extends StatefulWidget {
  final String channelId;
  final String channelName;

  const PremiumPlayerScreen({
    super.key,
    required this.channelId,
    required this.channelName,
  });

  @override
  State<PremiumPlayerScreen> createState() => _PremiumPlayerScreenState();
}

class _PremiumPlayerScreenState extends State<PremiumPlayerScreen> {
  final GlobalKey<NativeVideoPlayerState> _playerKey =
      GlobalKey<NativeVideoPlayerState>();
  bool _isLoading = true;
  List<Map<String, dynamic>> _sources = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSources();
    WakelockPlus.enable();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _loadSources() async {
    try {
      final premiumService = Provider.of<PremiumService>(
        context,
        listen: false,
      );
      final details = await premiumService.getChannelDetails(widget.channelId);

      if (details != null && details.sources.isNotEmpty) {
        // Convert VideoSource list to format expected by NativeVideoPlayer (List<Map<String, dynamic>>)
        final List<Map<String, dynamic>> sourcesMap = details.sources.map((s) {
          // Extra logic for DRM as per requirement 4: DASH only uses DRM
          final bool isDash = s.url.toLowerCase().endsWith('.mpd');

          return {
            'name': s.quality,
            'url': s.url,
            'userAgent':
                s.headers?['User-Agent'] ?? s.headers?['user-agent'] ?? '',
            'Referer': s.headers?['Referer'] ?? s.headers?['referer'] ?? '',
            'headers': s.headers != null ? jsonEncode(s.headers) : '',
            'scheme': isDash
                ? (s.drmType ?? '')
                : '', // Only apply scheme to DASH
            'license': isDash ? (s.drmKey ?? '') : '',
          };
        }).toList();

        if (mounted) {
          setState(() {
            _sources = sourcesMap;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _error = "No valid stream available";
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Error loading stream: $e";
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
        ]);
        await Future.delayed(const Duration(milliseconds: 50));
        if (context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (_sources.isNotEmpty)
            Positioned.fill(
              child: NativeVideoPlayer(
                key: _playerKey,
                url: _sources
                    .first['url'], // Initial URL, but native will use list
                sources: _sources,
                onPlaybackState: (state) {
                  if (state == 3) {
                    // Ready
                    if (mounted && _isLoading)
                      setState(() => _isLoading = false);
                  }
                },
              ),
            ),

          // Back Button
          Positioned(
            top: 20,
            right: 20,
            child: SafeArea(
              child: TVInteractive(
                onTap: () {
                  SystemChrome.setPreferredOrientations([
                    DeviceOrientation.portraitUp,
                  ]);
                  Navigator.pop(context);
                },
                borderRadius: BorderRadius.circular(12),
                child: const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),

          // Channel Name
          Positioned(
            top: 25,
            left: 20,
            child: SafeArea(
              child: Text(
                widget.channelName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(blurRadius: 10, color: Colors.black)],
                ),
              ),
            ),
          ),

          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: AppColors.accentBlue),
            ),

          if (_error != null)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Colors.redAccent,
                    size: 60,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  const SizedBox(height: 20),
                  TVInteractive(
                    onTap: () {
                      setState(() {
                        _isLoading = true;
                        _error = null;
                      });
                      _loadSources();
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accentBlue,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'إعادة المحاولة',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}
}
