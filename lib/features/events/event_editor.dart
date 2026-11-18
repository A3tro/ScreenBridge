import 'package:flutter/material.dart';
import '../../core/widgets/app_icon.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/ui.dart';
import '../../core/widgets/orbit_time_picker.dart';
import '../../data/app_controller.dart';
import '../../models/models.dart';

class EventEditor extends StatefulWidget {
  final ScheduleEvent? event;
  final DateTime? selectedDate;
  EventEditor({super.key, this.event, this.selectedDate});
  @override State<EventEditor> createState() => _EventEditorState();
}
class _EventEditorState extends State<EventEditor> {
  final form = GlobalKey<FormState>();
  late final TextEditingController title;
  late final TextEditingController location;
  late final TextEditingController notes;
  late DateTime day;
  late TimeOfDay start;
  late TimeOfDay end;
  late EventCategory category;
  late bool allDay;
  late String reminder;
  @override void initState() {
    super.initState();
    final e = widget.event;
    title = TextEditingController(text: e?.title ?? '');
    location = TextEditingController(text: e?.location ?? '');
    notes = TextEditingController(text: e?.notes ?? '');
    day = Dates.only(e?.start ?? widget.selectedDate ?? DateTime.now());
    start = TimeOfDay.fromDateTime(e?.start ?? DateTime(day.year,day.month,day.day,10));
    end = TimeOfDay.fromDateTime(e?.end ?? DateTime(day.year,day.month,day.day,11));
    category = e?.category ?? EventCategory.personal;
    allDay = e?.allDay ?? false;
    reminder = e?.reminder ?? 'なし';
  }
  @override void dispose() { title.dispose(); location.dispose(); notes.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(leading: const AppBackButton(), title: Text(widget.event == null ? '予定を追加' : '予定を編集')),
    body: SafeArea(child: Form(key: form, child: ListView(padding: EdgeInsets.fromLTRB(24, 8, 24, 30), children: [
      Text('予定のタイトル', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      SizedBox(height: 9),
      TextFormField(controller: title, maxLength: 80, decoration: InputDecoration(hintText: '例：アルバイト'),
        validator: (v) => v != null && v.trim().isNotEmpty ? null : 'タイトルは必須です'),
      SizedBox(height: 16),
      Text('日付と時間', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      SizedBox(height: 10),
      _select(Icons.calendar_today_outlined, '日付', Dates.date(day), () async {
        final picked = await showDatePicker(context: context, initialDate: day,
          firstDate: DateTime(2020), lastDate: DateTime(2100), locale: Locale('ja', 'JP'));
        if (picked != null && mounted) setState(() => day = picked);
      }),
      _select(Icons.schedule_outlined, '開始', start.format(context), () async {
        final picked = await showOrbitTimePicker(context, initialTime: start, title: '開始時間');
        if (picked != null && mounted) setState(() => start = picked);
      }),
      _select(Icons.schedule_outlined, '終了', end.format(context), () async {
        final picked = await showOrbitTimePicker(context, initialTime: end, title: '終了時間');
        if (picked != null && mounted) setState(() => end = picked);
      }),
      SwitchListTile(contentPadding: EdgeInsets.zero, value: allDay, activeColor: AppPalette.of(context).sage,
        onChanged: (v) => setState(() => allDay = v), title: Text('終日の予定', style: TextStyle(fontSize: 14))),
      Text('終了時間が開始時間より前の場合は、翌日終了として登録します。',
        style: TextStyle(fontSize: 11, color: AppPalette.of(context).muted)),
      SizedBox(height: 23),
      Text('カテゴリー', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      SizedBox(height: 11),
      Wrap(spacing: 8, runSpacing: 8, children: EventCategory.values.map((c) => ChoiceChip(
        avatar: CategoryArt(category: c, size: 26), label: Text(c.label), selected: c == category, onSelected: (_) => setState(() => category = c),
        selectedColor: c.background(context), backgroundColor: AppPalette.of(context).surface,
        side: BorderSide(color: c == category ? c.foreground(context) : AppPalette.of(context).line), labelStyle: TextStyle(fontSize: 12))).toList()),
      SizedBox(height: 24),
      TextFormField(controller: location, maxLength: 100, decoration: InputDecoration(labelText: '場所（任意）', prefixIcon: AppIcon(Icons.place_outlined))),
      SizedBox(height: 10),
      TextFormField(controller: notes, maxLines: 3, maxLength: 500,
        decoration: InputDecoration(labelText: 'メモ（任意）', alignLabelWithHint: true)),
      SizedBox(height: 15),
      DropdownButtonFormField<String>(value: reminder, decoration: InputDecoration(labelText: 'リマインダー（デモ設定）'),
        items: ['なし', '5分前', '15分前', '30分前', '1時間前'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
        onChanged: (v) => setState(() => reminder = v ?? 'なし')),
      SizedBox(height: 28),
      PrimaryButton(label: widget.event == null ? '予定を保存' : '変更を保存', onPressed: _save),
    ]))));
  Widget _select(IconData icon, String title, String value, VoidCallback onTap) => Padding(padding: EdgeInsets.symmetric(vertical: 5),
    child: SurfaceCard(onTap: onTap, child: Row(children: [AppIcon(icon, color: AppPalette.of(context).sage, size: 20),
      SizedBox(width: 13), Text(title, style: TextStyle(fontSize: 13, color: AppPalette.of(context).muted)),
      Spacer(), Flexible(child: Text(value, textAlign: TextAlign.right, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
      SizedBox(width: 5), AppIcon(Icons.chevron_right_rounded, color: AppPalette.of(context).muted, size: 19)])));
  void _save() {
    if (!form.currentState!.validate()) return;
    final begin = Dates.combine(day, start);
    var finish = Dates.combine(day, end);
    if (allDay) { finish = day.add(Duration(days: 1)); }
    else if (!finish.isAfter(begin)) { finish = finish.add(Duration(days: 1)); }
    final existing = widget.event;
    AppScope.of(context).saveEvent(ScheduleEvent(
      id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      title: title.text.trim(), start: allDay ? day : begin, end: finish,
      category: category, location: location.text.trim(), notes: notes.text.trim(),
      source: existing?.source ?? '', allDay: allDay, reminder: reminder,
      history: [...?existing?.history, if (existing != null) '手動で編集しました'],
    ));
    showDemoMessage(context, '予定を保存しました（アプリ終了時に初期化されます）');
    Navigator.pop(context);
  }
}
