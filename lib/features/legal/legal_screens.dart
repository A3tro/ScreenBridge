import 'package:flutter/material.dart';
import '../../core/i18n/lang.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_icon.dart';

/// お問い合わせ先（公開してもよいメールアドレスにしてください）
const contactEmail = 'wmin8532@gmail.com';
const _updated = '2026-11-17';

class _Section {
  final String title;
  final String body;
  const _Section(this.title, this.body);
}

/// 文書の画面（見出しと本文を並べる）
class _LegalPage extends StatelessWidget {
  final String title;
  final String intro;
  final List<_Section> sections;
  const _LegalPage({required this.title, required this.intro, required this.sections});
  @override Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Scaffold(
      appBar: AppBar(leading: const AppBackButton(), title: Text(title)),
      body: SafeArea(child: ListView(padding: const EdgeInsets.fromLTRB(24, 8, 24, 32), children: [
        Text('${tr('最終更新日：', 'Last updated: ')}$_updated', style: TextStyle(color: p.muted, fontSize: 12)),
        const SizedBox(height: 14),
        Text(intro, style: const TextStyle(fontSize: 13, height: 1.7)),
        const SizedBox(height: 20),
        for (var i = 0; i < sections.length; i++) Padding(padding: const EdgeInsets.only(bottom: 20), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${i + 1}. ${sections[i].title}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(sections[i].body, style: const TextStyle(fontSize: 13, height: 1.7)),
          ])),
      ])),
    );
  }
}

/// 利用規約
class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});
  @override Widget build(BuildContext context) => _LegalPage(
    title: tr('利用規約', 'Terms of Use'),
    intro: tr('この利用規約は、ScreenBridge AI（以下「本アプリ」）を使うときの条件です。本アプリを使うことで、この規約に同意したものとします。',
      'These Terms of Use set out the conditions for using ScreenBridge AI (the "App"). By using the App, you agree to these terms.'),
    sections: [
      _Section(tr('本アプリでできること', 'What the App does'),
        tr('本アプリは、シフト表の写真や、お店から届いた文章などから予定を読み取り、カレンダーにまとめるためのアプリです。',
          'The App reads events from photos of shift tables and messages from your workplace, and organizes them in a calendar.')),
      _Section(tr('アカウント', 'Your account'),
        tr('登録するときは、正しい情報を使ってください。パスワードは、ご自身で大切に管理してください。ほかの人のアカウントを使ってはいけません。',
          'Please use accurate information when you sign up. Keep your password safe. Do not use another person’s account.')),
      _Section(tr('読み取りの結果について', 'About scan results'),
        tr('AIや自動の読み取りは、まちがえることがあります。予定を保存する前に、日付や時間を必ず確認してください。読み取りの結果によって起きた損害（遅刻など）について、開発者は責任を負いません。',
          'AI and automatic reading can make mistakes. Always check dates and times before saving. The developer is not responsible for any damage caused by scan results (such as being late).')),
      _Section(tr('ほかの人の情報', 'Other people’s information'),
        tr('シフト表などには、ほかの人の名前が写っていることがあります。読み取りは、自分の予定を確認する目的だけに使い、写っている情報を外に広めないでください。',
          'Shift tables may include other people’s names. Use the scan only to check your own schedule, and do not share that information with others.')),
      _Section(tr('利用の制限', 'Usage limits'),
        tr('写真のAI読み取りは、1人1日10回までです。回数は、サービスの状況に合わせて変更することがあります。',
          'AI photo scans are limited to 10 per person per day. This limit may change depending on service conditions.')),
      _Section(tr('禁止していること', 'Prohibited actions'),
        tr('不正なアクセス、システムに大きな負荷をかける行為、法律に反する行為、ほかの人の権利を侵害する行為、AIの機能を本来の目的以外で使う行為を禁止します。',
          'Unauthorized access, placing heavy load on the system, illegal actions, infringing on others’ rights, and using the AI features for unintended purposes are prohibited.')),
      _Section(tr('サービスの変更・停止', 'Changes and suspension'),
        tr('本アプリの内容は、予告なく変更・中断・終了することがあります。',
          'The App may be changed, suspended, or discontinued without notice.')),
      _Section(tr('保証について', 'Disclaimer'),
        tr('本アプリは、個人が学習とポートフォリオのために作成したアプリです。できる限り正しく動くように努めますが、すべての動作を保証するものではありません。',
          'The App was created by an individual for learning and portfolio purposes. While every effort is made for it to work correctly, its operation is not guaranteed.')),
      _Section(tr('規約の変更', 'Changes to these terms'),
        tr('この規約を変更したときは、本アプリの中でお知らせします。',
          'If these terms change, we will let you know in the App.')),
      _Section(tr('お問い合わせ', 'Contact'), contactEmail),
    ],
  );
}

