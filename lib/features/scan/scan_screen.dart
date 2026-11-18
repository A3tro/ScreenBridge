import 'package:flutter/material.dart';
import '../../core/i18n/lang.dart';
import '../../core/widgets/app_icon.dart';
import '../../core/widgets/orbit_loader.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui.dart';
import '../../data/app_controller.dart';
import 'ai_event_reader.dart';
import 'scan_prepare_screen.dart';

class ScanScreen extends StatefulWidget {
  ScanScreen({super.key});
  @override State<ScanScreen> createState() => _ScanScreenState();
}
class _ScanScreenState extends State<ScanScreen> {
  bool cameraBusy = false; // カメラを開いている間
  bool libraryBusy = false; // ライブラリを開いている間
  bool get busy => cameraBusy || libraryBusy;

  Future<void> _photos({required bool camera}) async {
    setState(() { if (camera) { cameraBusy = true; } else { libraryBusy = true; } });
    final pages = await pickPages(context, camera: camera);
    if (!mounted) return;
    setState(() { cameraBusy = false; libraryBusy = false; });
    if (pages.isNotEmpty) _open(pages: pages);
  }

  Future<void> _paste() async {
    final text = await showPasteDialog(context);
    if (text == null || text.trim().isEmpty || !mounted) return;
    _open(text: text);
  }

  void _open({List<ScanPage> pages = const [], String text = ''}) => Navigator.push(context,
    MaterialPageRoute(builder: (_) => ScanPrepareScreen(initialPages: pages, initialText: text)));

  @override Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = AppPalette.of(context);
    return Scaffold(body: SafeArea(child: ListView(padding: EdgeInsets.fromLTRB(24, 0, 24, 28), children: [
      ScreenHeader(title: tr('読み取り', 'Scan'), subtitle: tr('シフト表や案内をスキャンして、予定に', 'Turn shift tables and notices into events')),
      Illustration('scan_import', height: 190),
      SizedBox(height: 10),
      Center(child: Text(tr('写真や文章から、自分の予定だけを取り出します', 'Pick out only your own events from a photo or text'),
        textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
      SizedBox(height: 22),
      _CameraButton(busy: cameraBusy, onPressed: busy ? null : () => _photos(camera: true)),
      SizedBox(height: 12),
      Row(children: [
        Expanded(child: _Tile(icon: Icons.photo_library_outlined, label: tr('ライブラリ', 'Library'),
          onTap: busy ? null : () => _photos(camera: false))),
        SizedBox(width: 12),
        Expanded(child: _Tile(icon: Icons.text_snippet_outlined, label: tr('文章を貼り付け', 'Paste text'), onTap: busy ? null : _paste)),
      ]),
      SizedBox(height: 18),
      SurfaceCard(color: p.mint, child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AppIcon(Icons.shield_outlined, color: p.sage, size: 22), SizedBox(width: 11),
        Expanded(child: Text(tr('プライバシー：写真は、読み取りのためにGoogleのAI（Gemini）へ送ります。アプリには保存しません。'
            '文章は、まずこの端末の中で読み取り、読めなかったときだけAIで読み取ります。',
            'Privacy: photos are sent to Google’s AI (Gemini) only to read them, and are not stored in the app. '
            'Text is read on your device first, and sent to the AI only if it cannot be read.'),
          style: TextStyle(fontSize: 12, height: 1.55))),
      ])),
      SizedBox(height: 26),
      SectionLabel(title: tr('最近の取り込み', 'Recent imports')), SizedBox(height: 12),
      for (final record in app.imports) Padding(padding: EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Container(height: 42, width: 42, decoration: BoxDecoration(color: p.lavender, borderRadius: BorderRadius.circular(13)),
            child: AppIcon(Icons.description_outlined, size: 21)), SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_sourceName(record.title), maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
            Text('${dateLabel(record.createdAt)} ・ ${tr('${record.count}件', '${record.count} ${record.count == 1 ? 'event' : 'events'}')}',
              style: TextStyle(color: p.muted, fontSize: 11)),
          ])),
          if (!app.isSignedIn) DemoPill(text: tr('サンプル', 'Sample')),
        ])),
      if (app.imports.isEmpty) Text(tr('まだ取り込みはありません', 'No imports yet'), style: TextStyle(color: p.muted, fontSize: 12)),
    ])));
  }

  /// 取り込みの名前（英語のときは、英語にする）
  String _sourceName(String s) => switch (s) {
    'AIの読み取り' => tr('AIの読み取り', 'AI scan'),
    '貼り付けた文章' => tr('貼り付けた文章', 'Pasted text'),
    _ => s,
  };
}

/// 「カメラでスキャン」のボタン。開いている間は、ログインのボタンと同じく、丸と点が回る
class _CameraButton extends StatelessWidget {
  final bool busy;
  final VoidCallback? onPressed;
  const _CameraButton({required this.busy, required this.onPressed});
  @override Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return SizedBox(width: double.infinity, height: 56, child: FilledButton(
      onPressed: busy ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: p.butter, disabledBackgroundColor: p.butter,
        foregroundColor: p.navy, disabledForegroundColor: p.navy,
        elevation: 0, side: BorderSide(color: p.navy),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
      child: busy
        ? const OrbitLoader(size: 34)
        : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            AppIcon(Icons.photo_camera_outlined, size: 20),
            const SizedBox(width: 8),
            Text(tr('カメラでスキャン', 'Scan with camera'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ]),
    ));
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _Tile({required this.icon, required this.label, required this.onTap});
  @override Widget build(BuildContext context) => SurfaceCard(onTap: onTap, child: SizedBox(height: 72, child: Column(
    mainAxisAlignment: MainAxisAlignment.center, children: [
      AppIcon(icon, size: 26), SizedBox(height: 8),
      Text(label, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
    ])));
}