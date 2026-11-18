import '../../models/models.dart';

/// 貼り付けた文章から、予定の候補を作ります。
/// 端末の中だけで動き、文章を外部には送りません。
///
/// 読み取れる例:
///   11/15(土) 18:00-23:00 アルバイト @三宮店
///   11月16日 22:00〜02:00 夜勤（日をまたぐ予定は、翌日の終了時間にします）
///   明日 9時〜10時半 授業
///   2026/12/1 試験
class TextEventParser {
  TextEventParser._();

  static List<ExtractedEventCandidate> parse(String text, {DateTime? now}) {
    final base = now ?? DateTime.now();
    final today = DateTime(base.year, base.month, base.day);
    final stamp = base.microsecondsSinceEpoch;
    final out = <ExtractedEventCandidate>[];
    for (final raw in _normalize(text).split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      final c = _parseLine(line, today, 'scan-$stamp-${out.length}');
      if (c != null) out.add(c);
    }
    return out;
  }

  // ---------- 1行を読む ----------
  static ExtractedEventCandidate? _parseLine(String original, DateTime today, String id) {
    var rest = original;
    final notes = <String>[];

    DateTime? date;
    final d = _findDate(rest, today);
    if (d != null) {
      date = d.date;
      rest = d.rest;
      if (d.note != null) notes.add(d.note!);
    }

    final t = _findTime(rest);
    if (t != null) {
      rest = t.rest;
      if (t.note != null) notes.add(t.note!);
    }

    // 日付も時間もない行は、予定とみなさない
    if (date == null && t == null) return null;

    var dateMissing = false;
    if (date == null) {
      date = today;
      dateMissing = true;
      notes.add('日付が書かれていないため、今日として読み取りました');
    }

    DateTime start;
    DateTime end;
    var allDay = false;
    if (t == null) {
      allDay = true;
      start = DateTime(date.year, date.month, date.day);
      end = DateTime(date.year, date.month, date.day, 23, 59);
    } else {
      start = DateTime(date.year, date.month, date.day, t.sh, t.sm);
      end = DateTime(date.year, date.month, date.day, t.eh, t.em);
      // 夜勤など、日をまたぐ予定
      if (!end.isAfter(start)) end = end.add(const Duration(days: 1));
    }

    var location = '';
    final loc = _location.firstMatch(rest);
    if (loc != null) {
      location = loc.group(1)!;
      rest = rest.replaceRange(loc.start, loc.end, ' ');
    }

    final category = _guess(original);
    final cleaned = _cleanTitle(rest);
    final title = cleaned.isEmpty ? category.label : cleaned;
    final note = notes.isEmpty ? null : notes.join('\n');

    return ExtractedEventCandidate(
      id: id,
      event: ScheduleEvent(
        id: id,
        title: title,
        start: start,
        end: end,
        category: category,
        location: location,
        source: '貼り付けた文章',
        confirmed: note == null,
        allDay: allDay,
      ),
      selected: !dateMissing, // 日付がない候補は、確認してから選ぶ
      uncertainty: note,
    );
  }

  // ---------- 日付 ----------
  static final _ymd = RegExp(r'(\d{4})[/.\-年](\d{1,2})[/.\-月](\d{1,2})日?');
  static final _md = RegExp(r'(?<!\d)(\d{1,2})[/月](\d{1,2})(?:日|(?![\d:時]))');
  static final _relative = RegExp(r'(明後日|あさって|明日|今日|本日)');
  static final _dayOnly = RegExp(r'(?<!\d)(\d{1,2})日(?![間目\d])');

  static _DateHit? _findDate(String line, DateTime today) {
    var m = _ymd.firstMatch(line);
    if (m != null) {
      final y = int.parse(m[1]!);
      final mo = int.parse(m[2]!);
      final d = int.parse(m[3]!);
      if (_validDate(y, mo, d)) return _DateHit(DateTime(y, mo, d), null, _cut(line, m));
    }

    m = _md.firstMatch(line);
    if (m != null) {
      final mo = int.parse(m[1]!);
      final d = int.parse(m[2]!);
      if (_validDate(today.year, mo, d)) {
        var date = DateTime(today.year, mo, d);
        // 30日以上前の日付は、来年のものとみなす
        if (date.isBefore(today.subtract(const Duration(days: 30)))) {
          date = DateTime(today.year + 1, mo, d);
        }
        return _DateHit(date, null, _cut(line, m));
      }
    }

    m = _relative.firstMatch(line);
    if (m != null) {
      final w = m[1]!;
      final days = (w == '明後日' || w == 'あさって') ? 2 : (w == '明日' ? 1 : 0);
      return _DateHit(DateTime(today.year, today.month, today.day + days), null, _cut(line, m));
    }

    m = _dayOnly.firstMatch(line);
    if (m != null) {
      final d = int.parse(m[1]!);
      if (d >= 1 && d <= 31) {
        var date = DateTime(today.year, today.month, d);
        if (date.day == d && date.isBefore(today)) date = DateTime(today.year, today.month + 1, d);
        if (date.day == d) {
          return _DateHit(date, '月が書かれていないため、${date.month}月として読み取りました', _cut(line, m));
        }
      }
    }
    return null;
  }

  static bool _validDate(int y, int m, int d) {
    if (m < 1 || m > 12 || d < 1 || d > 31) return false;
    final x = DateTime(y, m, d);
    return x.month == m && x.day == d;
  }

