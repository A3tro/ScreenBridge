import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../app/app.dart';
import '../../core/i18n/lang.dart';
import '../../core/widgets/app_icon.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui.dart';
import '../../data/app_controller.dart';
import '../auth/password_reset_screens.dart';
import '../settings/theme_screen.dart';

/// プロフィールの写真（小さくして、Firestoreの自分のユーザーの情報に保存する）
class ProfilePhoto {
  ProfilePhoto._();
  static final bytes = ValueNotifier<Uint8List?>(null);
  static String? _owner; // だれの写真か（ユーザーのID）

  static User? get _user {
    if (Firebase.apps.isEmpty) return null;
    try {
      final u = FirebaseAuth.instance.currentUser;
      return (u == null || u.isAnonymous) ? null : u;
    } catch (_) {
      return null;
    }
  }

  /// Googleでログインした人の、Googleアカウントの写真
  static String? get googleUrl => _user?.photoURL;

  /// 保存してある写真を読み込む（人が変わったときだけ）
  static Future<void> load() async {
    final u = _user;
    if (u == null) {
      if (_owner != null) { _owner = null; bytes.value = null; } // ログアウトしたので、前の人の写真を消す
      return;
    }
    if (_owner == u.uid) return;
    _owner = u.uid;
    bytes.value = null;
    try {
      final snap = await FirebaseFirestore.instance.collection('users').doc(u.uid).get()
          .timeout(const Duration(seconds: 10));
      final s = snap.data()?['photo'];
      if (s is String && s.isNotEmpty) bytes.value = base64Decode(s);
    } catch (_) {}
  }

  /// 写真を選んで保存する。失敗したら、表示する文章を返す（成功やキャンセルは null）
  static Future<String?> pickAndSave() async {
    try {
      final f = await ImagePicker().pickImage(source: ImageSource.gallery,
        maxWidth: 256, maxHeight: 256, imageQuality: 70);
      if (f == null) return null;
      final data = await f.readAsBytes();
      if (data.lengthInBytes > 700 * 1024) {
        return tr('写真が大きすぎます。別の写真を選んでください', 'The photo is too large. Please choose another one.');
      }
      bytes.value = data;
      final u = _user;
      if (u == null) return null; // デモ中は、アプリの中だけ
      _owner = u.uid;
      await FirebaseFirestore.instance.collection('users').doc(u.uid)
          .set({'photo': base64Encode(data)}, SetOptions(merge: true))
          .timeout(const Duration(seconds: 15));
      return null;
    } catch (_) {
      return tr('写真を保存できませんでした。もう一度お試しください', 'Could not save the photo. Please try again.');
    }
  }

  /// 写真を消す
  static Future<String?> remove() async {
    bytes.value = null;
    final u = _user;
    if (u == null) return null;
    try {
      await FirebaseFirestore.instance.collection('users').doc(u.uid)
          .set({'photo': FieldValue.delete()}, SetOptions(merge: true))
          .timeout(const Duration(seconds: 15));
      return null;
    } catch (_) {
      return tr('写真を消せませんでした。もう一度お試しください', 'Could not remove the photo. Please try again.');
    }
  }
}

/// 丸い写真（写真がなければ、Googleの写真、それもなければ人のマーク）
class _Avatar extends StatelessWidget {
  final double size;
  const _Avatar({required this.size});
  @override Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    Widget placeholder() => Center(child: AppIcon(Icons.person_rounded, size: size * .6, color: p.navy));
    return ValueListenableBuilder<Uint8List?>(valueListenable: ProfilePhoto.bytes, builder: (context, data, _) {
      final Widget child;
      if (data != null) {
        child = Image.memory(data, fit: BoxFit.cover, width: size, height: size);
      } else if (ProfilePhoto.googleUrl != null) {
        child = Image.network(ProfilePhoto.googleUrl!, fit: BoxFit.cover, width: size, height: size,
          errorBuilder: (_, __, ___) => placeholder());
      } else {
        child = placeholder();
      }
      return ClipOval(child: Container(width: size, height: size, color: p.peach, child: child));
    });
  }
}

