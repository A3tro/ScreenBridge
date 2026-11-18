import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import '../core/i18n/lang.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/status_views.dart';
import '../data/app_controller.dart';
import '../features/auth/password_reset_screens.dart';
import '../features/home/main_shell.dart';
import '../features/onboarding/welcome.dart';

/// 日本語の文字は、アプリに入れた Noto Sans JP で表示する（「□」にならないように）
ThemeData _withJapaneseFont(ThemeData t) => t.copyWith(
  textTheme: t.textTheme.apply(fontFamilyFallback: const ['NotoSansJP']),
  primaryTextTheme: t.primaryTextTheme.apply(fontFamilyFallback: const ['NotoSansJP']),
);

class ScreenBridgeApp extends StatefulWidget {
  const ScreenBridgeApp({super.key});
  @override State<ScreenBridgeApp> createState() => _ScreenBridgeAppState();
}
class _ScreenBridgeAppState extends State<ScreenBridgeApp> {
  final AppController controller = AppController();
  @override void initState() { super.initState(); NetStatus.start(); }
  @override void dispose() { controller.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AppScope(
    controller: controller,
    child: AnimatedBuilder(animation: controller, builder: (context, _) => MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ScreenBridge AI',
      theme: _withJapaneseFont(AppTheme.light()),
      darkTheme: _withJapaneseFont(AppTheme.dark()),
      themeMode: controller.darkPreference ? ThemeMode.dark : ThemeMode.light,
      themeAnimationDuration: WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations ? Duration.zero : const Duration(milliseconds: 500),
      locale: Lang.en ? const Locale('en', 'US') : const Locale('ja', 'JP'),
      supportedLocales: const [Locale('ja', 'JP'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => ColoredBox(color: AppPalette.of(context).ivory,
        child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 460),
          child: LayoutBuilder(builder: (context, constraints) => MediaQuery(
            data: MediaQuery.of(context).copyWith(size: Size(constraints.maxWidth, constraints.maxHeight)),
            child: ClipRect(child: OfflineBanner(child: child ?? const SizedBox.shrink()))))))),
      home: const RootGate(),
    )),
  );
}

/// 最初の分岐の画面
/// メールのリンクから開いたら「新しいパスワード」、ログイン中ならホーム、そうでなければ最初の画面
class RootGate extends StatelessWidget {
  const RootGate({super.key});
  @override Widget build(BuildContext context) {
    final resetCode = ResetLink.pending;
    if (resetCode != null) return NewPasswordFromLinkScreen(oobCode: resetCode);
    final app = AppScope.of(context);
    if (!app.authReady) {
      // 読み込み中。つながっていなければ、オフラインの画面
      return ValueListenableBuilder<bool>(valueListenable: NetStatus.online,
        builder: (context, online, _) => online ? const SkeletonScreen() : const OfflineScreen());
    }
    if (app.isSignedIn) Lang.load(app); // 保存してある言語を読み込む
    return app.isSignedIn ? MainShell() : WelcomeScreen();
  }
}