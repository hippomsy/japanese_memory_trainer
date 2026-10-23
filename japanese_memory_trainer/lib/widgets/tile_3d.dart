import 'dart:math';

import 'package:flutter/material.dart';

/// 2026-10-17 문장 만들기용 3D 블록 조각.
/// 두께(아래 옆면)가 있는 블록처럼 보이고, 누르면 쑥 눌렸다가 올라오며,
/// 처음 나타날 때는 앞으로 뒤집히듯 튀어나온다.
class Tile3D extends StatefulWidget {
  const Tile3D({
    super.key,
    required this.label,
    required this.face,
    required this.edge,
    required this.textColor,
    this.border,
    this.fontSize = 18,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    this.depth = 5,
    this.onTap,
  });

  final String label;
  final Color face; // 윗면 색
  final Color edge; // 옆면(두께) 색
  final Color textColor;
  final Color? border;
  final double fontSize;
  final EdgeInsets padding;
  final double depth;
  final VoidCallback? onTap;

  @override
  State<Tile3D> createState() => _Tile3DState();
}

class _Tile3DState extends State<Tile3D> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final press = _down ? widget.depth - 1 : 0.0;
    final radius = BorderRadius.circular(11);
    final block = Padding(
      // 옆면이 보일 자리만큼 아래 여백.
      padding: EdgeInsets.only(bottom: widget.depth),
      child: Stack(clipBehavior: Clip.none, children: [
        // 옆면(두께)
        Positioned.fill(
          top: widget.depth,
          bottom: -widget.depth,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: widget.edge,
              borderRadius: radius,
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: _down ? 0.10 : 0.22),
                    blurRadius: _down ? 2 : 6,
                    offset: Offset(0, _down ? 1 : 4)),
              ],
            ),
          ),
        ),
        // 윗면
        AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          transform: Matrix4.translationValues(0, press, 0),
          padding: widget.padding,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: widget.border ?? widget.edge, width: 1.2),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color.lerp(widget.face, Colors.white, 0.35)!, widget.face],
            ),
          ),
          child: Text(widget.label,
              style: TextStyle(
                  fontSize: widget.fontSize,
                  fontWeight: FontWeight.w700,
                  color: widget.textColor,
                  shadows: const [Shadow(color: Colors.white70, offset: Offset(0, 1))])),
        ),
      ]),
    );

    return TweenAnimationBuilder<double>(
      // 처음 나타날 때: 뒤로 눕혀져 있다가 일어서며 살짝 튐.
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Transform(
        alignment: Alignment.bottomCenter,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.002)
          ..rotateX((1 - t) * pi / 2.6)
          ..scale(0.85 + 0.15 * t),
        child: Opacity(opacity: t.clamp(0.0, 1.0), child: child),
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapCancel: enabled ? () => setState(() => _down = false) : null,
        onTapUp: enabled
            ? (_) {
                setState(() => _down = false);
                widget.onTap!();
              }
            : null,
        child: Opacity(opacity: enabled || widget.border != null ? 1 : 0.92, child: block),
      ),
    );
  }
}
