import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/i18n/lang.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_icon.dart';
import '../../core/widgets/blob_loader.dart';
import '../../core/widgets/ui.dart';
import '../../models/models.dart';
import 'ai_event_reader.dart';
import 'ai_usage.dart';
import 'candidate_review_screen.dart';
import 'keyword_filter.dart';
import 'text_event_parser.dart';

/// カメラかライブラリから、写真を読み込む（ライブラリは複数選べる）
Future<List<ScanPage>> pickPages(BuildContext context, {required bool camera}) async {
  final picker = ImagePicker();
  try {
    final List<XFile> files;
    if (camera) {
      final f = await picker.pickImage(source: ImageSource.camera, maxWidth: 2200, maxHeight: 2200, imageQuality: 85);
      files = f == null ? [] : [f];
    } else {
      files = await picker.pickMultiImage(maxWidth: 2200, maxHeight: 2200, imageQuality: 85);
    }
    final pages = <ScanPage>[];
    for (final f in files) {
      pages.add(ScanPage(await f.readAsBytes(), _mime(f), f.name));
    }
    return pages;
  } catch (_) {
    if (context.mounted) {
      showDemoMessage(context, camera
          ? tr('カメラを使えませんでした。カメラの許可を確認してください', 'Could not use the camera. Please check camera permission.')
          : tr('写真を選べませんでした。写真へのアクセスを確認してください', 'Could not pick photos. Please check photo access.'));
    }
    return [];
  }
}

String _mime(XFile f) {
  final t = f.mimeType;
  if (t != null && t.startsWith('image/')) return t;
  final n = f.name.toLowerCase();
  if (n.endsWith('.png')) return 'image/png';
  if (n.endsWith('.webp')) return 'image/webp';
  if (n.endsWith('.heic')) return 'image/heic';
  if (n.endsWith('.heif')) return 'image/heif';
  return 'image/jpeg';
}

/// 文章を貼り付けるダイアログ
Future<String?> showPasteDialog(BuildContext context, {String initial = ''}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(context: context, builder: (dialogContext) => AlertDialog(
    title: Text(tr('シフトや予定の文章を貼り付け', 'Paste your shift or schedule text')),
    content: TextField(controller: controller, maxLines: 8, maxLength: 5000, autofocus: true,
      decoration: InputDecoration(hintText: tr('お店から届いたシフトの文章などを、そのまま貼り付けてください',
        'Paste the shift message from your workplace as it is'))),
    actions: [
      TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(tr('キャンセル', 'Cancel'))),
      TextButton(onPressed: () => Navigator.pop(dialogContext, controller.text), child: Text(tr('決定', 'OK'))),
    ]));
}

class ScanPrepareScreen extends StatefulWidget {
  final List<ScanPage> initialPages;
  final String initialText;
  ScanPrepareScreen({super.key, this.initialPages = const [], this.initialText = ''});
  @override State<ScanPrepareScreen> createState() => _ScanPrepareScreenState();
}

class _ScanPrepareScreenState extends State<ScanPrepareScreen> {
  late final List<ScanPage> pages = [...widget.initialPages];
  late String text = widget.initialText;
  final keyword = TextEditingController(); // 最初は空っぽ（ユーザーが自分で書く）
  final pager = PageController(viewportFraction: .9);
  bool analyzing = false;
  bool touched = false; // 名前の欄を一度でもさわったか（エラーの表示に使う）
  String status = '';
  int? left; // 今日あと何回、写真のAI読み取りが使えるか

  bool get hasKeyword => NameKeywords.split(keyword.text).isNotEmpty;

  @override void initState() {
    super.initState();
    keyword.addListener(() { if (mounted) setState(() {}); }); // 入力に合わせて、ボタンを押せるようにする
    _loadLeft();
  }

  @override void dispose() { keyword.dispose(); pager.dispose(); super.dispose(); }

  Future<void> _loadLeft() async {
    if (!AiUsage.signedIn) { if (mounted) setState(() => left = 0); return; }
    try {
      final n = await AiUsage.remaining();
      if (mounted) setState(() => left = n);
    } catch (_) {
      if (mounted) setState(() => left = null);
    }
  }

