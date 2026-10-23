import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

/// 2026-10-11 기본 부수 과정: 핵심 부수 97개를 12과로 나눠 그림(획)·이야기·예시 한자·퀴즈·
/// 간격 반복으로 외운다. 데이터: assets/kanji/radicals.json
const radicalCourseAsset = 'assets/kanji/radicals.json';

/// 부수가 한자 안에서 놓이는 자리.
enum RadicalPosition { hen, tsukuri, kanmuri, ashi, tare, nyou, kamae, free }

extension RadicalPositionLabel on RadicalPosition {
  /// 한국식 이름(변·방·머리…)
  String get label => switch (this) {
        RadicalPosition.hen => '변 (왼쪽)',
        RadicalPosition.tsukuri => '방 (오른쪽)',
        RadicalPosition.kanmuri => '머리 (위)',
        RadicalPosition.ashi => '발 (아래)',
        RadicalPosition.tare => '엄 (위 + 왼쪽)',
        RadicalPosition.nyou => '받침 (왼쪽 + 아래)',
        RadicalPosition.kamae => '몸 (둘러쌈)',
        RadicalPosition.free => '여러 자리',
      };

  String get short => label.split(' ').first;
}

class RadicalExample {
  const RadicalExample(
      {required this.kanji,
      required this.hunEum,
      required this.strokes,
      this.alsoContains = ''});
  final String kanji, hunEum;

  /// 이 한자에서 부수에 해당하는 획 번호(0부터).
  final List<int> strokes;

  /// 이 한자에 함께 들어 있는 다른 부수들(퀴즈 오답 보기에서 뺀다).
  final String alsoContains;

  factory RadicalExample.fromJson(Map<String, dynamic> j) => RadicalExample(
        kanji: j['k'] as String,
        hunEum: j['h'] as String? ?? '',
        strokes: (j['s'] as List<dynamic>).cast<int>(),
        alsoContains: j['in'] as String? ?? '',
      );
}

class Radical {
  const Radical({
    required this.form,
    required this.forms,
    required this.korean,
    required this.nickname,
    required this.japaneseName,
    required this.position,
    required this.meaning,
    required this.story,
    required this.count,
    required this.examples,
    this.lesson = 0,
  });

  /// 대표 모양(예: 氵)
  final String form;

  /// 같은 부수로 보는 모양들(예: 氵水氺)
  final String forms;

  /// 훈음(예: 물 수)
  final String korean;

  /// 부수 별칭(예: 삼수변)
  final String nickname;

  /// 일본어 이름(예: さんずい)
  final String japaneseName;
  final RadicalPosition position;

  /// 뜻 요약(예: 물 · 액체 · 강)
  final String meaning;

  /// 기억 이야기
  final String story;

  /// 앱의 한자 중 이 부수가 들어간 글자 수
  final int count;
  final List<RadicalExample> examples;
  final int lesson;

  /// 퀴즈 보기용 이름: "삼수변 (물 수)"
  String get title => nickname == korean ? korean : '$nickname ($korean)';

  factory Radical.fromJson(Map<String, dynamic> j, {int lesson = 0}) => Radical(
        form: j['f'] as String,
        forms: j['forms'] as String? ?? j['f'] as String,
        korean: j['kr'] as String,
        nickname: j['nick'] as String? ?? '',
        japaneseName: j['ja'] as String? ?? '',
        position: RadicalPosition.values.firstWhere((p) => p.name == j['pos'],
            orElse: () => RadicalPosition.free),
        meaning: j['mean'] as String? ?? '',
        story: j['story'] as String? ?? '',
        count: j['n'] as int? ?? 0,
        examples: [
          for (final e in (j['ex'] as List<dynamic>? ?? const []))
            RadicalExample.fromJson(e as Map<String, dynamic>)
        ],
        lesson: lesson,
      );
}

class RadicalLesson {
  const RadicalLesson(
      {required this.number, required this.title, required this.radicals});
  final int number;
  final String title;
  final List<Radical> radicals;
  String get label => '${number.toString().padLeft(2, '0')}과';
}

class RadicalCourse {
  RadicalCourse(this.lessons)
      : radicals = [for (final l in lessons) ...l.radicals];
  final List<RadicalLesson> lessons;
  final List<Radical> radicals;

  Radical? byForm(String form) {
    for (final r in radicals) {
      if (r.form == form) return r;
    }
    return null;
  }

