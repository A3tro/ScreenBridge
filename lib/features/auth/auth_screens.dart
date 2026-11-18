import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../core/i18n/lang.dart';
import '../../core/widgets/app_icon.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui.dart';
import '../../data/app_controller.dart';
import '../legal/legal_screens.dart';
import 'password_reset_screens.dart';
import '../../core/widgets/orbit_loader.dart';

final RegExp _emailPattern = RegExp(r'^[^@ ]+@[^@ ]+\.[^@ ]+$');

/// ログインできたら、最初の画面まで戻る（ログイン中なら、自動でホームになる）
void _backToRoot(BuildContext context) => Navigator.of(context).popUntil((route) => route.isFirst);

/// Googleでログイン。戻り値: (成功したか, 表示するメッセージ。キャンセルのときは null)
Future<(bool, String?)> _signInWithGoogle() async {
  try {
    final provider = GoogleAuthProvider();
    if (kIsWeb) {
      await FirebaseAuth.instance.signInWithPopup(provider);
    } else {
      await FirebaseAuth.instance.signInWithProvider(provider);
    }
    return (true, null);
  } on FirebaseAuthException catch (e) {
    final String? message = switch (e.code) {
      'popup-closed-by-user' || 'cancelled-popup-request' || 'web-context-canceled' || 'canceled' => null,
      'popup-blocked' => tr('ポップアップがブロックされました。許可してから、もう一度お試しください',
        'The pop-up was blocked. Please allow pop-ups and try again.'),
      'account-exists-with-different-credential' => tr('このメールアドレスは、別の方法で登録済みです。その方法でログインしてください',
        'This email is already registered with another sign-in method. Please use that method.'),
      'operation-not-allowed' => tr('Googleでのログインが、まだ有効になっていません', 'Sign in with Google is not set up yet.'),
      'unauthorized-domain' => tr('このアドレスは、Firebaseの承認済みドメインに追加されていません', 'This domain is not authorized in Firebase.'),
      'network-request-failed' => tr('ネットワークにつながりません。電波を確認してください', 'No network connection. Please check your connection.'),
      _ => tr('Googleでログインできませんでした（${e.code}）', 'Could not sign in with Google (${e.code})'),
    };
    return (false, message);
  } catch (_) {
    return (false, tr('Googleでログインできませんでした。もう一度お試しください', 'Could not sign in with Google. Please try again.'));
  }
}

/// Googleの「G」（色つきの文字で表しています。公式のロゴ画像に替えるときは、ここを差し替えます）
class _GoogleG extends StatelessWidget {
  const _GoogleG();
  @override Widget build(BuildContext context) => ShaderMask(
    blendMode: BlendMode.srcIn,
    shaderCallback: (rect) => const SweepGradient(
      colors: [Color(0xFFEA4335), Color(0xFFFBBC05), Color(0xFF34A853), Color(0xFF4285F4), Color(0xFFEA4335)],
      stops: [0.0, 0.25, 0.5, 0.75, 1.0],
    ).createShader(rect),
    child: const Text('G', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900, height: 1)),
  );
}

/// 横に長い「Googleで続ける」ボタン
class _GoogleButton extends StatelessWidget {
  final VoidCallback? onPressed;
  const _GoogleButton({required this.onPressed});
  @override Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return SizedBox(width: double.infinity, height: 56, child: OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: p.surface,
        foregroundColor: p.navy,
        side: BorderSide(color: p.navy, width: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const _GoogleG(),
        const SizedBox(width: 10),
        Text(tr('Googleで続ける', 'Continue with Google'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      ]),
    ));
  }
}

/// 大きいボタン。処理中は、文字の代わりに、くるくる回るマークを出す
class _MainButton extends StatelessWidget {
  final String label;
  final bool busy;
  final VoidCallback? onPressed;
  const _MainButton({required this.label, required this.busy, required this.onPressed});
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
        : Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
    ));
  }
}

// =====================================================================
// ログイン
// =====================================================================
class LoginScreen extends StatefulWidget {
  LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController();
  final password = TextEditingController();
  bool visible = false;
  bool busy = false;
  String? error;
  @override void dispose() { email.dispose(); password.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (!form.currentState!.validate()) return;
    final app = AppScope.of(context);
    setState(() { busy = true; error = null; });
    final err = await app.signIn(email.text, password.text);
    if (!mounted) return;
    if (err != null) { setState(() { busy = false; error = err; }); return; }
    _backToRoot(context);
  }

