import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

/// 2026-10-11 「백퍼 일본어 회화」 456개 표현(원어민 음성 + 대화문).
/// 대화문은 원어민 음성을 받아 적어 교정·번역한 것이다. 데이터: assets/hyakupa/hyakupa.json
const hyakupaAsset = 'assets/hyakupa/hyakupa.json';

/// 표현 번호 → 음성 파일(1 → assets/hyakupa_audio/001.mp3)
String hyakupaAudioAsset(int number) =>
    'assets/hyakupa_audio/${number.toString().padLeft(3, '0')}.mp3';

class HyakupaLine {
  const HyakupaLine(
      {required this.speaker,
      required this.start,
      required this.end,
      required this.japanese,
      required this.korean});
  final String speaker, japanese, korean;
  final double start, end;

  Duration get startAt => Duration(milliseconds: (start * 1000).round());
  Duration get endAt => Duration(milliseconds: (end * 1000).round());
  double get length => end - start;

  factory HyakupaLine.fromJson(Map<String, dynamic> j) => HyakupaLine(
        speaker: j['sp'] as String? ?? 'A',
        start: (j['s'] as num).toDouble(),
        end: (j['e'] as num).toDouble(),
        japanese: j['ja'] as String,
        korean: j['ko'] as String? ?? '',
      );
}

class HyakupaTrack {
  const HyakupaTrack({
    required this.number,
    required this.title,
    required this.meaning,
    required this.note,
    required this.titleStart,
    required this.titleEnd,
    required this.duration,
    required this.dialogs,
  });
  final int number;

  /// 핵심 표현(예: シャッターチャンス, ね / な)
  final String title;
  final String meaning, note;

  /// 핵심 표현을 읽는 구간(초)
  final double titleStart, titleEnd;
  final double duration;

  /// 대화(보통 1개, 표현이 둘이면 2개)
  final List<List<HyakupaLine>> dialogs;

  String get id => 'hp$number';
  String get label => number.toString().padLeft(3, '0');
  String get audio => hyakupaAudioAsset(number);
  List<HyakupaLine> get lines => [for (final d in dialogs) ...d];

  /// 「ね / な」 → [ね, な]
  List<String> get variants => [
        for (final v in title.split('/'))
          if (v.trim().isNotEmpty) v.trim()
      ];

  /// 핵심 표현이 들어 있는 대사(빈칸 문제용). 없으면 null.
  (HyakupaLine, String)? get blankLine {
    final vs = [...variants]..sort((a, b) => b.length.compareTo(a.length));
    for (final l in lines) {
      for (final v in vs) {
        if (v.length >= 2 && l.japanese.contains(v)) return (l, v);
      }
    }
    return null;
  }

  factory HyakupaTrack.fromJson(Map<String, dynamic> j) {
    final h = (j['h'] as List<dynamic>?)?.cast<num>() ?? const [0, 0];
    return HyakupaTrack(
      number: j['no'] as int,
      title: j['title'] as String,
      meaning: j['meaning'] as String? ?? '',
      note: j['note'] as String? ?? '',
      titleStart: h[0].toDouble(),
      titleEnd: h[1].toDouble(),
      duration: (j['dur'] as num?)?.toDouble() ?? 30,
      dialogs: [
        for (final d in (j['d'] as List<dynamic>? ?? const []))
          [
            for (final l in d as List<dynamic>)
              HyakupaLine.fromJson(l as Map<String, dynamic>)
          ]
      ],
    );
  }
}

/// 20개씩 묶은 단원.
class HyakupaUnit {
  const HyakupaUnit(this.number, this.tracks);
  final int number;
  final List<HyakupaTrack> tracks;
  String get range => '${tracks.first.label}–${tracks.last.label}';
  String get title => tracks.first.number <= 100 ? '말투 · 감탄사 · 종조사' : '회화체 표현';
}

class HyakupaBook {
  HyakupaBook(this.tracks)
      : units = [
          for (var i = 0; i < tracks.length; i += unitSize)
            HyakupaUnit(i ~/ unitSize + 1,
                tracks.sublist(i, min(i + unitSize, tracks.length)))
        ];
  static const int unitSize = 20;
  final List<HyakupaTrack> tracks;
  final List<HyakupaUnit> units;

