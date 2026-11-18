import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_icon.dart';
import '../../core/widgets/motion.dart';
import '../../data/app_controller.dart';

/// Swipeable prism preview inspired by the user's theme-selection recording.
class ThemeScreen extends StatefulWidget {
  const ThemeScreen({super.key});
  @override State<ThemeScreen> createState() => _ThemeScreenState();
}
class _ThemeScreenState extends State<ThemeScreen> with SingleTickerProviderStateMixin {
  PageController? pages;
  int selected = 0;
  late final AnimationController orbit = AnimationController(vsync: this, duration: const Duration(seconds: 12));
  @override void didChangeDependencies() {
    super.didChangeDependencies();
    if (pages == null) { selected = AppScope.of(context).darkPreference ? 1 : 0; pages = PageController(initialPage: selected); }
    if (MediaQuery.of(context).disableAnimations) { orbit.stop(); } else { orbit.repeat(); }
  }
  @override void dispose() { pages?.dispose(); orbit.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    final reduced = MediaQuery.of(context).disableAnimations;
    final p = selected == 0 ? AppPalette.light : AppPalette.dark;
    final app = AppScope.of(context);
    return Theme(data: selected == 0 ? AppTheme.light() : AppTheme.dark(), child: AnimatedContainer(duration: reduced ? Duration.zero : const Duration(milliseconds: 450), color: p.ivory,
      child: Scaffold(backgroundColor: Colors.transparent,
        appBar: AppBar(backgroundColor: Colors.transparent, foregroundColor: p.navy,
          leading: IconButton(tooltip: '戻る', onPressed: () => Navigator.pop(context), icon: AppIcon(Icons.arrow_back, color: p.navy)),
          title: Text('テーマ', style: TextStyle(fontSize: 16, color: p.navy)), centerTitle: true),
        body: SafeArea(child: LayoutBuilder(builder: (context, bounds) => SingleChildScrollView(child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: bounds.maxHeight), child: Column(children: [
            const SizedBox(height: 14), Text('MAKE IT YOURS', style: TextStyle(color: p.muted, letterSpacing: 2, fontSize: 10)),
            SizedBox(height: math.min(340.0, math.max(240.0, bounds.maxHeight * .5)), child: PageView.builder(
              controller: pages, itemCount: 2, onPageChanged: (i) => setState(() => selected = i),
              itemBuilder: (context, index) => AnimatedBuilder(animation: Listenable.merge([pages!, orbit]), builder: (context, _) {
                final current = pages!.hasClients && pages!.position.haveDimensions ? pages!.page ?? selected.toDouble() : selected.toDouble();
                final delta = index - current;
                return Transform(alignment: Alignment.center,
                  transform: Matrix4.identity()..setEntry(3,2,.0015)..rotateY(reduced ? 0 : delta * 1.15),
                  child: Center(child: SizedBox(width: 280, height: 290,
                    child: CustomPaint(painter: _PrismPainter(dark: index == 1, phase: orbit.value,
                      turn: reduced ? 0 : math.sin(orbit.value * math.pi * 2) * .08)))));
              }))),
            AnimatedSwitcher(duration: reduced ? Duration.zero : const Duration(milliseconds: 250), child: Column(key: ValueKey(selected), children: [
              Text(selected == 0 ? 'Daylight' : 'Midnight', style: TextStyle(fontSize: 30, letterSpacing: -.7, fontWeight: FontWeight.w600, color: p.navy)),
              const SizedBox(height: 9), Text(selected == 0 ? 'やわらかな色で、毎日を軽やかに。' : '静かな夜に、目にやさしい落ち着きを。',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: p.muted)),
            ])),
            const SizedBox(height: 23),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(2, (i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5), child: Semantics(selected: selected == i, child: OutlinedButton(
                style: OutlinedButton.styleFrom(foregroundColor: p.navy, backgroundColor: selected == i ? p.lavender : Colors.transparent,
                  side: BorderSide(color: p.line)),
                onPressed: () => pages!.animateToPage(i, duration: reduced ? Duration.zero : const Duration(milliseconds: 500), curve: Curves.easeInOutCubic),
                child: Text(i == 0 ? 'ライト' : 'ダーク')))))),
            const SizedBox(height: 26),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 40), child: PressScale(child: SizedBox(width: double.infinity,
              child: FilledButton(style: FilledButton.styleFrom(backgroundColor: p.lavender, foregroundColor: p.navy,
                padding: const EdgeInsets.symmetric(vertical: 18)),
                onPressed: () { app.setThemePreference(selected == 1); Navigator.pop(context); },
                child: Text(app.darkPreference == (selected == 1) ? 'このテーマで戻る' : 'このテーマを使う'))))),
            const SizedBox(height: 12), Text('左右にスワイプしてプレビュー', style: TextStyle(fontSize: 10, color: p.muted)),
            const SizedBox(height: 26),
          ]))))))));
  }
}
class _PrismPainter extends CustomPainter {
  final bool dark;
  final double phase, turn;
  _PrismPainter({required this.dark, required this.phase, required this.turn});
  @override void paint(Canvas canvas, Size size) {
    final bounds = const Rect.fromLTWH(25,24,230,240);
    final triangle = Path()..moveTo(140+turn*90,26)..lineTo(253,258)..lineTo(27,258)..close();
    canvas.drawShadow(triangle, dark ? Colors.deepPurple : Colors.black26, 16, false);
    canvas.drawPath(triangle, Paint()..shader = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
      colors: dark ? [const Color(0xFFB599F2),const Color(0xFF29224D),const Color(0xFF6953BC)] :
        [const Color(0xFFFFE9AE),const Color(0xFFCBC4F5),const Color(0xFFAAD5BA)]).createShader(bounds));
    canvas.save(); canvas.clipPath(triangle);
    final center = Offset(140 + math.sin(phase*math.pi*2)*9,165);
    for(int i=0;i<7;i++) {
      canvas.drawOval(Rect.fromCenter(center:center+Offset(math.sin(phase*math.pi*2+i)*12,i*8.0-24),width:160-i*11.0,height:75+i*5.0),
        Paint()..style=PaintingStyle.stroke..strokeWidth=.8..color=Colors.white.withOpacity(.2));
    }
    final orb = Rect.fromCircle(center:center,radius:52);
    canvas.drawCircle(center,52,Paint()..shader=RadialGradient(center:const Alignment(-.4,-.5),colors:dark?
      [const Color(0xFFB7B5FF),const Color(0xFF5143A0),const Color(0xFF242344)]:
      [Colors.white,const Color(0xFFA3D6B7),const Color(0xFF5DA481)]).createShader(orb));
    for(int i=0;i<25;i++) {
      final x=35+(i*73%217).toDouble(); final y=30+(i*37%225).toDouble();
      canvas.drawCircle(Offset(x,y),i%3==0?1.7:.8,Paint()..color=Colors.white.withOpacity(.3+.3*math.sin(phase*math.pi*2+i).abs()));
    }
    canvas.restore();
    canvas.drawPath(triangle,Paint()..style=PaintingStyle.stroke..strokeWidth=1..color=(dark?Colors.white:const Color(0xFF4E514D)).withOpacity(.6));
  }
  @override bool shouldRepaint(covariant _PrismPainter old) => old.dark != dark || old.phase != phase || old.turn != turn;
}