  Future<void> _google() async {
    setState(() { busy = true; error = null; });
    final (ok, message) = await _signInWithGoogle();
    if (!mounted) return;
    if (ok) { _backToRoot(context); return; }
    setState(() { busy = false; error = message; });
  }

  @override Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Scaffold(appBar: AppBar(leading: const AppBackButton()), body: SafeArea(child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(28, 0, 28, 30), child: Form(key: form, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Center(child: Illustration('login', height: 170)),
        SizedBox(height: 16),
        Text('Welcome Back', style: Theme.of(context).textTheme.headlineMedium),
        SizedBox(height: 6),
        Text(tr('おかえりなさい。今日の予定を確認しましょう。', 'Good to see you. Let’s check today’s schedule.'),
          style: TextStyle(color: p.muted, fontSize: 13)),
        SizedBox(height: 24),

        TextFormField(controller: email, keyboardType: TextInputType.emailAddress, enabled: !busy,
          decoration: InputDecoration(labelText: tr('メールアドレス', 'Email'), prefixIcon: AppIcon(Icons.mail_outline_rounded)),
          validator: (v) => v != null && _emailPattern.hasMatch(v.trim()) ? null : tr('有効なメールアドレスを入力してください', 'Please enter a valid email')),
        SizedBox(height: 14),
        TextFormField(controller: password, obscureText: !visible, enabled: !busy, onFieldSubmitted: (_) => _submit(),
          decoration: InputDecoration(labelText: tr('パスワード', 'Password'), prefixIcon: AppIcon(Icons.lock_outline_rounded),
            suffixIcon: IconButton(onPressed: () => setState(() => visible = !visible),
              icon: AppIcon(visible ? Icons.visibility_off_outlined : Icons.visibility_outlined))),
          validator: (v) => v != null && v.length >= 6 ? null : tr('6文字以上で入力してください', 'Please enter at least 6 characters')),
        Align(alignment: Alignment.centerRight, child: TextButton(
          onPressed: busy ? null : () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => ForgotPasswordScreen(initialEmail: email.text.trim()))),
          child: Text(tr('パスワードを忘れた方', 'Forgot password?'),
            style: TextStyle(color: p.sage, fontSize: 12, fontWeight: FontWeight.w600)))),
        if (error != null) Padding(padding: EdgeInsets.only(bottom: 10),
          child: Text(error!, style: TextStyle(color: p.danger, fontSize: 13, height: 1.5))),
        SizedBox(height: 4),
        _MainButton(label: tr('ログイン', 'Log in'), busy: busy, onPressed: _submit),

        SizedBox(height: 28),
        Row(children: [
          Expanded(child: Divider(color: p.line)),
          Padding(padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text(tr('または', 'OR'), style: TextStyle(fontSize: 11, color: p.muted, letterSpacing: 1))),
          Expanded(child: Divider(color: p.line)),
        ]),
        SizedBox(height: 18),
        _GoogleButton(onPressed: busy ? null : _google),

        SizedBox(height: 26),
        Center(child: TextButton(
          onPressed: busy ? null : () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => RegisterScreen())),
          child: Text.rich(TextSpan(children: [
            TextSpan(text: tr('アカウントがない方  ', 'Don’t have an account?  '), style: TextStyle(color: p.muted, fontSize: 13)),
            TextSpan(text: tr('新規登録', 'Sign up'), style: TextStyle(color: p.sage, fontSize: 13, fontWeight: FontWeight.w700)),
          ])))),
      ])))));
  }
}