class ProfileScreen extends StatelessWidget {
  ProfileScreen({super.key});
  @override Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = AppPalette.of(context);
    ProfilePhoto.load();
    return Scaffold(body: SafeArea(child: ListView(padding: EdgeInsets.fromLTRB(24, 0, 24, 34), children: [
      ScreenHeader(title: tr('プロフィール', 'Profile'),
        subtitle: app.isSignedIn ? tr('アカウントと設定', 'Account & settings') : tr('デモ用の設定', 'Demo settings')),

      // 写真と名前（押すと、プロフィールの管理）
      SurfaceCard(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _ManageProfileScreen())),
        child: Row(children: [
          _Avatar(size: 62),
          SizedBox(width: 15),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(app.user.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
            Text(app.user.email, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.muted, fontSize: 11)),
            if (!app.isSignedIn) ...[SizedBox(height: 5), DemoPill(text: tr('デモモード', 'Demo mode'))],
          ])),
          AppIcon(Icons.chevron_right_rounded, size: 19, color: p.muted),
        ])),

      SizedBox(height: 26), _label(context, tr('アカウント', 'Account')), SizedBox(height: 10),
      SurfaceCard(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4), child: Column(children: [
        _row(context, Icons.lock_outline_rounded, tr('パスワードとセキュリティ', 'Password & Security'), '', () =>
          Navigator.push(context, MaterialPageRoute(builder: (_) => const _PasswordSecurityScreen()))),
        Divider(height: 1),
        SwitchListTile(value: app.notificationsEnabled, onChanged: app.setNotifications,
          activeColor: p.sage, contentPadding: EdgeInsets.zero,
          secondary: AppIcon(Icons.notifications_none_rounded, color: p.sage),
          title: Text(tr('通知', 'Notifications'), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          subtitle: Text(tr('通知は、Android版で対応予定です', 'Coming in the Android version'),
            style: TextStyle(fontSize: 11, color: p.muted))),
        Divider(height: 1),
        _row(context, Icons.translate_rounded, tr('言語', 'Language'), Lang.en ? 'English' : '日本語',
          () => _language(context, app)),
      ])),

      SizedBox(height: 26), _label(context, tr('設定', 'Preferences')), SizedBox(height: 10),
      SurfaceCard(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4), child: Column(children: [
        _row(context, Icons.info_outline_rounded, tr('アプリについて', 'About'), 'v0.2.0', () => _info(context, 'ScreenBridge AI',
          tr('シフト表の写真や、お店から届いた文章から、自分の予定だけを読み取って、カレンダーにまとめるアプリです。',
            'An app that reads only your own schedule from shift-table photos or messages from your workplace, and puts it in your calendar.'))),
        Divider(height: 1),
        _row(context, Icons.shield_outlined, tr('プライバシーとデータ', 'Privacy & Data'), '', () => _info(context,
          tr('データについて', 'About your data'),
          app.isSignedIn
            ? tr('予定とプロフィールは、あなたのアカウントに保存されます（Firebase）。写真の読み取りでは、写真をGoogleのAI（Gemini）へ送りますが、'
                'アプリには保存しません。貼り付けた文章は、まず端末の中で読み取り、読めなかったときだけAIで読み取ります。',
                'Your events and profile are saved to your account (Firebase). When reading a photo, it is sent to Google\'s AI (Gemini), '
                'but it is not stored in the app. Pasted text is read on your device first, and sent to the AI only if it cannot be read.')
            : tr('デモでは、予定はこの端末のメモリの中だけにあり、アプリを閉じると初期化されます。'
                'ログインすると、予定があなたのアカウントに保存されます。',
                'In demo mode, events exist only in this device\'s memory and are reset when you close the app. '
                'Sign in to save your events to your account.'))),
        Divider(height: 1),
        _row(context, Icons.palette_outlined, tr('テーマ', 'Theme'),
          app.darkPreference ? tr('ダーク', 'Dark') : tr('ライト', 'Light'), () =>
          Navigator.push(context, MaterialPageRoute(builder: (_) => const ThemeScreen()))),
      ])),

      SizedBox(height: 26),
      PrimaryButton(label: app.isSignedIn ? tr('ログアウト', 'Log out') : tr('デモを終了', 'End demo'),
        icon: Icons.logout_rounded, secondary: true, onPressed: () => _logout(context, app)),
    ])));
  }

  Widget _label(BuildContext context, String text) => Text(text,
    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppPalette.of(context).muted));

  /// 1行の項目（矢印は、いつもいちばん右）
  Widget _row(BuildContext context, IconData icon, String title, String value, VoidCallback onTap) {
    final p = AppPalette.of(context);
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(9), child: Padding(
      padding: EdgeInsets.symmetric(vertical: 14), child: Row(children: [
        AppIcon(icon, size: 21, color: p.sage), SizedBox(width: 12),
        Expanded(child: Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
        if (value.isNotEmpty) ...[
          ConstrainedBox(constraints: BoxConstraints(maxWidth: 130), child: Text(value, textAlign: TextAlign.right,
            maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: p.muted))),
          SizedBox(width: 5),
        ],
        AppIcon(Icons.chevron_right_rounded, size: 19, color: p.muted),
      ])));
  }

  /// ログアウト（ログイン中）か、デモの終了
  Future<void> _logout(BuildContext context, AppController app) async {
    if (app.isSignedIn) {
      final ok = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
        title: Text(tr('ログアウトしますか？', 'Log out?')),
        content: Text(tr('保存した予定は、アカウントに残ります。もう一度ログインすると、表示されます。',
          'Your saved events stay in your account. They will appear again when you sign in.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(tr('キャンセル', 'Cancel'))),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(tr('ログアウト', 'Log out'))),
        ]));
      if (ok != true) return;
      await app.signOut();
    }
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const RootGate()), (route) => false);
  }

  /// 言語を選ぶ
  Future<void> _language(BuildContext context, AppController app) async {
    final english = await showDialog<bool>(context: context, builder: (dialogContext) => SimpleDialog(
      title: Text(tr('表示する言語', 'Language')), children: [
        SimpleDialogOption(onPressed: () => Navigator.pop(dialogContext, false),
          child: Row(children: [Expanded(child: Text('日本語')), if (!Lang.en) AppIcon(Icons.check_rounded, size: 18)])),
        SimpleDialogOption(onPressed: () => Navigator.pop(dialogContext, true),
          child: Row(children: [Expanded(child: Text('English')), if (Lang.en) AppIcon(Icons.check_rounded, size: 18)])),
      ]));
    if (english == null || english == Lang.en) return;
    await Lang.set(app, english);
  }

  void _info(BuildContext context, String title, String content) => showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(
    title: Text(title), content: Text(content),
    actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(tr('閉じる', 'Close')))]));
}

