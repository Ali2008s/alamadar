import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'dart:ui';
import 'package:almadar/core/theme.dart';
import 'package:almadar/data/models.dart';
import 'package:almadar/widgets/tv_interactive.dart';

class CustomPlayerControls extends StatefulWidget {
  final Player player;
  final VideoController controller;
  final Channel channel;
  final int currentSourceIndex;
  final Function(int) onSourceChanged;
  final Function(BoxFit) onFitChanged;
  final bool isLive;

  const CustomPlayerControls({
    super.key,
    required this.player,
    required this.controller,
    required this.channel,
    required this.currentSourceIndex,
    required this.onSourceChanged,
    required this.onFitChanged,
    this.isLive = false,
  });

  @override
  State<CustomPlayerControls> createState() => _CustomPlayerControlsState();
}

class _CustomPlayerControlsState extends State<CustomPlayerControls> {
  bool _isVisible = true;
  bool _isLocked = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _playbackSpeed = 1.0;
  bool _isBuffering = false;
  BoxFit _fit = BoxFit.contain;

  @override
  void initState() {
    super.initState();
    widget.player.stream.position.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    widget.player.stream.duration.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    widget.player.stream.buffering.listen((b) {
      if (mounted) setState(() => _isBuffering = b);
    });
    widget.player.stream.rate.listen((r) {
      if (mounted) setState(() => _playbackSpeed = r);
    });
  }

  void _cycleFit() {
    setState(() {
      if (_fit == BoxFit.contain) {
        _fit = BoxFit.cover;
      } else if (_fit == BoxFit.cover) {
        _fit = BoxFit.fill;
      } else {
        _fit = BoxFit.contain;
      }
    });
    widget.onFitChanged(_fit);
  }

  void _toggleVisibility() {
    if (_isLocked) return;
    setState(() => _isVisible = !_isVisible);
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String mm = twoDigits(d.inMinutes.remainder(60));
    String ss = twoDigits(d.inSeconds.remainder(60));
    return "$mm:$ss";
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggleVisibility,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          if (_isVisible) ...[
            // Black overlay
            Container(color: Colors.black26),

            // Top Bar
            Positioned(
              top: 40,
              left: 20,
              right: 20,
              child: Row(
                children: [
                  const Spacer(),
                  // Close Icon (X)
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24, width: 0.5),
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Buffering Indicator
            if (_isBuffering)
              const Center(
                child: CircularProgressIndicator(color: AppColors.accentBlue),
              ),

            // Center Controls
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Back 10s
                  IconButton(
                    icon: const Icon(
                      Icons.fast_rewind_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                    onPressed: () {
                      widget.player.seek(
                        _position - const Duration(seconds: 10),
                      );
                    },
                  ),
                  const SizedBox(width: 40),
                  // Play/Pause Large
                  GestureDetector(
                    onTap: () => widget.player.playOrPause(),
                    child: ClipOval(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white24, width: 1),
                          ),
                          child: StreamBuilder<bool>(
                            stream: widget.player.stream.playing,
                            builder: (context, snapshot) {
                              final playing = snapshot.data ?? true;
                              return Icon(
                                playing
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 50,
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                  // Forward 10s
                  IconButton(
                    icon: const Icon(
                      Icons.fast_forward_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                    onPressed: () {
                      widget.player.seek(
                        _position + const Duration(seconds: 10),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Bottom Bar
            Positioned(
              bottom: 40,
              left: 20,
              right: 20,
              child: Column(
                children: [
                  // Server Selection Pill Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ...widget.channel.sources
                          .asMap()
                          .entries
                          .map((entry) {
                            int idx = entry.key;
                            bool isCurrent = widget.currentSourceIndex == idx;
                            return Padding(
                              padding: const EdgeInsets.only(left: 10),
                              child: TVInteractive(
                                onTap: () => widget.onSourceChanged(idx),
                                borderRadius: BorderRadius.circular(20),
                                padding: EdgeInsets.zero,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: isCurrent
                                        ? AppColors.accentGradient
                                        : null,
                                    color: isCurrent ? null : Colors.black45,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isCurrent
                                          ? Colors.transparent
                                          : Colors.white24,
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    'سيرفر ${idx + 1}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          })
                          .toList()
                          .reversed
                          .toList(), // Reversed for RTL layout
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Options Row (Auto HD, تمديد)
                  Row(
                    children: [
                      // "تمديد" (Aspect Ratio)
                      TVInteractive(
                        onTap: _cycleFit,
                        borderRadius: BorderRadius.circular(20),
                        padding: EdgeInsets.zero,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white24, width: 1),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.unfold_more_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'تمديد',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Speed Control
                      if (!widget.isLive)
                        TVInteractive(
                          onTap: () {
                            double nextSpeed = _playbackSpeed >= 2.0
                                ? 0.5
                                : _playbackSpeed + 0.5;
                            widget.player.setRate(nextSpeed);
                          },
                          borderRadius: BorderRadius.circular(20),
                          padding: EdgeInsets.zero,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black45,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white24,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.speed_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${_playbackSpeed}x',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const Spacer(),
                      // Duration labels
                      Text(
                        _formatDuration(_duration),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      const Text(
                        ' / ',
                        style: TextStyle(color: Colors.white24),
                      ),
                      Text(
                        _formatDuration(_position),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // RTL Progress Bar at the very bottom
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Directionality(
                textDirection:
                    TextDirection.ltr, // Standard LTR direction for progress
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4.0,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6.0,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 14.0,
                    ),
                    activeTrackColor: AppColors.accentBlue,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: AppColors.accentBlue,
                  ),
                  child: Slider(
                    value: _position.inMilliseconds.toDouble().clamp(
                      0,
                      _duration.inMilliseconds.toDouble() > 0
                          ? _duration.inMilliseconds.toDouble()
                          : 1,
                    ),
                    max: _duration.inMilliseconds.toDouble() > 0
                        ? _duration.inMilliseconds.toDouble()
                        : 1,
                    onChanged: (val) {
                      widget.player.seek(Duration(milliseconds: val.toInt()));
                    },
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
