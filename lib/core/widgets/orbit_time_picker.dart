import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

Future<TimeOfDay?> showOrbitTimePicker(BuildContext context, {required TimeOfDay initialTime, required String title}) =>
  showDialog<TimeOfDay>(context: context, builder: (_) => OrbitTimePicker(initialTime: initialTime, title: title));

class OrbitTimePicker extends StatefulWidget {
  final TimeOfDay initialTime;
  final String title;
  const OrbitTimePicker({super.key, required this.initialTime, required this.title});
  @override State<OrbitTimePicker> createState() => _OrbitTimePickerState();
}
class _OrbitTimePickerState extends State<OrbitTimePicker> {
  late int hour = widget.initialTime.hour;
  late int minute = widget.initialTime.minute;
  bool hours = true;
  void _drag(Offset point, double size) {
    final delta = point - Offset(size / 2, size / 2);
    if (delta.distance < size * .25) return;
    final angle = (math.atan2(delta.dy, delta.dx) + math.pi / 2 + math.pi * 2) % (math.pi * 2);
    final count = hours ? 24 : 60;
    setState(() { final value = (angle / (math.pi * 2) * count).round() % count;
      if (hours) { hour = value; } else { minute = value; }
    });
  }
  @override Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Dialog(insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: p.ivory, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 380), child: SingleChildScrollView(
        padding: const EdgeInsets.all(22), child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(widget.title, style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 6),
          Text('リングを動かすか、時・分を選択', style: TextStyle(color: p.muted, fontSize: 12), textAlign: TextAlign.center),
          const SizedBox(height: 14),
          LayoutBuilder(builder: (context, constraints) {
            final size = math.min(270.0, constraints.maxWidth);
            return Semantics(label: '${hours ? '時' : '分'}のダイヤル', value: hours ? '$hour時' : '$minute分',
              onIncrease: () => setState(() { if (hours) { hour = (hour + 1) % 24; } else { minute = (minute + 1) % 60; } }),
              onDecrease: () => setState(() { if (hours) { hour = (hour + 23) % 24; } else { minute = (minute + 59) % 60; } }),
              child: GestureDetector(onPanDown: (d) => _drag(d.localPosition, size), onPanUpdate: (d) => _drag(d.localPosition, size),
                child: SizedBox(width: size, height: size, child: CustomPaint(
                  painter: _OrbitPainter(value: hours ? hour / 24 : minute / 60, hours: hours, palette: p),
                  child: Center(child: IgnorePointer(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(hours ? '時間' : '分', style: TextStyle(fontSize: 12, color: p.muted)), const SizedBox(height: 6),
                    Text('${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
                      style: TextStyle(fontSize: size * .125, fontWeight: FontWeight.w600, color: p.navy)),
                    const SizedBox(height: 7), Text('24時間表示', style: TextStyle(fontSize: 10, color: p.muted)),
                  ])))))));
          }),
          const SizedBox(height: 14),
          Row(children: [Expanded(child: DropdownButtonFormField<int>(key: const ValueKey('time-hour'), value: hour,
            isExpanded: true, decoration: InputDecoration(labelText: '時', fillColor: hours ? p.mint : p.surface),
            items: List.generate(24, (i) => DropdownMenuItem(value: i, child: Text(i.toString().padLeft(2, '0')))),
            onTap: () => setState(() => hours = true), onChanged: (v) => setState(() { hour = v!; hours = true; }))),
            const SizedBox(width: 14), Expanded(child: DropdownButtonFormField<int>(key: const ValueKey('time-minute'), value: minute,
              isExpanded: true, decoration: InputDecoration(labelText: '分', fillColor: !hours ? p.mint : p.surface),
              items: List.generate(60, (i) => DropdownMenuItem(value: i, child: Text(i.toString().padLeft(2, '0')))),
              onTap: () => setState(() => hours = false), onChanged: (v) => setState(() { minute = v!; hours = false; }))),
          ]),
          const SizedBox(height: 20),
          Wrap(alignment: WrapAlignment.end, spacing: 12, runSpacing: 8, children: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('キャンセル')),
            FilledButton(key: const ValueKey('time-confirm'), style: FilledButton.styleFrom(backgroundColor: p.sage, foregroundColor: p.ivory),
              onPressed: () => Navigator.pop(context, TimeOfDay(hour: hour, minute: minute)), child: const Text('決定')),
          ]),
        ]))));
  }
}
class _OrbitPainter extends CustomPainter {
  final double value;
  final bool hours;
  final AppPalette palette;
  _OrbitPainter({required this.value, required this.hours, required this.palette});
  @override void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero); final r = size.width * .43;
    final ring = Paint()..style = PaintingStyle.stroke..strokeWidth = size.width * .07..strokeCap = StrokeCap.round;
    canvas.drawCircle(c, r, ring..color = palette.line.withOpacity(.5));
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawArc(rect, -math.pi / 2, math.max(.03, value * math.pi * 2), false,
      ring..shader = SweepGradient(startAngle: -math.pi / 2, endAngle: math.pi * 1.5,
        colors: [palette.mint, const Color(0xFF45C886)]).createShader(rect));
    canvas.drawCircle(c, r * .83, Paint()..color = palette.surface);
    for (int i = 0; i < 24; i++) {
      final a = i / 24 * math.pi * 2 - math.pi / 2;
      Offset at(double radius) => c + Offset(math.cos(a), math.sin(a)) * radius;
      canvas.drawLine(at(r * .79), at(r * (i % 6 == 0 ? .72 : .75)), Paint()..color = palette.muted..strokeWidth = i % 6 == 0 ? 1.6 : .8);
    }
    final angle = value * math.pi * 2 - math.pi / 2;
    final point = c + Offset(math.cos(angle), math.sin(angle)) * r;
    canvas.drawShadow(Path()..addOval(Rect.fromCircle(center: point, radius: 14)), Colors.black26, 5, true);
    canvas.drawCircle(point, 14, Paint()..color = palette.surface);
    canvas.drawCircle(point, 7, Paint()..color = const Color(0xFF45C886));
  }
  @override bool shouldRepaint(covariant _OrbitPainter old) => old.value != value || old.hours != hours || old.palette != palette;
}
