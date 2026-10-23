import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:kioku_japanese/services/news_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const jlptN4MockAsset = 'assets/jlpt_n4_mock/mock.json';

/// 2026-10-10 지문의 한 덩어리: 문단(text) 또는 표(rows).
class MockBlock {
  const MockBlock.text(this.text, [this.tokens = const []]) : rows = null;
  const MockBlock.table(this.rows)
      : text = null,
        tokens = const [];
  final String? text;
  final List<List<String>>? rows;

  /// 후리가나·단어 뜻이 붙은 문단(연습·채점 후 화면).
  final List<NewsToken> tokens;

  factory MockBlock.fromJson(Map<String, dynamic> j) => j['table'] != null
      ? MockBlock.table([
          for (final r in j['table'] as List<dynamic>)
            [for (final c in r as List<dynamic>) c as String]
        ])
      : MockBlock.text(j['p'] as String, _tokens(j['t']));
}

List<NewsToken> _tokens(Object? raw) => [
      for (final t in (raw as List<dynamic>?) ?? const [])
        NewsToken.fromJson(t as Map<String, dynamic>)
    ];

/// 2026-10-10 지문(문단·표)과 한국어 해석.
class MockPassage {
  const MockPassage({required this.blocks, required this.korean});
  final List<MockBlock> blocks;
  final List<String> korean;

  factory MockPassage.fromJson(Map<String, dynamic> j) => MockPassage(
      blocks: [
        for (final b in j['blocks'] as List<dynamic>)
          MockBlock.fromJson(b as Map<String, dynamic>)
      ],
      korean: [for (final k in j['ko'] as List<dynamic>) k as String]);
}

/// 문제 문장 조각. 【】 안은 밑줄(underline) 칸이다.
class StemPart {
  const StemPart(this.text, {this.underline = false});
  final String text;
  final bool underline;
}

List<StemPart> stemParts(String stem) {
  final parts = <StemPart>[];
  final re = RegExp(r'【([^】]*)】');
  var at = 0;
  for (final m in re.allMatches(stem)) {
    if (m.start > at) parts.add(StemPart(stem.substring(at, m.start)));
    parts.add(StemPart(m.group(1)!, underline: true));
    at = m.end;
  }
  if (at < stem.length) parts.add(StemPart(stem.substring(at)));
  return parts;
}

class MockQuestion {
  const MockQuestion(
      {required this.no,
      required this.stem,
      required this.options,
      required this.answer,
      required this.explanation,
      this.passage,
      this.korean = '',
      this.answerSentence = '',
      this.answerTokens = const [],
      this.optionKorean = const [],
      this.optionTokens = const []});
  final int no;
  final String stem;
  final List<String> options;
  final int answer;
  final String explanation;

  /// 같은 問題 안에서 몇 번째 지문을 보는지(없으면 null).
  final int? passage;

  /// 정답을 넣은 완성 문장(일본어)과 그 해석.
  final String answerSentence, korean;
  final List<NewsToken> answerTokens;

  /// 보기마다 뜻(빈 문자열이면 표시하지 않음)과 후리가나 조각.
  final List<String> optionKorean;
  final List<List<NewsToken>> optionTokens;

  factory MockQuestion.fromJson(Map<String, dynamic> j) => MockQuestion(
      no: j['no'] as int,
      stem: j['stem'] as String,
      options: [for (final o in j['options'] as List<dynamic>) o as String],
      answer: j['answer'] as int,
      explanation: j['exp'] as String,
      passage: j['passage'] as int?,
      korean: j['ko'] as String? ?? '',
      answerSentence: j['ja'] as String? ?? '',
      answerTokens: _tokens(j['jaT']),
      optionKorean: [
        for (final o in (j['optKo'] as List<dynamic>?) ?? const []) o as String
      ],
      optionTokens: [
        for (final o in (j['optT'] as List<dynamic>?) ?? const []) _tokens(o)
      ]);
}

class MockMondai {
  const MockMondai(
      {required this.no,
      required this.japanese,
      required this.korean,
      required this.passages,
      required this.questions});
  final int no;
  final String japanese, korean;
  final List<MockPassage> passages;
  final List<MockQuestion> questions;

  factory MockMondai.fromJson(Map<String, dynamic> j) => MockMondai(
      no: j['no'] as int,
      japanese: j['ja'] as String,
      korean: j['ko'] as String,
      passages: [
        for (final p in j['passages'] as List<dynamic>)
          MockPassage.fromJson(p as Map<String, dynamic>)
      ],
      questions: [
        for (final q in j['questions'] as List<dynamic>)
          MockQuestion.fromJson(q as Map<String, dynamic>)
      ]);
}

class MockSection {
  const MockSection(
      {required this.id,
      required this.title,
      required this.minutes,
      required this.mondai});
  final String id, title;
  final int minutes;
  final List<MockMondai> mondai;

  String get korean => id == 'vocab' ? '문자·어휘' : '문법·독해';
  List<MockQuestion> get questions =>
      [for (final m in mondai) ...m.questions];

