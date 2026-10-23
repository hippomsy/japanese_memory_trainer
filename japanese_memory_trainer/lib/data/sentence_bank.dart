import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:kioku_japanese/models/word_catalog.dart';

/// 2026-09-30 문장 만들기 문제 한 개. 한국어 뜻을 보고 [chunks]를 올바른 순서로 늘어놓는다.
class SentenceItem {
  const SentenceItem({
    required this.wordId,
    required this.korean,
    required this.kana,
    required this.chunks,
  });

  /// 이 문장이 연습하는 챕터 단어 ID.
  final String wordId;
  final String korean;

  /// 문장 전체의 히라가나 읽기.
  final String kana;

  /// 올바른 순서의 문장 조각들.
  final List<String> chunks;

  String get japanese => chunks.join();

  factory SentenceItem.fromJson(Map<String, dynamic> json) => SentenceItem(
        wordId: json['w'] as String,
        korean: json['ko'] as String,
        kana: json['kana'] as String? ?? '',
        chunks: (json['ja'] as List<dynamic>).cast<String>(),
      );
}

/// 2026-09-30 챕터별 문장 만들기 문제 모음(챕터마다 5문제, N4 수준 문법).
/// 키는 "급수|품사|챕터번호"(예: N5|명사|1)이다.
class SentenceBank {
  SentenceBank(this._byChapter);

  static const String assetPath = 'assets/sentences/sentences.json';
  static SentenceBank instance = SentenceBank(const <String, List<SentenceItem>>{});

  final Map<String, List<SentenceItem>> _byChapter;

  int get chapterCount => _byChapter.length;

  static String keyOf(Chapter chapter) => '${chapter.grade}|${chapter.category}|${chapter.number}';

  static SentenceBank parse(String raw) {
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return SentenceBank(<String, List<SentenceItem>>{
      for (final e in map.entries)
        e.key: [
          for (final item in e.value as List<dynamic>) SentenceItem.fromJson(item as Map<String, dynamic>),
        ],
    });
  }

  static Future<SentenceBank> load() async => parse(await rootBundle.loadString(assetPath));

  List<SentenceItem> forChapter(Chapter chapter) => _byChapter[keyOf(chapter)] ?? const <SentenceItem>[];
}
