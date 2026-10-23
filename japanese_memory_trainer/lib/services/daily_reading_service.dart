import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'news_service.dart';

String readingDate(DateTime time) =>
    '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')}';

/// 2026-10-04 하루의 일기: 미리 작성한 365편(앱에 포함)을 첫 사용일부터 하루 한 편씩,
/// 오전 7시에 공개한다. 인터넷·외부 기사·자동 번역을 쓰지 않으므로 배포해도 저작권 문제가 없다.
/// (예전의 RSS 뉴스 + 기기 내 번역 기능은 배포 시 저작권 위험 때문에 제거했다.)
class DailyReadingService {
  DailyReadingService(this.preferences, this.lexicon,
      {DateTime Function()? clock})
      : clock = clock ?? DateTime.now;

  static const String startKey = 'diary_start_v1';
  static const String assetPath = 'assets/news/haru_diary.json';

  final SharedPreferences preferences;
  final NewsLexicon lexicon;
  final DateTime Function() clock;

  List<dynamic>? _raw;

  Future<List<NewsArticle>> diaries() async {
    final now = clock();
    var start = preferences.getString(startKey);
    if (start == null) {
      start = readingDate(now);
      await preferences.setString(startKey, start);
    }
    final first = DateTime.parse(start);
    final raw = _raw ??=
        jsonDecode(await rootBundle.loadString(assetPath)) as List<dynamic>;
    final result = <NewsArticle>[];
    for (var i = 0; i < raw.length; i++) {
      final day = DateTime(first.year, first.month, first.day + i);
      // 아직 공개되지 않은 날부터는 볼 필요가 없다.
      if (day.isAfter(DateTime(now.year, now.month, now.day))) break;
      final entry = raw[i] as Map<String, dynamic>;
      final sentences = entry['sentences'] as List<dynamic>;
      final tokens = entry['tokens'] as List<dynamic>;
      final article = NewsArticle(
          id: '${readingDate(day)}-diary',
          date: readingDate(day),
          category: '하루의 일기 · ${i + 1}화',
          title: [
            for (final t in entry['titleTokens'] as List<dynamic>)
              NewsToken.fromJson(t as Map<String, dynamic>)
          ],
          titleKorean: entry['titleKo'] as String,
          paragraphs: [
            // 문장 순서(j)로 후리가나 조각을 짝지어, 같은 문장이 두 번 나와도 섞이지 않게 한다.
            for (var j = 0; j < sentences.length; j++)
              NewsParagraph(tokens: [
                for (final t in tokens[j] as List<dynamic>)
                  NewsToken.fromJson(t as Map<String, dynamic>)
              ], korean: (sentences[j] as List<dynamic>)[1] as String)
          ],
          distribution: const {},
          words: const [],
          question:
              NewsQuestion.fromJson(entry['question'] as Map<String, dynamic>),
          source:
              '앱에서 작성한 창작 일기 · 하루(24세), 도쿄의 작은 서점 직원 · 총 ${raw.length}화');
      if (isNewsVisible(article, now)) result.add(article.enrich(lexicon));
    }
    return result;
  }
}
