import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import '../core/i18n/lang.dart';
import '../core/utils/date_utils.dart';
import '../models/models.dart';

class AppController extends ChangeNotifier {
  static const AppUser _guest = AppUser(name: 'ゲスト', email: 'demo@screenbridge.app');
  AppUser user = _guest;
  int currentTab = 0;
  bool darkPreference = false; // Applied to the whole app; session-scoped preference.
  bool notificationsEnabled = true;
  String language = '日本語';
  final List<ScheduleEvent> events = [];
  final List<ScheduleChange> changes = [];
  final List<NotificationItem> notifications = [];
  final List<ImportRecord> imports = [];

  /// true: ログイン中（予定はFirestoreに保存） / false: デモ（アプリの中だけ）
  bool get isSignedIn => _uid != null;
  /// 起動時にログイン状態の確認が終わったか
  bool authReady = false;
  /// Firestoreとの同期でエラーがあったときの文章
  String? syncError;

  String? _uid;
  StreamSubscription<User?>? _authSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _eventsSub;
  Timer? _ticker;
  final Set<String> _readIds = {}; // 読んだお知らせ

  AppController() {
    _resetToDemo();
    _listenAuth();
    // お知らせを、5分ごとに作り直す（「まもなく始まります」など）
    _ticker = Timer.periodic(const Duration(minutes: 5), (_) {
      if (_uid != null) { _buildReminders(); notifyListeners(); }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _eventsSub?.cancel();
    _ticker?.cancel();
    super.dispose();
  }

  // ---------- ログイン状態の監視 ----------
  void _listenAuth() {
    if (Firebase.apps.isEmpty) { authReady = true; return; } // Firebase未初期化（テストなど）
    try {
      _authSub = FirebaseAuth.instance.userChanges().listen(_onUser, onError: (Object _) {
        authReady = true;
        notifyListeners();
      });
    } catch (_) {
      authReady = true;
    }
  }

  void _onUser(User? u) {
    final uid = (u == null || u.isAnonymous) ? null : u.uid;
    authReady = true;
    if (uid != _uid) {
      _eventsSub?.cancel();
      _eventsSub = null;
      _uid = uid;
      if (uid == null) {
        _resetToDemo();
      } else {
        events.clear(); changes.clear(); notifications.clear(); imports.clear();
        _readIds.clear();
        currentTab = 0;
        syncError = null;
        _eventsSub = _eventsCol(uid).snapshots().listen(_onEvents, onError: (Object e) {
          syncError = _firestoreMessage(e);
          notifyListeners();
        });
      }
    }
    if (u != null && uid != null) {
      final n = u.displayName?.trim() ?? '';
      user = AppUser(name: n.isNotEmpty ? n : (u.email ?? 'ユーザー').split('@').first, email: u.email ?? '');
    }
    notifyListeners();
  }

  CollectionReference<Map<String, dynamic>> _eventsCol(String uid) =>
      FirebaseFirestore.instance.collection('users').doc(uid).collection('events');

  void _onEvents(QuerySnapshot<Map<String, dynamic>> snap) {
    syncError = null;
    events..clear()..addAll(snap.docs.map(_eventFromDoc).whereType<ScheduleEvent>());
    _buildReminders();
    notifyListeners();
  }

  // ---------- お知らせ（受信箱）を、予定から作る ----------
  DateTime _earlier(DateTime a, DateTime b) => a.isBefore(b) ? a : b;

  void _buildReminders() {
    if (_uid == null) return;
    final now = DateTime.now();
    final today = Dates.only(now);
    final tomorrow = today.add(const Duration(days: 1));
    final items = <NotificationItem>[];
    for (final e in sortedEvents) {
      if (!e.end.isAfter(now)) continue; // 終わった予定は出さない
      final time = e.allDay ? tr('終日', 'All day') : Dates.range(e.start, e.end);
      final where = e.location.isEmpty ? '' : ' ・ ${e.location}';
      final message = '${e.title}（$time$where）';
      final startsSoon = !e.allDay && e.start.isAfter(now) && e.start.difference(now).inMinutes <= 60;
      if (startsSoon) {
        final id = 'soon-${e.id}-${e.start.millisecondsSinceEpoch}';
        items.add(NotificationItem(id: id, title: tr('まもなく始まります', 'Starting soon'), message: message,
          createdAt: _earlier(now, e.start.subtract(const Duration(hours: 1))),
          icon: Icons.alarm_rounded, target: 'calendar', read: _readIds.contains(id)));
      } else if (Dates.sameDay(e.start, today) || e.start.isBefore(now)) {
        final id = 'today-${e.id}-${today.millisecondsSinceEpoch}';
        items.add(NotificationItem(id: id, title: tr('今日の予定', 'Today'), message: message,
          createdAt: _earlier(now, e.start.subtract(const Duration(hours: 3))),
          icon: Icons.today_outlined, target: 'calendar', read: _readIds.contains(id)));
      } else if (Dates.sameDay(e.start, tomorrow)) {
        final id = 'tomorrow-${e.id}-${tomorrow.millisecondsSinceEpoch}';
        items.add(NotificationItem(id: id, title: tr('明日の予定', 'Tomorrow'), message: message,
          createdAt: _earlier(now, today.add(const Duration(hours: 18))),
          icon: Icons.event_outlined, target: 'calendar', read: _readIds.contains(id)));
      }
    }
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    notifications..clear()..addAll(items);
  }

  Map<String, dynamic> _eventToMap(ScheduleEvent e) => {
    'title': e.title,
    'start': Timestamp.fromDate(e.start),
    'end': Timestamp.fromDate(e.end),
    'category': e.category.name,
    'location': e.location,
    'notes': e.notes,
    'source': e.source,
    'confirmed': e.confirmed,
    'allDay': e.allDay,
    'reminder': e.reminder,
    'history': e.history,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  ScheduleEvent? _eventFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    try {
      final m = d.data();
      return ScheduleEvent(
        id: d.id,
        title: (m['title'] ?? '') as String,
        start: (m['start'] as Timestamp).toDate(),
        end: (m['end'] as Timestamp).toDate(),
        category: EventCategory.values.firstWhere((c) => c.name == m['category'], orElse: () => EventCategory.personal),
        location: (m['location'] ?? '') as String,
        notes: (m['notes'] ?? '') as String,
        source: (m['source'] ?? '') as String,
        confirmed: (m['confirmed'] ?? true) as bool,
        allDay: (m['allDay'] ?? false) as bool,
        reminder: (m['reminder'] ?? 'なし') as String,
        history: List<String>.from((m['history'] ?? const []) as List),
      );
    } catch (_) {
      return null; // 形が違うデータは読み飛ばす
    }
  }

  String _firestoreMessage(Object e) {
    if (e is FirebaseException && e.code == 'permission-denied') {
      return '保存できません。Firestoreのルールを確認してください';
    }
    return '保存または読み込みができませんでした。通信を確認してください';
  }

  // ---------- ログイン・新規登録・ログアウト ----------
  static String authMessage(String code) => switch (code) {
    'invalid-email' => 'メールアドレスの形式が正しくありません',
    'user-not-found' => 'このメールアドレスは登録されていません',
    'wrong-password' || 'invalid-credential' || 'invalid-login-credentials' => 'メールアドレスまたはパスワードが違います',
    'email-already-in-use' => 'このメールアドレスは既に登録されています。ログインしてください',
    'weak-password' => 'パスワードが短すぎます',
    'too-many-requests' => '試行回数が多すぎます。しばらく待ってからお試しください',
    'network-request-failed' => 'ネットワークにつながりません。電波を確認してください',
    'operation-not-allowed' => 'メール/パスワードのログインが、Firebaseで有効になっていません',
    'user-disabled' => 'このアカウントは無効になっています',
    _ => 'うまくいきませんでした（$code）',
  };
  static const String _timeoutMessage = '応答がありません。電波のよい場所で、もう一度お試しください';

  /// 成功したら null、失敗したら表示用の文章を返す
  Future<String?> signIn(String email, String password) async {
    try {
      await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email.trim(), password: password)
          .timeout(const Duration(seconds: 20));
      return null;
    } on FirebaseAuthException catch (e) {
      return authMessage(e.code);
    } on TimeoutException {
      return _timeoutMessage;
    } catch (_) {
      return 'ログインできませんでした。もう一度お試しください';
    }
  }

  Future<String?> register(String name, String email, String password) async {
    try {
      final cred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email.trim(), password: password)
          .timeout(const Duration(seconds: 20));
      final u = cred.user;
      if (u != null) {
        try { await u.updateDisplayName(name.trim()); } catch (_) {}
        user = AppUser(name: name.trim(), email: u.email ?? email.trim());
        notifyListeners();
      }
      return null;
    } on FirebaseAuthException catch (e) {
      return authMessage(e.code);
    } on TimeoutException {
      return _timeoutMessage;
    } catch (_) {
      return '登録できませんでした。もう一度お試しください';
    }
  }

