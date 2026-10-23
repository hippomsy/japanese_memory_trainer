import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:kioku_japanese/services/news_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 2026-10-14 N4 이야기 극장: 직접 쓴 N4 수준 창작 단편 10편.
/// 원고는 tool/stories/sNN.py, 후리가나·단어 연결은 tool/stories/build_stories.py 가 만든다.
/// 녹음 파일 없이 기기 TTS(ja-JP)로 전체·문장 듣기를 한다.
const storiesAsset = 'assets/stories/n4_stories.json';

List<NewsToken> _tokens(Object? raw) => [
      for (final t in (raw as List<dynamic>? ?? const []))
        NewsToken.fromJson(t as Map<String, dynamic>)
    ];

class StorySentence {
  const StorySentence(
      {required this.japanese,
      required this.korean,
      required this.tokens,
      this.paragraphStart = false});
  final String japanese, korean;
  final List<NewsToken> tokens;
  final bool paragraphStart;

  factory StorySentence.fromJson(Map<String, dynamic> j) => StorySentence(
      japanese: j['ja'] as String,
      korean: j['ko'] as String,
      tokens: _tokens(j['t']),
      paragraphStart: j['p'] == true);
}

class StoryWord {
  const StoryWord(this.word, this.reading, this.meaning, this.level);
  final String word, reading, meaning;
  final int level;

  /// 읽기만으로 된 단어(わざと 등)는 표기와 읽기가 같다.
  bool get kanaOnly => word == reading;

  factory StoryWord.fromJson(List<dynamic> j) =>
      StoryWord(j[0] as String, j[1] as String, j[2] as String, j[3] as int);
}

class StoryGrammar {
  const StoryGrammar(
      {required this.pattern,
      required this.meaning,
      required this.note,
      required this.japanese,
      required this.korean});
  final String pattern, meaning, note, japanese, korean;

  factory StoryGrammar.fromJson(Map<String, dynamic> j) => StoryGrammar(
      pattern: j['pattern'] as String,
      meaning: j['meaning'] as String,
      note: j['note'] as String,
      japanese: j['ja'] as String,
      korean: j['ko'] as String);
}

class StoryQuestion {
  const StoryQuestion(
      {required this.japanese,
      required this.korean,
      required this.options,
      required this.answer,
      required this.explanation});
  final String japanese, korean, explanation;
  final List<String> options;
  final int answer;

  factory StoryQuestion.fromJson(Map<String, dynamic> j) => StoryQuestion(
      japanese: j['ja'] as String,
      korean: j['ko'] as String,
      options: (j['options'] as List<dynamic>).cast<String>(),
      answer: j['answer'] as int,
      explanation: j['explanation'] as String? ?? '');
}

class Story {
  const Story(
      {required this.number,
      required this.title,
      required this.titleKorean,
      required this.scene,
      required this.summary,
      required this.titleTokens,
      required this.sentences,
      required this.words,
      required this.grammar,
      required this.questions});
  final int number;
  final String title, titleKorean, scene, summary;
  final List<NewsToken> titleTokens;
  final List<StorySentence> sentences;
  final List<StoryWord> words;
  final List<StoryGrammar> grammar;
  final List<StoryQuestion> questions;

  String get id => 'story_$number';

  /// 전체 해석: 문단 단위로 한국어 문장을 이어 붙인다.
  String get koreanFull {
    final buffer = StringBuffer();
    for (final s in sentences) {
      if (s.paragraphStart && buffer.isNotEmpty) {
        buffer.write('\n\n');
      } else if (buffer.isNotEmpty) {
        buffer.write(' ');
      }
      buffer.write(s.korean);
    }
    return buffer.toString();
  }

  factory Story.fromJson(Map<String, dynamic> j) => Story(
        number: j['number'] as int,
        title: j['title'] as String,
        titleKorean: j['titleKo'] as String,
        scene: j['scene'] as String,
        summary: j['summary'] as String? ?? '',
        titleTokens: _tokens(j['titleTokens']),
        sentences: [
          for (final s in j['sentences'] as List<dynamic>)
            StorySentence.fromJson(s as Map<String, dynamic>)
        ],
        words: [
          for (final w in j['words'] as List<dynamic>? ?? const [])
            StoryWord.fromJson(w as List<dynamic>)
        ],
        grammar: [
          for (final g in j['grammar'] as List<dynamic>? ?? const [])
            StoryGrammar.fromJson(g as Map<String, dynamic>)
        ],
        questions: [
          for (final q in j['questions'] as List<dynamic>? ?? const [])
            StoryQuestion.fromJson(q as Map<String, dynamic>)
        ],
      );

  static List<Story> parse(String raw) => [
        for (final s in jsonDecode(raw) as List<dynamic>)
          Story.fromJson(s as Map<String, dynamic>)
      ];

  static Future<List<Story>> load([AssetBundle? bundle]) async =>
      parse(await (bundle ?? rootBundle).loadString(storiesAsset));
}

/// 2026-10-14 이야기별 학습 기록(읽음·문제 점수·외운 단어)을 기기에 저장한다.
class StoryProgress {
  StoryProgress(this.preferences);
  final SharedPreferences preferences;
  static const key = 'n4_story_records_v1';

  Map<String, dynamic> get _records {
    try {
      return jsonDecode(preferences.getString(key) ?? '{}')
          as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  Map<String, dynamic> _entry(String id) =>
      Map<String, dynamic>.from(_records[id] as Map? ?? {});

  Future<void> _put(String id, Map<String, dynamic> entry) {
    final records = _records;
    records[id] = entry;
    return preferences.setString(key, jsonEncode(records));
  }

  bool read(String id) => _entry(id)['read'] == true;

  /// 맞힌 문제 수(아직 다 풀지 않았으면 null).
  int? score(String id) => _entry(id)['score'] as int?;

  /// 단어 카드에서 "알아요"로 표시한 단어.
  Set<String> known(String id) =>
      {...(_entry(id)['known'] as List<dynamic>? ?? const []).cast<String>()};

  Future<void> markRead(String id) {
    final e = _entry(id)..['read'] = true;
    return _put(id, e);
  }

  Future<void> saveScore(String id, int score) {
    final e = _entry(id)
      ..['score'] = score
      ..['read'] = true;
    return _put(id, e);
  }

  Future<void> setKnown(String id, String word, bool known) {
    final set = this.known(id);
    known ? set.add(word) : set.remove(word);
    final list = set.toList()..sort();
    final e = _entry(id)..['known'] = list;
    return _put(id, e);
  }

  int get readCount => _records.values.where((e) => e['read'] == true).length;
}
