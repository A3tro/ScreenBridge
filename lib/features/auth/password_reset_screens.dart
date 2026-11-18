import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../app/app.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_icon.dart';
import '../../core/widgets/ui.dart';
import '../../data/app_controller.dart';
import 'auth_screens.dart';

final RegExp _mailPattern = RegExp(r'^[^@ ]+@[^@ ]+\.[^@ ]+$');

/// メールのリンクから開かれたとき、そのリンクの情報（oobCode）を持っておく
class ResetLink {
  ResetLink._();
  static String? _code = _read();
  static String? _read() {
    if (!kIsWeb) return null;
    final q = Uri.base.queryParameters;
    final code = q['oobCode'] ?? '';
    return (q['mode'] == 'resetPassword' && code.isNotEmpty) ? code : null;
  }
  static String? get pending => _code;
  static void clear() => _code = null;
}

/// 丸い背景の上に、大きいアイコンと小さいマークを重ねた絵
class _CircleArt extends StatelessWidget {
  final IconData icon;
  final IconData? badge;
  const _CircleArt({required this.icon, this.badge});
  @override Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Center(child: Container(width: 170, height: 170,
      decoration: BoxDecoration(color: p.butter.withValues(alpha: .45), shape: BoxShape.circle),
      child: Stack(alignment: Alignment.center, children: [
        AppIcon(icon, size: 72, color: p.navy),
        if (badge != null) Positioned(right: 38, bottom: 40, child: Container(
          padding: EdgeInsets.all(3),
          decoration: BoxDecoration(color: p.surface, shape: BoxShape.circle, border: Border.all(color: p.navy, width: 1.5)),
          child: AppIcon(badge, size: 22, color: p.navy))),
      ])));
  }
}

/// ① パスワードをお忘れの方：メールアドレスを入れて、再設定のメールを送る
class ForgotPasswordScreen extends StatefulWidget {
  final String initialEmail;
  const ForgotPasswordScreen({super.key, this.initialEmail = ''});
  @override State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final email = TextEditingController(text: widget.initialEmail);
  bool busy = false;
  String? error;
  @override void dispose() { email.dispose(); super.dispose(); }

  Future<void> _send() async {
    final value = email.text.trim();
    if (!_mailPattern.hasMatch(value)) {
      setState(() => error = '有効なメールアドレスを入力してください');
      return;
    }
    final app = AppScope.of(context);
    setState(() { busy = true; error = null; });
    final err = await app.sendPasswordReset(value); // 登録されていないときは「このメールアドレスは登録されていません」
    if (!mounted) return;
    if (err != null) { setState(() { busy = false; error = err; }); return; }
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ResetEmailSentScreen(email: value)));
  }

  @override Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Scaffold(
      appBar: AppBar(leading: const AppBackButton(), title: Text('パスワードをお忘れの方'), centerTitle: true),
      body: SafeArea(child: ListView(padding: EdgeInsets.fromLTRB(28, 12, 28, 30), children: [
        _CircleArt(icon: Icons.lock_outline_rounded, badge: Icons.question_mark_rounded),
        SizedBox(height: 28),
        Text('登録したメールアドレスを入力してください。\nパスワードを再設定するためのリンクを送ります。',
          textAlign: TextAlign.center, style: TextStyle(fontSize: 13, height: 1.7)),
        SizedBox(height: 26),
        TextField(controller: email, keyboardType: TextInputType.emailAddress, enabled: !busy,
          onSubmitted: (_) => _send(),
          decoration: InputDecoration(labelText: 'メールアドレス', prefixIcon: AppIcon(Icons.mail_outline_rounded))),
        if (error != null) Padding(padding: EdgeInsets.only(top: 10),
          child: Text(error!, style: TextStyle(color: p.danger, fontSize: 13, height: 1.5))),
        SizedBox(height: 30),
        PrimaryButton(label: busy ? '送信中…' : '送信', onPressed: busy ? null : _send),
      ])),
    );
  }
}

/// ② メールを確認してください：届いたリンクを押してもらう
class ResetEmailSentScreen extends StatefulWidget {
  final String email;
  const ResetEmailSentScreen({super.key, required this.email});
  @override State<ResetEmailSentScreen> createState() => _ResetEmailSentScreenState();
}

