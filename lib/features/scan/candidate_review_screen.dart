import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/app_icon.dart';
import '../../core/widgets/ui.dart';
import '../../data/app_controller.dart';
import '../../models/models.dart';

/// 前に保存した予定と比べた結果
enum _Kind { added, changed, duplicate }

class _Check {
  _Kind kind;
  ScheduleEvent? old; // 変更・登録済みのときの、前の予定
  List<ScheduleEvent> overlaps; // 時間が重なる、ほかの予定
  _Check(this.kind, {this.old, this.overlaps = const []});
}

/// 読み取った予定の一覧。前の予定と比べて、確認・修正・削除して、保存する
class CandidateReviewScreen extends StatefulWidget {
  final List<ExtractedEventCandidate> candidates;
  final String sourceLabel;
  final String keywordLabel;
  CandidateReviewScreen({super.key, required this.candidates, required this.sourceLabel, this.keywordLabel = ''});
  @override State<CandidateReviewScreen> createState() => _CandidateReviewScreenState();
}

class _CandidateReviewScreenState extends State<CandidateReviewScreen> {
  late final List<ExtractedEventCandidate> items = [...widget.candidates];
  final Map<String, _Check> checks = {};
  final List<ScheduleEvent> missing = []; // 前に保存したシフトで、今回の表にないもの
  final Set<String> removeIds = {}; // 削除する予定のID
  List<ScheduleEvent> existing = const [];
  bool analyzed = false;

  int get selectedCount => items.where((c) => c.selected).length;
  int get totalCount => selectedCount + removeIds.length;

  @override void didChangeDependencies() {
    super.didChangeDependencies();
    if (!analyzed) {
      analyzed = true;
      existing = [...AppScope.of(context).events];
      _analyze();
    }
  }

  // ---------- 前の予定と比べる ----------
  String _norm(String s) => s.replaceAll(RegExp(r'\s+'), '').toLowerCase();
  bool _sameShift(ScheduleEvent a, ScheduleEvent b) =>
    (a.category == EventCategory.work && b.category == EventCategory.work) || _norm(a.title) == _norm(b.title);
  bool _sameTime(ScheduleEvent a, ScheduleEvent b) => a.start == b.start && a.end == b.end;
  bool _overlap(ScheduleEvent a, ScheduleEvent b) =>
    !a.allDay && !b.allDay && a.start.isBefore(b.end) && b.start.isBefore(a.end);

  void _analyze() {
    final used = <String>{};
    for (final c in items) {
      final e = c.event;
      final sameDay = existing.where((x) => !used.contains(x.id) && Dates.sameDay(x.start, e.start)).toList();

      ScheduleEvent? dup;
      for (final x in sameDay) { if (_sameTime(x, e)) { dup = x; break; } }
      if (dup != null) {
        used.add(dup.id);
        checks[c.id] = _Check(_Kind.duplicate, old: dup);
        c.selected = false; // 同じ予定がもうあるので、最初はチェックを外す
        continue;
      }

      ScheduleEvent? old;
      for (final x in sameDay) { if (_sameShift(x, e)) { old = x; break; } }
      if (old != null) used.add(old.id);
      final overlaps = existing.where((x) => x.id != old?.id && _overlap(x, e)).toList();
      checks[c.id] = _Check(old != null ? _Kind.changed : _Kind.added, old: old, overlaps: overlaps);
    }

    // 今回読み取ったシフトの期間にあるのに、見つからなかった前のシフト
    final work = items.where((c) => c.event.category == EventCategory.work).toList();
    if (work.isNotEmpty) {
      final days = work.map((c) => Dates.only(c.event.start)).toList()..sort();
      final from = days.first;
      final to = days.last.add(const Duration(days: 1));
      missing.addAll(existing.where((x) => x.category == EventCategory.work && !used.contains(x.id)
        && !x.start.isBefore(from) && x.start.isBefore(to)));
      missing.sort((a, b) => a.start.compareTo(b.start));
    }
  }

  /// 修正したあとに、もう一度比べ直す
  void _recheck(ExtractedEventCandidate c) {
    final ch = checks[c.id];
    if (ch == null) return;
    if (ch.kind == _Kind.duplicate && ch.old != null && !_sameTime(ch.old!, c.event)) ch.kind = _Kind.changed;
    ch.overlaps = existing.where((x) => x.id != ch.old?.id && _overlap(x, c.event)).toList();
  }