  HyakupaTrack? byNumber(int n) {
    for (final t in tracks) {
      if (t.number == n) return t;
    }
    return null;
  }

  /// 표현·뜻·대사에서 찾기.
  List<HyakupaTrack> search(String q) {
    final s = q.trim();
    if (s.isEmpty) return const [];
    final n = int.tryParse(s);
    return tracks.where((t) {
      if (n != null && t.number == n) return true;
      if (t.title.contains(s) || t.meaning.contains(s)) return true;
      return t.lines.any((l) => l.japanese.contains(s) || l.korean.contains(s));
    }).toList();
  }

  factory HyakupaBook.parse(String raw) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    return HyakupaBook([
      for (final t in (j['tracks'] as List<dynamic>))
        HyakupaTrack.fromJson(t as Map<String, dynamic>)
    ]);
  }

  static HyakupaBook? _cache;
  static Future<HyakupaBook> load() async =>
      _cache ??= HyakupaBook.parse(await rootBundle.loadString(hyakupaAsset));
}

/// 2026-10-11 표현별 기억 단계(간격 반복) + 즐겨찾기.
class HyakupaProgress {
  HyakupaProgress(this._prefs);
  final SharedPreferences _prefs;
  static const _prefix = 'hyakupa.v1.';
  static const _favKey = 'hyakupa.v1.favorites';
  static const int masteredStage = 5;
  static const int maxStage = 7;
  static const List<Duration> intervals = [
    Duration.zero,
    Duration(minutes: 10),
    Duration(days: 1),
    Duration(days: 3),
    Duration(days: 7),
    Duration(days: 14),
    Duration(days: 30),
    Duration(days: 90),
  ];

  (int, int) _read(int n) {
    final raw = _prefs.getString('$_prefix$n');
    if (raw == null) return (0, 0);
    final p = raw.split('|');
    return (int.tryParse(p.first) ?? 0, p.length > 1 ? int.tryParse(p[1]) ?? 0 : 0);
  }

  Future<void> _write(int n, int stage, DateTime due) =>
      _prefs.setString('$_prefix$n', '$stage|${due.millisecondsSinceEpoch}');

  int stage(int n) => _read(n).$1;
  bool isNew(int n) => stage(n) == 0;
  bool isMastered(int n) => stage(n) >= masteredStage;
  DateTime dueAt(int n) => DateTime.fromMillisecondsSinceEpoch(_read(n).$2);
  bool isDue(int n, DateTime now) => !isNew(n) && !dueAt(n).isAfter(now);

  /// 대화를 다 듣고 「배웠어요」를 눌렀을 때.
  Future<void> markLearned(int n, DateTime now) async {
    if (isNew(n)) await _write(n, 1, now.add(intervals[1]));
  }

  Future<void> record(int n, bool correct, DateTime now) async {
    final s = stage(n);
    if (correct) {
      final next = min(max(s, 1) + 1, maxStage);
      await _write(n, next, now.add(intervals[next]));
    } else {
      await _write(n, 1, now.add(intervals[1]));
    }
  }

  List<HyakupaTrack> due(List<HyakupaTrack> all, DateTime now) =>
      all.where((t) => isDue(t.number, now)).toList()
        ..sort((a, b) => dueAt(a.number).compareTo(dueAt(b.number)));

  int learnedCount(List<HyakupaTrack> all) =>
      all.where((t) => !isNew(t.number)).length;
  int masteredCount(List<HyakupaTrack> all) =>
      all.where((t) => isMastered(t.number)).length;

  double unitRatio(HyakupaUnit u) {
    if (u.tracks.isEmpty) return 0;
    final sum = u.tracks
        .map((t) => min(stage(t.number), masteredStage))
        .fold<int>(0, (a, b) => a + b);
    return sum / (u.tracks.length * masteredStage);
  }

  /// 아직 배우지 않은 첫 표현.
  HyakupaTrack? nextNew(HyakupaBook b) {
    for (final t in b.tracks) {
      if (isNew(t.number)) return t;
    }
    return null;
  }