class _ResetEmailSentScreenState extends State<ResetEmailSentScreen> {
  int wait = 60; // 再送できるまでの秒数
  Timer? timer;
  bool busy = false;
  String? message;
  bool messageIsError = false;

  @override void initState() { super.initState(); _startTimer(); }
  @override void dispose() { timer?.cancel(); super.dispose(); }

  void _startTimer() {
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() { wait--; if (wait <= 0) t.cancel(); });
    });
  }

  Future<void> _resend() async {
    final app = AppScope.of(context);
    setState(() { busy = true; message = null; });
    final err = await app.sendPasswordReset(widget.email);
    if (!mounted) return;
    setState(() {
      busy = false;
      messageIsError = err != null;
      message = err ?? 'もう一度、メールを送りました';
      if (err == null) wait = 60;
    });
    if (err == null) _startTimer();
  }

  @override Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Scaffold(
      appBar: AppBar(leading: const AppBackButton(), title: Text('メールを確認してください'), centerTitle: true),
      body: SafeArea(child: ListView(padding: EdgeInsets.fromLTRB(28, 12, 28, 30), children: [
        _CircleArt(icon: Icons.mark_email_unread_outlined),
        SizedBox(height: 28),
        Text(widget.email, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        SizedBox(height: 8),
        Text('に、パスワード再設定のリンクを送りました。\nメールのリンクを押すと、新しいパスワードを決める画面が開きます。',
          textAlign: TextAlign.center, style: TextStyle(fontSize: 13, height: 1.7)),
        SizedBox(height: 18),
        SurfaceCard(color: p.mint, child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AppIcon(Icons.info_outline_rounded, color: p.sage, size: 20), SizedBox(width: 10),
          Expanded(child: Text('メールが届かないときは、迷惑メールフォルダも確認してください。'
            'Gmailの場合は「迷惑メールではないことを報告」を押すと、次から届きやすくなります。',
            style: TextStyle(fontSize: 12, height: 1.6))),
        ])),
        SizedBox(height: 14),
        Center(child: TextButton(onPressed: (busy || wait > 0) ? null : _resend,
          child: Text(wait > 0 ? 'メールを再送する（$wait秒後）' : 'メールを再送する'))),
        if (message != null) Text(message!, textAlign: TextAlign.center,
          style: TextStyle(color: messageIsError ? p.danger : p.sage, fontSize: 12)),
        SizedBox(height: 22),
        PrimaryButton(label: 'ログイン画面に戻る', onPressed: () => Navigator.pop(context)),
      ])),
    );
  }
}

/// ③ メールのリンクから開く：新しいパスワードを決める
class NewPasswordFromLinkScreen extends StatefulWidget {
  final String oobCode;
  const NewPasswordFromLinkScreen({super.key, required this.oobCode});
  @override State<NewPasswordFromLinkScreen> createState() => _NewPasswordFromLinkScreenState();
}

class _NewPasswordFromLinkScreenState extends State<NewPasswordFromLinkScreen> {
  final password = TextEditingController();
  final confirm = TextEditingController();
  bool checking = true; // リンクを確認中
  bool visible = false;
  bool busy = false;
  bool done = false;
  String? email;
  String? fatal; // リンクが使えないときの文章
  String? error;

  @override void initState() { super.initState(); _check(); }
  @override void dispose() { password.dispose(); confirm.dispose(); super.dispose(); }

  String _message(String code) => switch (code) {
    'expired-action-code' => 'このリンクは、有効期限が切れています。もう一度、パスワードの再設定をやり直してください',
    'invalid-action-code' => 'このリンクは使えません。すでに使ったか、古いリンクです。もう一度、パスワードの再設定をやり直してください',
    'user-disabled' => 'このアカウントは無効になっています',
    'user-not-found' => 'このアカウントは見つかりません',
    'weak-password' => 'パスワードが弱すぎます。もっと長いパスワードにしてください',
    'network-request-failed' => 'ネットワークにつながりません。電波を確認してください',
    _ => 'うまくいきませんでした（$code）',
  };

