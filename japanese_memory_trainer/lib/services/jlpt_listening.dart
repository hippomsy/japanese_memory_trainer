import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:kioku_japanese/services/news_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 2026-10-08 JLPT N5 청해(완전정복 한 권으로 N5 MP3 · 4회분 96문제) 데이터.
/// 원어민 녹음을 음성 인식으로 받아 적고 사람이 다듬은 스크립트이다.
/// 問題1·2는 책의 그림(문제 용지)이 없으므로 대화에 맞춰 그림문자 보기를 새로 만들었다.
const jlptN5ListeningAsset = 'assets/jlpt_n5/listening.json';

Duration _sec(Object? v) =>
    Duration(milliseconds: ((v as num) * 1000).round());

List<NewsToken> _tokens(Object? raw) => [
      for (final t in (raw as List<dynamic>? ?? const []))
        NewsToken.fromJson(t as Map<String, dynamic>)
    ];

/// 녹음 속 구간(문제 오디오 파일 기준).
class JlptSpan {
  const JlptSpan(this.start, this.end);
  final Duration start, end;
  static JlptSpan? fromJson(Object? raw) {
    if (raw is! List || raw.length < 2) return null;
    return JlptSpan(_sec(raw[0]), _sec(raw[1]));
  }

  bool contains(Duration p) => p >= start && p < end;
}

class JlptLine {
  const JlptLine(
      {required this.speaker,
      required this.japanese,
      required this.korean,
      required this.tokens,
      required this.span});
  final String speaker, japanese, korean;
  final List<NewsToken> tokens;
  final JlptSpan span;

  /// 「ナ」는 문제 안내(내레이션).
  bool get isNarration => speaker == 'ナ';

  factory JlptLine.fromJson(Map<String, dynamic> j) => JlptLine(
      speaker: j['sp'] as String,
      japanese: j['ja'] as String,
      korean: j['ko'] as String,
      tokens: _tokens(j['r']),
      span: JlptSpan.fromJson(j['span'])!);
}

class JlptOption {
  const JlptOption(
      {required this.japanese, required this.korean, this.emoji, this.span});
  final String japanese, korean;

  /// 問題1·2 보기 그림(그림문자). 問題3·4는 없음.
  final String? emoji;

  /// 問題3·4 보기가 녹음 속에서 읽히는 구간.
  final JlptSpan? span;

  factory JlptOption.fromJson(Map<String, dynamic> j) => JlptOption(
      japanese: j['ja'] as String,
      korean: j['ko'] as String,
      emoji: j['emoji'] as String?,
      span: JlptSpan.fromJson(j['span']));
}

class JlptScene {
  const JlptScene(
      {required this.emoji, required this.japanese, required this.korean});
  final String emoji, japanese, korean;
}

class JlptQuestion {
  const JlptQuestion({
    required this.id,
    required this.test,
    required this.mondai,
    required this.number,
    required this.audio,
    required this.duration,
    required this.lines,
    required this.options,
    required this.answer,
    required this.explanation,
    this.ask,
    this.askKorean,
    this.askTokens = const [],
    this.scene,
    this.note,
  });

  final String id, audio, explanation;
  final int test, mondai, number, answer;
  final Duration duration;
  final List<JlptLine> lines;
  final List<JlptOption> options;
  final String? ask, askKorean, note;
  final List<NewsToken> askTokens;
  final JlptScene? scene;

  /// 問題3·4: 보기를 소리로만 듣는 문제(그림 보기 없음).
  bool get optionsSpoken => mondai >= 3;

  factory JlptQuestion.fromJson(Map<String, dynamic> j) {
    final ask = j['ask'] as Map<String, dynamic>?;
    final pic = j['pic'] as Map<String, dynamic>?;
    return JlptQuestion(
      id: j['id'] as String,
      test: j['test'] as int,
      mondai: j['mondai'] as int,
      number: j['no'] as int,
      audio: j['audio'] as String,
      duration: _sec(j['duration']),
      lines: [
        for (final l in j['lines'] as List<dynamic>)
          JlptLine.fromJson(l as Map<String, dynamic>)
      ],
      options: [
        for (final o in j['options'] as List<dynamic>)
          JlptOption.fromJson(o as Map<String, dynamic>)
      ],
      answer: j['answer'] as int,
      explanation: j['exp'] as String? ?? '',
      ask: ask?['ja'] as String?,
      askKorean: ask?['ko'] as String?,
      askTokens: _tokens(ask?['r']),
      scene: pic == null
          ? null
          : JlptScene(
              emoji: pic['emoji'] as String,
              japanese: pic['ja'] as String,
              korean: pic['ko'] as String),
      note: j['note'] as String?,
    );
  }
}

