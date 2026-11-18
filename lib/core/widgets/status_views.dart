import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import '../i18n/lang.dart';
import '../theme/app_theme.dart';
import 'app_icon.dart';
import 'blob_loader.dart';

/// インターネットにつながっているか
class NetStatus {
  NetStatus._();
  static final online = ValueNotifier<bool>(true);
  static StreamSubscription<List<ConnectivityResult>>? _sub;

  static void start() {
    if (_sub != null) return;
    recheck();
    _sub = Connectivity().onConnectivityChanged.listen(_update, onError: (Object _) {});
  }

  static Future<void> recheck() async {
    try { _update(await Connectivity().checkConnectivity()); } catch (_) {}
  }

  static void _update(List<ConnectivityResult> r) {
    online.value = !(r.isEmpty || r.every((x) => x == ConnectivityResult.none));
  }
}

/// オフラインのとき、画面の上に帯を出す
class OfflineBanner extends StatelessWidget {
  final Widget child;
  const OfflineBanner({super.key, required this.child});
  @override Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: NetStatus.online,
    builder: (context, online, _) => Column(children: [
      AnimatedSize(duration: const Duration(milliseconds: 250), child: online
        ? const SizedBox(width: double.infinity)
        : Material(color: const Color(0xFF2B2B2B), child: SafeArea(bottom: false, child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(children: [
              const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(tr('オフラインです。つながると、自動で保存されます', 'You are offline. Changes will sync when you reconnect.'),
                style: const TextStyle(color: Colors.white, fontSize: 12))),
            ]))))),
      Expanded(child: MediaQuery.removePadding(context: context, removeTop: !online, child: child)),
    ]),
  );
}

/// 押せる項目（エラーの画面などで使う）
class StatusAction {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const StatusAction({required this.icon, required this.title, required this.subtitle, required this.onTap});
}

/// エラーやオフラインのときの画面（大きい絵、見出し、説明、押せる項目）
class StatusView extends StatelessWidget {
  final IconData icon;
  final String eyebrow;
  final String title;
  final String message;
  final List<StatusAction> actions;
  const StatusView({super.key, required this.icon, required this.eyebrow, required this.title,
    required this.message, this.actions = const []});

  @override Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Center(child: SingleChildScrollView(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(eyebrow, style: TextStyle(color: p.muted, fontSize: 12)),
      const SizedBox(height: 8),
      Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
      const SizedBox(height: 10),
      Text(message, textAlign: TextAlign.center, style: TextStyle(color: p.muted, fontSize: 13, height: 1.6)),
      const SizedBox(height: 26),
      Container(width: 170, height: 170,
        decoration: BoxDecoration(shape: BoxShape.circle,
          gradient: RadialGradient(colors: [p.lavender, p.lavender.withValues(alpha: 0)])),
        child: Center(child: Container(width: 92, height: 92,
          decoration: BoxDecoration(color: p.surface, shape: BoxShape.circle,
            boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 18, offset: Offset(0, 8))]),
          child: Center(child: AppIcon(icon, size: 44, color: p.navy))))),
      const SizedBox(height: 26),
      for (final a in actions) Padding(padding: const EdgeInsets.only(bottom: 10), child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Material(color: p.surface, borderRadius: BorderRadius.circular(16), clipBehavior: Clip.antiAlias,
          child: InkWell(onTap: a.onTap, child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [
            Container(width: 36, height: 36, decoration: BoxDecoration(color: p.ivory, shape: BoxShape.circle),
              child: Center(child: AppIcon(a.icon, size: 18, color: p.navy))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(a.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              Text(a.subtitle, style: TextStyle(fontSize: 11, color: p.muted)),
            ])),
            AppIcon(Icons.chevron_right_rounded, size: 19, color: p.muted),
          ])))))),
    ])));
  }
}

/// オフラインの画面（起動のときに、つながらなかったとき）
class OfflineScreen extends StatelessWidget {
  const OfflineScreen({super.key});
  @override Widget build(BuildContext context) => Scaffold(body: SafeArea(child: StatusView(
    icon: Icons.wifi_off_rounded,
    eyebrow: tr('つながっていないようです…', 'Looks like you are offline…'),
    title: tr('オフラインです', 'You are offline'),
    message: tr('インターネットにつながっていません。Wi-Fiや電波を確認してください。\nつながると、自動で元に戻ります。',
      'No internet connection. Please check your Wi-Fi or signal.\nThe app will continue automatically when you are back online.'),
    actions: [
      StatusAction(icon: Icons.refresh_rounded, title: tr('もう一度試す', 'Try again'),
        subtitle: tr('つながったか、確かめます', 'Check the connection again'), onTap: NetStatus.recheck),
    ],
  )));
}

/// 読み込み中の画面（ふわっと光る玉）
class SkeletonScreen extends StatelessWidget {
  const SkeletonScreen({super.key});
  @override Widget build(BuildContext context) => Scaffold(body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    const BlobLoader(size: 150),
    const SizedBox(height: 18),
    Text(tr('読み込み中…', 'Loading…'), style: TextStyle(color: AppPalette.of(context).muted, fontSize: 13)),
  ])));
}