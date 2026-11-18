import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:firebase_ai/firebase_ai.dart';
import '../../core/i18n/lang.dart';
import '../../models/models.dart';

/// 読み取りに使う1ページ分の写真
class ScanPage {
  final Uint8List bytes;
  final String mimeType;
  final String name;
  const ScanPage(this.bytes, this.mimeType, this.name);
}

/// 写真や文章を、AI（Gemini）で読み取って、予定の候補にする
class AiEventReader {
  AiEventReader._();

  /// 使うAIのモデル（上から順に使う）
  /// 上限になった・混んでいる・名前が見つからないときは、次のモデルに切り替える
  static const models = [
    'gemini-3.5-flash',      // 表では「Gemini 3.6 Flash」：1日20回
    'gemini-3.8-flash',      // 1日20回
    'gemini-3-flash',        // 1日20回
    'gemini-2.5-flash',      // 1日20回
    'gemini-3.5-flash-lite', // 1日500回（少し精度が下がる）
    'gemini-3.1-flash-lite', // 1日500回（少し精度が下がる）
    'gemini-2.5-flash-lite', // 1日20回
  ];

  /// 最後に使ったモデル（エラーの表示用）
  static String modelName = models.first;

  /// しばらく使わないモデルと、使えるようになる時刻
  static final Map<String, DateTime> _skipUntil = {};

  /// 1日の回数が戻る時刻（太平洋時間の夜0時 ＝ 世界標準時の朝8時。日本時間の夕方5時）
  static DateTime _nextDailyReset() {
    final now = DateTime.now().toUtc();
    var reset = DateTime.utc(now.year, now.month, now.day, 8);
    if (!reset.isAfter(now)) reset = reset.add(const Duration(days: 1));
    return reset;
  }

  /// このモデルを、しばらく飛ばすことにする
  static void _skip(String name, Object e) {
    final s = e.toString();
    final DateTime until;
    if (_isQuota(e)) {
      until = s.contains('PerMinute')
        ? DateTime.now().toUtc().add(const Duration(minutes: 1)) // 1分の上限
        : _nextDailyReset(); // 1日の上限
    } else if (_isBusy(e)) {
      until = DateTime.now().toUtc().add(const Duration(minutes: 5)); // 混んでいる
    } else {
      until = DateTime.now().toUtc().add(const Duration(days: 1)); // 名前が見つからない
    }
    _skipUntil[name] = until;
  }

  static bool _skipped(String name) {
    final until = _skipUntil[name];
    if (until == null) return false;
    if (DateTime.now().toUtc().isAfter(until)) { _skipUntil.remove(name); return false; }
    return true;
  }

  static final _schema = Schema(SchemaType.object, properties: {
    'events': Schema(SchemaType.array, items: Schema(SchemaType.object, properties: {
      'title': Schema(SchemaType.string),
      'date': Schema(SchemaType.string),
      'start': Schema(SchemaType.string),
      'end': Schema(SchemaType.string, nullable: true),
      'location': Schema(SchemaType.string),
      'category': Schema(SchemaType.string),
      'note': Schema(SchemaType.string),
    })),
  });

  static GenerativeModel _model(String name) => FirebaseAI.googleAI().generativeModel(
    model: name,
    generationConfig: GenerationConfig(responseMimeType: 'application/json', responseSchema: _schema),
  );

  /// 回数の上限になった
  static bool _isQuota(Object e) {
    final s = e.toString();
    return s.contains('429') || s.contains('quota') || s.contains('RESOURCE_EXHAUSTED');
  }

  /// モデルの名前が見つからない
  static bool _isNotFound(Object e) {
    final s = e.toString();
    return s.contains('404') || s.contains('not found') || s.contains('NOT_FOUND') || s.contains('is not supported');
  }

  /// Google側が混んでいる・一時的に調子が悪い
  static bool _isBusy(Object e) {
    final s = e.toString();
    return s.contains('high demand') || s.contains('overloaded') || s.contains('UNAVAILABLE')
      || s.contains('[500]') || s.contains('[502]') || s.contains('[503]') || s.contains('[504]')
      || s.contains('"code": 500') || s.contains('"code": 503');
  }