  factory RadicalCourse.parse(String raw) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    final lessonsJson = (j['lessons'] as List<dynamic>).cast<Map<String, dynamic>>();
    final lessonOf = <String, int>{};
    for (final l in lessonsJson) {
      for (final f in (l['r'] as List<dynamic>).cast<String>()) {
        lessonOf[f] = l['no'] as int;
      }
    }
    final byForm = <String, Radical>{
      for (final r in (j['radicals'] as List<dynamic>).cast<Map<String, dynamic>>())
        r['f'] as String:
            Radical.fromJson(r, lesson: lessonOf[r['f'] as String] ?? 0)
    };
    return RadicalCourse([
      for (final l in lessonsJson)
        RadicalLesson(
          number: l['no'] as int,
          title: l['title'] as String,
          radicals: [
            for (final f in (l['r'] as List<dynamic>).cast<String>())
              if (byForm[f] != null) byForm[f]!
          ],
        )
    ]);
  }

  static RadicalCourse? _cache;
  static Future<RadicalCourse> load() async =>
      _cache ??= RadicalCourse.parse(await rootBundle.loadString(radicalCourseAsset));
}

/// 2026-10-11 부수별 기억 단계(간격 반복). 0 = 아직 안 배움.
/// 맞히면 한 단계 올라가고 다음 복습이 점점 멀어진다. 틀리면 1단계로 돌아간다.
class RadicalProgress {
  RadicalProgress(this._prefs);
  final SharedPreferences _prefs;

  static const String _prefix = 'radical.v1.';
  static const int masteredStage = 5;
  static const int maxStage = 7;

  /// 단계별 다음 복습까지의 간격.
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

  (int, int) _read(String form) {
    final raw = _prefs.getString('$_prefix$form');
    if (raw == null) return (0, 0);
    final p = raw.split('|');
    return (int.tryParse(p.first) ?? 0, p.length > 1 ? int.tryParse(p[1]) ?? 0 : 0);
  }

  Future<void> _write(String form, int stage, DateTime due) =>
      _prefs.setString('$_prefix$form', '$stage|${due.millisecondsSinceEpoch}');

  int stage(String form) => _read(form).$1;
  bool isNew(String form) => stage(form) == 0;
  bool isMastered(String form) => stage(form) >= masteredStage;
  DateTime dueAt(String form) =>
      DateTime.fromMillisecondsSinceEpoch(_read(form).$2);
  bool isDue(String form, DateTime now) =>
      !isNew(form) && !dueAt(form).isAfter(now);

  /// 카드로 처음 배웠을 때.
  Future<void> markLearned(String form, DateTime now) async {
    if (isNew(form)) await _write(form, 1, now.add(intervals[1]));
  }

  /// 퀴즈·복습 결과 기록. 한 번의 세션에서 처음 답한 결과만 넘긴다.
  Future<void> record(String form, bool correct, DateTime now) async {
    final s = stage(form);
    if (correct) {
      final next = min(max(s, 1) + 1, maxStage);
      await _write(form, next, now.add(intervals[next]));
    } else {
      await _write(form, 1, now.add(intervals[1]));
    }
  }

  List<Radical> due(List<Radical> all, DateTime now) {
    final list = all.where((r) => isDue(r.form, now)).toList()
      ..sort((a, b) => dueAt(a.form).compareTo(dueAt(b.form)));
    return list;
  }

  int masteredCount(List<Radical> all) =>
      all.where((r) => isMastered(r.form)).length;
  int learnedCount(List<Radical> all) =>
      all.where((r) => !isNew(r.form)).length;

  /// 과 진행률(0~1): 단계 합 / (부수 수 × 외움 단계)
  double lessonRatio(RadicalLesson l) {
    if (l.radicals.isEmpty) return 0;
    final sum = l.radicals
        .map((r) => min(stage(r.form), masteredStage))
        .fold<int>(0, (a, b) => a + b);
    return sum / (l.radicals.length * masteredStage);
  }

  /// 아직 다 배우지 않은 첫 과.
  RadicalLesson? nextLesson(RadicalCourse c) {
    for (final l in c.lessons) {
      if (l.radicals.any((r) => isNew(r.form))) return l;
    }
    return null;
  }
}

/// 퀴즈 종류.
enum RadicalQuizKind {
  /// 부수 모양 → 이름·뜻 고르기
  meaning,

  /// 이름·뜻 → 부수 모양 고르기
  form,

  /// 한자 → 그 안에 들어 있는 부수 고르기
  find,

  /// 부수 모양 → 자리(변·방·머리…) 고르기
  position,

  /// 부수 모양 → 일본어 이름 고르기
  japanese,
}

class RadicalQuestion {
  const RadicalQuestion({
    required this.kind,
    required this.radical,
    required this.options,
    required this.answer,
    this.kanji,
  });
  final RadicalQuizKind kind;
  final Radical radical;

  /// 보기. 모양(form)·이름 문자열·자리 이름 중 하나.
  final List<String> options;
  final int answer;

  /// [RadicalQuizKind.find]에서 보여 줄 한자.
  final RadicalExample? kanji;

  /// 보기가 부수 모양(글자 그림으로 보여 줌)인지.
  bool get optionsAreForms =>
      kind == RadicalQuizKind.form || kind == RadicalQuizKind.find;