/// プライバシーポリシー
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});
  @override Widget build(BuildContext context) => _LegalPage(
    title: tr('プライバシーポリシー', 'Privacy Policy'),
    intro: tr('ScreenBridge AI（以下「本アプリ」）が、どんな情報を集めて、どのように使うかを説明します。',
      'This policy explains what information ScreenBridge AI (the "App") collects and how it is used.'),
    sections: [
      _Section(tr('集める情報', 'Information we collect'),
        tr('・アカウントの情報（名前、メールアドレス。Googleでログインした場合は、Googleのプロフィール写真）\n'
          '・登録した予定\n・設定したプロフィール写真\n・名前のキーワード、言語の設定\n・写真のAI読み取りを使った回数',
          '• Account information (name, email address, and your Google profile photo if you sign in with Google)\n'
          '• Events you save\n• Profile photo you set\n• Name keywords and language setting\n• Number of AI photo scans you used')),
      _Section(tr('使う目的', 'How we use it'),
        tr('ログイン、予定の保存と表示、読み取りの回数の制限、不具合への対応のために使います。広告には使いません。',
          'For signing in, saving and showing your events, limiting scans, and fixing problems. It is not used for advertising.')),
      _Section(tr('保存する場所', 'Where it is stored'),
        tr('情報は、Googleが提供するFirebase（Authentication、Cloud Firestore）に保存します。予定やプロフィールは、本人だけが読み書きできるように設定しています。',
          'Information is stored in Firebase (Authentication and Cloud Firestore) provided by Google. Your events and profile are set so that only you can read and write them.')),
      _Section(tr('写真と文章の扱い', 'Photos and text'),
        tr('写真は、予定を読み取るためにGoogleのAI（Gemini）へ送ります。本アプリには保存しません。'
          'AIは無料の利用枠を使っているため、送った内容が、Googleの規約にもとづいて、Googleのサービスの改善に使われることがあります。'
          '貼り付けた文章は、まず端末の中で読み取り、読み取れなかったときだけAIへ送ります。',
          'Photos are sent to Google’s AI (Gemini) to read your events, and are not stored in the App. '
          'Because the App uses the free tier of the AI, what you send may be used to improve Google’s services under Google’s terms. '
          'Pasted text is read on your device first, and sent to the AI only if it cannot be read.')),
      _Section(tr('ほかの人への提供', 'Sharing with others'),
        tr('法律にもとづく場合をのぞき、集めた情報を、ほかの人や会社に渡すことはありません（上で説明したGoogleのサービスをのぞく）。',
          'We do not share your information with other people or companies, except as required by law (and except for the Google services described above).')),
      _Section(tr('情報の削除', 'Deleting your information'),
        tr('予定は、本アプリの中でいつでも削除できます。アカウントとすべての情報の削除を希望するときは、お問い合わせ先までご連絡ください。',
          'You can delete your events in the App at any time. To delete your account and all your information, please contact us.')),
      _Section(tr('このポリシーの変更', 'Changes to this policy'),
        tr('このポリシーを変更したときは、本アプリの中でお知らせします。',
          'If this policy changes, we will let you know in the App.')),
      _Section(tr('お問い合わせ', 'Contact'), contactEmail),
    ],
  );
}