import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// ふわっと光りながら、形が変わる玉（読み込み中の表示）
class BlobLoader extends StatefulWidget {
  final double size;
  const BlobLoader({super.key, this.size = 140});
  @override State<BlobLoader> createState() => _BlobLoaderState();
}

class _BlobLoaderState extends State<BlobLoader> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
  @override void dispose() { c.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    // 動きを減らす設定の人には、止めて表示する
    if (MediaQuery.of(context).disableAnimations) { c.stop(); } else if (!c.isAnimating) { c.repeat(); }
    return Semantics(label: 'Loading', child: SizedBox(width: widget.size, height: widget.size,
      child: AnimatedBuilder(animation: c, builder: (_, __) => CustomPaint(
        painter: _BlobPainter(t: c.value, colors: [p.lavender, p.butter, p.mint], edge: p.navy)))));
  }
}

class _BlobPainter extends CustomPainter {
  final double t;
  final List<Color> colors;
  final Color edge;
  _BlobPainter({required this.t, required this.colors, required this.edge});

  @override void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final base = size.width * 0.32;
    final angle = t * 2 * math.pi;

    // 波のように、ふちが動く形
    Path blob(double scale, double phase) {
      final path = Path();
      const n = 72;
      for (var i = 0; i <= n; i++) {
        final a = i / n * 2 * math.pi;
        final r = base * scale * (1
          + 0.10 * math.sin(3 * a + angle + phase)
          + 0.07 * math.sin(2 * a - angle * 2 + phase)
          + 0.05 * math.cos(4 * a + angle * 3));
        final pt = center + Offset(math.cos(a + angle * 0.3), math.sin(a + angle * 0.3)) * r;
        if (i == 0) { path.moveTo(pt.dx, pt.dy); } else { path.lineTo(pt.dx, pt.dy); }
      }
      return path..close();
    }

    final rect = Rect.fromCircle(center: center, radius: base * 1.3);
    // まわりの光
    canvas.drawPath(blob(1.18, 0.8), Paint()
      ..color = colors[0].withValues(alpha: .6)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20));
    // 本体（色が回る）
    final body = blob(1.0, 0);
    canvas.drawPath(body, Paint()..shader = SweepGradient(
      colors: [...colors, colors.first], transform: GradientRotation(angle)).createShader(rect));
    // つやの光
    canvas.drawPath(body, Paint()..shader = RadialGradient(center: const Alignment(-0.3, -0.4), radius: 0.8,
      colors: [Colors.white.withValues(alpha: .7), Colors.white.withValues(alpha: 0)]).createShader(rect));
    // うすいふち
    canvas.drawPath(body, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.2..color = edge.withValues(alpha: .25));
  }

  @override bool shouldRepaint(_BlobPainter old) => old.t != t;
}