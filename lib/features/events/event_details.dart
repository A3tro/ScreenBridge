import 'package:flutter/material.dart';
import '../../core/widgets/app_icon.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/ui.dart';
import '../../data/app_controller.dart';
import '../../models/models.dart';
import 'event_editor.dart';

class EventDetails extends StatelessWidget {
  final String eventId;
  EventDetails({super.key, required this.eventId});
  @override Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final event = app.eventById(eventId);
    if (event == null) return Scaffold(appBar: AppBar(leading: const AppBackButton(), ), body: Center(child: Text('この予定は削除されました')));
    return Scaffold(appBar: AppBar(leading: const AppBackButton(), actions: [IconButton(tooltip: '編集', onPressed: () => Navigator.push(context,
      MaterialPageRoute(builder: (_) => EventEditor(event: event))), icon: AppIcon(Icons.edit_outlined))]),
      body: SafeArea(child: ListView(padding: EdgeInsets.fromLTRB(25, 8, 25, 30), children: [
        Container(height: 225, decoration: BoxDecoration(color: event.category.background(context), borderRadius: BorderRadius.circular(25)),
          child: Center(child: CategoryArt(category: event.category, size: 300))),
        SizedBox(height: 27),
        CategoryBadge(event.category), SizedBox(height: 13),
        Text(event.title, style: Theme.of(context).textTheme.headlineMedium),
        SizedBox(height: 24),
        _detail(context, Icons.calendar_today_outlined, '日付', Dates.date(event.start)),
        _detail(context, Icons.schedule_rounded, '時間', event.allDay ? '終日' : Dates.range(event.start, event.end)),
        if (event.location.isNotEmpty) _detail(context, Icons.place_outlined, '場所', event.location),
        if (event.notes.isNotEmpty) _detail(context, Icons.notes_rounded, 'メモ', event.notes),
        _detail(context, Icons.notifications_none_rounded, '通知', event.reminder),
        if (event.source.isNotEmpty) _detail(context, Icons.file_present_outlined, '取り込み元', event.source),
        _detail(context, Icons.verified_outlined, '確認状態', event.confirmed ? '確認済み' : '要確認'),
        SizedBox(height: 20),
        SectionLabel(title: '変更履歴'), SizedBox(height: 10),
        if (event.history.isEmpty) Text('変更履歴はありません', style: TextStyle(color: AppPalette.of(context).muted))
        else ...event.history.map((h) => Padding(padding: EdgeInsets.symmetric(vertical: 6),
          child: Text('• $h', style: TextStyle(fontSize: 13)))),
        SizedBox(height: 30),
        PrimaryButton(label: '予定を編集', icon: Icons.edit_outlined, onPressed: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => EventEditor(event: event)))),
        SizedBox(height: 12),
        Center(child: TextButton.icon(onPressed: () => _delete(context, app, event),
          icon: AppIcon(Icons.delete_outline_rounded, color: AppPalette.of(context).danger),
          label: Text('この予定を削除', style: TextStyle(color: AppPalette.of(context).danger)))),
      ])));
  }
  Widget _detail(BuildContext context, IconData icon, String title, String value) => Padding(padding: EdgeInsets.symmetric(vertical: 12),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 42, height: 42, decoration: BoxDecoration(color: AppPalette.of(context).surface, borderRadius: BorderRadius.circular(12)),
        child: AppIcon(icon, size: 20, color: AppPalette.of(context).sage)), SizedBox(width: 13),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(fontSize: 11, color: AppPalette.of(context).muted)), SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      ])),
    ]));
  void _delete(BuildContext context, AppController app, ScheduleEvent event) async {
    final yes = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
      title: Text('予定を削除しますか？'), content: Text('「${event.title}」を削除します。'), actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text('キャンセル')),
        TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text('削除', style: TextStyle(color: AppPalette.of(context).danger))),
      ]));
    if (yes == true && context.mounted) { app.deleteEvent(event.id); Navigator.pop(context); }
  }
}