  Set<int> get favorites => {
        for (final s in _prefs.getStringList(_favKey) ?? const <String>[])
          if (int.tryParse(s) != null) int.parse(s)
      };
  bool isFavorite(int n) => favorites.contains(n);
  Future<void> toggleFavorite(int n) {
    final f = favorites;
    if (!f.remove(n)) f.add(n);
    return _prefs.setStringList(_favKey, [for (final x in f.toList()..sort()) '$x']);
  }
}

enum HyakupaQuizKind {
  /// 표현 → 뜻
  meaning,

  /// 뜻 → 표현
  expression,

  /// 대사 빈칸에 들어갈 표현
  blank,

  /// 표현 음성 듣고 뜻 고르기
  listen,
}

class HyakupaQuestion {
  const HyakupaQuestion(
      {required this.kind,
      required this.track,
      required this.options,
      required this.answer,
      this.line,
      this.blanked = ''});
  final HyakupaQuizKind kind;
  final HyakupaTrack track;
  final List<String> options;
  final int answer;

  /// 빈칸 문제의 대사
  final HyakupaLine? line;

  /// 빈칸으로 바꾼 일본어 대사
  final String blanked;

  String get prompt => switch (kind) {
        HyakupaQuizKind.meaning => '이 표현의 뜻은?',
        HyakupaQuizKind.expression => '「${track.meaning}」을 일본어로?',
        HyakupaQuizKind.blank => '빈칸에 들어갈 표현은?',
        HyakupaQuizKind.listen => '듣고 뜻을 고르세요',
      };
  bool get optionsAreJapanese =>
      kind == HyakupaQuizKind.expression || kind == HyakupaQuizKind.blank;
}

class HyakupaQuizBuilder {
  HyakupaQuizBuilder(this.pool, {Random? random}) : _rnd = random ?? Random();
  final List<HyakupaTrack> pool;
  final Random _rnd;

  List<HyakupaQuestion> build(List<HyakupaTrack> targets) {
    const kinds = [
      HyakupaQuizKind.blank,
      HyakupaQuizKind.meaning,
      HyakupaQuizKind.listen,
      HyakupaQuizKind.expression,
    ];
    final order = [...targets]..shuffle(_rnd);
    return [
      for (var i = 0; i < order.length; i++)
        question(order[i], kinds[(i + _rnd.nextInt(kinds.length)) % kinds.length])
    ];
  }

  HyakupaQuestion question(HyakupaTrack t, HyakupaQuizKind kind) {
    final blank = t.blankLine;
    if (kind == HyakupaQuizKind.blank && blank == null) {
      kind = HyakupaQuizKind.meaning;
    }
    switch (kind) {
      case HyakupaQuizKind.meaning:
      case HyakupaQuizKind.listen:
        return _choices(t, kind, (x) => x.meaning);
      case HyakupaQuizKind.expression:
        return _choices(t, kind, (x) => x.title);
      case HyakupaQuizKind.blank:
        final (line, v) = blank!;
        final q = _choices(t, kind, (x) => x.variants.first,
            right: v,
            exclude: (x) =>
                x.variants.contains(v) || line.japanese.contains(x.variants.first));
        return HyakupaQuestion(
            kind: kind,
            track: t,
            options: q.options,
            answer: q.answer,
            line: line,
            blanked: line.japanese.replaceFirst(v, '＿＿＿'));
    }
  }

  HyakupaQuestion _choices(
      HyakupaTrack t, HyakupaQuizKind kind, String Function(HyakupaTrack) label,
      {String? right, bool Function(HyakupaTrack)? exclude}) {
    final correct = right ?? label(t);
    final used = <String>{correct};
    final wrong = <String>[];
    // 가까운 번호(같은 단원)의 표현을 먼저 오답으로 쓴다(비슷한 종류라 헷갈리기 쉬움).
    final near = pool.where((x) => (x.number - t.number).abs() <= 15).toList()..shuffle(_rnd);
    final far = [...pool]..shuffle(_rnd);
    for (final x in [...near, ...far]) {
      if (wrong.length >= 3) break;
      final l = label(x);
      if (x.number == t.number || l.isEmpty || used.contains(l)) continue;
      if (exclude?.call(x) ?? false) continue;
      wrong.add(l);
      used.add(l);
    }
    final opts = [correct, ...wrong]..shuffle(_rnd);
    return HyakupaQuestion(
        kind: kind, track: t, options: opts, answer: opts.indexOf(correct));
  }
}
