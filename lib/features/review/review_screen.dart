import 'package:flutter/material.dart';
import '../../core/widgets/app_icon.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/ui.dart';
import '../../core/widgets/orbit_time_picker.dart';
import '../../data/app_controller.dart';
import '../../models/models.dart';

class ReviewScreen extends StatefulWidget {
  ReviewScreen({super.key});
  @override State<ReviewScreen> createState() => _ReviewScreenState();
}
class _ReviewScreenState extends State<ReviewScreen> {
  late final List<ExtractedEventCandidate> candidates;
  @override void initState() {
    super.initState();
    final today = Dates.only(DateTime.now());
    DateTime at(int days, int hour) => DateTime(today.year, today.month, today.day + days, hour);
    final seed = DateTime.now().microsecondsSinceEpoch;
    candidates = [
      ExtractedEventCandidate(id: '1', event: ScheduleEvent(id: 'import-${seed}a', title: 'アルバイト',
        start: at(1,19), end: at(1,23), category: EventCategory.work,
        location: '三宮店', source: 'デモ抽出のサンプル', confirmed: false),
        uncertainty: '既存のアルバイトと変更・重複している可能性'),
      ExtractedEventCandidate(id: '2', event: ScheduleEvent(id: 'import-${seed}b', title: '授業のお知らせ',
        start: at(2,13), end: at(2,14), category: EventCategory.school,
        location: '教室B', source: 'デモ抽出のサンプル', confirmed: false),
        uncertainty: '終了時間は仮の値です。確認してください'),
    ];
  }
  @override Widget build(BuildContext context) {
    final count = candidates.where((c) => c.selected).length;
    return Scaffold(appBar: AppBar(leading: const AppBackButton(), title: Text('読み取り結果の確認')),
      body: SafeArea(child: Column(children: [
        Expanded(child: ListView(padding: EdgeInsets.fromLTRB(23, 8, 23, 24), children: [
          DemoPill(text: 'AI結果ではなくサンプルです'), SizedBox(height: 17),
          Text('登録前に確認しましょう', style: Theme.of(context).textTheme.headlineSmall),
          SizedBox(height: 8),
          Text('候補ごとに内容を編集・選択できます。曖昧な項目は確認してください。',
            style: TextStyle(color: AppPalette.of(context).muted, fontSize: 12, height: 1.6)),
          SizedBox(height: 18),
          for (final candidate in candidates) _candidateCard(context, candidate),
          SizedBox(height: 8),
          SurfaceCard(color: AppPalette.of(context).butter, child: Text(
            '同じ時間帯の予定や既存予定との重なりは、保存前に確認が必要です。'
            'これはサンプルであり実際のAI信頼度ではありません。',
            style: TextStyle(fontSize: 12, height: 1.5))),
        ])),
        Container(color: AppPalette.of(context).surface, padding: EdgeInsets.fromLTRB(23, 13, 23, 16), child: Column(children: [
          Text('$count件をカレンダーに登録', style: TextStyle(color: AppPalette.of(context).muted, fontSize: 12)),
          SizedBox(height: 9),
          PrimaryButton(label: '選択した予定を確認して保存', onPressed: count > 0 ? _confirm : null),
        ])),
      ])));
  }
  Widget _candidateCard(BuildContext context, ExtractedEventCandidate c) => Padding(
    padding: EdgeInsets.only(bottom: 12), child: SurfaceCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Checkbox(value: c.selected, activeColor: AppPalette.of(context).sage, onChanged: (v) => setState(() => c.selected = v ?? false)),
        Expanded(child: Text(c.event.title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
        PopupMenuButton<String>(tooltip: '候補を操作', onSelected: (value) {
          if (value == 'edit') _edit(c);
          if (value == 'remove') setState(() => candidates.remove(c));
        }, itemBuilder: (context) => [PopupMenuItem(value: 'edit', child: Text('編集する')),
          PopupMenuItem(value: 'remove', child: Text('候補を削除'))], child: AppIcon(Icons.more_horiz_rounded))]),
      Padding(padding: EdgeInsets.only(left: 13), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CategoryBadge(c.event.category), SizedBox(height: 12),
        _field('日付', Dates.date(c.event.start)),
        _field('時間', Dates.range(c.event.start, c.event.end)),
        _field('場所', c.event.location.isEmpty ? '未設定' : c.event.location),
        if (c.uncertainty != null) ...[SizedBox(height: 9),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            AppIcon(Icons.info_outline_rounded, size: 17, color: AppPalette.of(context).danger), SizedBox(width: 7),
            Expanded(child: Text(c.uncertainty!, style: TextStyle(fontSize: 12, color: AppPalette.of(context).danger))),
          ])],
        SizedBox(height: 8),
        TextButton.icon(onPressed: () => _edit(c), icon: AppIcon(Icons.edit_outlined, size: 17),
          label: Text('内容を修正する'), style: TextButton.styleFrom(foregroundColor: AppPalette.of(context).sage)),
      ])),
    ])));
  Widget _field(String label, String value) => Padding(padding: EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [SizedBox(width: 48, child: Text(label, style: TextStyle(fontSize: 12, color: AppPalette.of(context).muted))),
      Expanded(child: Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)))]));
  Future<void> _edit(ExtractedEventCandidate c) async {
    final changed = await showModalBottomSheet<ScheduleEvent>(context: context, isScrollControlled: true,
      backgroundColor: AppPalette.of(context).ivory, useSafeArea: true,
      builder: (context) => CandidateEditor(event: c.event));
    if (changed != null && mounted) setState(() { c.event = changed; c.uncertainty = null; });
  }
  Future<void> _confirm() async {
    final app = AppScope.of(context);
    final chosen = candidates.where((c) => c.selected).toList();
    // Warn explicitly rather than silently merging or overwriting schedules.
    final overlapping = chosen.where((c) => app.events.any((e) =>
      c.event.start.isBefore(e.end) && c.event.end.isAfter(e.start))).length;
    final approved = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
      title: Text('予定を登録しますか？'),
      content: Text('選択した${chosen.length}件を登録します。${overlapping > 0 ? '\n\n$overlapping件は既存の予定と時間が重なります。重複する可能性があるため確認してください。' : ''}\n\nこのデモではデータは再起動時に初期化されます。'),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text('戻って修正')),
        TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text('登録する'))]));
    if (approved == true && mounted) {
      app.saveCandidates(chosen);
      showDemoMessage(context, '${chosen.length}件を保存しました');
      Navigator.of(context).popUntil((route) => route.isFirst);
      app.setTab(1);
    }
  }
}

