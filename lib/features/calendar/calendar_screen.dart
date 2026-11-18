import 'package:flutter/material.dart';
import '../../core/i18n/lang.dart';
import '../../core/widgets/app_icon.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/ui.dart';
import '../../data/app_controller.dart';
import '../../models/models.dart';
import '../events/event_details.dart';
import '../events/event_editor.dart';

/// カレンダー：1か月の表で、予定を探して見る画面
class CalendarScreen extends StatefulWidget {
  CalendarScreen({super.key});
  @override State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime selected = Dates.only(DateTime.now());
  late DateTime month = DateTime(selected.year, selected.month);

  static const _saturday = Color(0xFF3B6EA8);

  void changeMonth(int delta) => setState(() {
    month = DateTime(month.year, month.month + delta);
    final today = Dates.only(DateTime.now());
    selected = (today.year == month.year && today.month == month.month) ? today : DateTime(month.year, month.month);
  });

  void goToday() => setState(() {
    selected = Dates.only(DateTime.now());
    month = DateTime(selected.year, selected.month);
  });

  @override Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = AppPalette.of(context);
    final events = app.onDay(selected);
    final first = DateTime(month.year, month.month);
    final offset = first.weekday - 1; // 月曜はじまり
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final rows = ((offset + daysInMonth) / 7).ceil();
    final today = Dates.only(DateTime.now());

    return Scaffold(body: SafeArea(child: Column(children: [
      ScreenHeader(title: tr('カレンダー', 'Calendar'), subtitle: monthLabel(month), trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(tooltip: tr('前の月', 'Previous month'), onPressed: () => changeMonth(-1), icon: AppIcon(Icons.chevron_left_rounded)),
        IconButton(tooltip: tr('次の月', 'Next month'), onPressed: () => changeMonth(1), icon: AppIcon(Icons.chevron_right_rounded)),
      ])),

      // 1か月の表
      Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Column(children: [
        Row(children: List.generate(7, (i) => Expanded(child: Center(child: Text(weekdayShort(i + 1),
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
            color: i == 5 ? _saturday : i == 6 ? p.danger : p.muted)))))),
        SizedBox(height: 6),
        for (var r = 0; r < rows; r++) Row(children: List.generate(7, (c) {
          final n = r * 7 + c - offset + 1;
          if (n < 1 || n > daysInMonth) return const Expanded(child: SizedBox(height: 48));
          final day = DateTime(month.year, month.month, n);
          final chosen = Dates.sameDay(day, selected);
          final isToday = Dates.sameDay(day, today);
          final dayEvents = app.onDay(day);
          final numberColor = chosen ? p.ivory : (c == 6 ? p.danger : (c == 5 ? _saturday : p.navy));
          return Expanded(child: InkWell(borderRadius: BorderRadius.circular(12), onTap: () => setState(() => selected = day),
            child: Container(height: 48, margin: EdgeInsets.all(1.5),
              decoration: BoxDecoration(color: chosen ? p.navy : Colors.transparent, borderRadius: BorderRadius.circular(12),
                border: isToday && !chosen ? Border.all(color: p.navy, width: 1.2) : null),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('$n', style: TextStyle(fontSize: 14, color: numberColor,
                  fontWeight: chosen || isToday ? FontWeight.w800 : FontWeight.w500)),
                SizedBox(height: 4),
                SizedBox(height: 5, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  for (final e in dayEvents.take(3)) Container(width: 5, height: 5, margin: EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(shape: BoxShape.circle, color: chosen ? p.ivory : e.category.foreground(context))),
                ])),
              ]))));
        })),
      ])),
      Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Align(alignment: Alignment.centerRight,
        child: TextButton(onPressed: goToday, child: Text(tr('今日へ戻る', 'Back to today'), style: TextStyle(color: p.sage, fontSize: 12))))),

      // 選んだ日の予定
      Expanded(child: Container(decoration: BoxDecoration(color: p.surface,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(27), topRight: Radius.circular(27))),
        child: Column(children: [
          Padding(padding: EdgeInsets.fromLTRB(23, 18, 23, 6), child: Row(children: [
            Expanded(child: Text(tr('${longDateLabel(selected)}の予定', longDateLabel(selected)),
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
            Text(tr('${events.length}件', '${events.length} ${events.length == 1 ? 'event' : 'events'}'),
              style: TextStyle(color: p.sage, fontWeight: FontWeight.w700)),
          ])),
          Expanded(child: AnimatedSwitcher(duration: Duration(milliseconds: 200), child: events.isEmpty
            ? Center(key: ValueKey(selected.toString()), child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Illustration('calendar_empty', height: 110),
                SizedBox(height: 6), Text(tr('この日の予定はありません', 'No events on this day'), style: TextStyle(color: p.muted)),
              ])))
            : ListView(key: ValueKey(selected.toString()), padding: EdgeInsets.fromLTRB(20, 0, 20, 90), children: [
                for (final e in events) _eventRow(context, e),
              ]))),
        ]))),
    ])), floatingActionButton: FloatingActionButton(tooltip: tr('予定を追加', 'Add event'), onPressed: () => Navigator.push(context,
      MaterialPageRoute(builder: (_) => EventEditor(selectedDate: selected))),
      backgroundColor: p.navy, foregroundColor: p.ivory, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: AppIcon(Icons.add_rounded)));
  }

  /// 予定の1行
  Widget _eventRow(BuildContext context, ScheduleEvent e) {
    final p = AppPalette.of(context);
    return Material(color: Colors.transparent, child: InkWell(borderRadius: BorderRadius.circular(15),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EventDetails(eventId: e.id))),
      child: Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Row(children: [
        Container(width: 47, height: 47,
          decoration: BoxDecoration(color: e.category.background(context), borderRadius: BorderRadius.circular(15)),
          child: CategoryArt(category: e.category, size: 42)),
        SizedBox(width: 13),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(e.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          SizedBox(height: 4),
          Text(e.allDay ? tr('終日', 'All day') : Dates.range(e.start, e.end),
            style: TextStyle(color: p.muted, fontSize: 12)),
          if (e.location.isNotEmpty) Text(e.location, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(color: p.muted, fontSize: 11)),
        ])),
        if (!e.confirmed) AppIcon(Icons.error_outline_rounded, color: p.danger, size: 19),
        SizedBox(width: 4),
        AppIcon(Icons.chevron_right_rounded, color: p.muted, size: 21),
      ]))));
  }
}