class JlptTest {
  const JlptTest(
      {required this.id, required this.title, required this.korean});
  final int id;
  final String title, korean;
}

class JlptMondai {
  const JlptMondai(
      {required this.id, required this.japanese, required this.korean});
  final int id;
  final String japanese, korean;

  /// 문제 유형 안내(한국어).
  String get guide => switch (id) {
        1 => '대화를 듣고 앞으로 할 일·고를 것을 찾아요.',
        2 => '질문의 핵심 정보(시간·장소·이유)를 찾아요.',
        3 => '그림의 상황에서 화살표(➡) 사람이 할 말을 골라요.',
        _ => '짧은 말을 듣고 알맞은 대답을 골라요.',
      };
}

class JlptListeningBook {
  const JlptListeningBook(
      {required this.tests, required this.mondai, required this.questions});
  final List<JlptTest> tests;
  final List<JlptMondai> mondai;
  final List<JlptQuestion> questions;

  List<JlptQuestion> section(int test, int mondai) => [
        for (final q in questions)
          if (q.test == test && q.mondai == mondai) q
      ];

  List<JlptQuestion> ofTest(int test) =>
      [for (final q in questions) if (q.test == test) q];

  JlptMondai mondaiOf(int id) => mondai.firstWhere((m) => m.id == id);
  JlptTest testOf(int id) => tests.firstWhere((t) => t.id == id);

  static JlptListeningBook parse(String raw) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    return JlptListeningBook(
      tests: [
        for (final t in j['tests'] as List<dynamic>)
          JlptTest(
              id: (t as Map<String, dynamic>)['id'] as int,
              title: t['title'] as String,
              korean: t['ko'] as String)
      ],
      mondai: [
        for (final m in j['mondai'] as List<dynamic>)
          JlptMondai(
              id: (m as Map<String, dynamic>)['id'] as int,
              japanese: m['ja'] as String,
              korean: m['ko'] as String)
      ],
      questions: [
        for (final q in j['questions'] as List<dynamic>)
          JlptQuestion.fromJson(q as Map<String, dynamic>)
      ],
    );
  }

  static Future<JlptListeningBook> load([AssetBundle? bundle]) async =>
      parse(await (bundle ?? rootBundle).loadString(jlptN5ListeningAsset));
}

/// 2026-10-08 JLPT N5 청해 풀이 기록(문제별 마지막 선택·정답 여부)을 기기에 저장한다.
class JlptListeningProgress {
  JlptListeningProgress(this.preferences);
  final SharedPreferences preferences;
  static const key = 'jlpt_n5_listening_v1';

  Map<String, dynamic> get _records {
    try {
      return jsonDecode(preferences.getString(key) ?? '{}')
          as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  /// 마지막으로 고른 보기(아직 안 풀었으면 null).
  int? choice(String id) => (_records[id] as Map?)?['c'] as int?;

  bool? correct(String id) => (_records[id] as Map?)?['ok'] as bool?;

  Future<void> answer(String id, int choice, bool correct) async {
    final records = _records;
    final old = Map<String, dynamic>.from(records[id] as Map? ?? {});
    records[id] = {
      'c': choice,
      'ok': correct,
      'n': ((old['n'] as int?) ?? 0) + 1,
      'at': DateTime.now().toIso8601String(),
    };
    await preferences.setString(key, jsonEncode(records));
  }

  Future<void> clear(Iterable<String> ids) async {
    final records = _records;
    for (final id in ids) {
      records.remove(id);
    }
    await preferences.setString(key, jsonEncode(records));
  }

  int solved(Iterable<JlptQuestion> qs) =>
      qs.where((q) => choice(q.id) != null).length;
  int right(Iterable<JlptQuestion> qs) =>
      qs.where((q) => correct(q.id) == true).length;
  List<JlptQuestion> wrong(Iterable<JlptQuestion> qs) =>
      [for (final q in qs) if (correct(q.id) == false) q];
}
