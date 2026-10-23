import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:kioku_japanese/services/news_service.dart';
import 'package:kioku_japanese/services/review_scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 2026-10-09 「딱! 한권 JLPT 단어장 N4」 MP3(DAY01~30) 단어장 데이터.
/// 녹음은 「일본어 단어 → 한국어 뜻」 순서이며, 단어마다 두 구간의 시각을 가지고 있어
/// 일본어 발음·한국어 뜻을 원어민 음성으로 따로 들을 수 있다.
const n4WordbookAsset = 'assets/n4_wordbook/words.json';

Duration _sec(Object? v) =>
    Duration(milliseconds: ((v as num) * 1000).round());

class AudioSpan {
  const AudioSpan(this.start, this.end);
  final Duration start, end;
  Duration get length => end - start;
  static AudioSpan? fromJson(Object? raw) => raw is List && raw.length == 2
      ? AudioSpan(_sec(raw[0]), _sec(raw[1]))
      : null;
}

/// 2026-10-10 단어 속 한자 한 글자 풀이(한국 훈음 + 음독·훈독).
class N4Kanji {
  const N4Kanji(this.char, this.hunEum, this.on, this.kun);
  final String char, hunEum, on, kun;
}

class N4Word {
  const N4Word({
    required this.id,
    required this.day,
    required this.japanese,
    required this.reading,
    required this.korean,
    required this.audio,
    required this.jaSpan,
    this.koSpan,
    this.exampleJapanese,
    this.exampleKorean,
    this.kanji = const [],
  });
  final String id, japanese, reading, korean;

  /// 2026-10-10 한자 풀이(가나 단어는 빈 목록).
  final List<N4Kanji> kanji;
  final int day;

  /// 이 단어가 들어 있는 DAY 녹음 파일.
  final String audio;
  final AudioSpan jaSpan;
  final AudioSpan? koSpan;
  final String? exampleJapanese, exampleKorean;

  /// 표기와 읽기가 같으면(가나 단어) 후리가나를 따로 보이지 않는다.
  bool get hasReading => reading.isNotEmpty && reading != japanese;

  factory N4Word.fromJson(Map<String, dynamic> j, int day, String audio) =>
      N4Word(
        id: j['id'] as String,
        day: day,
        audio: audio,
        japanese: j['ja'] as String,
        reading: j['r'] as String? ?? '',
        korean: j['ko'] as String,
        jaSpan: AudioSpan.fromJson(j['js'])!,
        koSpan: AudioSpan.fromJson(j['ks']),
        exampleJapanese: j['exJa'] as String?,
        exampleKorean: j['exKo'] as String?,
        kanji: [
          for (final k in (j['k'] as List<dynamic>? ?? const []))
            N4Kanji((k as List)[0] as String, k[1] as String, k[2] as String,
                k[3] as String)
        ],
      );
}

/// 2026-10-10 독해 문장: 후리가나 토큰과, 토큰마다 이 DAY 단어 id(없으면 null).
class N4Sentence {
  const N4Sentence(
      {required this.japanese,
      required this.korean,
      required this.tokens,
      required this.wordIds});
  final String japanese, korean;
  final List<NewsToken> tokens;
  final List<String?> wordIds;

  factory N4Sentence.fromJson(Map<String, dynamic> j) {
    final raw = (j['t'] as List<dynamic>).cast<Map<String, dynamic>>();
    return N4Sentence(
      japanese: j['ja'] as String,
      korean: j['ko'] as String,
      tokens: [for (final t in raw) NewsToken.fromJson(t)],
      wordIds: [for (final t in raw) t['n'] as String?],
    );
  }
}

class N4ReadingQuestion {
  const N4ReadingQuestion(
      {required this.japanese,
      required this.korean,
      required this.options,
      required this.answer,
      required this.explanation});
  final String japanese, korean, explanation;
  final List<String> options;
  final int answer;
}