  // ---------- 時間 ----------
  static const _noEnd = '終了時間が書かれていないため、1時間の予定として読み取りました';
  static final _rangeColon = RegExp(r'(\d{1,2}):(\d{2})\s*(?:~|-|から)\s*(\d{1,2}):(\d{2})');
  static final _rangeKanji = RegExp(r'(\d{1,2})時(半|\d{1,2}分?)?\s*(?:~|-|から)\s*(\d{1,2})時(半|\d{1,2}分?)?');
  static final _rangeBare = RegExp(r'(?<![\d:])(\d{1,2})\s*(?:~|-)\s*(\d{1,2})(?![\d:])');
  static final _singleColon = RegExp(r'(\d{1,2}):(\d{2})');
  static final _singleKanji = RegExp(r'(\d{1,2})時(半|\d{1,2}分?)?');

  static _TimeHit? _findTime(String line) {
    var m = _rangeColon.firstMatch(line);
    if (m != null) {
      final h1 = int.parse(m[1]!), n1 = int.parse(m[2]!), h2 = int.parse(m[3]!), n2 = int.parse(m[4]!);
      if (_okTime(h1, n1) && _okTime(h2, n2)) return _TimeHit(h1, n1, h2, n2, null, _cut(line, m));
    }

    m = _rangeKanji.firstMatch(line);
    if (m != null) {
      final h1 = int.parse(m[1]!), n1 = _min(m[2]), h2 = int.parse(m[3]!), n2 = _min(m[4]);
      if (_okTime(h1, n1) && _okTime(h2, n2)) return _TimeHit(h1, n1, h2, n2, null, _cut(line, m));
    }

    m = _rangeBare.firstMatch(line);
    if (m != null) {
      final h1 = int.parse(m[1]!), h2 = int.parse(m[2]!);
      if (_okTime(h1, 0) && _okTime(h2, 0)) {
        return _TimeHit(h1, 0, h2, 0, '「${m[0]}」を、時間として読み取りました', _cut(line, m));
      }
    }

    m = _singleColon.firstMatch(line);
    if (m != null) {
      final h = int.parse(m[1]!), n = int.parse(m[2]!);
      if (_okTime(h, n)) return _TimeHit(h, n, h + 1, n, _noEnd, _cut(line, m));
    }

    m = _singleKanji.firstMatch(line);
    if (m != null) {
      final h = int.parse(m[1]!), n = _min(m[2]);
      if (_okTime(h, n)) return _TimeHit(h, n, h + 1, n, _noEnd, _cut(line, m));
    }
    return null;
  }

  static bool _okTime(int h, int m) => h >= 0 && h <= 24 && m >= 0 && m < 60;

  static int _min(String? g) {
    if (g == null) return 0;
    if (g == '半') return 30;
    return int.tryParse(g.replaceAll('分', '')) ?? 0;
  }

  // ---------- 場所・タイトル・カテゴリ ----------
  static final _location = RegExp(r'(?:@|場所[:：]?)\s*([^\s,、]+)');

  static String _cleanTitle(String s) {
    var t = s.replaceAll(RegExp(r'\([月火水木金土日祝]\)'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    t = t.replaceAll(RegExp(r'^[\s、,:\-~・/|]+'), '').replaceAll(RegExp(r'[\s、,:\-~・/|]+$'), '');
    return t;
  }

  static EventCategory _guess(String s) {
    bool has(List<String> words) => words.any(s.contains);
    if (has(['バイト', 'アルバイト', 'シフト', '勤務', '出勤', '夜勤'])) return EventCategory.work;
    if (has(['試験', 'テスト', '検定', '資格', '模試', '面接'])) return EventCategory.exam;
    if (has(['授業', '講義', '学校', 'ゼミ', 'ミーティング', '課題', '提出', '演習', '説明会'])) return EventCategory.school;
    if (has(['旅行', 'お出かけ', '観光', '日帰り', '遠足'])) return EventCategory.travel;
    return EventCategory.personal;
  }

  // ---------- 共通 ----------
  static String _cut(String line, RegExpMatch m) => line.replaceRange(m.start, m.end, ' ');

  /// 全角の数字・記号を、半角にそろえる
  static String _normalize(String s) {
    final b = StringBuffer();
    for (final r in s.runes) {
      if (r >= 0xFF10 && r <= 0xFF19) {
        b.writeCharCode(r - 0xFF10 + 0x30); // ０-９
      } else if (r == 0xFF1A) {
        b.write(':'); // ：
      } else if (r == 0xFF0F) {
        b.write('/'); // ／
      } else if (r == 0xFF20) {
        b.write('@'); // ＠
      } else if (r == 0xFF08) {
        b.write('('); // （
      } else if (r == 0xFF09) {
        b.write(')'); // ）
      } else if (r == 0x301C || r == 0xFF5E) {
        b.write('~'); // 〜 ～
      } else if (r == 0x2013 || r == 0x2014 || r == 0x2015 || r == 0xFF0D) {
        b.write('-'); // – — ― －
      } else if (r == 0x3000) {
        b.write(' '); // 全角スペース
      } else {
        b.writeCharCode(r);
      }
    }
    return b.toString().replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  }
}

class _DateHit {
  final DateTime date;
  final String? note;
  final String rest;
  const _DateHit(this.date, this.note, this.rest);
}

class _TimeHit {
  final int sh, sm, eh, em;
  final String? note;
  final String rest;
  const _TimeHit(this.sh, this.sm, this.eh, this.em, this.note, this.rest);
}