class CandidateEditor extends StatefulWidget {
  final ScheduleEvent event;
  CandidateEditor({super.key, required this.event});
  @override State<CandidateEditor> createState() => _CandidateEditorState();
}
class _CandidateEditorState extends State<CandidateEditor> {
  late final TextEditingController title;
  late final TextEditingController location;
  late DateTime date;
  late TimeOfDay start, end;
  late EventCategory category;
  @override void initState() {
    super.initState(); title = TextEditingController(text: widget.event.title);
    location = TextEditingController(text: widget.event.location);
    date = Dates.only(widget.event.start);
    start = TimeOfDay.fromDateTime(widget.event.start); end = TimeOfDay.fromDateTime(widget.event.end);
    category = widget.event.category;
  }
  @override void dispose() { title.dispose(); location.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => Padding(padding: EdgeInsets.fromLTRB(25, 20, 25, MediaQuery.of(context).viewInsets.bottom + 26),
    child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('予定候補を修正', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
      SizedBox(height: 18),
      TextField(controller: title, decoration: InputDecoration(labelText: 'タイトル（必須）')),
      SizedBox(height: 12),
      TextField(controller: location, decoration: InputDecoration(labelText: '場所')),
      SizedBox(height: 12),
      OutlinedButton.icon(onPressed: () async { final d = await showDatePicker(context: context,
        initialDate: date, firstDate: DateTime(2020), lastDate: DateTime(2100), locale: Locale('ja', 'JP'));
        if (d != null && mounted) setState(() => date = d);
      }, icon: AppIcon(Icons.calendar_today_outlined), label: Text(Dates.date(date))),
      Row(children: [
        Expanded(child: TextButton(onPressed: () => _pickTime(true), child: Text('開始 ${start.format(context)}'))),
        Expanded(child: TextButton(onPressed: () => _pickTime(false), child: Text('終了 ${end.format(context)}'))),
      ]),
      DropdownButtonFormField<EventCategory>(value: category,
        items: EventCategory.values.map((c) => DropdownMenuItem(value: c, child: Text(c.label))).toList(),
        onChanged: (v) => setState(() => category = v ?? category)),
      SizedBox(height: 20),
      PrimaryButton(label: '変更を反映', onPressed: () {
        if (title.text.trim().isEmpty) { showDemoMessage(context, 'タイトルを入力してください'); return; }
        final begin = Dates.combine(date, start);
        var finish = Dates.combine(date, end);
        if (!finish.isAfter(begin)) finish = finish.add(Duration(days: 1));
        Navigator.pop(context, widget.event.copyWith(title: title.text.trim(),
          location: location.text.trim(), category: category, start: begin, end: finish));
      }),
    ])));
  Future<void> _pickTime(bool isStart) async {
    final result = await showOrbitTimePicker(context, initialTime: isStart ? start : end, title: isStart ? '開始時間' : '終了時間');
    if (result != null && mounted) setState(() { if (isStart) { start = result; } else { end = result; } });
  }
}