/// 2026-10-10 DAY 단어로 만든 독해 지문(제목 · 문장 · 내용 확인 문제).
class N4Reading {
  const N4Reading(
      {required this.title,
      required this.titleKorean,
      required this.sentences,
      required this.questions});
  final String title, titleKorean;
  final List<N4Sentence> sentences;
  final List<N4ReadingQuestion> questions;

  factory N4Reading.fromJson(Map<String, dynamic> j) => N4Reading(
        title: j['title'] as String,
        titleKorean: j['titleKo'] as String,
        sentences: [
          for (final s in j['sentences'] as List<dynamic>)
            N4Sentence.fromJson(s as Map<String, dynamic>)
        ],
        questions: [
          for (final q in j['questions'] as List<dynamic>)
            N4ReadingQuestion(
                japanese: (q as Map<String, dynamic>)['ja'] as String,
                korean: q['ko'] as String,
                options: (q['options'] as List<dynamic>).cast<String>(),
                answer: q['answer'] as int,
                explanation: q['exp'] as String? ?? '')
        ],
      );
}

class N4Day {
  const N4Day(
      {required this.day,
      required this.title,
      required this.titleKorean,
      required this.audio,
      required this.words,
      this.reading});
  final int day;
  final String title, titleKorean, audio;
  final List<N4Word> words;
  final N4Reading? reading;

  factory N4Day.fromJson(Map<String, dynamic> j) {
    final day = j['day'] as int;
    final audio = j['audio'] as String;
    return N4Day(
      day: day,
      title: j['title'] as String? ?? '',
      titleKorean: j['titleKo'] as String? ?? '',
      audio: audio,
      words: [
        for (final w in j['words'] as List<dynamic>)
          N4Word.fromJson(w as Map<String, dynamic>, day, audio)
      ],
      reading: j['reading'] == null
          ? null
          : N4Reading.fromJson(j['reading'] as Map<String, dynamic>),
    );
  }
}

class N4Wordbook {
  const N4Wordbook(this.days);
  final List<N4Day> days;

  int get wordCount => days.fold(0, (n, d) => n + d.words.length);
  Iterable<N4Word> get allWords => days.expand((d) => d.words);
  N4Word? wordById(String id) {
    for (final w in allWords) {
      if (w.id == id) return w;
    }
    return null;
  }
  N4Day dayOf(int day) => days.firstWhere((d) => d.day == day);

  static N4Wordbook parse(String raw) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    return N4Wordbook([
      for (final d in j['days'] as List<dynamic>)
        N4Day.fromJson(d as Map<String, dynamic>)
    ]);
  }

  static Future<N4Wordbook> load([AssetBundle? bundle]) async =>
      parse(await (bundle ?? rootBundle).loadString(n4WordbookAsset));
}

/// 사지선다 한 문제.
class N4QuizQuestion {
  const N4QuizQuestion(
      {required this.word, required this.choices, required this.answer, required this.reverse});
  final N4Word word;
  final List<N4Word> choices;
  final int answer;

  /// false: 일본어를 보고 뜻 고르기, true: 뜻을 보고 일본어 고르기.
  final bool reverse;
}

/// 2026-10-09 같은 DAY(부족하면 이웃 DAY)의 단어로 오답 보기를 만든다.
List<N4QuizQuestion> buildN4Quiz(N4Wordbook book, List<N4Word> targets,
    {required bool reverse, Random? random}) {
  final rnd = random ?? Random();
  final questions = <N4QuizQuestion>[];
  for (final w in targets) {
    final pool = [
      ...book.dayOf(w.day).words,
      ...book.allWords.where((x) => (x.day - w.day).abs() == 1),
    ].where((x) => x.id != w.id && x.korean != w.korean && x.japanese != w.japanese).toList()
      ..shuffle(rnd);
    final picked = <N4Word>[];
    for (final p in pool) {
      if (picked.any((q) => q.korean == p.korean || q.japanese == p.japanese)) continue;
      picked.add(p);
      if (picked.length == 3) break;
    }
    final choices = [w, ...picked]..shuffle(rnd);
    questions.add(N4QuizQuestion(
        word: w, choices: choices, answer: choices.indexOf(w), reverse: reverse));
  }
  return questions;
}