  Future<String?> sendPasswordReset(String email) async {
    try {
      await FirebaseAuth.instance
          .sendPasswordResetEmail(email: email.trim())
          .timeout(const Duration(seconds: 20));
      return null;
    } on FirebaseAuthException catch (e) {
      return authMessage(e.code);
    } on TimeoutException {
      return _timeoutMessage;
    } catch (_) {
      return '送信できませんでした。もう一度お試しください';
    }
  }

  /// ログアウトの画面のボタンから呼ぶ（デモの状態に戻る）
  Future<void> signOut() async {
    try { await FirebaseAuth.instance.signOut(); } catch (_) {}
  }

  // ---------- デモのデータ ----------
  void _resetToDemo() {
    user = _guest;
    syncError = null;
    events.clear(); changes.clear(); notifications.clear(); imports.clear();
    _seed();
  }

  DateTime _at(int days, int hour, [int minute = 0]) {
    final base = Dates.only(DateTime.now()).add(Duration(days: days));
    return DateTime(base.year, base.month, base.day, hour, minute);
  }
  void _seed() {
    events.addAll([
      ScheduleEvent(id: 'class-today', title: 'アプリ開発演習', start: _at(0,9), end: _at(0,10,30), category: EventCategory.school, location: '神戸・教室A', notes: '卒業制作の画面レビュー'),
      ScheduleEvent(id: 'meeting-today', title: 'チームミーティング', start: _at(0,13,30), end: _at(0,14,30), category: EventCategory.school, location: 'オンライン', notes: '担当作業の確認'),
      ScheduleEvent(id: 'shift-today', title: 'アルバイト', start: _at(0,18), end: _at(0,23), category: EventCategory.work, location: '三宮店', source: 'シフト表（デモ）'),
      ScheduleEvent(id: 'shift-next', title: 'アルバイト', start: _at(1,18), end: _at(1,23), category: EventCategory.work, location: '三宮店', source: '旧シフト表（デモ）'),
      ScheduleEvent(id: 'exam', title: '資格試験の勉強', start: _at(2,11), end: _at(2,13), category: EventCategory.exam, location: '図書館'),
      ScheduleEvent(id: 'coffee', title: '友達とカフェ', start: _at(3,15), end: _at(3,16,30), category: EventCategory.personal, location: '三宮'),
      ScheduleEvent(id: 'osaka', title: '大阪へお出かけ', start: _at(5,10), end: _at(5,18), category: EventCategory.travel, location: '大阪'),
    ]);
    changes.addAll([
      ScheduleChange(id: 'chg1', eventId: 'shift-next', kind: ChangeKind.modified, newStart: _at(1,19), newEnd: _at(1,23), message: '開始時間が1時間変更されている可能性があります'),
      ScheduleChange(id: 'chg2', eventId: 'exam', kind: ChangeKind.duplicate, message: '同じ内容の予定が見つかりました'),
      ScheduleChange(id: 'chg3', eventId: 'coffee', kind: ChangeKind.overlap, message: '別の予定と時間が重なる可能性があります'),
      ScheduleChange(id: 'chg4', eventId: 'osaka', kind: ChangeKind.uncertain, message: '更新元の内容が曖昧です。確認してください'),
      ScheduleChange(id: 'chg5', eventId: 'coffee', kind: ChangeKind.cancellation, message: '取り消しの可能性があります'),
      ScheduleChange(id: 'chg6', eventId: 'exam', kind: ChangeKind.missingDate, message: '元の情報に日付がありません'),
    ]);
    notifications.addAll([
      NotificationItem(id: 'n1', title: '予定の変更候補', message: '明日のアルバイト開始時間を確認してください', createdAt: DateTime.now().subtract(const Duration(minutes: 18)), icon: Icons.compare_arrows_rounded, target: 'changes'),
      NotificationItem(id: 'n2', title: '重複の可能性', message: '同じ予定がすでに登録されています', createdAt: DateTime.now().subtract(const Duration(hours: 2)), icon: Icons.content_copy_rounded, target: 'changes'),
      NotificationItem(id: 'n3', title: '今日の予定', message: 'カレンダーで予定を確認しましょう', createdAt: DateTime.now().subtract(const Duration(hours: 5)), icon: Icons.calendar_today_outlined, target: 'calendar', read: true),
      NotificationItem(id: 'n4', title: '取り込み完了（デモ）', message: 'サンプルシフト表から予定候補を用意しました', createdAt: DateTime.now().subtract(const Duration(days: 1)), icon: Icons.document_scanner_outlined, target: 'scan', read: true),
      NotificationItem(id: 'n5', title: '未確認の読み取り候補', message: 'サンプルの予定候補は登録前に編集・確認が必要です', createdAt: DateTime.now().subtract(const Duration(hours: 8)), icon: Icons.fact_check_outlined, target: 'scan'),
    ]);
    imports.addAll([
      ImportRecord('シフト表_サンプル.png', DateTime.now().subtract(const Duration(days: 1)), 2),
      ImportRecord('学校のお知らせ（デモ）', DateTime.now().subtract(const Duration(days: 3)), 1),
    ]);
  }

