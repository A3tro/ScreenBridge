import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

/// 写真のAI読み取りの、1人1日の回数を数える
class AiUsage {
  AiUsage._();

  /// 1人1日に使える回数（Firestoreのルールの「<= 10」と合わせる）
  static const dailyLimit = 10;

  static User? get _user {
    if (Firebase.apps.isEmpty) return null;
    try {
      final u = FirebaseAuth.instance.currentUser;
      return (u == null || u.isAnonymous) ? null : u;
    } catch (_) {
      return null;
    }
  }

  static bool get signedIn => _user != null;

  /// 今日の日付（世界標準時。日本時間の朝9時に切り替わる）。Firestoreのルールと同じ書き方
  static String _today() {
    final d = DateTime.now().toUtc();
    return '${d.year}-${d.month}-${d.day}';
  }

  static DocumentReference<Map<String, dynamic>>? _ref() {
    final u = _user;
    if (u == null) return null;
    return FirebaseFirestore.instance.collection('users').doc(u.uid).collection('usage').doc(_today());
  }

  /// 今日あと何回使えるか（ログインしていなければ 0）。通信できないときは、エラーになる
  static Future<int> remaining() async {
    final ref = _ref();
    if (ref == null) return 0;
    final snap = await ref.get().timeout(const Duration(seconds: 10));
    final used = (snap.data()?['count'] as num?)?.toInt() ?? 0;
    return (dailyLimit - used).clamp(0, dailyLimit);
  }

  /// 1回使ったことを記録する
  static Future<void> addOne() async {
    final ref = _ref();
    if (ref == null) return;
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) {
        tx.set(ref, {'count': 1});
      } else {
        final c = (snap.data()?['count'] as num?)?.toInt() ?? 0;
        tx.update(ref, {'count': c + 1});
      }
    });
  }
}