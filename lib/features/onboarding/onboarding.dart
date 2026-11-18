import 'package:flutter/material.dart';
import '../../core/widgets/app_icon.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui.dart';
import '../auth/auth_screens.dart';
import 'animated_bridge.dart';

class OnboardingScreen extends StatefulWidget {
  OnboardingScreen({super.key});
  @override State<OnboardingScreen> createState() => _OnboardingScreenState();
}
class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _page = PageController();
  int index = 0;
  final pages = [
    ('onboarding_scan', 'スクショから\n予定を読み取る', 'シフト表やお知らせを、\nまとめて予定候補として確認。'),
    ('onboarding_changes', '変更や重複を\nチェック', '時間の変更や重なりを見つけて、\n登録する前にお知らせ。'),
    ('onboarding_calendar', '毎日をもっと\n安心に', '確認した予定を、\n見やすいカレンダーでひとつに。'),
  ];
  @override void dispose() { _page.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => Scaffold(body: SafeArea(child: Padding(
    padding: EdgeInsets.fromLTRB(27, 16, 27, 22), child: Column(children: [
      Row(children: [
        IconButton(icon: AppIcon(Icons.arrow_back_rounded), onPressed: () {
          if (index == 0) { Navigator.pop(context); } else { _page.previousPage(duration: Duration(milliseconds: 260), curve: Curves.easeInOut); }
        }),
        Spacer(),
        TextButton(onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => RegisterScreen())),
          child: Text('スキップ', style: TextStyle(color: AppPalette.of(context).muted))),
      ]),
      Expanded(child: PageView.builder(controller: _page, itemCount: pages.length,
        onPageChanged: (i) => setState(() => index = i), itemBuilder: (context, i) =>
          SingleChildScrollView(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            AnimatedBridge(stage: i),
            SizedBox(height: 30),
            Text(pages[i].$2, style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.center),
            SizedBox(height: 17),
            Text(pages[i].$3, style: TextStyle(color: AppPalette.of(context).muted, fontSize: 14, height: 1.7), textAlign: TextAlign.center),
          ])))),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(pages.length, (i) => AnimatedContainer(
        duration: Duration(milliseconds: 260), width: index == i ? 28 : 7, height: 7,
        margin: EdgeInsets.symmetric(horizontal: 3), decoration: BoxDecoration(
          color: index == i ? AppPalette.of(context).sage : AppPalette.of(context).line, borderRadius: BorderRadius.circular(10))))),
      SizedBox(height: 32),
      PrimaryButton(label: index == pages.length - 1 ? 'はじめる' : '次へ', icon: Icons.arrow_forward_rounded,
        onPressed: () { if (index == pages.length - 1) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => RegisterScreen()));
        } else { _page.nextPage(duration: Duration(milliseconds: 270), curve: Curves.easeInOut); } }),
    ]))));
}