  /// 연습 모드: 앞에서부터 5문제씩 묶는다.
  static const practiceSize = 5;
  int get practiceCount =>
      (questions.length + practiceSize - 1) ~/ practiceSize;
  List<MockQuestion> practice(int index) =>
      questions.skip(index * practiceSize).take(practiceSize).toList();

  MockMondai mondaiOf(MockQuestion q) =>
      mondai.firstWhere((m) => m.questions.contains(q));

  factory MockSection.fromJson(Map<String, dynamic> j) => MockSection(
      id: j['id'] as String,
      title: j['title'] as String,
      minutes: j['minutes'] as int,
      mondai: [
        for (final m in j['mondai'] as List<dynamic>)
          MockMondai.fromJson(m as Map<String, dynamic>)
      ]);
}

class MockSet {
  const MockSet(
      {required this.no,
      required this.title,
      required this.korean,
      required this.sections});
  final int no;
  final String title, korean;
  final List<MockSection> sections;

  factory MockSet.fromJson(Map<String, dynamic> j) => MockSet(
      no: j['no'] as int,
      title: j['title'] as String,
      korean: j['titleKo'] as String,
      sections: [
        for (final s in j['sections'] as List<dynamic>)
          MockSection.fromJson(s as Map<String, dynamic>)
      ]);
}

/// 2026-10-10 JLPT N4 모의고사(언어지식·독해) 2회분.
class JlptN4Mock {
  const JlptN4Mock(this.sets);
  final List<MockSet> sets;

  static JlptN4Mock parse(String raw) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    return JlptN4Mock([
      for (final s in j['sets'] as List<dynamic>)
        MockSet.fromJson(s as Map<String, dynamic>)
    ]);
  }

  static Future<JlptN4Mock> load([AssetBundle? bundle]) async =>
      parse(await (bundle ?? rootBundle).loadString(jlptN4MockAsset));
}

/// 2026-10-10 모의고사 기록: 섹션마다 고른 답(풀던 중에도 저장), 채점 여부, 최고 점수, 걸린 시간.
class JlptN4MockProgress {
  JlptN4MockProgress(this.preferences);
  final SharedPreferences preferences;
  static const key = 'jlpt_n4_mock_v1';

  static String sectionKey(MockSet set, MockSection section) =>
      '${set.no}-${section.id}';

  Map<String, dynamic> get _all {
    try {
      return jsonDecode(preferences.getString(key) ?? '{}')
          as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  Map<String, dynamic> _of(String k) =>
      Map<String, dynamic>.from(_all[k] as Map? ?? {});

  Future<void> _put(String k, Map<String, dynamic> v) async {
    final all = _all..[k] = v;
    await preferences.setString(key, jsonEncode(all));
  }

  /// 문제 번호 → 고른 보기.
  Map<int, int> answers(String k) => {
        for (final e in (_of(k)['a'] as Map? ?? {}).entries)
          int.parse(e.key as String): e.value as int
      };

  bool graded(String k) => _of(k)['done'] == true;
  int? score(String k) => _of(k)['score'] as int?;
  int? best(String k) => _of(k)['best'] as int?;
  int elapsed(String k) => (_of(k)['sec'] as int?) ?? 0;
  int attempts(String k) => (_of(k)['n'] as int?) ?? 0;

  Future<void> saveDraft(String k, Map<int, int> answers, int elapsed) async {
    final v = _of(k);
    if (v['done'] == true) return;
    v['a'] = {for (final e in answers.entries) '${e.key}': e.value};
    v['sec'] = elapsed;
    await _put(k, v);
  }

  /// 채점 결과를 저장하고 맞힌 개수를 돌려준다.
  Future<int> submit(String k, MockSection section, Map<int, int> answers,
      int elapsed) async {
    final right = section.questions
        .where((q) => answers[q.no] == q.answer)
        .length;
    final v = _of(k);
    v['a'] = {for (final e in answers.entries) '${e.key}': e.value};
    v['sec'] = elapsed;
    v['done'] = true;
    v['score'] = right;
    v['best'] = right > ((v['best'] as int?) ?? -1) ? right : v['best'];
    v['n'] = ((v['n'] as int?) ?? 0) + 1;
    v['at'] = DateTime.now().toIso8601String();
    await _put(k, v);
    return right;
  }

  /// 2026-10-10 5문제 연습 기록: 묶음 번호 → 최고 정답 수.
  int? practiceBest(String k, int index) =>
      ((_of('p:$k')['$index']) as int?);

  int practiceDone(String k) => _of('p:$k').length;

  Future<void> savePractice(String k, int index, int right) async {
    final v = _of('p:$k');
    final old = v['$index'] as int?;
    if (old == null || right > old) v['$index'] = right;
    await _put('p:$k', v);
  }

  /// 다시 풀기: 답·시간을 지우고 최고 점수·횟수만 남긴다.
  Future<void> restart(String k) async {
    final v = _of(k);
    await _put(k, {
      if (v['best'] != null) 'best': v['best'],
      if (v['n'] != null) 'n': v['n'],
    });
  }
}
