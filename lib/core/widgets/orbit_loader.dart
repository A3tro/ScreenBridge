import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 丸と、そのまわりを回る小さな点（読み込み中の表示）
class OrbitLoader extends StatefulWidget {
  final double size;
  final IconData? icon; // 丸の中に出すマーク（なしでもよい）
  const OrbitLoader({super.key, this.size = 120, this.icon});
  @override State<OrbitLoader> createState() => _OrbitLoaderState();
}

class _OrbitLoaderState extends State<OrbitLoader> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
  @override void dispose() { c.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final color = p.navy;
    final s = widget.size;
    if (MediaQuery.of(context).disableAnimations) { c.stop(); } else if (!c.isAnimating) { c.repeat(); }
    return Semantics(label: 'Loading', child: SizedBox(width: s, height: s, child: AnimatedBuilder(animation: c, builder: (_, __) {
      final angle = c.value * 2 * math.pi;
      final pulse = 1 + 0.04 * math.sin(angle * 2);
      final orbit = s * 0.42;
      final dot = s * 0.09;
      return Stack(alignment: Alignment.center, children: [
        // 真ん中の丸
        Transform.scale(scale: pulse, child: Container(width: s * 0.62, height: s * 0.62,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: color.withValues(alpha: .35), blurRadius: s * 0.18, spreadRadius: s * 0.02)]),
          child: widget.icon == null ? null : Center(child: Icon(widget.icon, color: p.ivory, size: s * 0.18)))),
        // まわる点
        Transform.translate(offset: Offset(math.cos(angle) * orbit, math.sin(angle) * orbit),
          child: Container(width: dot, height: dot, decoration: BoxDecoration(color: p.butter, shape: BoxShape.circle,
            border: Border.all(color: color, width: s * 0.012),
            boxShadow: [BoxShadow(color: p.butter.withValues(alpha: .8), blurRadius: dot)]))),
      ]);
    })));
  }
}