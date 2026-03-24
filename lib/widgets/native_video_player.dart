import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt_explode;
import 'package:video_player/video_player.dart';

class NativeVideoPlayer extends StatefulWidget {
  final String url;
  final String? quality;
  final Map<String, String>? drmData;
  final String? userAgent;
  final String? referer;
  final Function(bool isVisible)? onControlsVisibilityChange;
  final Function(List<String> qualities)? onAvailableQualities;
  final Function(int state)? onPlaybackState;
  final Function(String message)? onError;
  final List<Map<String, dynamic>>? sources;

  const NativeVideoPlayer({
    super.key,
    required this.url,
    this.quality,
    this.drmData,
    this.userAgent,
    this.referer,
    this.onControlsVisibilityChange,
    this.onAvailableQualities,
    this.onPlaybackState,
    this.onError,
    this.sources,
  });

  @override
  State<NativeVideoPlayer> createState() => NativeVideoPlayerState();
}

class NativeVideoPlayerState extends State<NativeVideoPlayer> {
  MethodChannel? _channel;
  VideoPlayerController? _iosController;
  bool _isInitialized = false;
  int _currentIosState = 0; // 0=None, 1=Buffering, 3=Ready, 4=Finished, -1=Error

  // Resolves YouTube links to a direct stream URL before passing to native player
  Future<String?> _resolveUrl(String url) async {
    if (url.contains('youtube.com') || url.contains('youtu.be')) {
      try {
        final yt = yt_explode.YoutubeExplode();

        // Robust ID extraction
        String? videoId;
        if (url.contains('youtu.be/')) {
          videoId = url.split('youtu.be/')[1].split('?')[0];
        } else if (url.contains('v=')) {
          videoId = url.split('v=')[1].split('&')[0];
        } else if (url.contains('/live/')) {
          videoId = url.split('/live/')[1].split('?')[0];
        } else if (url.contains('/shorts/')) {
          videoId = url.split('/shorts/')[1].split('?')[0];
        } else if (url.contains('/embed/')) {
          videoId = url.split('/embed/')[1].split('?')[0];
        }

        if (videoId == null) {
          try {
            videoId = yt_explode.VideoId.parseVideoId(url);
          } catch (_) {}
        }

        if (videoId == null) {
          debugPrint('Could not extract YouTube ID from: $url');
          return null;
        }

        debugPrint('Extracted YouTube ID: $videoId');
        final vid = yt_explode.VideoId(videoId);
        final video = await yt.videos.get(vid);

        String? streamUrl;
        if (video.isLive) {
          debugPrint('YouTube Video is LIVE, fetching HLS URL...');
          streamUrl = await yt.videos.streamsClient.getHttpLiveStreamUrl(vid);
        } else {
          debugPrint('YouTube Video is VOD, fetching manifest...');
          final manifest = await yt.videos.streamsClient.getManifest(vid);
          final streamInfo = manifest.muxed.withHighestBitrate();
          streamUrl = streamInfo.url.toString();
        }

        yt.close();
        debugPrint('YouTube Resolved Stream URL: $streamUrl');
        return streamUrl;
      } catch (e) {
        debugPrint('YouTube extraction failed for $url: $e');
        return null;
      }
    }
    return url;
  }

