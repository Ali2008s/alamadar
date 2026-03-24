import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:almadar/widgets/tv_interactive.dart';
import 'package:almadar/core/theme.dart';
import 'package:almadar/data/models.dart';
import 'package:almadar/services/persistence_service.dart';
import 'package:almadar/services/platform_service.dart';
import 'package:almadar/widgets/native_video_player.dart';
import 'package:provider/provider.dart';
import 'package:almadar/services/data_service.dart';
import 'package:almadar/services/focus_sound_service.dart';

// ─────────────────────────────────────────────────────────────
// PlayerPanelEntry
// ─────────────────────────────────────────────────────────────
class PlayerPanelEntry {
  final String id;
  final String title;
  final VoidCallback onTap;
  const PlayerPanelEntry({
    required this.id,
    required this.title,
    required this.onTap,
  });
}

// ─────────────────────────────────────────────────────────────
// PlayerScreen
// ─────────────────────────────────────────────────────────────
class PlayerScreen extends StatefulWidget {
  final Channel channel;
  final int initialSourceIndex;
  final bool isLive;
  final bool forceLandscapeMode;
  final List<PlayerPanelEntry> panelEntries;
  final String panelTitle;
  final String? progressId;
  final int? currentEpisodeIndex;
  final Function(int nextIndex)? onNextEpisode;

  const PlayerScreen({
    super.key,
    required this.channel,
    this.initialSourceIndex = 0,
    this.isLive = true,
    this.forceLandscapeMode = true,
    this.panelEntries = const [],
    this.panelTitle = 'الحلقات',
    this.progressId,
    this.currentEpisodeIndex,
    this.onNextEpisode,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  static int _playerInstances = 0;

  final GlobalKey<NativeVideoPlayerState> _playerKey =
      GlobalKey<NativeVideoPlayerState>();

  int _sourceIndex = 0;
  bool _isPlaying = true;
  bool _isBuffering = true;
  bool _showControls = true;
  bool _isLocked = false;

  final ValueNotifier<int> _positionNotifier = ValueNotifier(0);
  final ValueNotifier<int> _durationNotifier = ValueNotifier(0);
  bool _isSeeking = false;

  List<String> _qualities = ['Auto'];
  String _selectedQuality = 'Auto';
  int _resizeMode = 1;

  double _volume = 1.0;
  double _brightness = 0.5;

  bool _showFwdFlash = false;
  bool _showRwdFlash = false;
  Timer? _flashTimer;

  bool _showNextEp = false;
  int _nextEpSec = 5;
  Timer? _nextEpTimer;

  bool _showPanel = false;
  bool _showChannelsPanel = false;
  String? _selectedLiveCategoryId;
  Timer? _hideTimer;
  Timer? _posTimer;
  Timer? _saveTimer;
  Timer? _fallbackTimer;

  final FocusNode _playFocusNode = FocusNode();

  static const MethodChannel _volCh = MethodChannel('com.almadar.volume');
  bool _canLoadVideo = false;

  // Cache sources list to avoid NativeVideoPlayer rebuild on quality/UI changes.
  // Rebuilding sources list triggers didUpdateWidget → restarts playback (corrupts encrypted streams).
  late final List<Map<String, dynamic>> _cachedSources;

  @override
  void initState() {
    super.initState();
    _playerInstances++;
    _sourceIndex = widget.initialSourceIndex;
    WidgetsBinding.instance.addObserver(this);
    _setLandscape();
    WakelockPlus.enable();
    PlatformService.setDisplayCutoutMode(true);

    // Build sources list ONCE to prevent NativeVideoPlayer didUpdateWidget from firing.
    // If sources list reference changes on every build, didUpdateWidget restarts playback
    // which corrupts DRM/headers streams (shows garbled image, freezes app).
    _cachedSources = widget.channel.sources.map((s) => {
      'name': s.quality,
      'url': s.url,
      'userAgent': s.headers?['User-Agent'] ?? s.headers?['user-agent'] ?? 'IPTVSmartersPlayer',
      'Referer': s.headers?['Referer'] ?? s.headers?['referer'] ?? '',
      'headers': s.headers != null ? jsonEncode(s.headers) : '',
      'drmType': s.drmType ?? '',
      'drmLicenseUrl': s.drmLicenseUrl ?? '',
      'drmKey': s.drmKey ?? '',
    }).toList();

    // Initial delay for smooth transition
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _canLoadVideo = true);
    });

    _startHideTimer();
    _startPosTimer();
    _fetchVolume();
    _saveHistory();

