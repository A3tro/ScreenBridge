import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/i18n/lang.dart';
import '../../core/widgets/app_icon.dart';
import '../../core/widgets/category_illustration.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_utils.dart';
import '../../data/app_controller.dart';
import '../../models/models.dart';
import '../changes/changes_screen.dart';
import '../events/event_details.dart';
import '../events/event_editor.dart';
import '../settings/theme_screen.dart';

/// ホーム：今日のこと（次の予定、今週のシフト、今日の予定）が、ぱっと分かる画面
class HomeScreen extends StatefulWidget {
  HomeScreen({super.key});
  @override State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? timer;

  @override void initState() {
    super.initState();
    // 「あと◯分」を、1分ごとに更新する
    timer = Timer.periodic(const Duration(minutes: 1), (_) { if (mounted) setState(() {}); });
  }

  @override void dispose() { timer?.cancel(); super.dispose(); }

  /// 次の予定まで、あとどれくらいか
  String _until(ScheduleEvent e, DateTime now) {
    if (!e.start.isAfter(now)) {
      return e.allDay ? tr('今日', 'Today') : tr('開催中（${Dates.time(e.end)}まで）', 'Now (until ${Dates.time(e.end)})');
    }
    final days = Dates.only(e.start).difference(Dates.only(now)).inDays;
    if (days == 1) return tr('明日', 'Tomorrow');
    if (days >= 2) return tr('$days日後', 'In $days days');
    final d = e.start.difference(now);
    final h = d.inHours, m = d.inMinutes % 60;
    return h > 0 ? tr('あと$h時間$m分', 'In ${h}h ${m}m') : tr('あと$m分', 'In $m min');
  }

  /// 今週（月〜日）のシフトの回数と、合計の時間
  ({int count, double hours}) _weekWork(AppController app, DateTime now) {
    final monday = Dates.only(now).subtract(Duration(days: now.weekday - 1));
    final nextMonday = monday.add(const Duration(days: 7));
    final list = app.events.where((e) => e.category == EventCategory.work
      && !e.start.isBefore(monday) && e.start.isBefore(nextMonday)).toList();
    var minutes = 0;
    for (final e in list) { minutes += e.end.difference(e.start).inMinutes; }
    return (count: list.length, hours: minutes / 60);
  }

  @override Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = AppPalette.of(context);
    final now = DateTime.now();
    final todayEvents = app.onDay(now);
    final next = app.nextEvent;
    final week = _weekWork(app, now);
    final hoursText = week.hours == week.hours.roundToDouble() ? '${week.hours.toInt()}' : week.hours.toStringAsFixed(1);