  @override
  void initState() {
    super.initState();
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      _initIosController();
    }
  }

  Future<void> _initIosController() async {
    if (_iosController != null) {
      await _iosController!.dispose();
    }

    String finalUrl = widget.url;
    if (finalUrl.contains('youtube.com') || finalUrl.contains('youtu.be')) {
      final resolved = await _resolveUrl(finalUrl);
      if (resolved != null) {
        finalUrl = resolved;
      }
    }

    _iosController = VideoPlayerController.networkUrl(
      Uri.parse(finalUrl),
      httpHeaders: {
        'User-Agent': widget.userAgent ?? 'IPTVSmartersPlayer',
        'Referer': widget.referer ?? '',
      },
    );

    try {
      await _iosController!.initialize();
      if (mounted) {
        setState(() => _isInitialized = true);
        _iosController!.play();
        _iosController!.addListener(_iosListener);
        widget.onPlaybackState?.call(3); // Ready
      }
    } catch (e) {
      debugPrint('iOS VideoPlayer Initialization Failed: $e');
      widget.onError?.call("فشل تشغيل القناة على iOS");
    }
  }

  void _iosListener() {
    if (_iosController == null) return;
    
    final value = _iosController!.value;
    
    // Convert status to compatible state with Android
    // Android states: 1=Idle, 2=Buffering, 3=Ready, 4=Ended
    int newState = 0;
    if (value.isBuffering) {
      newState = 2; // Buffering
    } else if (value.isInitialized) {
      newState = 3; // Ready/Playing
    } else if (value.hasError) {
      newState = -1; // Error
    }

    if (value.position >= value.duration && value.duration > Duration.zero) {
      newState = 4; // Ended
    }

    if (newState != _currentIosState) {
      _currentIosState = newState;
      widget.onPlaybackState?.call(newState);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final bool isYouTube =
          widget.url.contains('youtube.com') || widget.url.contains('youtu.be');

      return PlatformViewLink(
        viewType: 'native_video_player_view',
        surfaceFactory: (context, controller) {
          return AndroidViewSurface(
            controller: controller as AndroidViewController,
            gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
            hitTestBehavior: PlatformViewHitTestBehavior.opaque,
          );
        },
        onCreatePlatformView: (params) {
          return PlatformViewsService.initExpensiveAndroidView(
            id: params.id,
            viewType: 'native_video_player_view',
            layoutDirection: TextDirection.ltr,
            creationParams: {
              'url': isYouTube ? null : widget.url,
              'drmData': widget.drmData,
              'quality': widget.quality,
              'userAgent': widget.userAgent,
              'referer': widget.referer,
              'sources': widget.sources,
            },
            creationParamsCodec: const StandardMessageCodec(),
            onFocus: () => params.onFocusChanged(true),
          )
            ..addOnPlatformViewCreatedListener(params.onPlatformViewCreated)
            ..addOnPlatformViewCreatedListener((int id) {
              _channel = MethodChannel('native_video_player_$id');
              _channel?.setMethodCallHandler((call) async {
                switch (call.method) {
                  case 'onPlaybackState':
                    int state = call.arguments['state'];
                    if (mounted) {
                      widget.onPlaybackState?.call(state);
                      if (state == 4) {
                        _reconnect();
                      }
                    }
                    break;
                  case 'onAvailableQualities':
                    final List<dynamic> qualities = call.arguments['qualities'];
                    debugPrint('NativeVideoPlayer: Received qualities from Native: $qualities');
                    widget.onAvailableQualities?.call(List<String>.from(qualities));
                    break;
                  case 'onError':
                    if (mounted) {
                      final String msg = call.arguments['message'];
                      if (widget.onError != null) {
                        widget.onError!(msg);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(msg),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                      }
                    }
                    break;
                  case 'onControlsVisibilityChange':
                    final bool isVisible = call.arguments['isVisible'];
                    widget.onControlsVisibilityChange?.call(isVisible);
                    break;
                }
              });

              // Resolve YouTube after view is created
              if (isYouTube) {
                _resolveUrl(widget.url).then((resolvedUrl) {
                  if (mounted) {
                    if (resolvedUrl != null) {
                      _channel?.invokeMethod('play', {
                        'url': resolvedUrl,
                        'drmData': widget.drmData,
                        'quality': widget.quality,
                        'userAgent': widget.userAgent,
                        'referer': widget.referer,
                        'sources': widget.sources,
                      });
                    } else {
                      widget.onError?.call("تعذر استخراج رابط البث من يوتيوب");
                    }
                  }
                });
              }
            })
            ..create();
        },
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      if (_iosController == null || !_isInitialized) {
        return const Center(
          child: CircularProgressIndicator(color: Colors.blue),
        );
      }
      return Center(
        child: AspectRatio(
          aspectRatio: _iosController!.value.aspectRatio,
          child: VideoPlayer(_iosController!),
        ),
      );
    }
    // For other platforms (macOS, Windows) - show unsupported message
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.play_disabled, color: Colors.white54, size: 60),
          SizedBox(height: 12),
          Text(
            'المشغل يعمل على أجهزة أندرويد فقط',
            style: TextStyle(color: Colors.white54),
          ),
        ],
      ),
    );
  }

  @override
  void didUpdateWidget(NativeVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Deep comparison of DRM data and sources to avoid redundant 'play' calls 
    // leading to infinite buffering loops.
    final bool drmChanged = !mapEquals(oldWidget.drmData, widget.drmData);
    final bool sourcesChanged = !listEquals(oldWidget.sources, widget.sources);
    
    if (oldWidget.url != widget.url ||
        drmChanged ||
        oldWidget.quality != widget.quality ||
        oldWidget.userAgent != widget.userAgent ||
        oldWidget.referer != widget.referer ||
        sourcesChanged) {
        
      debugPrint('NativeVideoPlayer: didUpdateWidget detected changes, re-playing...');
      
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        _initIosController();
      } else {
        // Check if YouTube link
        if (widget.url.contains('youtube.com') ||
            widget.url.contains('youtu.be')) {
          _resolveUrl(widget.url).then((resolvedUrl) {
            if (mounted && resolvedUrl != null) {
              _channel?.invokeMethod('play', {
                'url': resolvedUrl,
                'drmData': widget.drmData,
                'quality': widget.quality,
                'userAgent': widget.userAgent,
                'referer': widget.referer,
                'sources': widget.sources,
              });
            }
          });
        } else {
          _channel?.invokeMethod('play', {
            'url': widget.url,
            'drmData': widget.drmData,
            'quality': widget.quality,
            'userAgent': widget.userAgent,
            'referer': widget.referer,
            'sources': widget.sources,
          });
        }
      }
    }
  }

  Future<void> setResizeMode(int mode) async {
    await _channel?.invokeMethod('setResizeMode', {'mode': mode});
  }

  Future<int> getPosition() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return _iosController?.value.position.inMilliseconds ?? 0;
    }
    return await _channel?.invokeMethod<int>('getPosition') ?? 0;
  }

  Future<int> getDuration() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return _iosController?.value.duration.inMilliseconds ?? 0;
    }
    return await _channel?.invokeMethod<int>('getDuration') ?? 0;
  }

  Future<void> seekTo(int positionMs) async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await _iosController?.seekTo(Duration(milliseconds: positionMs));
      return;
    }
    await _channel?.invokeMethod('seekTo', {'position': positionMs});
  }

  Future<void> pause() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await _iosController?.pause();
      return;
    }
    await _channel?.invokeMethod('pause');
  }

  Future<void> resume() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await _iosController?.play();
      return;
    }
    await _channel?.invokeMethod('resume');
  }

  Future<Map<String, dynamic>?> getLiveWindow() async {
    final result = await _channel?.invokeMethod('getLiveWindow');
    return result != null ? Map<String, dynamic>.from(result) : null;
  }

  Future<void> stop() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await _iosController?.pause();
      await _iosController?.seekTo(Duration.zero);
      return;
    }
    await _channel?.invokeMethod('stop');
  }

  Future<void> startCast() async {
    await _channel?.invokeMethod('startCast');
  }

  Future<void> play(
    String url, {
    Map<String, String>? drmData,
    String? quality,
    String? userAgent,
    String? referer,
    List<Map<String, dynamic>>? sources,
  }) async {
    // Resolve YouTube before playing
    if (url.contains('youtube.com') || url.contains('youtu.be')) {
      final resolved = await _resolveUrl(url);
      if (resolved == null) {
        widget.onError?.call("تعذر استخراج رابط البث من يوتيوب");
        return;
      }
      url = resolved;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      // Re-init for quality change (disposes old one)
      // This is a simplified quality change: reload current URL or selected sourcered url
      // but on iOS, usually HLS handles it. If user selected a specific quality source:
      _initIosController(); // This will use widget.url (which should be updated if called from outside)
      return;
    }
    await _channel?.invokeMethod('play', {
      'url': url,
      'drmData': drmData,
      'quality': quality,
      'userAgent': userAgent,
      'referer': referer,
      'sources': sources,
    });
  }

  Future<void> invokeMethod(String method, [dynamic arguments]) async {
    await _channel?.invokeMethod(method, arguments);
  }

  void _reconnect() {
    _channel?.invokeMethod('play', {
      'url': widget.url,
      'drmData': widget.drmData,
      'quality': widget.quality,
      'userAgent': widget.userAgent,
      'referer': widget.referer,
      'sources': widget.sources,
    });
  }

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    _channel?.invokeMethod('stop');
    _iosController?.removeListener(_iosListener);
    _iosController?.dispose();
    super.dispose();
  }
}
