import 'package:flutter/material.dart';
import '../../core/widgets/app_icon.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui.dart';
import 'review_screen.dart';

class AnalysisScreen extends StatefulWidget {
  final String sourceDescription;
  AnalysisScreen({super.key, required this.sourceDescription});
  @override State<AnalysisScreen> createState() => _AnalysisScreenState();
}
class _AnalysisScreenState extends State<AnalysisScreen> with SingleTickerProviderStateMixin {
  late final AnimationController animation;
  int stage = 0;
  @override void initState() {
    super.initState();
    animation = AnimationController(vsync: this, duration: Duration(milliseconds: 1000));
    _runDemo();
  }
  @override void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) { animation.stop(); animation.value = 1; }
    else { animation.repeat(reverse: true); }
  }
  Future<void> _runDemo() async {
    for (var i = 1; i <= 3; i++) {
      await Future<void>.delayed(Duration(milliseconds: 320));
      if (!mounted) return;
      setState(() => stage = i);
    }
    if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ReviewScreen()));
  }
  @override void dispose() { animation.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(leading: const AppBackButton(), title: Text('サンプル分析')),
    body: SafeArea(child: Padding(padding: EdgeInsets.fromLTRB(30, 24, 30, 35),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        DemoPill(text: 'Gemini未接続 ・ 模擬結果'),
        Spacer(),
        FadeTransition(opacity: Tween<double>(begin: 0.65, end: 1).animate(animation),
          child: Illustration('analysis', height: 225)),
        SizedBox(height: 24),
        Text('予定候補を準備しています', style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
        SizedBox(height: 8),
        Text('これは実際の画像・文章解析ではありません。\n固定のサンプル候補を表示します。',
          textAlign: TextAlign.center, style: TextStyle(color: AppPalette.of(context).muted, fontSize: 12, height: 1.6)),
        SizedBox(height: 30),
        ...['入力をプレビューしています', 'サンプルの予定を整理しています', '確認が必要な項目を表示します']
          .asMap().entries.map((entry) => Padding(padding: EdgeInsets.symmetric(vertical: 7), child: Row(children: [
            AppIcon(entry.key < stage ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              size: 19, color: entry.key < stage ? AppPalette.of(context).sage : AppPalette.of(context).muted),
            SizedBox(width: 13),
            Text(entry.value, style: TextStyle(fontSize: 13)),
          ]))),
        Spacer(),
        LinearProgressIndicator(backgroundColor: AppPalette.of(context).line, color: AppPalette.of(context).sage, minHeight: 4),
      ]))));
}