  String get prompt => switch (kind) {
        RadicalQuizKind.meaning => '이 부수의 이름은?',
        RadicalQuizKind.form => '「${radical.title}」은 어느 것?',
        RadicalQuizKind.find => '이 한자에 들어 있는 부수는?',
        RadicalQuizKind.position => '이 부수는 한자의 어디에 놓일까요?',
        RadicalQuizKind.japanese => '일본어로는 뭐라고 부를까요?',
      };
}

/// 2026-10-11 헷갈리기 쉬운 짝(오답 보기로 먼저 넣는다).
const Map<String, String> radicalLookAlikes = {
  '礻': '衤', '衤': '礻', '冫': '氵', '氵': '冫', '冖': '宀', '宀': '冖',
  '⻖': '⻏', '⻏': '⻖', '刀': '刂', '刂': '刀', '广': '厂', '厂': '广',
  '⻌': '廴', '廴': '⻌', '彳': '亻', '亻': '彳', '攵': '殳', '殳': '攵',
  '隹': '鳥', '鳥': '隹', '心': '忄', '忄': '心', '火': '灬', '灬': '火',
  '日': '目', '目': '日', '戸': '尸', '尸': '戸', '衣': '衤', '王': '土',
  '土': '王', '夂': '攵', '穴': '宀', '疒': '广', '儿': '八', '八': '儿',
};

/// 2026-10-11 퀴즈 만들기. [pool]은 오답 보기를 고를 전체 부수.
class RadicalQuizBuilder {
  RadicalQuizBuilder(this.pool, {Random? random}) : _rnd = random ?? Random();
  final List<Radical> pool;
  final Random _rnd;

  /// 부수 하나당 한 문제. 종류는 골고루 섞는다.
  List<RadicalQuestion> build(List<Radical> targets) {
    final kinds = [
      RadicalQuizKind.meaning,
      RadicalQuizKind.find,
      RadicalQuizKind.form,
      RadicalQuizKind.find,
      RadicalQuizKind.meaning,
      RadicalQuizKind.position,
      RadicalQuizKind.form,
      RadicalQuizKind.japanese,
    ];
    final order = [...targets]..shuffle(_rnd);
    return [
      for (var i = 0; i < order.length; i++)
        question(order[i], kinds[(i + _rnd.nextInt(kinds.length)) % kinds.length])
    ];
  }

  RadicalQuestion question(Radical r, RadicalQuizKind kind) {
    if (kind == RadicalQuizKind.position && r.position == RadicalPosition.free) {
      kind = RadicalQuizKind.meaning;
    }
    if (kind == RadicalQuizKind.find && r.examples.isEmpty) {
      kind = RadicalQuizKind.form;
    }
    switch (kind) {
      case RadicalQuizKind.meaning:
        return _choices(r, kind, (x) => x.title);
      case RadicalQuizKind.japanese:
        return _choices(r, kind, (x) => x.japaneseName);
      case RadicalQuizKind.form:
        return _choices(r, kind, (x) => x.form);
      case RadicalQuizKind.find:
        final ex = r.examples[_rnd.nextInt(min(r.examples.length, 4))];
        return _choices(r, kind, (x) => x.form,
            exclude: (x) =>
                ex.alsoContains.contains(x.form) || ex.kanji.contains(x.form),
            kanji: ex);
      case RadicalQuizKind.position:
        final all = RadicalPosition.values
            .where((p) => p != RadicalPosition.free && p != r.position)
            .toList()
          ..shuffle(_rnd);
        final opts = [r.position, ...all.take(3)].map((p) => p.label).toList()
          ..shuffle(_rnd);
        return RadicalQuestion(
            kind: kind,
            radical: r,
            options: opts,
            answer: opts.indexOf(r.position.label));
    }
  }

  RadicalQuestion _choices(
      Radical r, RadicalQuizKind kind, String Function(Radical) label,
      {bool Function(Radical)? exclude, RadicalExample? kanji}) {
    final right = label(r);
    final used = <String>{right};
    final wrong = <String>[];
    bool ok(Radical x) =>
        x.form != r.form &&
        !used.contains(label(x)) &&
        label(x).isNotEmpty &&
        !(exclude?.call(x) ?? false);
    // 1) 헷갈리는 짝 2) 같은 과 3) 나머지
    final look = radicalLookAlikes[r.form];
    final candidates = <Radical>[
      ...pool.where((x) => x.form == look),
      ...(pool.where((x) => x.lesson == r.lesson).toList()..shuffle(_rnd)),
      ...(pool.toList()..shuffle(_rnd)),
    ];
    for (final x in candidates) {
      if (wrong.length >= 3) break;
      if (ok(x)) {
        wrong.add(label(x));
        used.add(label(x));
      }
    }
    final opts = [right, ...wrong]..shuffle(_rnd);
    return RadicalQuestion(
        kind: kind,
        radical: r,
        options: opts,
        answer: opts.indexOf(right),
        kanji: kanji);
  }
}