  void _info(String title, String body) => showDialog<void>(context: context, builder: (ctx) => AlertDialog(
    title: Text(title), content: Text(body),
    actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('閉じる', 'Close')))]));

  /// AIを使ってよいか確かめる。だめなら理由を表示して false
  Future<bool> _canUseAi() async {
    final limit = AiUsage.dailyLimit;
    if (!AiUsage.signedIn) {
      _info(tr('ログインが必要です', 'Sign-in required'),
        tr('写真のAI読み取りは、ログインすると使えます（1日$limit回まで）。\n文章の貼り付けは、ログインしなくても使えます。',
          'AI photo scans are available after you sign in ($limit per day).\nPasting text works without signing in.'));
      return false;
    }
    try {
      final n = await AiUsage.remaining();
      if (mounted) setState(() => left = n);
      if (n <= 0) {
        _info(tr('今日の回数を使い切りました', 'You have used today’s scans'),
          tr('AIでの読み取りは、1日$limit回までです。\n明日の朝9時に回数が戻るので、また使ってください。\n文章の貼り付けは、回数に関係なく使えます。',
            'AI scans are limited to $limit per day.\nYour scans reset at 9:00 AM (JST) tomorrow.\nPasting text works without a limit.'));
        return false;
      }
      return true;
    } catch (_) {
      _info(tr('回数を確認できませんでした', 'Could not check your scans'),
        tr('通信を確認して、もう一度お試しください。', 'Please check your connection and try again.'));
      return false;
    }
  }

  Future<void> _addPage() async {
    final camera = await showModalBottomSheet<bool>(context: context, builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: AppIcon(Icons.photo_camera_outlined), title: Text(tr('カメラで撮る', 'Take a photo')),
          onTap: () => Navigator.pop(ctx, true)),
        ListTile(leading: AppIcon(Icons.photo_library_outlined), title: Text(tr('ライブラリから選ぶ', 'Choose from library')),
          onTap: () => Navigator.pop(ctx, false)),
      ])));
    if (camera == null || !mounted) return;
    final added = await pickPages(context, camera: camera);
    if (added.isNotEmpty && mounted) setState(() => pages.addAll(added));
  }

  Future<void> _editText() async {
    final t = await showPasteDialog(context, initial: text);
    if (t != null && mounted) setState(() => text = t);
  }

  void _nameShift(List<ExtractedEventCandidate> list, List<String> keys) {
    if (keys.isEmpty) return;
    for (final c in list) {
      if (c.event.title == c.event.category.label) {
        c.event = c.event.copyWith(title: tr('シフト', 'Shift'), category: EventCategory.work);
      }
    }
  }

  void _openResult(List<ExtractedEventCandidate> list, String source, List<String> keys) =>
    Navigator.push(context, MaterialPageRoute(builder: (_) => CandidateReviewScreen(
      candidates: list, sourceLabel: source, keywordLabel: keys.join('、'))));

  Future<void> _analyze() async {
    if (pages.isEmpty && text.trim().isEmpty) return;
    final keys = NameKeywords.split(keyword.text);
    if (keys.isEmpty) { setState(() => touched = true); return; } // 名前が必須
    FocusScope.of(context).unfocus();
    final source = pages.isEmpty ? tr('貼り付けた文章', 'Pasted text') : tr('写真', 'Photo');

    // 文章だけのときは、まず端末の中で読む（AIを使わないので、回数に数えない）
    if (pages.isEmpty) {
      final local = TextEventParser.parse(NameKeywords.filterLines(text, keys));
      _nameShift(local, keys);
      if (local.isNotEmpty) { _openResult(local, source, keys); return; }
    }

    // ここから、AIを使う（1日の回数を確認する）
    if (!await _canUseAi() || !mounted) return;
    setState(() {
      analyzing = true;
      status = pages.isEmpty ? tr('AIで文章を読み取り中…', 'Reading the text with AI…')
          : pages.length > 1 ? tr('${pages.length}枚の写真を、まとめて読み取り中…', 'Reading ${pages.length} photos together…')
          : tr('写真を読み取り中…', 'Reading the photo…');
    });
    try {
      final list = await AiEventReader.read(pages: pages, text: text, keywords: keys);
      try { await AiUsage.addOne(); } catch (_) {} // 使った回数を記録
      await _loadLeft();
      if (!mounted) return;
      setState(() => analyzing = false);
      _openResult(list, source, keys);
    } catch (e) {
      if (!mounted) return;
      setState(() => analyzing = false);
      showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: Text(tr('読み取れませんでした', 'Could not read it')),
        content: SingleChildScrollView(child: Text(AiEventReader.errorMessage(e))),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('閉じる', 'Close')))]));
    }
  }

  @override Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final limit = AiUsage.dailyLimit;
    final canAnalyze = (pages.isNotEmpty || text.trim().isNotEmpty) && hasKeyword && !analyzing;
    final showKeywordError = touched && !hasKeyword;
    final usageText = !AiUsage.signedIn
        ? tr('写真のAI読み取りは、ログインすると使えます（1日$limit回まで）', 'AI photo scans are available after you sign in ($limit per day)')
        : left == null ? tr('写真のAI読み取り：今日の残りの回数を確認できませんでした', 'AI photo scans: could not check today’s remaining scans')
        : tr('写真のAI読み取り：今日はあと$left回（1日$limit回まで・毎朝9時に戻ります）',
            'AI photo scans: $left left today ($limit per day, resets at 9:00 AM JST)');
    return Scaffold(
      appBar: AppBar(leading: const AppBackButton(), title: Text(tr('読み取りの準備', 'Prepare scan')), actions: [
        TextButton.icon(onPressed: analyzing ? null : _addPage, icon: AppIcon(Icons.add_box_outlined), label: Text(tr('ページ追加', 'Add page'))),
      ]),
      body: Stack(children: [
        ListView(padding: EdgeInsets.fromLTRB(20, 8, 20, 30), children: [
          if (pages.isNotEmpty) ...[
            SizedBox(height: 340, child: PageView.builder(controller: pager, itemCount: pages.length,
              itemBuilder: (_, i) => Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Stack(children: [
                Positioned.fill(child: ClipRRect(borderRadius: BorderRadius.circular(18),
                  child: Container(color: p.surface, child: Image.memory(pages[i].bytes, fit: BoxFit.contain)))),
                Positioned(top: 8, right: 8, child: IconButton.filledTonal(tooltip: tr('このページを外す', 'Remove this page'),
                  onPressed: analyzing ? null : () => setState(() => pages.removeAt(i)), icon: AppIcon(Icons.close_rounded))),
                Positioned(left: 12, bottom: 10, child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                  child: Text('${i + 1} / ${pages.length}', style: TextStyle(color: Colors.white, fontSize: 12)))),
              ])))),
            SizedBox(height: 8),
            Text(tr('写真が複数あるときは、まとめて1つの資料として読み取ります（1回と数えます）',
              'Multiple photos are read together as one document (counts as 1 scan)'),
              textAlign: TextAlign.center, style: TextStyle(color: p.muted, fontSize: 12)),
            SizedBox(height: 14),
          ],
          SurfaceCard(onTap: analyzing ? null : _editText, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              AppIcon(Icons.text_snippet_outlined, size: 20), SizedBox(width: 8),
              Expanded(child: Text(pages.isEmpty ? tr('貼り付けた文章', 'Pasted text') : tr('補足の文章（任意）', 'Extra notes (optional)'),
                style: TextStyle(fontWeight: FontWeight.w700))),
              AppIcon(Icons.edit_outlined, size: 18, color: p.muted),
            ]),
            SizedBox(height: 8),
            Text(text.trim().isEmpty ? tr('タップして入力', 'Tap to enter') : text, maxLines: 8, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, height: 1.5, color: text.trim().isEmpty ? p.muted : null)),
          ])),
          SizedBox(height: 20),
          Row(children: [
            AppIcon(Icons.person_search_outlined, size: 20, color: p.navy), SizedBox(width: 6),
            Text(tr('あなたの名前', 'Your name'), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            SizedBox(width: 6),
            Container(padding: EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(color: p.danger, borderRadius: BorderRadius.circular(6)),
              child: Text(tr('必須', 'Required'), style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700))),
          ]),
          SizedBox(height: 8),
          TextField(controller: keyword, enabled: !analyzing,
            onChanged: (_) { if (!touched) setState(() => touched = true); },
            decoration: InputDecoration(
              hintText: tr('例：山田 太郎, ヤマダ', 'e.g. Taro Yamada, Yamada'),
              errorText: showKeywordError ? tr('自分の名前を入力してください', 'Please enter your name') : null)),
          SizedBox(height: 6),
          Text(tr('シフト表に書かれている自分の名前を入れると、あなたの予定だけを読み取ります。書き方が複数あるときは、カンマで区切ります。',
            'Enter your name as written on the shift table to read only your events. Separate different spellings with commas.'),
            style: TextStyle(color: p.muted, fontSize: 12, height: 1.6)),
          SizedBox(height: 18),
          SurfaceCard(color: p.mint, padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(children: [
              AppIcon(Icons.auto_awesome_rounded, size: 18, color: p.sage), SizedBox(width: 8),
              Expanded(child: Text(usageText, style: TextStyle(fontSize: 12, height: 1.5))),
            ])),
          SizedBox(height: 14),
          PrimaryButton(label: tr('イベントを解析する', 'Analyze events'), icon: Icons.auto_awesome_rounded,
            onPressed: canAnalyze ? _analyze : null),
          if (!hasKeyword) Padding(padding: EdgeInsets.only(top: 8),
            child: Text(tr('名前を入れると、押せるようになります', 'Enter your name to continue'),
              textAlign: TextAlign.center, style: TextStyle(color: p.muted, fontSize: 11))),
          SizedBox(height: 10),
          Text(tr('※ 地図や詳細が別の紙のときも、「ページ追加」でまとめて読み取れます',
            '※ If a map or details are on another page, add it with “Add page”'),
            textAlign: TextAlign.center, style: TextStyle(color: p.muted, fontSize: 11)),
        ]),
        // 読み取り中（光る玉）
        if (analyzing) Positioned.fill(child: Container(color: p.ivory.withValues(alpha: .92), child: Center(child: Column(
          mainAxisSize: MainAxisSize.min, children: [
            const BlobLoader(size: 160),
            SizedBox(height: 20),
            Text(status, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            SizedBox(height: 6),
            Text(tr('少しお待ちください', 'Please wait a moment'), style: TextStyle(color: p.muted, fontSize: 12)),
          ])))),
      ]),
    );
  }
}