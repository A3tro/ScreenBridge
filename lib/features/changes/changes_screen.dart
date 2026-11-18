import 'package:flutter/material.dart';
import '../../core/widgets/app_icon.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/ui.dart';
import '../../data/app_controller.dart';
import '../../models/models.dart';
import '../events/event_editor.dart';

class ChangesScreen extends StatelessWidget {
  ChangesScreen({super.key});
  @override Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final pending = app.changes.where((c) => !c.resolved).toList();
    final resolved = app.changes.where((c) => c.resolved).toList();
    return Scaffold(appBar: AppBar(leading: const AppBackButton(), title: Text('変更・重複の確認')),
      body: SafeArea(child: ListView(padding: EdgeInsets.fromLTRB(23, 8, 23, 35), children: [
        DemoPill(text: '変更検知はサンプルデータです'), SizedBox(height: 13),
        Text('登録前の確認が大切です', style: Theme.of(context).textTheme.headlineSmall),
        SizedBox(height: 7),
        Text('変更・重複・時間の重なりなどを見比べ、あなたが最終的に判断します。',
          style: TextStyle(fontSize: 12, color: AppPalette.of(context).muted, height: 1.55)),
        SizedBox(height: 21),
        if (pending.isEmpty) SurfaceCard(color: AppPalette.of(context).mint, child: Column(children: [
          AppIcon(Icons.check_circle_outline_rounded, color: AppPalette.of(context).sage, size: 40),
          SizedBox(height: 10), Text('すべての候補を確認しました'),
        ])),
        for (final c in pending) _changeCard(context, app, c),
        if (resolved.isNotEmpty) ...[
          SizedBox(height: 17), SectionLabel(title: '確認済み'), SizedBox(height: 7),
          for (final c in resolved) Padding(padding: EdgeInsets.symmetric(vertical: 5),
            child: Row(children: [AppIcon(Icons.check_circle_rounded, color: AppPalette.of(context).sage, size: 17),
              SizedBox(width: 7), Expanded(child: Text(c.message,
                style: TextStyle(fontSize: 11, color: AppPalette.of(context).muted)))])),
        ],
      ])));
  }
  Widget _changeCard(BuildContext context, AppController app, ScheduleChange c) {
    final event = app.eventById(c.eventId);
    final label = switch (c.kind) {
      ChangeKind.modified => '時間の変更', ChangeKind.duplicate => '重複の可能性',
      ChangeKind.overlap => '時間の重なり', ChangeKind.cancellation => '取り消しの可能性',
      ChangeKind.missingDate => '日付が不明', ChangeKind.uncertain => '不確かな変更',
    };
    return Padding(padding: EdgeInsets.only(bottom: 14), child: SurfaceCard(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [AppIcon(Icons.report_gmailerrorred_rounded, color: AppPalette.of(context).danger, size: 20),
        SizedBox(width: 8), Expanded(child: Text(label,
          style: TextStyle(color: AppPalette.of(context).danger, fontSize: 12, fontWeight: FontWeight.w800))),
        DemoPill(text: '要確認')]),
      SizedBox(height: 15),
      Text(event?.title ?? '対象の予定が見つかりません', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      SizedBox(height: 9),
      if (event != null) ...[
        Container(width: double.infinity, padding: EdgeInsets.all(13),
          decoration: BoxDecoration(color: AppPalette.of(context).ivory, borderRadius: BorderRadius.circular(12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('元の予定', style: TextStyle(color: AppPalette.of(context).muted, fontSize: 11)), SizedBox(height: 4),
            Text('${Dates.short(event.start)}   ${Dates.range(event.start, event.end)}',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          ])),
        if (c.newStart != null && c.newEnd != null) ...[
          Padding(padding: EdgeInsets.symmetric(vertical: 7), child: Center(child: AppIcon(Icons.arrow_downward_rounded,
            color: AppPalette.of(context).sage, size: 20))),
          Container(width: double.infinity, padding: EdgeInsets.all(13),
            decoration: BoxDecoration(color: AppPalette.of(context).mint, borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('新しい候補', style: TextStyle(color: AppPalette.of(context).sage, fontSize: 11)), SizedBox(height: 4),
              Text('${Dates.short(c.newStart!)}   ${Dates.range(c.newStart!, c.newEnd!)}',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppPalette.of(context).sage)),
            ])),
        ],
      ],
      SizedBox(height: 12),
      Text(c.message, style: TextStyle(fontSize: 12, color: AppPalette.of(context).muted, height: 1.5)),
      SizedBox(height: 14),
      PrimaryButton(label: c.kind == ChangeKind.modified ? '変更を承認' : '内容を確認済みにする',
        onPressed: event == null ? null : () => _resolve(context, app, c, accept: true)),
      SizedBox(height: 8),
      PrimaryButton(label: '元の予定を維持', secondary: true,
        onPressed: () => _resolve(context, app, c, accept: false)),
      if (event != null) Align(alignment: Alignment.center, child: TextButton(onPressed: () => Navigator.push(context,
        MaterialPageRoute(builder: (_) => EventEditor(event: event))),
        child: Text('手動で編集する', style: TextStyle(color: AppPalette.of(context).sage)))),
    ])));
  }
  void _resolve(BuildContext context, AppController app, ScheduleChange c, {required bool accept}) {
    app.resolveChange(c, accept: accept);
    showDemoMessage(context, accept ? '確認済みとして記録しました' : '元の予定を維持しました');
  }
}
