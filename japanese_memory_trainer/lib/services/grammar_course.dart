import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 2026-10-07 일본어 고급 문법(30강) 데이터.
/// 사용자 제공 강의 노트 PDF를 문자 인식으로 받아 적고, 노트에 비어 있던 빈칸 정답을 채워 정리했다.
/// 원고는 `tool/grammar/spec/grammar.txt`, 다시 만들기는 `python tool/grammar/build_grammar.py`.
const grammarLessonsAsset = 'assets/grammar/grammar_lessons.json';

/// 문장 속 `[정답]` 빈칸을 나눈 조각. [blank]가 참이면 빈칸이다.
class GapPart {
  const GapPart(this.text, this.blank);
  final String text;
  final bool blank;
}

/// `今朝、雨が[降り]はじめました。` → 조각 목록.
List<GapPart> splitGaps(String text) {
  final parts = <GapPart>[];
  final re = RegExp(r'\[(.+?)\]');
  var last = 0;
  for (final m in re.allMatches(text)) {
    if (m.start > last) parts.add(GapPart(text.substring(last, m.start), false));
    parts.add(GapPart(m.group(1)!, true));
    last = m.end;
  }
  if (last < text.length) parts.add(GapPart(text.substring(last), false));
  return parts;
}

/// 빈칸을 정답으로 채운 문장(읽어 주기용).
String fillGaps(String text) => text.replaceAllMapped(
    RegExp(r'\[(.+?)\]'), (m) => m.group(1)!);

class GapItem {
  const GapItem(this.base, this.japanese, this.korean);
  final String base, japanese, korean;
  String get filled => fillGaps(japanese);
  factory GapItem.fromJson(Map<String, dynamic> j) => GapItem(
      j['base'] as String? ?? '', j['ja'] as String, j['ko'] as String? ?? '');
}

class GrammarPoint {
  const GrammarPoint(
      {required this.head,
      required this.form,
      required this.meaning,
      required this.notes,
      required this.drills,
      required this.examples});
  final String head, form, meaning;
  final List<String> notes;
  final List<GapItem> drills, examples;

  factory GrammarPoint.fromJson(Map<String, dynamic> j) => GrammarPoint(
        head: j['head'] as String,
        form: j['form'] as String? ?? '',
        meaning: j['meaning'] as String? ?? '',
        notes: (j['notes'] as List<dynamic>? ?? const []).cast<String>(),
        drills: [
          for (final d in (j['drills'] as List<dynamic>? ?? const []))
            GapItem.fromJson(d as Map<String, dynamic>)
        ],
        examples: [
          for (final d in (j['examples'] as List<dynamic>? ?? const []))
            GapItem.fromJson(d as Map<String, dynamic>)
        ],
      );
}

class ChoiceQuestion {
  const ChoiceQuestion(this.japanese, this.korean, this.options, this.answer);
  final String japanese, korean;
  final List<String> options;
  final int answer;
  factory ChoiceQuestion.fromJson(Map<String, dynamic> j) => ChoiceQuestion(
      j['ja'] as String,
      j['ko'] as String? ?? '',
      (j['options'] as List<dynamic>).cast<String>(),
      j['answer'] as int);
}

/// 순서 맞추기: [chunks]가 정답 순서다.
class OrderQuestion {
  const OrderQuestion(this.japanese, this.korean, this.chunks);
  final String japanese, korean;
  final List<String> chunks;
  factory OrderQuestion.fromJson(Map<String, dynamic> j) => OrderQuestion(
      j['ja'] as String,
      j['ko'] as String? ?? '',
      (j['chunks'] as List<dynamic>).cast<String>());
}

class GrammarWord {
  const GrammarWord(this.word, this.reading, this.meaning);
  final String word, reading, meaning;
  factory GrammarWord.fromJson(Map<String, dynamic> j) => GrammarWord(
      j['w'] as String, j['r'] as String? ?? '', j['m'] as String? ?? '');
}

class GrammarLesson {
  const GrammarLesson(
      {required this.number,
      required this.title,
      required this.points,
      required this.table,
      required this.choices,
      required this.orders,
      required this.words});
  final int number;
  final String title;
  final List<GrammarPoint> points;
  final List<GapItem> table;
  final List<ChoiceQuestion> choices;
  final List<OrderQuestion> orders;
  final List<GrammarWord> words;

  String get id => 'g$number';
  String get label => '${number.toString().padLeft(2, '0')}강';
  String get headline => points.map((p) => p.head).join(' · ');

  factory GrammarLesson.fromJson(Map<String, dynamic> j) {
    List<T> list<T>(String key, T Function(Map<String, dynamic>) f) => [
          for (final x in (j[key] as List<dynamic>? ?? const []))
            f(x as Map<String, dynamic>)
        ];
    return GrammarLesson(
      number: j['no'] as int,
      title: j['title'] as String,
      points: list('points', GrammarPoint.fromJson),
      table: list('table', GapItem.fromJson),
      choices: list('choice', ChoiceQuestion.fromJson),
      orders: list('order', OrderQuestion.fromJson),
      words: list('words', GrammarWord.fromJson),
    );
  }

  static List<GrammarLesson>? _cache;

  static Future<List<GrammarLesson>> load() async =>
      _cache ??= parse(await rootBundle.loadString(grammarLessonsAsset));

  static List<GrammarLesson> parse(String raw) => [
        for (final l in ((jsonDecode(raw) as Map<String, dynamic>)['lessons']
            as List<dynamic>))
          GrammarLesson.fromJson(l as Map<String, dynamic>)
      ];
}

/// 2026-10-07 강의 완료·문제 점수·마지막 강의를 기기에 저장한다.
class GrammarProgress {
  GrammarProgress(this._prefs);
  final SharedPreferences _prefs;
  static const _doneKey = 'grammar_done_v1';
  static const _lastKey = 'grammar_last_v1';
  static String _scoreKey(String id) => 'grammar_score_v1_$id';

  Set<String> get done => (_prefs.getStringList(_doneKey) ?? const []).toSet();
  bool isDone(String id) => done.contains(id);
  Future<void> setDone(String id, bool value) async {
    final set = done;
    value ? set.add(id) : set.remove(id);
    await _prefs.setStringList(_doneKey, set.toList()..sort());
  }

  String? get last => _prefs.getString(_lastKey);
  Future<void> setLast(String id) => _prefs.setString(_lastKey, id);

  /// 마지막으로 푼 문제 점수(맞힌 수).
  int? score(String id) => _prefs.getInt(_scoreKey(id));
  Future<void> setScore(String id, int value) =>
      _prefs.setInt(_scoreKey(id), value);
}
