import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

/// シフト表などで、自分の名前（キーワード）が書かれた予定だけを残すための部品
class NameKeywords {
  NameKeywords._();

  static String _memory = '';
  static String? _owner; // だれの名前か（ユーザーのID）。違う人なら使わない

  /// いま使える名前（ログアウトしたり、別の人に変わったりしたら空になる）
  static String get current => _owner == _user?.uid ? _memory : '';

  static User? get _user {
    if (Firebase.apps.isEmpty) return null;
    try {
      final u = FirebaseAuth.instance.currentUser;
      return (u == null || u.isAnonymous) ? null : u;
    } catch (_) {
      return null;
    }
  }

  /// 保存されている名前を読み込む（ログイン中はFirestoreから、デモ中はアプリの中から）
  static Future<String> load() async {
    final u = _user;
    if (u == null) {
      if (_owner != null) { _memory = ''; _owner = null; } // ログアウトしたので、前の人の名前を消す
      return _memory;
    }
    if (_owner != u.uid) { _memory = ''; _owner = u.uid; }
    try {
      final snap = await FirebaseFirestore.instance.collection('users').doc(u.uid).get()
          .timeout(const Duration(seconds: 10));
      final v = snap.data()?['nameKeyword'];
      _memory = v is String ? v : '';
    } catch (_) {}
    return _memory;
  }

  /// 名前を保存する。保存できたら true
  static Future<bool> save(String value) async {
    _memory = value.trim();
    _owner = _user?.uid;
    final u = _user;
    if (u == null) return true;
    try {
      await FirebaseFirestore.instance.collection('users').doc(u.uid)
          .set({'nameKeyword': _memory}, SetOptions(merge: true))
          .timeout(const Duration(seconds: 10));
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 「山田 太郎, ヤマダ」のような入力を、名前のリストに分ける
  static List<String> split(String input) => input
      .split(RegExp(r'[,、，\n]'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  // 日付や時間が書かれている行かどうか
  static final _when = RegExp(r'\d{1,2}\s*[:/月時]|\d{1,2}\s*[-~〜～]\s*\d{1,2}|今日|本日|明日|明後日|あさって');

  /// 名前が書かれた予定の行だけを残し、行から名前を取り除いた文章を返す。
  /// 名前だけの見出し行のあとに、時間の行が続く形にも対応する。
  static String filterLines(String text, List<String> keywords) {
    final keys = keywords.map(_fold).where((k) => k.isNotEmpty).toList();
    if (keys.isEmpty) return text;
    final patterns = keys
        .map((k) => RegExp(k.split('').map(RegExp.escape).join(r'\s*'), caseSensitive: false))
        .toList();

    final out = <String>[];
    var inBlock = false;
    for (final raw in text.split(RegExp(r'\r?\n'))) {
      final line = _half(raw);
      if (line.trim().isEmpty) continue;
      final hasKey = patterns.any((p) => p.hasMatch(line));
      final hasWhen = _when.hasMatch(line);
      if (hasKey) {
        if (hasWhen) {
          var stripped = line;
          for (final p in patterns) {
            stripped = stripped.replaceAll(p, ' ');
          }
          out.add(stripped);
          inBlock = false;
        } else {
          inBlock = true; // 名前だけの見出し行。次の行から、自分の予定
        }
      } else if (hasWhen) {
        if (inBlock) out.add(line);
      } else {
        inBlock = false; // ほかの人の名前などの見出しで、自分の予定の区切りが終わる
      }
    }
    return out.join('\n');
  }

  /// 全角の英数字・記号を、半角にそろえる
  static String _half(String s) {
    final b = StringBuffer();
    for (final r in s.runes) {
      if (r >= 0xFF01 && r <= 0xFF5E) {
        b.writeCharCode(r - 0xFEE0);
      } else if (r == 0x3000) {
        b.write(' ');
      } else {
        b.writeCharCode(r);
      }
    }
    return b.toString();
  }

  static String _fold(String s) => _half(s).toLowerCase().replaceAll(RegExp(r'\s+'), '');
}