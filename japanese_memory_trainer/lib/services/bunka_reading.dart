import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:kioku_japanese/services/news_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 2026-10-05 문화 독해(일본 문화 읽기) 강의 데이터.
/// 원어민 녹음(bunka.zip)을 음성 인식으로 받아 적은 뒤 사람이 읽듯 다듬은 스크립트이며,
/// 문장마다 녹음 속 시작·끝 시각을 가지고 있어 문장 단위로 원음을 다시 들을 수 있다.
const bunkaLessonsAsset = 'assets/reading/bunka_lessons.json';

Duration _ms(Object? v) => Duration(milliseconds: ((v as num) * 1000).round());

List<NewsToken> _tokens(Object? raw) => [
      for (final t in (raw as List<dynamic>? ?? const []))
        NewsToken.fromJson(t as Map<String, dynamic>)
    ];

class BunkaSentence {
  const BunkaSentence(
      {required this.japanese,
      required this.korean,
      required this.tokens,
      required this.start,
      required this.end,
      this.paragraphStart = false});
  final String japanese, korean;
  final List<NewsToken> tokens;
  final Duration start, end;

  /// 이 문장에서 새 문단이 시작되는지.
  final bool paragraphStart;

  factory BunkaSentence.fromJson(Map<String, dynamic> j) => BunkaSentence(
      japanese: j['ja'] as String,
      korean: j['ko'] as String,
      tokens: _tokens(j['t']),
      start: _ms(j['s']),
      end: _ms(j['e']),
      paragraphStart: j['p'] == true);
}

class BunkaQuestion {
  const BunkaQuestion(
      {required this.japanese,
      required this.korean,
      required this.options,
      required this.answer,
      required this.explanation,
      this.start,
      this.end});
  final String japanese, korean, explanation;
  final List<String> options;
  final int answer;

  /// 문제 녹음 속 구간(없으면 null).
  final Duration? start, end;

  factory BunkaQuestion.fromJson(Map<String, dynamic> j) => BunkaQuestion(
      japanese: j['ja'] as String,
      korean: j['ko'] as String,
      options: (j['options'] as List<dynamic>).cast<String>(),
      answer: j['answer'] as int,
      explanation: j['explanation'] as String? ?? '',
      start: j['s'] == null ? null : _ms(j['s']),
      end: j['e'] == null ? null : _ms(j['e']));
}

class BunkaWord {
  const BunkaWord(this.word, this.reading, this.meaning, this.level);
  final String word, reading, meaning;
  final int level;
  factory BunkaWord.fromJson(List<dynamic> j) =>
      BunkaWord(j[0] as String, j[1] as String, j[2] as String, j[3] as int);
}

class BunkaLesson {
  const BunkaLesson(
      {required this.number,
      required this.part,
      required this.chapter,
      required this.title,
      required this.titleKorean,
      required this.titleTokens,
      required this.audio,
      required this.questionAudio,
      required this.sentences,
      required this.questions,
      required this.words,
      this.titleStart,
      this.titleEnd});
  final int number, part, chapter;
  final String title, titleKorean, audio, questionAudio;
  final List<NewsToken> titleTokens;
  final List<BunkaSentence> sentences;
  final List<BunkaQuestion> questions;
  final List<BunkaWord> words;
  final Duration? titleStart, titleEnd;

  String get id => 'bunka_$number';
  String get partLabel => part == 1 ? '기초' : '심화';

  /// 전체 해석: 문단 단위로 한국어 문장을 이어 붙인다.
  String get koreanFull {
    final buffer = StringBuffer();
    for (final s in sentences) {
      if (s.paragraphStart && buffer.isNotEmpty) buffer.write('\n\n');
      if (buffer.isNotEmpty && !buffer.toString().endsWith('\n')) {
        buffer.write(' ');
      }
      buffer.write(s.korean);
    }
    return buffer.toString();
  }

  factory BunkaLesson.fromJson(Map<String, dynamic> j) => BunkaLesson(
        number: j['number'] as int,
        part: j['part'] as int,
        chapter: j['chapter'] as int,
        title: j['title'] as String,
        titleKorean: j['titleKo'] as String,
        titleTokens: _tokens(j['titleTokens']),
        audio: j['audio'] as String,
        questionAudio: j['qaudio'] as String,
        titleStart: j['ts'] == null ? null : _ms(j['ts']),
        titleEnd: j['te'] == null ? null : _ms(j['te']),
        sentences: [
          for (final s in j['sentences'] as List<dynamic>)
            BunkaSentence.fromJson(s as Map<String, dynamic>)
        ],
        questions: [
          for (final q in j['questions'] as List<dynamic>)
            BunkaQuestion.fromJson(q as Map<String, dynamic>)
        ],
        words: [
          for (final w in j['words'] as List<dynamic>? ?? const [])
            BunkaWord.fromJson(w as List<dynamic>)
        ],
      );

  static List<BunkaLesson> parse(String raw) => [
        for (final l in jsonDecode(raw) as List<dynamic>)
          BunkaLesson.fromJson(l as Map<String, dynamic>)
      ];

  static Future<List<BunkaLesson>> load([AssetBundle? bundle]) async =>
      parse(await (bundle ?? rootBundle).loadString(bunkaLessonsAsset));
}

/// 2026-10-05 문화 독해 학습 기록(읽음 표시·문제 점수)을 기기에 저장한다.
class BunkaProgress {
  BunkaProgress(this.preferences);
  final SharedPreferences preferences;
  static const key = 'bunka_reading_records_v1';

  Map<String, dynamic> get _records {
    try {
      return jsonDecode(preferences.getString(key) ?? '{}')
          as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  Future<void> _save(Map<String, dynamic> records) =>
      preferences.setString(key, jsonEncode(records));

  bool read(String id) => _records[id]?['read'] == true;

  /// 맞힌 문제 수(아직 풀지 않았으면 null).
  int? score(String id) => _records[id]?['score'] as int?;

  Future<void> markRead(String id) async {
    final records = _records;
    final entry = Map<String, dynamic>.from(records[id] as Map? ?? {});
    entry['read'] = true;
    records[id] = entry;
    await _save(records);
  }

  Future<void> saveScore(String id, int score) async {
    final records = _records;
    final entry = Map<String, dynamic>.from(records[id] as Map? ?? {});
    entry['score'] = score;
    entry['read'] = true;
    records[id] = entry;
    await _save(records);
  }

  int get readCount => _records.values.where((e) => e['read'] == true).length;
}