/// プロフィールの管理：写真と名前
class _ManageProfileScreen extends StatefulWidget {
  const _ManageProfileScreen();
  @override State<_ManageProfileScreen> createState() => _ManageProfileScreenState();
}

class _ManageProfileScreenState extends State<_ManageProfileScreen> {
  late final TextEditingController name;
  bool _ready = false;
  bool busy = false;
  String? error;

  @override void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_ready) { _ready = true; name = TextEditingController(text: AppScope.of(context).user.name); }
  }

  @override void dispose() { name.dispose(); super.dispose(); }

  Future<void> _pick() async {
    setState(() { busy = true; error = null; });
    final err = await ProfilePhoto.pickAndSave();
    if (!mounted) return;
    setState(() { busy = false; error = err; });
  }

  Future<void> _removePhoto() async {
    setState(() { busy = true; error = null; });
    final err = await ProfilePhoto.remove();
    if (!mounted) return;
    setState(() { busy = false; error = err; });
  }

  void _save() {
    final n = name.text.trim();
    if (n.isEmpty) { setState(() => error = tr('名前を入力してください', 'Please enter your name')); return; }
    AppScope.of(context).updateProfile(name: n);
    showDemoMessage(context, tr('プロフィールを保存しました', 'Profile saved'));
    Navigator.pop(context);
  }

  @override Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = AppPalette.of(context);
    return Scaffold(
      appBar: AppBar(leading: const AppBackButton(), title: Text(tr('プロフィールの管理', 'Manage Profile'))),
      body: SafeArea(child: ListView(padding: EdgeInsets.fromLTRB(24, 12, 24, 30), children: [
        Center(child: SizedBox(width: 116, height: 116, child: Stack(children: [
          _Avatar(size: 110),
          Positioned(right: 0, bottom: 0, child: Material(color: p.butter,
            shape: CircleBorder(side: BorderSide(color: p.navy)),
            child: IconButton(tooltip: tr('写真を変える', 'Change photo'), onPressed: busy ? null : _pick,
              icon: AppIcon(Icons.photo_camera_outlined, size: 20)))),
        ]))),
        SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          TextButton(onPressed: busy ? null : _pick,
            child: Text(busy ? tr('保存中…', 'Saving…') : tr('写真を選ぶ', 'Choose photo'))),
          ValueListenableBuilder<Uint8List?>(valueListenable: ProfilePhoto.bytes, builder: (context, data, _) =>
            data == null ? SizedBox.shrink() : TextButton(onPressed: busy ? null : _removePhoto,
              child: Text(tr('写真を消す', 'Remove photo'), style: TextStyle(color: p.danger)))),
        ]),
        SizedBox(height: 16),
        TextField(controller: name, decoration: InputDecoration(labelText: tr('表示名', 'Display name'),
          prefixIcon: AppIcon(Icons.person_outline_rounded))),
        SizedBox(height: 16),
        if (app.isSignedIn) ...[
          Text(tr('メールアドレス', 'Email'), style: TextStyle(fontSize: 12, color: p.muted)),
          SizedBox(height: 4),
          Text(app.user.email, style: TextStyle(fontSize: 14)),
          SizedBox(height: 4),
          Text(tr('ログインに使うメールアドレスは、変更できません', 'The email you sign in with cannot be changed'),
            style: TextStyle(fontSize: 11, color: p.muted)),
        ],
        if (error != null) Padding(padding: EdgeInsets.only(top: 12),
          child: Text(error!, style: TextStyle(color: p.danger, fontSize: 13, height: 1.5))),
        SizedBox(height: 26),
        PrimaryButton(label: tr('保存', 'Save'), onPressed: busy ? null : _save),
        SizedBox(height: 12),
        Text(tr('写真は小さくして、あなたのアカウントに保存します。ほかの人には見えません。',
          'Your photo is resized and saved to your account. Other people cannot see it.'),
          textAlign: TextAlign.center, style: TextStyle(color: p.muted, fontSize: 11, height: 1.6)),
      ])),
    );
  }
}

