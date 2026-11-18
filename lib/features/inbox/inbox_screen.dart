import 'package:flutter/material.dart';
import '../../core/i18n/lang.dart';
import '../../core/widgets/app_icon.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/ui.dart';
import '../../data/app_controller.dart';
import '../../models/models.dart';
import '../changes/changes_screen.dart';

/// 受信箱（お知らせ）
class InboxScreen extends StatelessWidget {
  InboxScreen({super.key});
  @override Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = AppPalette.of(context);
    final unread = app.unreadCount;
    return Scaffold(body: SafeArea(child: ListView(padding: EdgeInsets.fromLTRB(24, 0, 24, 30), children: [
      ScreenHeader(
        title: tr('お知らせ', 'Inbox'),
        subtitle: tr('未読 $unread件', '$unread unread'),
        trailing: unread == 0 ? null : TextButton(
          onPressed: () { for (final n in [...app.notifications]) { if (!n.read) app.markRead(n); } },
          child: Text(tr('すべて既読', 'Mark all read'), style: TextStyle(color: p.sage, fontSize: 12, fontWeight: FontWeight.w700)))),
      if (!app.isSignedIn) ...[DemoPill(text: tr('デモのお知らせです', 'Demo notifications')), SizedBox(height: 15)],

      if (app.notifications.isEmpty) SurfaceCard(child: Padding(padding: EdgeInsets.symmetric(vertical: 18), child: Column(children: [
        AppIcon(Icons.notifications_none_rounded, size: 36, color: p.muted),
        SizedBox(height: 10),
        Text(tr('お知らせはありません', 'No notifications'), style: TextStyle(fontWeight: FontWeight.w700)),
        SizedBox(height: 4),
        Text(tr('今日と明日の予定や、まもなく始まる予定を、ここでお知らせします。',
          'Today’s and tomorrow’s events, and events starting soon, will appear here.'),
          textAlign: TextAlign.center, style: TextStyle(color: p.muted, fontSize: 12, height: 1.5)),
      ]))),
      for (final n in app.notifications) _notice(context, app, n),

      SizedBox(height: 16),
      Text(app.isSignedIn
          ? tr('アプリを閉じているときの通知は、Android版で対応予定です。', 'Notifications while the app is closed are coming in the Android version.')
          : tr('デモのお知らせです。ログインすると、あなたの予定からお知らせが届きます。',
              'These are demo notifications. Sign in to get notifications from your own events.'),
        style: TextStyle(fontSize: 11, color: p.muted)),
    ])));
  }

  Widget _notice(BuildContext context, AppController app, NotificationItem n) {
    final p = AppPalette.of(context);
    return Padding(padding: EdgeInsets.symmetric(vertical: 6), child: SurfaceCard(
      color: n.read ? p.surface : p.mint,
      onTap: () {
        app.markRead(n);
        if (n.target == 'changes') Navigator.push(context, MaterialPageRoute(builder: (_) => ChangesScreen()));
        if (n.target == 'calendar') app.setTab(1);
        if (n.target == 'scan') app.setTab(2);
      },
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 42, height: 42, decoration: BoxDecoration(color: p.ivory, borderRadius: BorderRadius.circular(13)),
          child: AppIcon(n.icon, color: p.sage, size: 21)),
        SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(n.title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800))),
            if (!n.read) CircleAvatar(radius: 4, backgroundColor: p.sage),
          ]),
          SizedBox(height: 5),
          Text(n.message, style: TextStyle(color: p.muted, fontSize: 12, height: 1.45)),
          SizedBox(height: 8),
          Text('${dateLabel(n.createdAt)} ${Dates.time(n.createdAt)}',
            style: TextStyle(color: p.sage, fontSize: 10, fontWeight: FontWeight.w600)),
        ])),
      ])));
  }
}