import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../data/app_controller.dart';

/// 表示する言語（日本語 / English）
class Lang {
  Lang._();
  static bool en = false;
  static String? _owner; // だれの設定を読み込んだか（ユーザーのID）

  static User? get _user {
    if (Firebase.apps.isEmpty) return null;
    try {
      final u = FirebaseAuth.instance.currentUser;
      return (u == null || u.isAnonymous) ? null : u;
    } catch (_) {
      return null;
    }
  }

  /// 言語を変える（表示を切り替えて、ログイン中ならアカウントに保存する）
  static Future<void> set(AppController app, bool english) async {
    en = english;
    app.setLanguage(english ? 'English' : '日本語');
    final u = _user;
    if (u == null) return;
    _owner = u.uid;
    try {
      await FirebaseFirestore.instance.collection('users').doc(u.uid)
          .set({'language': english ? 'en' : 'ja'}, SetOptions(merge: true));
    } catch (_) {}
  }

  /// 保存してある言語を読み込む（ログインした人が変わったときだけ）
  static Future<void> load(AppController app) async {
    final u = _user;
    if (u == null) { _owner = null; return; }
    if (_owner == u.uid) return;
    _owner = u.uid;
    try {
      final snap = await FirebaseFirestore.instance.collection('users').doc(u.uid).get()
          .timeout(const Duration(seconds: 10));
      final v = snap.data()?['language'];
      if (v == 'en' || v == 'ja') {
        en = v == 'en';
        app.setLanguage(en ? 'English' : '日本語');
      }
    } catch (_) {}
  }
}

/// 日本語と英語を並べて書いて、今の言語のほうを使う
/// 例：tr('プロフィール', 'Profile')
String tr(String ja, String en) => Lang.en ? en : ja;

const _weekdaysJa = ['月', '火', '水', '木', '金', '土', '日'];
const _weekdaysEn = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _monthsEn = ['January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December'];

/// 曜日（月 / Mon）。weekday は 1（月）〜 7（日）
String weekdayShort(int weekday) => (Lang.en ? _weekdaysEn : _weekdaysJa)[weekday - 1];

/// 短い日付（11/17（火） / Tue 11/17）
String dateLabel(DateTime d) => Lang.en
  ? '${weekdayShort(d.weekday)} ${d.month}/${d.day}'
  : '${d.month}/${d.day}（${weekdayShort(d.weekday)}）';

/// 長い日付（11月17日（火） / Tue, Nov 17）
String longDateLabel(DateTime d) => Lang.en
  ? '${weekdayShort(d.weekday)}, ${_monthsEn[d.month - 1].substring(0, 3)} ${d.day}'
  : '${d.month}月${d.day}日（${weekdayShort(d.weekday)}）';

/// 年と月（2026年 11月 / November 2026）
String monthLabel(DateTime d) => Lang.en ? '${_monthsEn[d.month - 1]} ${d.year}' : '${d.year}年 ${d.month}月';