  // ---------- 予定（ログイン中は、Firestoreにも保存） ----------
  List<ScheduleEvent> get sortedEvents => [...events]..sort((a,b) => a.start.compareTo(b.start));
  List<ScheduleEvent> onDay(DateTime day) => sortedEvents.where((e) => Dates.sameDay(e.start, day) ||
    (e.start.isBefore(Dates.only(day)) && e.end.isAfter(Dates.only(day)))).toList();
  List<ScheduleEvent> get todayEvents => onDay(DateTime.now());
  ScheduleEvent? get nextEvent {
    final now = DateTime.now();
    for (final e in sortedEvents) { if (e.end.isAfter(now)) return e; }
    return null;
  }
  int get pendingChanges => changes.where((c) => !c.resolved).length;
  int get unreadCount => notifications.where((n) => !n.read).length;
  ScheduleEvent? eventById(String id) { for (final e in events) { if (e.id == id) return e; } return null; }
  void setTab(int i) { currentTab = i; notifyListeners(); }

  void saveEvent(ScheduleEvent event) {
    final uid = _uid;
    var saved = event;
    if (uid != null && saved.id.isEmpty) saved = saved.copyWith(id: _eventsCol(uid).doc().id);
    final index = events.indexWhere((e) => e.id == saved.id);
    if (index < 0) { events.add(saved); } else { events[index] = saved; }
    notifyListeners();
    if (uid != null) {
      _eventsCol(uid).doc(saved.id).set(_eventToMap(saved)).catchError((Object e) {
        syncError = _firestoreMessage(e);
        notifyListeners();
      });
    }
  }