/// パスワードとセキュリティ
class _PasswordSecurityScreen extends StatefulWidget {
  const _PasswordSecurityScreen();
  @override State<_PasswordSecurityScreen> createState() => _PasswordSecurityScreenState();
}

class _PasswordSecurityScreenState extends State<_PasswordSecurityScreen> {
  final current = TextEditingController();
  final next = TextEditingController();
  final confirm = TextEditingController();
  bool visible = false;
  bool busy = false;
  String? error;
  String? done;

  @override void dispose() { current.dispose(); next.dispose(); confirm.dispose(); super.dispose(); }

  User? get user {
    try {
      final u = FirebaseAuth.instance.currentUser;
      return (u == null || u.isAnonymous) ? null : u;
    } catch (_) {
      return null;
    }
  }

  bool get hasPassword => user?.providerData.any((x) => x.providerId == 'password') ?? false;
  bool get hasGoogle => user?.providerData.any((x) => x.providerId == 'google.com') ?? false;

  String _message(String code) => switch (code) {
    'wrong-password' || 'invalid-credential' || 'invalid-login-credentials' =>
      tr('今のパスワードが違います', 'Your current password is incorrect'),
    'weak-password' => tr('新しいパスワードが弱すぎます。もっと長くしてください', 'The new password is too weak. Please make it longer.'),
    'too-many-requests' => tr('試行回数が多すぎます。しばらく待ってからお試しください', 'Too many attempts. Please wait and try again.'),
    'requires-recent-login' => tr('安全のため、一度ログインし直してから、お試しください', 'For security, please sign in again and retry.'),
    'network-request-failed' => tr('ネットワークにつながりません。電波を確認してください', 'No network connection. Please check your connection.'),
    _ => tr('うまくいきませんでした（$code）', 'Something went wrong ($code)'),
  };