  static Future<List<ExtractedEventCandidate>> read({
    List<ScanPage> pages = const [],
    String text = '',
    List<String> keywords = const [],
    DateTime? now,
  }) async {
    final base = now ?? DateTime.now();
    final parts = <Part>[
      TextPart(_prompt(base, keywords, text)),
      for (final p in pages) InlineDataPart(p.mimeType, p.bytes),
    ];
    // 使い切ったモデルは飛ばす（全部飛ばす対象なら、念のため全部試す）
    var order = models.where((m) => !_skipped(m)).toList();
    if (order.isEmpty) order = [...models];

    Object? last;
    for (final name in order) {
      modelName = name;
      try {
        final response = await _model(name)
            .generateContent([Content.multi(parts)])
            .timeout(const Duration(seconds: 90));
        return _toCandidates(response.text ?? '', base);
      } catch (e) {
        // 上限・混雑・名前が見つからない → 覚えておいて、次のモデルへ
        if (_isQuota(e) || _isBusy(e) || _isNotFound(e)) { _skip(name, e); last = e; continue; }
        rethrow;
      }
    }
    throw last ?? Exception('quota');
  }

  static String _prompt(DateTime now, List<String> keywords, String text) {
    const week = ['月', '火', '水', '木', '金', '土', '日'];
    final today = '${now.year}-${_two(now.month)}-${_two(now.day)}（${week[now.weekday - 1]}）';
    final key = keywords.isEmpty ? 'なし（すべての予定を出す）' : keywords.map((k) => '「$k」').join('、');
    final b = StringBuffer()
      ..writeln('あなたは、シフト表・お知らせ・案内文から予定を読み取るアシスタントです。')
      ..writeln('添付の写真（複数ある場合は、同じ資料の続きや補足です）と、下の文章から予定を取り出してください。')
      ..writeln()
      ..writeln('【条件】')
      ..writeln('- 今日は $today です。年が書かれていない日付は、今日から考えて最も自然な年にしてください。')
      ..writeln('- 絞り込みキーワード：$key')
      ..writeln('- キーワードがある場合は、その名前や言葉が書かれている予定だけを出してください。'
          '表形式のシフト表では、名前が書かれているマスの位置から、日付（行や列の見出し）と時間帯（時刻の目盛りやマスの範囲）を読み取ってください。')
      ..writeln('- 名前の表記ゆれ（カタカナ・ローマ字・大文字小文字・名字だけ・下の名前だけ）は、同じ人として扱ってください。')
      ..writeln('- date は YYYY-MM-DD、start と end は24時間の HH:mm で書いてください。終了時刻が分からない場合は end を null にしてください。')
      ..writeln('- 日をまたぐ予定（例：22:00〜翌2:00）は、開始の日付を date にして、end は 02:00 のように書いてください。')
      ..writeln('- category は work（バイト・仕事）、school（学校）、exam（試験）、travel（お出かけ）、personal（その他）のどれかにしてください。')
      ..writeln('- title は、何の予定か分かる短い名前にしてください（例：シフト勤務（〇〇店））。location は、書かれていなければ空文字にしてください。')
      ..writeln('- 読み取りに自信がない部分があれば、note に「何を確認すべきか」を短く書いてください。問題なければ空文字にしてください。')
      ..writeln('- 書かれていない予定を、推測で作らないでください。予定が見つからなければ、events は空の配列にしてください。');
    if (text.trim().isNotEmpty) {
      b
        ..writeln()
        ..writeln('【文章】')
        ..writeln(text.trim());
    }
    return b.toString();
  }

