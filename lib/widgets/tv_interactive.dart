import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:almadar/core/theme.dart';
import 'package:almadar/services/focus_sound_service.dart';

class TVInteractive extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleOnFocus;
  final double scaleOnPress;
  final BorderRadius? borderRadius;
  final Color? focusColor;
  final EdgeInsets? padding;
  final bool isRound;
  final FocusNode? focusNode;

  const TVInteractive({
    super.key,
    required this.child,
    this.focusNode,
    this.onTap,
    this.scaleOnFocus = 1.12,
    this.scaleOnPress = 0.98,
    this.borderRadius,
    this.focusColor,
    this.padding,
    this.isRound = false,
  });

  @override
  State<TVInteractive> createState() => _TVInteractiveState();
}

class _TVInteractiveState extends State<TVInteractive>
    with SingleTickerProviderStateMixin {
  late FocusNode _focusNode;
  bool _isFocused = false;
  bool _isPressed = false;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  FocusNode get _effectiveFocusNode => widget.focusNode ?? _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _effectiveFocusNode.addListener(_onFocusChange);

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: widget.scaleOnFocus)
        .animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
        );
  }

  void _onFocusChange() {
    setState(() {
      _isFocused = _effectiveFocusNode.hasFocus;
      if (_isFocused) {
        _controller.forward();
        FocusSoundService.play();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  void dispose() {
    _effectiveFocusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _effectiveFocusNode,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.enter) {
            if (widget.onTap != null) {
              // Subtle pulse on press
              _controller.reverse().then((_) => _controller.forward());
              widget.onTap!();
              return KeyEventResult.handled;
            }
          }
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        child: MouseRegion(
          onEnter: (_) {
            if (!_effectiveFocusNode.hasFocus) _effectiveFocusNode.requestFocus();
          },
          onExit: (_) {
            // Optional: remove focus on exit
          },
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              double currentScale = _isPressed
                  ? widget.scaleOnPress
                  : _scaleAnimation.value;

              return Transform.scale(
                scale: currentScale,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOutCubic,
                  padding: widget.padding,
                  decoration: BoxDecoration(
                    borderRadius:
                        widget.borderRadius ?? BorderRadius.circular(12),
                    boxShadow: const [],
                    border: Border.all(
                      color: _isFocused
                          ? (widget.focusColor ?? AppColors.accentBlue)
                                .withOpacity(0.8)
                          : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                  child: widget.child,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