  Future<void> _change() async {
    final u = user;
    if (u == null || u.email == null) return;
    String? err;
    if (current.text.isEmpty) {
      err = tr('今のパスワードを入力してください', 'Please enter your current password');
    } else if (next.text.length < 8) {
      err = tr('新しいパスワードは8文字以上にしてください', 'The new password must be at least 8 characters');
    } else if (next.text != confirm.text) {
      err = tr('新しいパスワードが一致しません', 'The new passwords do not match');
    } else if (next.text == current.text) {
      err = tr('前と違うパスワードにしてください', 'Please use a different password from before');
    }
    if (err != null) { setState(() { error = err; done = null; }); return; }

    setState(() { busy = true; error = null; done = null; });
    try {
      await u.reauthenticateWithCredential(EmailAuthProvider.credential(email: u.email!, password: current.text));
      await u.updatePassword(next.text);
      if (!mounted) return;
      setState(() { busy = false; done = tr('パスワードを変更しました', 'Your password has been changed'); });
      current.clear(); next.clear(); confirm.clear();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() { busy = false; error = _message(e.code); });
    } catch (_) {
      if (!mounted) return;
      setState(() { busy = false; error = tr('変更できませんでした。もう一度お試しください', 'Could not change it. Please try again.'); });
    }
  }

  @override Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final u = user;
    final methods = [if (hasPassword) tr('メールとパスワード', 'Email & password'), if (hasGoogle) 'Google'];
    return Scaffold(
      appBar: AppBar(leading: const AppBackButton(), title: Text(tr('パスワードとセキュリティ', 'Password & Security'))),
      body: SafeArea(child: ListView(padding: EdgeInsets.fromLTRB(24, 12, 24, 30), children: [
        if (u == null)
          Text(tr('ログインすると、使えるようになります。', 'Sign in to use this.'), style: TextStyle(fontSize: 14))
        else ...[
          SurfaceCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr('ログイン方法', 'Sign-in method'), style: TextStyle(fontSize: 12, color: p.muted)),
            SizedBox(height: 4),
            Text(methods.isEmpty ? tr('不明', 'Unknown') : methods.join(' / '),
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            SizedBox(height: 4),
            Text(u.email ?? '', style: TextStyle(fontSize: 12, color: p.muted)),
          ])),
          SizedBox(height: 22),
          if (hasPassword) ...[
            Text(tr('パスワードの変更', 'Change password'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            SizedBox(height: 12),
            TextField(controller: current, obscureText: !visible, enabled: !busy,
              decoration: InputDecoration(labelText: tr('今のパスワード', 'Current password'), prefixIcon: AppIcon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(onPressed: () => setState(() => visible = !visible),
                  icon: AppIcon(visible ? Icons.visibility_off_outlined : Icons.visibility_outlined)))),
            SizedBox(height: 12),
            TextField(controller: next, obscureText: !visible, enabled: !busy,
              decoration: InputDecoration(labelText: tr('新しいパスワード（8文字以上）', 'New password (8+ characters)'),
                prefixIcon: AppIcon(Icons.lock_reset_rounded))),
            SizedBox(height: 12),
            TextField(controller: confirm, obscureText: !visible, enabled: !busy, onSubmitted: (_) => _change(),
              decoration: InputDecoration(labelText: tr('新しいパスワードの確認', 'Confirm new password'),
                prefixIcon: AppIcon(Icons.verified_user_outlined))),
            if (error != null) Padding(padding: EdgeInsets.only(top: 10),
              child: Text(error!, style: TextStyle(color: p.danger, fontSize: 13, height: 1.5))),
            if (done != null) Padding(padding: EdgeInsets.only(top: 10),
              child: Text(done!, style: TextStyle(color: p.sage, fontSize: 13, fontWeight: FontWeight.w700))),
            SizedBox(height: 20),
            PrimaryButton(label: busy ? tr('変更中…', 'Changing…') : tr('パスワードを変更', 'Change password'),
              onPressed: busy ? null : _change),
            SizedBox(height: 8),
            Center(child: TextButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => ForgotPasswordScreen(initialEmail: u.email ?? ''))),
              child: Text(tr('今のパスワードを忘れた場合', 'Forgot your current password?'),
                style: TextStyle(color: p.sage, fontSize: 12)))),
          ] else
            SurfaceCard(color: p.mint, child: Text(
              tr('Googleでログインしているため、パスワードはGoogleアカウントで管理されています。'
                '変更するときは、Googleアカウントの設定から行ってください。',
                'You signed in with Google, so your password is managed by your Google Account. '
                'To change it, use your Google Account settings.'),
              style: TextStyle(fontSize: 13, height: 1.6))),
        ],
      ])),
    );
  }
}