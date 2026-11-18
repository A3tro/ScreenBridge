import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/widgets/app_icon.dart';
import '../../core/theme/app_theme.dart';

/// Vector artwork: no network images, animation packages, or font assets.
class AnimatedBridge extends StatefulWidget {
  final int stage;
  AnimatedBridge({super.key, this.stage = 0});
  @override State<AnimatedBridge> createState() => _AnimatedBridgeState();
}
class _AnimatedBridgeState extends State<AnimatedBridge> with SingleTickerProviderStateMixin {
  late final AnimationController motion = AnimationController(vsync: this, duration: Duration(seconds: 4));
  @override void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) { motion.stop(); motion.value = .5; }
    else { motion.repeat(reverse: true); }
  }
  @override void dispose() { motion.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => ExcludeSemantics(child: SizedBox(height: 300,
    child: FittedBox(child: SizedBox(width: 330, height: 300, child: AnimatedBuilder(animation: motion,
      builder: (context, _) {
        final float = math.sin(motion.value * math.pi * 2) * 7;
        return Stack(alignment: Alignment.center, children: [
          Container(width: 270, height: 270, decoration: BoxDecoration(color: AppPalette.of(context).lavender,
            shape: BoxShape.circle, border: Border.all(color: AppPalette.of(context).navy, width: .8))),
          Positioned(left: 30, top: 27 + float, child: Transform.rotate(angle: -.09,
            child: _paper(context, width: 170, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [AppIcon(Icons.photo_outlined, size: 18), SizedBox(width: 8), Text('SCREENSHOT', style: TextStyle(fontSize: 9, letterSpacing: 1))]),
              SizedBox(height: 20),
              for (int i = 0; i < 3; i++) Container(height: 28, margin: EdgeInsets.only(bottom: 9),
                decoration: BoxDecoration(color: i == widget.stage % 3 ? AppPalette.of(context).butter : AppPalette.of(context).ivory,
                  borderRadius: BorderRadius.circular(6)), child: Center(child: Text(['学校  09:00', 'シフト  18:00', 'カフェ  15:00'][i], style: TextStyle(fontSize: 11)))),
            ])))),
          Positioned(right: 18, bottom: 28 - float, child: Transform.rotate(angle: .07,
            child: _paper(context, width: 168, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [AppIcon(widget.stage == 1 ? Icons.fact_check_outlined : Icons.calendar_today_outlined, size: 18), SizedBox(width: 9),
                Text(widget.stage == 1 ? 'REVIEW' : 'MY SCHEDULE', style: TextStyle(fontSize: 9, letterSpacing: 1))]),
              SizedBox(height: 18),
              Wrap(spacing: 7, runSpacing: 7, children: List.generate(14, (i) => Container(width: 20, height: 20,
                alignment: Alignment.center, decoration: BoxDecoration(color: i == 8 ? AppPalette.of(context).mint : AppPalette.of(context).ivory,
                  borderRadius: BorderRadius.circular(5)), child: Text('${i + 1}', style: TextStyle(fontSize: 9))))),
              SizedBox(height: 15),
              Container(height: 28, decoration: BoxDecoration(color: AppPalette.of(context).butter, borderRadius: BorderRadius.circular(6)),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [AppIcon(Icons.check, size: 14), SizedBox(width: 5), Text('確認して登録', style: TextStyle(fontSize: 10))])),
            ])))),
          Positioned(right: 32, top: 32 - float, child: Container(width: 48, height: 48,
            decoration: BoxDecoration(color: AppPalette.of(context).mint, shape: BoxShape.circle, border: Border.all(color: AppPalette.of(context).navy)),
            child: AppIcon(widget.stage == 1 ? Icons.check : Icons.arrow_downward, size: 22))),
        ]);
      })))));
  Widget _paper(BuildContext context, {required double width, required Widget child}) => Container(width: width,
    padding: EdgeInsets.all(15), decoration: BoxDecoration(color: AppPalette.of(context).surface,
      borderRadius: BorderRadius.circular(16), border: Border.all(color: AppPalette.of(context).navy),
      boxShadow: [BoxShadow(color: Color(0x181E2220), offset: Offset(4, 5))]), child: child);
}
