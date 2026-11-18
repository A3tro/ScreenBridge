import 'package:flutter/material.dart';
import '../../core/i18n/lang.dart';
import '../../core/widgets/app_icon.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui.dart';
import '../auth/auth_screens.dart';
import '../home/main_shell.dart';
import 'onboarding.dart';
import 'animated_bridge.dart';
import '../settings/theme_screen.dart';

class WelcomeScreen extends StatelessWidget {
  WelcomeScreen({super.key});
  @override Widget build(BuildContext context) => Scaffold(body: SafeArea(child: LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(child: ConstrainedBox(
      constraints: BoxConstraints(minHeight: constraints.maxHeight),
      child: Padding(padding: EdgeInsets.fromLTRB(26, 18, 26, 24), child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [AppIcon(Icons.filter_none, size: 23), SizedBox(width: 9),
            Text('ScreenBridge', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            Spacer(),
            IconButton(tooltip: tr('テーマを選ぶ', 'Choose theme'),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ThemeScreen())),
              icon: const AppIcon(Icons.palette_outlined)),
            Container(padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: AppPalette.of(context).butter, borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppPalette.of(context).navy)),
              child: Text('AI', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)))]),
          Padding(padding: EdgeInsets.symmetric(vertical: 16), child: AnimatedBridge()),
          Column(children: [
            Text('LESS TYPING. MORE LIVING.', style: TextStyle(fontSize: 10, letterSpacing: 2)),
            SizedBox(height: 16),
            Text(tr('スクショを、\nあなたの予定に。', 'From screenshots\nto your schedule.'), textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 32, height: 1.4)),
            SizedBox(height: 14),
            Text(tr('学校のお知らせも、バイトのシフトも。\n読み取って、確認して、カレンダーへ。',
              'School notices and work shifts.\nRead, check, and add them to your calendar.'), textAlign: TextAlign.center,
              style: TextStyle(color: AppPalette.of(context).muted, height: 1.8, fontSize: 13)),
            SizedBox(height: 28),
            PrimaryButton(label: tr('はじめる', 'Get started'), icon: Icons.arrow_forward,
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OnboardingScreen()))),
            SizedBox(height: 8),
            TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LoginScreen())),
              child: Text(tr('アカウントをお持ちの方は ログイン', 'Already have an account? Log in'))),
          ]),
        ])))))));
}

/// （ほかの画面から使われている場合のために残しています）デモの画面を開く
void openDemo(BuildContext context) => Navigator.of(context).pushAndRemoveUntil(
  MaterialPageRoute(builder: (_) => MainShell()), (route) => false);