  static List<ExtractedEventCandidate> _toCandidates(String raw, DateTime base) {
    final cleaned = raw.replaceAll(RegExp(r'^```(?:json)?|```$', multiLine: true), '').trim();
    final decoded = jsonDecode(cleaned);
    final list = (decoded is Map && decoded['events'] is List) ? decoded['events'] as List : const [];
    final out = <ExtractedEventCandidate>[];
    final stamp = base.microsecondsSinceEpoch;
    for (final item in list) {
      if (item is! Map) continue;
      final date = DateTime.tryParse('${item['date'] ?? ''}'.trim());
      if (date == null) continue;
      final notes = <String>[];
      final note = '${item['note'] ?? ''}'.trim();
      if (note.isNotEmpty) notes.add(note);

      final start = _hm(item['start']);
      DateTime s;
      DateTime e;
      var allDay = false;
      if (start == null) {
        allDay = true;
        s = DateTime(date.year, date.month, date.day);
        e = DateTime(date.year, date.month, date.day, 23, 59);
      } else {
        s = DateTime(date.year, date.month, date.day, start.$1, start.$2);
        final end = _hm(item['end']);
        if (end == null) {
          e = s.add(const Duration(hours: 1));
          notes.add(tr('終了時間が読み取れなかったため、1時間の予定にしています', 'The end time could not be read, so it is set to 1 hour'));
        } else {
          e = DateTime(date.year, date.month, date.day, end.$1, end.$2);
          if (!e.isAfter(s)) e = e.add(const Duration(days: 1)); // 日をまたぐ予定
        }
      }

      final id = 'ai-$stamp-${out.length}';
      final category = EventCategory.values.firstWhere(
        (c) => c.name == '${item['category']}', orElse: () => EventCategory.personal);
      final title = '${item['title'] ?? ''}'.trim();
      final joined = notes.isEmpty ? null : notes.join('\n');
      out.add(ExtractedEventCandidate(
        id: id,
        event: ScheduleEvent(
          id: id,
          title: title.isEmpty ? category.label : title,
          start: s,
          end: e,
          category: category,
          location: '${item['location'] ?? ''}'.trim(),
          source: 'AIの読み取り',
          confirmed: joined == null,
          allDay: allDay,
        ),
        uncertainty: joined,
      ));
    }
    return out;
  }

  static (int, int)? _hm(Object? v) {
    final m = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch('${v ?? ''}'.trim());
    if (m == null) return null;
    final h = int.parse(m[1]!), n = int.parse(m[2]!);
    if (h > 24 || n > 59) return null;
    return (h, n);
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  /// エラーを、画面に出す文章にする（最後に、詳しい内容も付ける）
  static String errorMessage(Object e) {
    final s = e.toString();
    String msg;
    if (e is TimeoutException) {
      msg = tr('時間がかかりすぎました。写真の枚数を減らすか、通信のよい場所でお試しください',
        'It took too long. Try fewer photos or a better connection.');
    } else if (e is FormatException) {
      msg = tr('AIの返事を読み取れませんでした。もう一度お試しください', 'Could not understand the AI’s reply. Please try again.');
    } else if (_isBusy(e)) {
      msg = tr('いま、GoogleのAIがとても混んでいます。回数は使っていないので、少し時間をおいて、もう一度お試しください',
        'Google’s AI is very busy right now. No scan was used. Please wait a little and try again.');
    } else if (s.contains('App Check')) {
      msg = tr('App Checkが「適用」になっています。Firebaseコンソールの App Check →「API」→「Firebase AI Logic」で、適用を解除してください',
        'App Check is enforced. Turn off enforcement for Firebase AI Logic in the Firebase console.');
    } else if (s.contains('free tier')) {
      msg = tr('このFirebaseプロジェクトでは、Geminiの無料枠が使えません', 'This Firebase project cannot use the Gemini free tier.');
    } else if (_isQuota(e)) {
      msg = tr('アプリ全体の、今日のAIの利用回数を使い切りました。夕方5時ごろに、また使えるようになります',
        'The app has used all of today’s AI quota. It will be available again around 5:00 PM (JST).');
    } else if (s.contains('403') || s.contains('PERMISSION_DENIED') || s.contains('has not been used')) {
      msg = tr('FirebaseのAI機能（AI Logic）が、まだ有効になっていません。コンソールで有効にしてください',
        'Firebase AI Logic is not enabled yet. Please enable it in the console.');
    } else if (_isNotFound(e)) {
      msg = tr('使えるAIのモデルが見つかりませんでした。ai_event_reader.dart のモデル名を確認してください',
        'No usable AI model was found. Check the model names in ai_event_reader.dart.');
    } else {
      msg = tr('AIで読み取れませんでした', 'Could not read it with the AI');
    }
    return '$msg\n\n（${tr('詳しい内容', 'Details')}：$s）';
  }
}