    if (!widget.isLive && widget.progressId != null) {
      _resumeProgress();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.paused) {
      _playerKey.currentState?.pause();
      setState(() => _isPlaying = false);
      _saveProgress();
    } else if (s == AppLifecycleState.resumed) {
      _playerKey.currentState?.resume();
      setState(() => _isPlaying = true);
    }
  }

  @override
  void dispose() {
    _playFocusNode.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _hideTimer?.cancel();
    _posTimer?.cancel();
    _saveTimer?.cancel();
    _nextEpTimer?.cancel();
    _fallbackTimer?.cancel();
    _flashTimer?.cancel();
    _saveProgress();
    WakelockPlus.disable();
    // Use a sync-safe way to restore previous orientation state via empty list or allowing all
    _playerInstances--;
    if (_playerInstances == 0) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      PlatformService.setDisplayCutoutMode(false);
    }
    _positionNotifier.dispose();
    _durationNotifier.dispose();
    super.dispose();
  }

  void _setLandscape() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    if (widget.forceLandscapeMode) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      // Allow all orientations including portrait
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _showControls && !_isSeeking) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControls() {
    if (_isLocked) return;
    setState(() => _showControls = !_showControls);
    if (_showControls) {
      _startHideTimer();
      // Delay slightly to ensure UI is built before requesting focus
      Future.delayed(const Duration(milliseconds: 50), () {
        if (mounted && _showControls && _playFocusNode.canRequestFocus) {
          _playFocusNode.requestFocus();
        }
      });
    }
  }

  void _showAndReset() {
    if (_isLocked) return;
    setState(() => _showControls = true);
    _startHideTimer();
  }

  void _startPosTimer() {
    _posTimer?.cancel();
    _posTimer = Timer.periodic(const Duration(milliseconds: 500), (
      timer,
    ) async {
      if (!mounted || _isSeeking) return;

      final state = _playerKey.currentState;
      if (state != null) {
        final pos = await state.getPosition();
        final dur = await state.getDuration();

        if (mounted) {
          _positionNotifier.value = pos;
          if (dur > 0) {
            _durationNotifier.value = dur;
          } else if (widget.isLive) {
            _durationNotifier.value = 0;
          }

          // Auto trigger next episode if near end
          if (!widget.isLive &&
              _durationNotifier.value > 0 &&
              (_durationNotifier.value - _positionNotifier.value) < 5000 &&
              !_showNextEp) {
            if (widget.onNextEpisode != null) _triggerNextEp();
          }
        }
      }
    });

    _saveTimer?.cancel();
    _saveTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) _saveProgress();
    });
  }

  void _saveHistory() {
    PersistenceService.addToHistory({
      'id': widget.channel.id,
      'title': widget.channel.name, // EntertainmentScreen uses 'title'
      'poster': widget.channel.logoUrl, // EntertainmentScreen uses 'poster'
      'categoryId': widget.channel.categoryId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  void _saveProgress() {
    if (widget.progressId != null && _positionNotifier.value > 0 && _durationNotifier.value > 0) {
      PersistenceService.saveWatchProgress(
        widget.progressId!,
        _positionNotifier.value,
        _durationNotifier.value,
      );
    }
  }

  Future<void> _resumeProgress() async {
    final saved = await PersistenceService.getWatchProgress(widget.progressId!);
    if (saved > 1000 && mounted) {
      // Give the player a moment to load
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) _performSeek(saved);
    }
  }

  void _togglePlay() {
    if (_isPlaying) {
      _playerKey.currentState?.pause();
    } else {
      _playerKey.currentState?.resume();
    }
    setState(() => _isPlaying = !_isPlaying);
    _showAndReset();
  }

  void _performSeek(int ms) async {
    final state = _playerKey.currentState;
    if (state == null) return;

    setState(() {
      _isSeeking = true;
    });
    _positionNotifier.value = ms;

    // Direct seek call to native
    await state.seekTo(ms);

    // Minor delay to let ExoPlayer stabilize
    await Future.delayed(const Duration(milliseconds: 600));

    if (mounted) {
      setState(() {
        _isSeeking = false;
      });
      _showAndReset(); // Keep controls visible
    }
  }

  void _seekFwd() {
    // Allow seeking even in Live for DVR support
    _performSeek(_positionNotifier.value + 10000);
    _flash(true);
    _showAndReset();
  }

  void _seekBwd() {
    // Allow seeking even in Live for DVR support
    _performSeek(_positionNotifier.value - 10000);
    _flash(false);
    _showAndReset();
  }

  void _flash(bool fwd) {
    _flashTimer?.cancel();
    setState(() {
      _showFwdFlash = fwd;
      _showRwdFlash = !fwd;
    });
    _flashTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted)
        setState(() {
          _showFwdFlash = false;
          _showRwdFlash = false;
        });
    });
  }

  void _handleError() {
    final totalSrc = widget.channel.sources.length;
    if (totalSrc <= 1) return;
    _fallbackTimer?.cancel();
    _fallbackTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() {
        _sourceIndex = (_sourceIndex + 1) % totalSrc;
        _isBuffering = true;
        _qualities = ['Auto'];
        _selectedQuality = 'Auto';
      });
      _playerKey.currentState?.play(
        widget.channel.sources[_sourceIndex].url,
        drmData: widget.channel.sources[_sourceIndex].drmType != null
            ? {
                'type': widget.channel.sources[_sourceIndex].drmType ?? '',
                'licenseUrl': widget.channel.sources[_sourceIndex].drmLicenseUrl ?? '',
                'key': widget.channel.sources[_sourceIndex].drmKey ?? '',
              }
            : null,
      );
    });
  }

  void _cycleResize() {
    setState(() {
      if (_resizeMode == 1)
        _resizeMode = 3;
      else if (_resizeMode == 3)
        _resizeMode = 0;
      else
        _resizeMode = 1;
    });
    _playerKey.currentState?.setResizeMode(_resizeMode);
    _showAndReset();
  }

  Future<void> _fetchVolume() async {
    try {
      final v = await _volCh.invokeMethod<double>('getVolume');
      if (v != null && mounted) setState(() => _volume = v);
    } catch (_) {}
  }

  Future<void> _setVolume(double v) async {
    try {
      await _volCh.invokeMethod('setVolume', {'value': v});
    } catch (_) {}
  }

  Future<void> _setBrightness(double v) async {
    try {
      await _volCh.invokeMethod('setBrightness', {'value': v});
    } catch (_) {}
  }

  // ── Gestures ──
  double _dragStartY = 0;
  double _dragValStart = 0;
  bool _isDraggingLeft = true;

  void _onDragStart(DragStartDetails d, bool left) {
    _dragStartY = d.globalPosition.dy;
    _isDraggingLeft = left;
    _dragValStart = left ? _brightness : _volume;
  }

  void _onDragUpdate(DragUpdateDetails d) {
    final dy = _dragStartY - d.globalPosition.dy;
    final h = MediaQuery.of(context).size.height;
    final delta = dy / (h * 0.8);
    final nv = (_dragValStart + delta).clamp(0.01, 1.0);
    if (_isDraggingLeft) {
      setState(() => _brightness = nv);
      _setBrightness(nv);
    } else {
      setState(() => _volume = nv);
      _setVolume(nv);
    }
  }

  String _fmt(int ms) {
    if (ms <= 0) return '00:00';
    final duration = Duration(milliseconds: ms);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    final String minutesStr = minutes.toString().padLeft(2, '0');
    final String secondsStr = seconds.toString().padLeft(2, '0');

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:$minutesStr:$secondsStr';
    }
    return '$minutesStr:$secondsStr';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.channel.sources.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text('لا توجد ', style: TextStyle(color: Colors.white)),
        ),
      );
    }

    final src = widget.channel.sources[_sourceIndex];

    return PopScope(
      canPop: false, // Intercept system back gestures and buttons
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        
        // Reset to default orientations immediately
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
        
        Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Focus(
          autofocus: true,
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent) {
              final keyName = event.logicalKey.keyLabel.toLowerCase();
              if (keyName.contains('select') ||
                  keyName.contains('enter') ||
                  keyName == ' ' ||
                  event.logicalKey == LogicalKeyboardKey.numpadEnter) {
                if (!_showControls) {
                  _toggleControls();
                  return KeyEventResult.handled;
                }
              } else if (keyName.contains('arrow') ||
                  keyName.contains('dpad')) {
                if (!_showControls) {
                  // If controls are hidden, arrows do seeking only (NOT volume/brightness)
                  // Volume/brightness are touch-only to avoid accidental changes on TV
                  if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                    _seekFwd();
                    return KeyEventResult.handled;
                  } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                    _seekBwd();
                    return KeyEventResult.handled;
                  }
                  // Up/Down arrows without controls do nothing (no volume via remote)
                  return KeyEventResult.ignored;
                } else {
                  // Controls are visible. Restart the hide timer because the user is navigating!
                  _startHideTimer();
                  // DO NOT catch the event. Let the framework move focus to buttons.
                  return KeyEventResult.ignored;
                }
              }
            }
            return KeyEventResult.ignored;
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggleControls,
            child: Stack(
              children: [
                // Player
                Positioned.fill(
                  child: !_canLoadVideo
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.accentBlue,
                          ),
                        )
                      : NativeVideoPlayer(
                          key: _playerKey,
                          url: src.url,
                          quality: _selectedQuality,
                          drmData: src.drmType != null
                              ? {
                                  'type': src.drmType ?? '',
                                  'licenseUrl': src.drmLicenseUrl ?? '',
                                  'key': src.drmKey ?? '',
                                }
                              : null,
                          userAgent:
                              src.headers?['User-Agent'] ??
                              src.headers?['user-agent'] ??
                              "IPTVSmartersPlayer",
                          referer:
                              src.headers?['Referer'] ?? src.headers?['referer'],
                          sources: _cachedSources, // Use cached list — prevents didUpdateWidget from restarting playback
                          onAvailableQualities: (q) {
                            if (mounted)
                              setState(() => _qualities = ['Auto', ...q]);
                          },
                          onPlaybackState: (state) async {
                            if (!mounted) return;
                            setState(
                                () => _isBuffering = (state == 1 || state == 2));
                            if (state == 3) {
                              _fallbackTimer?.cancel();
                              // Force update duration when ready
                              final dur =
                                  await _playerKey.currentState?.getDuration() ??
                                      0;
                              if (mounted && dur > 0) {
                                _durationNotifier.value = dur;
                              }
                            }
                            if (state == 4 || state == -1) {
                              if (!widget.isLive)
                                _triggerNextEp();
                              else
                                _handleError();
                            }
                          },
                          onError: (errMsg) {
                            if (mounted) _handleError();
                          },
                        ),
                ),

                // Gestures
                if (!_isLocked) Positioned.fill(child: _buildGestureZones()),

                // Flash feedback
                if (_showRwdFlash) _buildFlash(false),
                if (_showFwdFlash) _buildFlash(true),

                // Controls
                if (!_isLocked)
                  Positioned.fill(
                    child: AnimatedOpacity(
                      opacity: _showControls ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 250),
                      child: ExcludeFocus(
                        excluding: !_showControls,
                        child: IgnorePointer(
                          ignoring: !_showControls,
                          child: _buildControls(),
                        ),
                      ),
                    ),
                  ),

                // Buffering indicator (Exactly centered)
                if (_isBuffering && !_showNextEp)
                  const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.accentBlue,
                      strokeWidth: 3,
                    ),
                  ),

                // Side panel & Next ep overheads
                if (_isLocked) _buildLockOverlay(),
                if (_showNextEp && !widget.isLive) _buildNextEpOverlay(),
                if (_showPanel) _buildSidePanelOverlay(),
                if (_showChannelsPanel) _buildLiveChannelsOverlay(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGestureZones() {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        children: [
          // Left - Brightness (Visually Left, seeks backward)
          Expanded(
            flex: 1,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggleControls,
              onDoubleTap: _seekBwd,
              onVerticalDragStart: (d) => _onDragStart(d, true),
              onVerticalDragUpdate: _onDragUpdate,
            ),
          ),
          // Center - Tap and Horizontal Seek
          Expanded(
            flex: 2,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggleControls,
              onDoubleTap: _togglePlay,
              onHorizontalDragStart: (d) {
                setState(() {
                  _isSeeking = true;
                  _showControls = true;
                });
              },
              onHorizontalDragUpdate: (d) {
                if (_durationNotifier.value <= 0 && !widget.isLive) return;
                final dx = d.primaryDelta ?? 0;
                final speedMultiplier = 1500; // ms per pixel dragged
                final newPos = _positionNotifier.value + (dx * speedMultiplier).toInt();

                final maxDur = _durationNotifier.value > 0 ? _durationNotifier.value : newPos + 10000;
                _positionNotifier.value = newPos.clamp(0, maxDur);
                _playerKey.currentState?.seekTo(_positionNotifier.value);
              },
              onHorizontalDragEnd: (d) {
                _performSeek(_positionNotifier.value);
              },
            ),
          ),
          // Right - Volume
          Expanded(
            flex: 1,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggleControls,
              onDoubleTap: _seekFwd,
              onVerticalDragStart: (d) => _onDragStart(d, false),
              onVerticalDragUpdate: _onDragUpdate,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlash(bool fwd) {
    return Align(
      alignment: fwd ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.35,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: fwd ? Alignment.centerLeft : Alignment.centerRight,
            end: fwd ? Alignment.centerRight : Alignment.centerLeft,
            colors: [Colors.transparent, Colors.white10],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              fwd ? Icons.forward_10_rounded : Icons.replay_10_rounded,
              color: Colors.white,
              size: 54,
            ),
            const SizedBox(height: 8),
            Text(
              fwd ? '+10 ثانية' : '-10 ثانية',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Column(
      children: [
        _buildTopBar(),
        Expanded(
          child: Row(
            children: [
              _buildSideIndicator(true),
              Expanded(
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildBigSeekBtn(false),
                      const SizedBox(width: 40),
                      _buildBigPlayBtn(),
                      const SizedBox(width: 40),
                      _buildBigSeekBtn(true),
                    ],
                  ),
                ),
              ),
              _buildSideIndicator(false),
            ],
          ),
        ),
        _buildBottomBar(),
      ],
    );
  }

  Widget _buildSideIndicator(bool left) {
    final val = left ? _brightness : _volume;
    return Focus(
      canRequestFocus: true,
      onFocusChange: (hasFocus) {
        setState(() {});
      },
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            final nv = (val + 0.1).clamp(0.01, 1.0);
            if (left) {
              setState(() => _brightness = nv);
              _setBrightness(nv);
            } else {
              setState(() => _volume = nv);
              _setVolume(nv);
            }
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            final nv = (val - 0.1).clamp(0.01, 1.0);
            if (left) {
              setState(() => _brightness = nv);
              _setBrightness(nv);
            } else {
              setState(() => _volume = nv);
              _setVolume(nv);
            }
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (context) {
          final hasFocus = Focus.of(context).hasFocus;
          return Container(
            width: 50,
            margin: const EdgeInsets.symmetric(vertical: 60),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: hasFocus ? AppColors.accentBlue : Colors.transparent,
                width: 2,
              ),
              color: hasFocus ? Colors.white.withOpacity(0.1) : Colors.transparent,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  left ? Icons.brightness_6_rounded : Icons.volume_up_rounded,
                  color: hasFocus ? Colors.white : Colors.white54,
                  size: 16,
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Container(
                    width: 3,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        FractionallySizedBox(
                          heightFactor: val,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: AppColors.accentGradient,
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.accentBlue.withOpacity(0.3),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 20, 15, 15),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withOpacity(0.8), Colors.transparent],
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () {
              SystemChrome.setPreferredOrientations([
                DeviceOrientation.portraitUp,
              ]);
              Navigator.of(context).pop();
            },
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.channel.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (widget.isLive)
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Text(
                        'مباشر',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(width: 15),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE50914), Color(0xFFB20710)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.4),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: TVInteractive(
              onTap: () {
                _playerKey.currentState?.startCast();
                setState(
                  () => _showControls = false,
                ); // Hide controls to see the UI cleanly
              },
              borderRadius: BorderRadius.circular(12),
              child: const Padding(
                padding: EdgeInsets.all(8.0),
                child: Icon(
                  Icons.cast_connected_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),
          const SizedBox(width: 15),
          if (widget.channel.sources.isNotEmpty) _buildServerPills(),
        ],
      ),
    );
  }

  Widget _buildServerPills() {
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.5,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        reverse: true,
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: widget.channel.sources
              .asMap()
              .entries
              .toList()
              .reversed
              .map((e) {
                final src = e.value;
                final isCur = _sourceIndex == e.key;
                return TVInteractive(
                  onTap: () {
                    if (isCur) return;
                    setState(() {
                      _sourceIndex = e.key;
                      _isBuffering = true;
                      _isPlaying = true;
                      _qualities = ['Auto'];
                      _selectedQuality = 'Auto';
                    });
                    _showAndReset();
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      gradient: isCur ? AppColors.accentGradient : null,
                      color: isCur ? null : Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isCur
                            ? Colors.white
                            : Colors.white.withOpacity(0.2),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      src.quality.isNotEmpty && src.quality != 'تلقائي'
                          ? src.quality
                          : 'سيرفر ${e.key + 1}',
                      style: TextStyle(
                        color: isCur ? Colors.white : Colors.white70,
                        fontSize: 12,
                        fontWeight: isCur ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              })
              .toList(),
        ),
      ),
    );
  }

  Widget _buildBigPlayBtn() {
    return TVInteractive(
      focusNode: _playFocusNode,
      onTap: _togglePlay,
      borderRadius: BorderRadius.circular(25),
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24, width: 1.5),
        ),
        child: Icon(
          _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          color: Colors.white,
          size: 30,
        ),
      ),
    );
  }

  Widget _buildBigSeekBtn(bool fwd) {
    return ValueListenableBuilder<int>(
      valueListenable: _durationNotifier,
      builder: (context, duration, _) {
        if (widget.isLive && duration == 0) return const SizedBox(width: 40);
        return TVInteractive(
          onTap: fwd ? _seekFwd : _seekBwd,
          borderRadius: BorderRadius.circular(25),
          child: Icon(
            fwd ? Icons.forward_10_rounded : Icons.replay_10_rounded,
            color: Colors.white,
            size: 40,
          ),
        );
      },
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black87, Colors.transparent],
        ),
      ),
      child: Column(
        children: [
          _buildProgressBar(),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              if (!widget.isLive && widget.onNextEpisode != null)
                _bottomAction(Icons.skip_next_rounded, 'التالي', _goNextEp),
              if (!widget.isLive && widget.panelEntries.isNotEmpty)
                _bottomAction(
                  Icons.format_list_bulleted_rounded,
                  'الحلقات',
                  () => setState(() => _showPanel = true),
                ),
              if (widget.isLive)
                _bottomAction(
                  Icons.live_tv_rounded,
                  'القنوات',
                  () => setState(() => _showChannelsPanel = true),
                ),
              _bottomAction(Icons.tune_rounded, 'الجودة', _showQualitySheet),
              _bottomAction(
                _isLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
                'قفل',
                () => setState(() => _isLocked = true),
              ),
              _bottomAction(
                Icons.aspect_ratio_rounded,
                _resizeMode == 1
                    ? 'ملء'
                    : (_resizeMode == 3 ? 'تكبير' : 'احتواء'),
                _cycleResize,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bottomAction(IconData icon, String label, VoidCallback onTap) {
    return TVInteractive(
      onTap: () {
        _startHideTimer();
        onTap();
      },
      borderRadius: BorderRadius.circular(12),
      scaleOnFocus: 1.20,
      focusColor: AppColors.accentBlue,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 26),
          const SizedBox(height: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return AnimatedBuilder(
      animation: Listenable.merge([_positionNotifier, _durationNotifier]),
      builder: (context, _) {
        final pos = _positionNotifier.value;
        final dur = _durationNotifier.value;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _fmt(pos),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _fmt(dur),
                    style: TextStyle(
                      color: widget.isLive ? Colors.redAccent : Colors.white70,
                      fontSize: 12,
                      fontWeight: widget.isLive
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            Directionality(
              textDirection: TextDirection.ltr, // Netflix style LTR (English)
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 4,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                  activeTrackColor: Colors.red,
                  inactiveTrackColor: Colors.white24,
                  thumbColor: Colors.red,
                  overlayColor: Colors.red.withOpacity(0.2),
                ),
                child: Focus(
                  canRequestFocus: false, // Prevents TV focus from getting stuck in slider
                  descendantsAreFocusable: false,
                  child: Slider(
                    value: pos.toDouble().clamp(
                      0.0,
                      dur.toDouble() > 0 ? dur.toDouble() : pos.toDouble() + 1000,
                    ),
                    min: 0,
                    max: dur.toDouble() > 0 ? dur.toDouble() : (pos.toDouble() + 1000),
                    onChanged: (v) {
                      setState(() {
                        _isSeeking = true;
                      });
                      _positionNotifier.value = v.toInt();
                      _playerKey.currentState?.seekTo(v.toInt());
                    },
                    onChangeEnd: (v) => _performSeek(v.toInt()),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showQualitySheet() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF151515),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text(
          'اختر الجودة',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SizedBox(
          width: 300,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _qualities
                  .map(
                    (q) => TVInteractive(
                      onTap: () {
                        setState(() {
                          _selectedQuality = q;
                          _isBuffering = true;
                        });
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: _selectedQuality == q
                              ? AppColors.accentBlue.withOpacity(0.2)
                              : Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _selectedQuality == q
                                ? AppColors.accentBlue
                                : Colors.transparent,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              q,
                              style: TextStyle(
                                color: _selectedQuality == q
                                    ? AppColors.accentBlue
                                    : Colors.white,
                                fontWeight: _selectedQuality == q
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            if (_selectedQuality == q)
                              const Icon(
                                Icons.check,
                                color: AppColors.accentBlue,
                                size: 20,
                              ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLockOverlay() {
    return Positioned(
      bottom: 30,
      right: 30,
      child: TVInteractive(
        onTap: () => setState(() => _isLocked = false),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            color: Colors.black54,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.lock_rounded, color: Colors.white, size: 30),
        ),
      ),
    );
  }

  Widget _buildNextEpOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black87,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'الحلقة التالية ستفتح خلال',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 10),
            Text(
              '$_nextEpSec',
              style: const TextStyle(
                color: AppColors.accentBlue,
                fontSize: 50,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _cancelNextEp,
                  child: const Text('إلغاء'),
                ),
                const SizedBox(width: 20),
                ElevatedButton(
                  onPressed: _goNextEp,
                  child: const Text('تشغيل الآن'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidePanelOverlay() {
    return Stack(
      children: [
        GestureDetector(
          onTap: () => setState(() => _showPanel = false),
          child: Container(color: Colors.black45),
        ),
        Positioned(
          top: 0,
          bottom: 0,
          right: 0,
          width: 300,
          child: Container(
            color: const Color(0xFF151515),
            child: Column(
              children: [
                AppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  title: Text(
                    widget.panelTitle,
                    style: const TextStyle(fontSize: 18),
                  ),
                  automaticallyImplyLeading: false,
                  actions: [
                    IconButton(
                      onPressed: () => setState(() => _showPanel = false),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: widget.panelEntries.length,
                    itemBuilder: (c, i) => ListTile(
                      selected: widget.currentEpisodeIndex == i,
                      title: Text(
                        widget.panelEntries[i].title,
                        style: const TextStyle(color: Colors.white),
                      ),
                      onTap: () {
                        setState(() => _showPanel = false);
                        widget.panelEntries[i].onTap();
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _triggerNextEp() {
    if (widget.onNextEpisode == null) return;
    setState(() {
      _showNextEp = true;
      _nextEpSec = 5;
    });
    _nextEpTimer?.cancel();
    _nextEpTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _nextEpSec--);
      if (_nextEpSec <= 0) {
        t.cancel();
        _goNextEp();
      }
    });
  }

  void _goNextEp() {
    if (widget.onNextEpisode != null && widget.currentEpisodeIndex != null) {
      widget.onNextEpisode!(widget.currentEpisodeIndex! + 1);
    }
  }

  void _cancelNextEp() {
    _nextEpTimer?.cancel();
    setState(() => _showNextEp = false);
  }

  Widget _buildLiveChannelsOverlay() {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Stack(
        children: [
          GestureDetector(
            onTap: () => setState(() => _showChannelsPanel = false),
            child: Container(color: Colors.transparent),
          ),
          Positioned(
            top: 0,
            bottom: 0,
            right: 0,
            width: 500,
            child: Container(
              color: const Color(0xFA151515),
              child: Row(
                children: [
                  // Categories List
                  Expanded(
                    flex: 1,
                    child: Container(
                      color: Colors.black26,
                      child: Builder(
                        builder: (ctx) {
                          final service = Provider.of<DataService>(
                            context,
                            listen: false,
                          );
                          bool isOurWorld =
                              widget.channel.categoryId == 'our_world' ||
                              widget.channel.categoryId == 'our_world_series';
                          if (isOurWorld) {
                            return StreamBuilder<List<Map<String, dynamic>>>(
                              stream: service.getOurWorldCategories('live'),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData)
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                final cats = snapshot.data ?? [];
                                return ListView.builder(
                                  itemCount: cats.length,
                                  itemBuilder: (context, index) {
                                    final cat = cats[index];
                                    bool isSelected =
                                        _selectedLiveCategoryId == cat['id'];
                                    return TVInteractive(
                                      onTap: () => setState(
                                        () =>
                                            _selectedLiveCategoryId = cat['id'],
                                      ),
                                      borderRadius: BorderRadius.circular(0),
                                      child: Container(
                                        color: isSelected
                                            ? AppColors.accentBlue.withOpacity(
                                                0.3,
                                              )
                                            : Colors.transparent,
                                        padding: const EdgeInsets.all(12),
                                        child: Text(
                                          cat['name'] ?? '',
                                          style: TextStyle(
                                            color: isSelected
                                                ? Colors.white
                                                : Colors.white70,
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            );
                          } else {
                            return StreamBuilder<List<Category>>(
                              stream: service.getCategories(),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData)
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                final cats = snapshot.data ?? [];
                                return ListView.builder(
                                  itemCount: cats.length,
                                  itemBuilder: (context, index) {
                                    final cat = cats[index];
                                    bool isSelected =
                                        _selectedLiveCategoryId == cat.id;
                                    return TVInteractive(
                                      onTap: () => setState(
                                        () => _selectedLiveCategoryId = cat.id,
                                      ),
                                      borderRadius: BorderRadius.circular(0),
                                      child: Container(
                                        color: isSelected
                                            ? AppColors.accentBlue.withOpacity(
                                                0.3,
                                              )
                                            : Colors.transparent,
                                        padding: const EdgeInsets.all(12),
                                        child: Text(
                                          cat.name,
                                          style: TextStyle(
                                            color: isSelected
                                                ? Colors.white
                                                : Colors.white70,
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            );
                          }
                        },
                      ),
                    ),
                  ),
                  // Channels List
                  Expanded(
                    flex: 2,
                    child: Builder(
                      builder: (ctx) {
                        if (_selectedLiveCategoryId == null) {
                          return const Center(
                            child: Text(
                              'اختر قسماً',
                              style: TextStyle(color: Colors.white54),
                            ),
                          );
                        }
                        final service = Provider.of<DataService>(
                          context,
                          listen: false,
                        );
                        bool isOurWorld =
                            widget.channel.categoryId == 'our_world' ||
                            widget.channel.categoryId == 'our_world_series';
                        if (isOurWorld) {
                          return StreamBuilder<List<Map<String, dynamic>>>(
                            stream: service.getOurWorldContent(
                              'live',
                              categoryId: _selectedLiveCategoryId,
                            ),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData)
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              final items = snapshot.data ?? [];
                              return ListView.builder(
                                itemCount: items.length,
                                itemBuilder: (context, index) {
                                  final item = items[index];
                                  return TVInteractive(
                                    onTap: () {
                                      Map<String, String>? headers;
                                      if (item['headers'] is Map)
                                        headers = Map<String, String>.from(
                                          item['headers'] as Map,
                                        );
                                      final rawUrl =
                                          item['url'] ??
                                          item['streamUrl'] ??
                                          '';
                                      final newChannel = Channel(
                                        id: item['id']?.toString() ?? '',
                                        name: item['name']?.toString() ?? '',
                                        logoUrl:
                                            item['logo'] ??
                                            item['stream_icon'] ??
                                            '',
                                        categoryId: 'our_world',
                                        sources: [
                                          VideoSource(
                                            quality: 'Auto',
                                            url: rawUrl,
                                            drmType: item['drmType']
                                                ?.toString(),
                                            drmKey: item['drmKey']?.toString(),
                                            drmLicenseUrl: item['drmLicenseUrl']
                                                ?.toString(),
                                            headers: headers,
                                          ),
                                        ],
                                      );
                                      setState(
                                        () => _showChannelsPanel = false,
                                      );
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => PlayerScreen(
                                            channel: newChannel,
                                            isLive: true,
                                          ),
                                        ),
                                      );
                                    },
                                    borderRadius: BorderRadius.circular(0),
                                    child: ListTile(
                                      leading:
                                          item['logo'] != null &&
                                              item['logo'].toString().isNotEmpty
                                          ? Image.network(
                                              item['logo'],
                                              width: 40,
                                              height: 40,
                                              errorBuilder: (c, e, s) =>
                                                  const Icon(
                                                    Icons.tv,
                                                    color: Colors.white,
                                                  ),
                                            )
                                          : const Icon(
                                              Icons.tv,
                                              color: Colors.white,
                                            ),
                                      title: Text(
                                        item['name'] ?? '',
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          );
                        } else {
                          return StreamBuilder<List<Channel>>(
                            stream: service.getChannels(
                              _selectedLiveCategoryId!,
                            ),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData)
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              final channels = snapshot.data ?? [];
                              return ListView.builder(
                                itemCount: channels.length,
                                itemBuilder: (context, index) {
                                  final ch = channels[index];
                                  return TVInteractive(
                                    onTap: () {
                                      setState(
                                        () => _showChannelsPanel = false,
                                      );
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => PlayerScreen(
                                            channel: ch,
                                            isLive: true,
                                          ),
                                        ),
                                      );
                                    },
                                    borderRadius: BorderRadius.circular(0),
                                    child: ListTile(
                                      leading: ch.logoUrl.isNotEmpty
                                          ? Image.network(
                                              ch.logoUrl,
                                              width: 40,
                                              height: 40,
                                              errorBuilder: (c, e, s) =>
                                                  const Icon(
                                                    Icons.tv,
                                                    color: Colors.white,
                                                  ),
                                            )
                                          : const Icon(
                                              Icons.tv,
                                              color: Colors.white,
                                            ),
                                      title: Text(
                                        ch.name,
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