    return Scaffold(body: SafeArea(child: ListView(padding: EdgeInsets.fromLTRB(22, 12, 22, 26), children: [
      Row(children: [SizedBox(width: 48),
        Spacer(), Text('ScreenBridge', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        Spacer(),
        IconButton(tooltip: tr('テーマ', 'Theme'), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ThemeScreen())),
          icon: const AppIcon(Icons.palette_outlined)),
        IconButton(tooltip: tr('お知らせ', 'Notifications'), onPressed: () => app.setTab(3), icon: Badge(
          isLabelVisible: app.unreadCount > 0, smallSize: 6, child: AppIcon(Icons.notifications_none, size: 23)))]),
      SizedBox(height: 23),
      Text(tr('${app.user.name} さん、おかえりなさい', 'Welcome back, ${app.user.name}'),
        style: TextStyle(fontSize: 11, color: p.muted, letterSpacing: 1)),
      SizedBox(height: 8),
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(child: Text('Today', style: TextStyle(fontSize: 37, fontWeight: FontWeight.w700, letterSpacing: -1.5))),
        Padding(padding: EdgeInsets.only(bottom: 7), child: Text(longDateLabel(now), style: TextStyle(fontSize: 12))),
      ]),
      SizedBox(height: 22),

      // 次の予定
      _nextCard(context, next, now),
      SizedBox(height: 12),

      // 今週のシフト
      Row(children: [
        Expanded(child: _stat(context, tr('今週のシフト', 'Shifts this week'), tr('${week.count}回', '${week.count}'), p.mint)),
        SizedBox(width: 12),
        Expanded(child: _stat(context, tr('今週の勤務時間', 'Hours this week'), tr('$hoursText時間', '$hoursText h'), p.peach)),
      ]),
      SizedBox(height: 12),

      // 読み取りへ
      Material(color: p.butter, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: p.navy, width: .8)),
        child: InkWell(borderRadius: BorderRadius.circular(16), onTap: () => app.setTab(2), child: Padding(padding: EdgeInsets.all(17),
          child: Row(children: [AppIcon(Icons.document_scanner_outlined, size: 22), SizedBox(width: 13),
            Expanded(child: Text(tr('写真や文章から予定を追加', 'Add events from a photo or text'),
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
            AppIcon(Icons.arrow_forward, size: 18)])))),
      SizedBox(height: 24),

      // 今日の予定
      Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('TODAY’S AGENDA', style: TextStyle(fontSize: 11, letterSpacing: 1.4, fontWeight: FontWeight.w600)),
        SizedBox(height: 5),
        Text(tr('${todayEvents.length}件の予定', '${todayEvents.length} ${todayEvents.length == 1 ? 'event' : 'events'}'),
          style: TextStyle(fontSize: 11, color: p.muted))])),
        IconButton.filledTonal(tooltip: tr('予定を追加', 'Add event'), style: IconButton.styleFrom(backgroundColor: p.surface),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EventEditor(selectedDate: Dates.only(now)))),
          icon: AppIcon(Icons.add, size: 22))]),
      SizedBox(height: 15),
      if (todayEvents.isEmpty) Container(width: double.infinity, padding: EdgeInsets.all(30), decoration: _box(p.surface),
        child: Column(children: [AppIcon(Icons.event_available_outlined, size: 30), SizedBox(height: 12),
          Text(tr('今日は予定がありません', 'No events today')),
          SizedBox(height: 6),
          Text(tr('＋から予定を追加できます', 'Tap + to add an event'), style: TextStyle(fontSize: 12, color: p.muted))])),
      for (final event in todayEvents) _event(context, event),

      if (app.pendingChanges > 0) ...[SizedBox(height: 12),
        Material(color: p.mint, borderRadius: BorderRadius.circular(14), child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          leading: AppIcon(Icons.rule_outlined, size: 22),
          title: Text(tr('${app.pendingChanges}件の確認待ち', '${app.pendingChanges} to review'),
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          subtitle: Text(tr('変更・重複の候補を見る', 'See changes and duplicates'), style: TextStyle(fontSize: 11)),
          trailing: AppIcon(Icons.chevron_right, size: 20),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChangesScreen()))))],
      SizedBox(height: 8),
      Center(child: TextButton(onPressed: () => app.setTab(1),
        child: Text(tr('カレンダーで、ほかの日を見る', 'See other days in the calendar'),
          style: TextStyle(color: p.sage, fontSize: 12)))),
    ])));
  }

  Widget _nextCard(BuildContext context, ScheduleEvent? e, DateTime now) {
    final p = AppPalette.of(context);
    return Material(color: p.lavender, clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: BorderSide(color: p.navy, width: .8)),
      child: InkWell(onTap: e == null ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => EventDetails(eventId: e.id))),
        child: Padding(padding: EdgeInsets.all(18), child: e == null
          ? Row(children: [AppIcon(Icons.event_available_outlined, size: 28), SizedBox(width: 12),
              Expanded(child: Text(tr('これからの予定はありません', 'No upcoming events'),
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)))])
          : Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('NEXT', style: TextStyle(fontSize: 10, letterSpacing: 1.4, fontWeight: FontWeight.w600)),
                SizedBox(height: 6),
                Text(_until(e, now), style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                SizedBox(height: 6),
                Text(e.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                SizedBox(height: 3),
                Text('${dateLabel(e.start)}  ${e.allDay ? tr('終日', 'All day') : Dates.range(e.start, e.end)}',
                  style: TextStyle(fontSize: 12, color: p.muted)),
                if (e.location.isNotEmpty) Text(e.location, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: p.muted)),
              ])),
              SizedBox(width: 10),
              CategoryIllustration(category: e.category, width: 64, height: 64, animated: false),
            ]))));
  }

  Widget _stat(BuildContext context, String label, String value, Color color) => Container(
    padding: EdgeInsets.all(16), decoration: _box(color),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
      SizedBox(height: 6),
      Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
    ]));

  BoxDecoration _box(Color color) => BoxDecoration(color: color, borderRadius: BorderRadius.circular(22),
    border: Border.all(color: AppPalette.of(context).navy, width: .8));

  Widget _event(BuildContext context, ScheduleEvent e) => Padding(padding: EdgeInsets.only(bottom: 13), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    SizedBox(width: 48, child: Padding(padding: EdgeInsets.only(top: 19), child: Text(e.allDay ? tr('終日', 'All day') : Dates.time(e.start),
      style: TextStyle(fontSize: 11, color: AppPalette.of(context).muted)))),
    Expanded(child: Material(color: AppPalette.of(context).surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: AppPalette.of(context).line)),
      child: InkWell(borderRadius: BorderRadius.circular(16), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EventDetails(eventId: e.id))),
        child: Padding(padding: EdgeInsets.all(16), child: Row(children: [
          Container(width: 3, height: 48, decoration: BoxDecoration(color: e.category.foreground(context), borderRadius: BorderRadius.circular(4))),
          SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(e.title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)), SizedBox(height: 7),
            Text(e.allDay ? tr('終日', 'All day') : Dates.range(e.start, e.end), style: TextStyle(fontSize: 10, color: AppPalette.of(context).muted)),
            if (e.location.isNotEmpty) ...[SizedBox(height: 4), Text(e.location, style: TextStyle(fontSize: 10, color: AppPalette.of(context).muted))],
          ])), SizedBox(width: 8), CategoryIllustration(category: e.category, width: 40, height: 40, animated: false),
        ]))))),
  ]));
}