// =====================================================================
// 新規登録（メールだけ。Googleは、ログイン画面のボタンから）
// =====================================================================
class RegisterScreen extends StatefulWidget {
  RegisterScreen({super.key});
  @override State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final confirm = TextEditingController();
  bool visible = false;
  bool acceptTerms = false;
  bool busy = false;
  String? error;
  @override void dispose() { name.dispose(); email.dispose(); password.dispose(); confirm.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (!form.currentState!.validate()) return;
    if (!acceptTerms) {
      showDemoMessage(context, tr('利用規約とプライバシーポリシーに同意してください', 'Please agree to the Terms of Use and Privacy Policy'));
      return;
    }
    final app = AppScope.of(context);
    setState(() { busy = true; error = null; });
    final err = await app.register(name.text, email.text, password.text);
    if (!mounted) return;
    if (err != null) { setState(() { busy = false; error = err; }); return; }
    _backToRoot(context);
  }

  @override Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Scaffold(appBar: AppBar(leading: const AppBackButton()), body: SafeArea(child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(28, 8, 28, 30), child: Form(key: form, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Create Account', style: Theme.of(context).textTheme.headlineMedium),
        SizedBox(height: 8),
        Text(tr('新しい毎日を、ここから。', 'Start your new routine here.'), style: TextStyle(color: p.muted)),
        SizedBox(height: 24),
        TextFormField(controller: name, enabled: !busy,
          decoration: InputDecoration(labelText: tr('お名前', 'Name'), prefixIcon: AppIcon(Icons.person_outline_rounded)),
          validator: (v) => (v?.trim().isNotEmpty ?? false) ? null : tr('お名前を入力してください', 'Please enter your name')),
        SizedBox(height: 14),
        TextFormField(controller: email, enabled: !busy, keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(labelText: tr('メールアドレス', 'Email'), prefixIcon: AppIcon(Icons.mail_outline_rounded)),
          validator: (v) => v != null && _emailPattern.hasMatch(v.trim()) ? null : tr('有効なメールアドレスを入力してください', 'Please enter a valid email')),
        SizedBox(height: 14),
        TextFormField(controller: password, enabled: !busy, obscureText: !visible,
          decoration: InputDecoration(labelText: tr('パスワード', 'Password'), prefixIcon: AppIcon(Icons.lock_outline_rounded), suffixIcon: IconButton(
            onPressed: () => setState(() => visible = !visible), icon: AppIcon(visible ? Icons.visibility_off_outlined : Icons.visibility_outlined))),
          validator: (v) => v != null && v.length >= 8 ? null : tr('8文字以上にしてください', 'Use at least 8 characters')),
        SizedBox(height: 14),
        TextFormField(controller: confirm, enabled: !busy, obscureText: !visible, onFieldSubmitted: (_) => _submit(),
          decoration: InputDecoration(labelText: tr('パスワードの確認', 'Confirm password'), prefixIcon: AppIcon(Icons.verified_user_outlined)),
          validator: (v) => v == password.text ? null : tr('パスワードが一致しません', 'Passwords do not match')),
        SizedBox(height: 9),
        CheckboxListTile(value: acceptTerms, onChanged: busy ? null : (v) => setState(() => acceptTerms = v ?? false),
          controlAffinity: ListTileControlAffinity.leading, contentPadding: EdgeInsets.zero, activeColor: p.sage,
          title: Text(tr('利用規約とプライバシーポリシーに同意します', 'I agree to the Terms of Use and Privacy Policy'),
            style: TextStyle(fontSize: 12))),
        Wrap(spacing: 10, children: [
          TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsScreen())),
            child: Text(tr('利用規約', 'Terms of Use'))),
          TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyScreen())),
            child: Text(tr('プライバシーポリシー', 'Privacy Policy'))),
        ]),
        if (error != null) Padding(padding: EdgeInsets.only(top: 4, bottom: 8),
          child: Text(error!, style: TextStyle(color: p.danger, fontSize: 13, height: 1.5))),
        SizedBox(height: 12),
        _MainButton(label: tr('アカウントを作成', 'Create account'), busy: busy, onPressed: _submit),
        SizedBox(height: 22),
        Center(child: TextButton(
          onPressed: busy ? null : () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LoginScreen())),
          child: Text.rich(TextSpan(children: [
            TextSpan(text: tr('すでにアカウントをお持ちの方  ', 'Already have an account?  '), style: TextStyle(color: p.muted, fontSize: 13)),
            TextSpan(text: tr('ログイン', 'Log in'), style: TextStyle(color: p.sage, fontSize: 13, fontWeight: FontWeight.w700)),
          ])),
        )),
      ])))));
  }
}