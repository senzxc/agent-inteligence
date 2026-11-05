import 'package:flutter/material.dart';

class PressBounce extends StatefulWidget {
  const PressBounce({super.key, this.onTap, required this.child});

  final VoidCallback? onTap;
  final Widget child;

  @override
  State<PressBounce> createState() => _PressBounceState();
}

class _PressBounceState extends State<PressBounce> {
  bool _isPressed = false;

  void _setPressed(bool isPressed) {
    if (_isPressed == isPressed) return;
    setState(() => _isPressed = isPressed);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null ? null : (_) => _setPressed(true),
      onTapUp: widget.onTap == null ? null : (_) => _setPressed(false),
      onTapCancel: widget.onTap == null ? null : () => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.9 : 1,
        duration: Duration(milliseconds: _isPressed ? 90 : 420),
        curve: _isPressed ? Curves.easeOutCubic : Curves.elasticOut,
        child: widget.child,
      ),
    );
  }
}
