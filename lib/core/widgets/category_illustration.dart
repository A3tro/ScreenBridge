import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/models.dart';

/// Original vector scenes, rather than enlarged category glyphs or emoji.
class CategoryIllustration extends StatefulWidget {
  final EventCategory category;
  final double width, height;
  final bool animated;
  const CategoryIllustration({super.key, required this.category, this.width = 300, this.height = 210, this.animated = true});
  @override State<CategoryIllustration> createState() => _CategoryIllustrationState();
}
class _CategoryIllustrationState extends State<CategoryIllustration> with SingleTickerProviderStateMixin {
  late final AnimationController motion = AnimationController(vsync: this, duration: const Duration(seconds: 5));
  @override void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.animated && !MediaQuery.of(context).disableAnimations) { motion.repeat(); } else { motion.stop(); }
  }
  @override void dispose() { motion.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => Semantics(label: '${widget.category.label}のイラスト', image: true,
    child: SizedBox(width: widget.width, height: widget.height, child: FittedBox(child: SizedBox(width: 320, height: 210,
      child: AnimatedBuilder(animation: motion, builder: (_, __) => CustomPaint(painter: _Scene(widget.category, motion.value)))))));
}
class _Scene extends CustomPainter {
  final EventCategory category;
  final double t;
  _Scene(this.category, this.t);
  final ink = const Color(0xFF303139);
  final cream = const Color(0xFFFFFCF3);
  final green = const Color(0xFFAAD5BA);
  final yellow = const Color(0xFFFFDF96);
  final purple = const Color(0xFFB7AAE8);
  @override void paint(Canvas c, Size size) {
    final pen = Paint()..color = ink..strokeWidth = 2.5..style = PaintingStyle.stroke..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
    void path(Path p, Color color) { c.drawPath(p, Paint()..color=color); c.drawPath(p, pen); }
    void box(double x,double y,double w,double h,Color color,[double r=6]) => path(Path()..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x,y,w,h),Radius.circular(r))), color);
    void line(double x,double y,double x2,double y2) => c.drawLine(Offset(x,y),Offset(x2,y2),pen);
    void circle(double x,double y,double r,Color color) => path(Path()..addOval(Rect.fromCircle(center:Offset(x,y),radius:r)),color);
    final bob = math.sin(t*math.pi*2)*4;
    c.drawOval(const Rect.fromLTWH(38,178,247,15),Paint()..color=ink.withOpacity(.09));
    // Tiny moving stars belong to the scene, not to the content label.
    for (final pos in [Offset(39,62+bob),Offset(277,44-bob),Offset(254,111+bob)]) {
      c.drawLine(pos-const Offset(4,0),pos+const Offset(4,0),pen);
      c.drawLine(pos-const Offset(0,4),pos+const Offset(0,4),pen);
    }
    switch(category) {
      case EventCategory.school:
        // Study desk, open laptop, books, plant and wall clock.
        line(39,174,279,174); line(62,174,58,195);line(259,174,263,195);
        box(104,80,124,84,cream,9);box(114,90,104,62,purple,4);
        path(Path()..moveTo(95,164)..lineTo(237,164)..lineTo(246,173)..lineTo(87,173)..close(),green);
        box(49,153,46,19,yellow,3);box(44,139,47,14,cream,3);line(53,146,82,146);
        box(245,148,25,25,green,3);line(257,148,257,121);
        path(Path()..moveTo(257,139)..quadraticBezierTo(234,136,242,119)..quadraticBezierTo(259,121,257,139),green);
        path(Path()..moveTo(257,132)..quadraticBezierTo(278,124,270,112)..quadraticBezierTo(252,117,257,132),green);
        circle(77,59,23,cream);line(77,59,77,44);line(77,59,87+bob,65);
        line(129,111,200,111);line(129,124,183,124);line(129,137,194,137);
      case EventCategory.work:
        // Cafe shift: coffee cup, order ticket and serving tray.
        box(77,169,173,12,green,6);
        path(Path()..moveTo(94,112)..lineTo(162,112)..lineTo(155,166)..lineTo(101,166)..close(),cream);
        path(Path()..moveTo(163,120)..cubicTo(195,112,188,154,159,150)..lineTo(160,141)..cubicTo(174,141,177,126,162,130)..close(),yellow);
        c.drawOval(const Rect.fromLTWH(94,106,68,13),Paint()..color=yellow);c.drawOval(const Rect.fromLTWH(94,106,68,13),pen);
        box(193,55,61,100,cream,4);box(206,48,35,15,purple,3);
        for(int i=0;i<4;i++){line(204,84.0+i*15.0,242.0-i*3.0,84.0+i*15.0);}
        c.drawPath(Path()..moveTo(118,97)..cubicTo(101,82+bob,134,79-bob,118,62+bob),pen);
        c.drawPath(Path()..moveTo(140,95)..cubicTo(125,79-bob,154,76+bob,140,56-bob),pen);
      case EventCategory.personal:
        // A quiet afternoon: mug, flower vase and keepsake photo.
        box(59,83,85,82,cream,5);box(68,92,67,52,purple,2);
        circle(90,107,8,yellow);path(Path()..moveTo(69,143)..lineTo(94,119)..lineTo(109,134)..lineTo(121,121)..lineTo(135,144)..close(),green);
        box(155,134,58,43,yellow,8);c.drawArc(const Rect.fromLTWH(202,140,27,26),-1.57,3.14,false,pen);
        box(242,127,26,51,purple,9);line(255,126,255,84+bob);
        for(int i=0;i<5;i++){final a=i*math.pi*2/5;circle(255+math.cos(a)*13,77+bob+math.sin(a)*13,9,cream);}
        circle(255,77+bob,8,yellow);line(50,181,277,181);
      case EventCategory.exam:
        // Open revision book, oversized pencil and timer.
        path(Path()..moveTo(57,92)..quadraticBezierTo(105,78,157,97)..quadraticBezierTo(207,78,259,92)..lineTo(259,174)..quadraticBezierTo(204,159,157,178)..quadraticBezierTo(106,159,57,174)..close(),cream);
        line(157,97,157,178);
        for(int i=0;i<4;i++){line(75,113.0+i*13.0,137,113.0+i*13.0);line(177,113.0+i*13.0,235,113.0+i*13.0);}
        c.save();c.translate(218,126+bob);c.rotate(.35);box(-5,-66,12,82,yellow,2);path(Path()..moveTo(-5,16)..lineTo(1,29)..lineTo(7,16)..close(),purple);c.restore();
        circle(105,53,24,green);box(98,21,14,8,yellow,2);line(105,53,105,39);line(105,53,116+bob,58);
      case EventCategory.travel:
        // Carry-on suitcase, luggage tag and a drifting paper plane.
        box(104,73,46,41,cream,7);box(82,102,103,77,purple,13);
        line(111,111,111,168);line(155,111,155,168);circle(103,184,5,ink);circle(164,184,5,ink);
        box(148,122,25,30,yellow,4);circle(159,129,2,cream);
        c.save();c.translate(220+bob,63-bob);c.rotate(-.15);
        path(Path()..moveTo(-32,0)..lineTo(39,-21)..lineTo(13,30)..lineTo(3,10)..close(),cream);
        line(3,10,39,-21);line(3,10,-2,26);line(-2,26,13,30);c.restore();
        c.drawPath(Path()..moveTo(192,108)..quadraticBezierTo(253,116,246,149)..quadraticBezierTo(238,181,209,158),pen..color=ink.withOpacity(.4));
    }
  }
  @override bool shouldRepaint(covariant _Scene old) => old.t != t || old.category != category;
}