  Future<void> _check() async {
    try {
      final e = await FirebaseAuth.instance.verifyPasswordResetCode(widget.oobCode);
      if (!mounted) return;
      setState(() { email = e; checking = false; });
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() { fatal = _message(e.code); checking = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { fatal = 'リンクを確認できませんでした。通信を確認してください'; checking = false; });
    }
  }

  Future<void> _save() async {
    if (password.text.length < 8) { setState(() => error = 'パスワードは8文字以上にしてください'); return; }
    if (password.text != confirm.text) { setState(() => error = 'パスワードが一致しません'); return; }
    setState(() { busy = true; error = null; });
    try {
      await FirebaseAuth.instance.confirmPasswordReset(code: widget.oobCode, newPassword: password.text);
      if (!mounted) return;
      setState(() { busy = false; done = true; });
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() { busy = false; error = _message(e.code); });
    } catch (_) {
      if (!mounted) return;
      setState(() { busy = false; error = '保存できませんでした。もう一度お試しください'; });
    }
  }

  /// 最初の画面に戻って、ログイン画面を開く
  void _goLogin() {
    ResetLink.clear();
    final nav = Navigator.of(context);
    nav.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const RootGate()), (route) => false);
    nav.push(MaterialPageRoute(builder: (_) => LoginScreen()));
  }

  @override Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final Widget body;
    if (checking) {
      body = Center(child: CircularProgressIndicator());
    } else if (fatal != null) {
      body = ListView(padding: EdgeInsets.fromLTRB(28, 24, 28, 30), children: [
        _CircleArt(icon: Icons.link_off_rounded),
        SizedBox(height: 28),
        Text(fatal!, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, height: 1.7)),
        SizedBox(height: 30),
        PrimaryButton(label: 'ログイン画面へ', onPressed: _goLogin),
      ]);
    } else if (done) {
      body = ListView(padding: EdgeInsets.fromLTRB(28, 24, 28, 30), children: [
        _CircleArt(icon: Icons.lock_outline_rounded, badge: Icons.check_rounded),
        SizedBox(height: 28),
        Text('新しいパスワードを設定しました', textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        SizedBox(height: 10),
        Text('新しいパスワードで、ログインしてください。', textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, height: 1.7)),
        SizedBox(height: 30),
        PrimaryButton(label: 'ログインへ進む', icon: Icons.arrow_forward_rounded, onPressed: _goLogin),
      ]);
    } else {
      body = ListView(padding: EdgeInsets.fromLTRB(28, 12, 28, 30), children: [
        _CircleArt(icon: Icons.lock_outline_rounded, badge: Icons.check_rounded),
        SizedBox(height: 24),
        if (email != null) Text(email!, textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        SizedBox(height: 8),
        Text('新しいパスワードを決めてください。\n8文字以上で、前と違うパスワードにしてください。',
          textAlign: TextAlign.center, style: TextStyle(fontSize: 13, height: 1.7)),
        SizedBox(height: 24),
        TextField(controller: password, obscureText: !visible, enabled: !busy,
          decoration: InputDecoration(labelText: '新しいパスワード', prefixIcon: AppIcon(Icons.lock_outline_rounded),
            suffixIcon: IconButton(onPressed: () => setState(() => visible = !visible),
              icon: AppIcon(visible ? Icons.visibility_off_outlined : Icons.visibility_outlined)))),
        SizedBox(height: 14),
        TextField(controller: confirm, obscureText: !visible, enabled: !busy, onSubmitted: (_) => _save(),
          decoration: InputDecoration(labelText: 'パスワードの確認', prefixIcon: AppIcon(Icons.verified_user_outlined))),
        if (error != null) Padding(padding: EdgeInsets.only(top: 10),
          child: Text(error!, style: TextStyle(color: p.danger, fontSize: 13, height: 1.5))),
        SizedBox(height: 30),
        PrimaryButton(label: busy ? '保存中…' : '保存', onPressed: busy ? null : _save),
      ]);
    }
    return Scaffold(
      appBar: AppBar(title: Text('新しいパスワード'), centerTitle: true, automaticallyImplyLeading: false),
      body: SafeArea(child: body),
    );
  }
}