  // ---------- 表示の部品 ----------
  String _hm(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  String _range(ScheduleEvent e) => e.allDay ? '終日' : '${_hm(e.start)}〜${_hm(e.end)}';

  Widget _statusChip(_Check? ch) {
    final p = AppPalette.of(context);
    final (label, bg, fg) = switch (ch?.kind ?? _Kind.added) {
      _Kind.added => ('新規', p.mint, p.sage),
      _Kind.changed => ('時間の変更', const Color(0xFFFFE7C2), const Color(0xFF8A5300)),
      _Kind.duplicate => ('登録済み', p.line, p.muted),
    };
    return Container(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)));
  }

  // ---------- 修正 ----------
  Future<void> _edit(ExtractedEventCandidate c) async {
    final titleCtl = TextEditingController(text: c.event.title);
    var start = c.event.start;
    var end = c.event.end;
    var timeChanged = false;

    final ok = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) {
      Future<void> pickDate() async {
        final d = await showDatePicker(context: ctx, initialDate: start,
          firstDate: DateTime(start.year - 1), lastDate: DateTime(start.year + 2));
        if (d == null) return;
        final length = end.difference(start);
        setLocal(() {
          start = DateTime(d.year, d.month, d.day, start.hour, start.minute);
          end = start.add(length);
        });
      }

      Future<void> pickTime(bool isStart) async {
        final t = await showTimePicker(context: ctx, initialTime: TimeOfDay.fromDateTime(isStart ? start : end),
          builder: (c2, child) => MediaQuery(data: MediaQuery.of(c2).copyWith(alwaysUse24HourFormat: true), child: child!));
        if (t == null) return;
        setLocal(() {
          timeChanged = true;
          if (isStart) {
            final length = end.difference(start);
            start = DateTime(start.year, start.month, start.day, t.hour, t.minute);
            end = start.add(length);
          } else {
            var e = DateTime(start.year, start.month, start.day, t.hour, t.minute);
            if (!e.isAfter(start)) e = e.add(const Duration(days: 1));
            end = e;
          }
        });
      }

      return AlertDialog(
        title: Text('予定を修正'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: titleCtl, decoration: InputDecoration(labelText: 'タイトル')),
          SizedBox(height: 8),
          ListTile(contentPadding: EdgeInsets.zero, leading: AppIcon(Icons.event_outlined),
            title: Text(Dates.short(start)), subtitle: Text('日付を変える'), onTap: pickDate),
          ListTile(contentPadding: EdgeInsets.zero, leading: AppIcon(Icons.schedule_rounded),
            title: Text('開始  ${_hm(start)}'), onTap: () => pickTime(true)),
          ListTile(contentPadding: EdgeInsets.zero, leading: AppIcon(Icons.schedule_outlined),
            title: Text('終了  ${_hm(end)}${Dates.sameDay(start, end) ? '' : '（翌日）'}'), onTap: () => pickTime(false)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('キャンセル')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('決定')),
        ],
      );
    }));

    if (ok == true && mounted) {
      setState(() {
        final t = titleCtl.text.trim();
        c.event = c.event.copyWith(title: t.isEmpty ? c.event.title : t, start: start, end: end,
          allDay: timeChanged ? false : c.event.allDay);
        c.uncertainty = null;
        c.selected = true;
        _recheck(c);
      });
    }
  }

  void _showNote(ExtractedEventCandidate c) => showDialog<void>(context: context, builder: (ctx) => AlertDialog(
    title: Text('確認してください'), content: Text(c.uncertainty ?? ''),
    actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text('閉じる'))]));

  // ---------- 保存 ----------
  void _save() {
    if (totalCount == 0) return;
    final app = AppScope.of(context);
    final added = <ExtractedEventCandidate>[];
    var changed = 0;
    for (final c in items.where((c) => c.selected)) {
      final ch = checks[c.id];
      final old = ch?.old;
      if (ch != null && ch.kind != _Kind.added && old != null) {
        // 前の予定を書き換える（2つにしない）
        app.saveEvent(old.copyWith(
          title: c.event.title, start: c.event.start, end: c.event.end, allDay: c.event.allDay, confirmed: true,
          location: c.event.location.isEmpty ? old.location : c.event.location,
          history: [...old.history, '${Dates.short(DateTime.now())} 読み取りで時間を変更（前：${_range(old)}）']));
        changed++;
      } else {
        added.add(c);
      }
    }
    if (added.isNotEmpty) app.saveCandidates(added);
    for (final id in removeIds) { app.deleteEvent(id); }
    final parts = [
      if (added.isNotEmpty) '${added.length}件を追加',
      if (changed > 0) '$changed件を変更',
      if (removeIds.isNotEmpty) '${removeIds.length}件を削除',
    ];
    showDemoMessage(context, '${parts.join('・')}しました。カレンダーのタブで確認できます');
    app.setTab(1);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  // ---------- 画面 ----------
  Widget _card(ExtractedEventCandidate c) {
    final p = AppPalette.of(context);
    final e = c.event;
    final ch = checks[c.id];
    return Padding(padding: EdgeInsets.only(bottom: 12), child: Opacity(opacity: c.selected ? 1 : .55, child: Material(
      color: p.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: c.selected ? p.navy : p.line, width: c.selected ? 1.5 : 1)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: () => _edit(c), child: Padding(padding: EdgeInsets.fromLTRB(4, 12, 4, 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Checkbox(value: c.selected, shape: CircleBorder(), activeColor: p.navy,
            onChanged: (v) => setState(() => c.selected = v ?? false)),
          Container(width: 64, padding: EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(color: e.category.background(context), borderRadius: BorderRadius.circular(14)),
            child: Column(children: [
              Text('${e.start.month}/${e.start.day}', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: p.navy)),
              SizedBox(height: 2),
              Text(e.allDay ? '終日' : _hm(e.start), style: TextStyle(fontSize: 12, color: p.muted)),
            ])),
          SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _statusChip(ch),
            SizedBox(height: 6),
            Text(e.title, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, height: 1.35)),
            if (!e.allDay) Padding(padding: EdgeInsets.only(top: 4),
              child: Text('〜 ${_hm(e.end)}${Dates.sameDay(e.start, e.end) ? '' : '（翌日）'}',
                style: TextStyle(color: p.muted, fontSize: 13))),
            if (ch?.kind == _Kind.changed && ch?.old != null) Padding(padding: EdgeInsets.only(top: 4),
              child: Text('前：${_range(ch!.old!)}', style: TextStyle(color: p.muted, fontSize: 12,
                decoration: TextDecoration.lineThrough))),
            if (ch?.kind == _Kind.duplicate) Padding(padding: EdgeInsets.only(top: 4),
              child: Text('同じ予定が、すでに保存されています', style: TextStyle(color: p.muted, fontSize: 12))),
            if (e.location.isNotEmpty) Padding(padding: EdgeInsets.only(top: 4), child: Row(children: [
              AppIcon(Icons.place_outlined, size: 15, color: p.muted), SizedBox(width: 4),
              Expanded(child: Text(e.location, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: p.muted, fontSize: 12))),
            ])),
            for (final o in (ch?.overlaps ?? const <ScheduleEvent>[]).take(2)) Padding(padding: EdgeInsets.only(top: 4),
              child: Text('⚠ 「${o.title}」（${_range(o)}）と時間が重なっています',
                style: TextStyle(color: p.danger, fontSize: 11, height: 1.5))),
            SizedBox(height: 8),
            Row(children: [CategoryBadge(e.category), SizedBox(width: 6), AppIcon(Icons.edit_outlined, size: 16, color: p.muted)]),
          ])),
          Column(children: [
            if (c.uncertainty != null) IconButton(tooltip: '確認が必要', onPressed: () => _showNote(c),
              icon: AppIcon(Icons.warning_amber_rounded, color: const Color(0xFFF59E0B))),
            IconButton(tooltip: '削除', onPressed: () => setState(() => items.remove(c)),
              icon: AppIcon(Icons.delete_outline_rounded, color: p.danger)),
          ]),
        ]))))));
  }

  Widget _empty(BuildContext context) {
    final p = AppPalette.of(context);
    return Center(child: Padding(padding: EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [
      AppIcon(Icons.search_off_rounded, size: 56, color: p.muted),
      SizedBox(height: 14),
      Text('予定が見つかりませんでした', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
      SizedBox(height: 8),
      Text(widget.keywordLabel.isEmpty
          ? '日付や時間が写っているか、文章の書き方を確認してください'
          : '「${widget.keywordLabel}」の予定が見つかりませんでした。名前の書き方（カタカナ・ローマ字）を確認してください',
        textAlign: TextAlign.center, style: TextStyle(color: p.muted, fontSize: 12, height: 1.6)),
      SizedBox(height: 18),
      PrimaryButton(label: '戻って修正する', secondary: true, onPressed: () => Navigator.pop(context)),
    ])));
  }

  @override Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final nNew = items.where((c) => checks[c.id]?.kind == _Kind.added).length;
    final nChanged = items.where((c) => checks[c.id]?.kind == _Kind.changed).length;
    final nDup = items.where((c) => checks[c.id]?.kind == _Kind.duplicate).length;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(tooltip: '閉じる', onPressed: () => Navigator.pop(context), icon: AppIcon(Icons.close_rounded)),
        title: Text('イベント一覧（${items.length}件）')),
      body: SafeArea(child: items.isEmpty ? _empty(context) : ListView(padding: EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
        Row(children: [
          Expanded(child: Text('解析結果', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18))),
          TextButton(onPressed: () => setState(() { for (final c in items) { c.selected = false; } }), child: Text('全解除')),
          TextButton(onPressed: () => setState(() { for (final c in items) { c.selected = true; } }), child: Text('全選択')),
        ]),
        Text('新規 $nNew件・時間の変更 $nChanged件・登録済み $nDup件',
          style: TextStyle(color: p.navy, fontSize: 13, fontWeight: FontWeight.w600)),
        if (widget.keywordLabel.isNotEmpty) Padding(padding: EdgeInsets.only(top: 4),
          child: Text('${widget.sourceLabel}から、「${widget.keywordLabel}」の予定だけを表示しています',
            style: TextStyle(color: p.sage, fontSize: 12))),
        SizedBox(height: 12),
        for (final c in items) _card(c),
        if (missing.isNotEmpty) ...[
          SizedBox(height: 8),
          Text('今回の表にない予定（なくなった可能性があります）', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          SizedBox(height: 4),
          Text('前に保存したシフトのうち、今回読み取った期間にあるのに、見つからなかったものです。'
            '休みになった場合は、「削除する」にチェックを入れてください。',
            style: TextStyle(color: p.muted, fontSize: 12, height: 1.6)),
          SizedBox(height: 6),
          for (final x in missing) CheckboxListTile(
            value: removeIds.contains(x.id),
            onChanged: (v) => setState(() { if (v == true) { removeIds.add(x.id); } else { removeIds.remove(x.id); } }),
            controlAffinity: ListTileControlAffinity.leading, contentPadding: EdgeInsets.zero, activeColor: p.danger,
            title: Text('${x.start.month}/${x.start.day}  ${x.title}', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            subtitle: Text('${_range(x)}　削除する', style: TextStyle(fontSize: 12))),
          SizedBox(height: 8),
        ],
        Text('項目をタップして修正。ゴミ箱で、一覧から外せます。\nチェックした項目だけが、保存の対象になります。',
          style: TextStyle(color: p.muted, fontSize: 12, height: 1.6)),
      ])),
      bottomNavigationBar: items.isEmpty ? null : SafeArea(child: Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(children: [
          Expanded(child: _BottomButton(title: 'スマホのカレンダー', subtitle: '準備中（Android版で対応）', filled: false, onPressed: null)),
          SizedBox(width: 12),
          Expanded(child: _BottomButton(title: 'アプリに保存', subtitle: '$totalCount件を反映', filled: true,
            onPressed: totalCount == 0 ? null : _save)),
        ]))),
    );
  }
}

class _BottomButton extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool filled;
  final VoidCallback? onPressed;
  const _BottomButton({required this.title, required this.subtitle, required this.filled, required this.onPressed});
  @override Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final child = Column(mainAxisSize: MainAxisSize.min, children: [
      Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
      SizedBox(height: 2),
      Text(subtitle, style: TextStyle(fontSize: 11)),
    ]);
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));
    return SizedBox(height: 62, child: filled
      ? FilledButton(onPressed: onPressed, style: FilledButton.styleFrom(backgroundColor: p.butter, foregroundColor: p.navy,
          shape: shape, side: BorderSide(color: p.navy)), child: child)
      : OutlinedButton(onPressed: onPressed, style: OutlinedButton.styleFrom(foregroundColor: p.navy,
          shape: shape, side: BorderSide(color: p.line)), child: child));
  }
}