  void deleteEvent(String id) {
    events.removeWhere((e) => e.id == id);
    notifyListeners();
    final uid = _uid;
    if (uid != null) {
      _eventsCol(uid).doc(id).delete().catchError((Object e) {
        syncError = _firestoreMessage(e);
        notifyListeners();
      });
    }
  }

  void resolveChange(ScheduleChange c, {required bool accept}) {
    if (accept && c.kind == ChangeKind.modified && c.newStart != null && c.newEnd != null) {
      final old = eventById(c.eventId);
      if (old != null) saveEvent(old.copyWith(start: c.newStart, end: c.newEnd,
        history: [...old.history, 'デモ変更を承認しました']));
    }
    // Other types require explicit user judgment; 'accept' acknowledges the warning.
    c.resolved = true;
    notifyListeners();
  }

  void markRead(NotificationItem item) {
    item.read = true;
    _readIds.add(item.id);
    notifyListeners();
  }

  void updateProfile({String? name, String? email}) {
    // ログイン中は、メールアドレスはアカウントのものを使う（ここでは変えない）
    user = AppUser(name: name ?? user.name, email: isSignedIn ? user.email : (email ?? user.email));
    notifyListeners();
    if (isSignedIn && name != null && name.trim().isNotEmpty) {
      FirebaseAuth.instance.currentUser?.updateDisplayName(name.trim()).catchError((Object _) {});
    }
  }
  void setLanguage(String value) {
    language = value;
    _buildReminders(); // お知らせの言葉も、言語に合わせて作り直す
    notifyListeners();
  }
  void setNotifications(bool value) { notificationsEnabled = value; notifyListeners(); }
  void setThemePreference(bool value) { darkPreference = value; notifyListeners(); }
  void saveCandidates(List<ExtractedEventCandidate> candidates) {
    final picked = candidates.where((c) => c.selected).toList();
    for (final candidate in picked) {
      saveEvent(candidate.event.copyWith(confirmed: true));
    }
    imports.insert(0, ImportRecord(picked.isEmpty ? '取り込み' : picked.first.event.source, DateTime.now(), picked.length));
    notifyListeners();
  }
}

class AppScope extends InheritedNotifier<AppController> {
  const AppScope({super.key, required AppController controller, required super.child}) : super(notifier: controller);
  static AppController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope is required');
    return scope!.notifier!;
  }
}