/// 2026-10-09 단어장 학습 기록: 외운 단어(퀴즈에서 맞힘), 틀린 단어, DAY별 최고 점수.
class N4WordbookProgress {
  N4WordbookProgress(this.preferences);
  final SharedPreferences preferences;
  static const key = 'n4_wordbook_v1';

  Map<String, dynamic> get _data {
    try {
      return jsonDecode(preferences.getString(key) ?? '{}') as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  Future<void> _save(Map<String, dynamic> d) =>
      preferences.setString(key, jsonEncode(d));

  Set<String> _set(String name) =>
      {...((_data[name] as List?) ?? const []).cast<String>()};

  Set<String> get known => _set('known');
  Set<String> get wrong => _set('wrong');

  int? best(int day) => (_data['best'] as Map?)?['$day'] as int?;
  bool studied(int day) =>
      ((_data['studied'] as List?) ?? const []).contains(day);

  Future<void> markStudied(int day) async {
    final d = _data;
    final list = {...((d['studied'] as List?) ?? const []).cast<int>(), day}.toList()..sort();
    d['studied'] = list;
    await _save(d);
  }

  // ---------------------------------------------------------------------
  // 2026-10-10 장기 기억(간격 반복). 앱의 FSRS 스케줄러로 단어마다 다음 복습 시각을 정한다.
  // 등급: 1 모름 · 2 헷갈림 · 3 기억남 · 4 쉬움. 퀴즈 정답은 3, 오답은 1로 반영한다.
  static final scheduler = ReviewScheduler();

  Map<String, dynamic> get _srs =>
      Map<String, dynamic>.from(_data['srs'] as Map? ?? {});

  Map<String, dynamic>? srsOf(String id) =>
      (_srs[id] as Map?)?.cast<String, dynamic>();

  bool isNew(String id) => srsOf(id) == null;

  DateTime? nextReview(String id) {
    final v = srsOf(id)?['next'] as String?;
    return v == null ? null : DateTime.tryParse(v);
  }

  bool isDue(String id, DateTime now) {
    final next = nextReview(id);
    return next != null && !next.isAfter(now);
  }

  /// 현재 복습 간격(일). 화면의 기억 단계(1~7) 표시용.
  double intervalDays(String id) {
    final s = srsOf(id);
    if (s == null) return 0;
    return scheduler.intervalDaysForStability((s['s'] as num).toDouble());
  }

  /// 0 = 아직 안 봄, 1~7 = 기억 단계(7은 60일 이상 간격 = 장기 기억).
  int stage(String id) =>
      isNew(id) ? 0 : scheduler.stageForIntervalDays(intervalDays(id));

  /// 등급을 골랐을 때의 새 상태(저장하지 않음). 버튼에 다음 간격을 미리 보여줄 때 쓴다.
  Map<String, dynamic> preview(String id, int rating, DateTime now) {
    final old = srsOf(id);
    double s, d;
    var reps = 0, lapses = 0;
    if (old == null) {
      s = scheduler.initialStability(rating);
      d = scheduler.initialDifficulty(rating);
    } else {
      final oldS = (old['s'] as num).toDouble();
      final oldD = (old['d'] as num).toDouble();
      final last = DateTime.tryParse(old['last'] as String? ?? '') ?? now;
      final elapsed = now.difference(last).inMinutes / (24 * 60);
      final r = scheduler.retrievability(stabilityDays: oldS, elapsedDays: elapsed);
      d = scheduler.nextDifficulty(difficulty: oldD, rating: rating);
      s = rating == 1
          ? scheduler.nextStabilityOnForget(difficulty: oldD, stability: oldS, retrievability: r)
          : scheduler.nextStabilityOnRecall(
              difficulty: oldD, stability: oldS, retrievability: r, rating: rating);
      reps = old['r'] as int? ?? 0;
      lapses = old['l'] as int? ?? 0;
    }
    // 모름은 10분 뒤, 그 밖에는 FSRS 간격.
    final next = rating == 1
        ? now.add(const Duration(minutes: 10))
        : scheduler.nextReviewAt(stabilityDays: s, from: now);
    return {
      's': s,
      'd': d,
      'r': reps + 1,
      'l': lapses + (rating == 1 ? 1 : 0),
      'last': now.toIso8601String(),
      'next': next.toIso8601String(),
    };
  }

  Future<void> review(String id, int rating, [DateTime? now]) async {
    final at = now ?? DateTime.now();
    final d = _data;
    final srs = Map<String, dynamic>.from(d['srs'] as Map? ?? {});
    final first = (srs[id] as Map?)?['f'] as String?;
    srs[id] = {...preview(id, rating, at), 'f': first ?? dayKey(at)};
    d['srs'] = srs;
    final days = {...((d['days'] as List?) ?? const []).cast<String>(), dayKey(at)};
    d['days'] = (days.toList()..sort()).reversed.take(400).toList();
    await _save(d);
  }

  // ---------------------------------------------------------------------
  // 2026-10-10 하루 목표: 새 단어는 하루 [dailyGoal]개까지만, 복습을 먼저.
  static const goalChoices = [5, 8, 10, 15];

  static String dayKey(DateTime t) =>
      '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';

  int get dailyGoal => _data['goal'] as int? ?? 8;

  Future<void> setDailyGoal(int goal) async {
    final d = _data;
    d['goal'] = goal;
    await _save(d);
  }

  /// 오늘 처음 카드로 본(외우기 시작한) 단어 수.
  int newToday(DateTime now) {
    final key = dayKey(now);
    return _srs.values.where((v) => (v as Map)['f'] == key).length;
  }

  int remainingNew(DateTime now) =>
      (dailyGoal - newToday(now)).clamp(0, dailyGoal).toInt();

  /// 단어장 순서(DAY 1부터)로 아직 안 본 단어 [count]개.
  List<N4Word> nextNewWords(N4Wordbook book, int count) =>
      book.allWords.where((w) => isNew(w.id)).take(count).toList();

  /// 오늘까지 하루도 빠지지 않고 공부한 날 수(오늘 아직 안 했으면 어제까지).
  int streak(DateTime now) {
    final days = ((_data['days'] as List?) ?? const []).cast<String>().toSet();
    var day = DateTime(now.year, now.month, now.day);
    if (!days.contains(dayKey(day))) day = day.subtract(const Duration(days: 1));
    var n = 0;
    while (days.contains(dayKey(day))) {
      n++;
      day = day.subtract(const Duration(days: 1));
    }
    return n;
  }

  /// 복습할 때가 된 단어(가장 오래 기다린 순).
  List<N4Word> dueWords(N4Wordbook book, DateTime now) {
    final list = [for (final w in book.allWords) if (isDue(w.id, now)) w];
    list.sort((a, b) => nextReview(a.id)!.compareTo(nextReview(b.id)!));
    return list;
  }

  /// 간격이 21일 이상인(오래 기억하고 있는) 단어 수.
  int longTermCount(Iterable<N4Word> words) =>
      words.where((w) => intervalDays(w.id) >= 21).length;

  Future<void> record(String wordId, bool correct) async {
    await review(wordId, correct ? 3 : 1);
    final d = _data;
    final known = {...((d['known'] as List?) ?? const []).cast<String>()};
    final wrong = {...((d['wrong'] as List?) ?? const []).cast<String>()};
    if (correct) {
      known.add(wordId);
      wrong.remove(wordId);
    } else {
      wrong.add(wordId);
      known.remove(wordId);
    }
    d['known'] = known.toList();
    d['wrong'] = wrong.toList();
    await _save(d);
  }

  Future<void> saveScore(int day, int score) async {
    final d = _data;
    final best = Map<String, dynamic>.from(d['best'] as Map? ?? {});
    if ((best['$day'] as int? ?? -1) < score) best['$day'] = score;
    d['best'] = best;
    await _save(d);
  }
}
