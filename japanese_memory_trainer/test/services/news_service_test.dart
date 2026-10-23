import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kioku_japanese/models/vocabulary.dart';
import 'package:kioku_japanese/services/news_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 2026-10-01 쉬운 뉴스 데이터·보관소 검증
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final raw = File('test/fixtures/news_sample.json').readAsStringSync();

  test('bundled feed parses with ruby, levels, translation and key words', () {
    final articles = parseNewsFeed(raw);
    expect(articles, isNotEmpty);
    for (final a in articles) {
      expect(a.titleKorean, isNotEmpty);
      expect(a.paragraphs, isNotEmpty);
      expect(a.paragraphs.every((p) => p.korean.isNotEmpty), isTrue);
      expect(a.words, isNotEmpty);
      final tagged = a.paragraphs.expand((p) => p.tokens).where((t) => t.level != null);
      expect(tagged, isNotEmpty);
      final ruby = a.paragraphs.expand((p) => p.tokens).expand((t) => t.parts).where((p) => p.$2.isNotEmpty);
      expect(ruby, isNotEmpty);
    }
  });

  test('refresh caches remote feed and falls back when offline', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    const remote = '{"version":1,"articles":[{"id":"2099-01-01-1","date":"2099-01-01","category":"테스트",'
        '"title":[{"p":[["新","しん"]]}],"titleKo":"새 기사","paragraphs":[{"t":[{"p":[["今日","きょう"]],"lv":5,"w":"今日"}],"ko":"오늘"}],'
        '"dist":{"N5":1},"words":[{"jp":"今日","reading":"きょう","ko":"오늘","lv":5}]}]}';
    final repo = NewsRepository(prefs, feedUrl: 'https://example.com/news.json', fetcher: (_) async => remote,
        bundled: parseNewsFeed(raw), clock: () => DateTime(2100));
    final fresh = await repo.refresh();
    expect(fresh!.first.id, '2099-01-01-1');

    final offline = NewsRepository(prefs, feedUrl: 'https://example.com/news.json',
        fetcher: (_) async => throw const SocketException('offline'), bundled: parseNewsFeed(raw),
        clock: () => DateTime(2100));
    expect(await offline.refresh(), isNull);
    final local = await offline.loadLocal();
    expect(local.first.id, '2099-01-01-1'); // 저장해 둔 기사
    expect(local.length, parseNewsFeed(raw).length + 1);
  });

  test('google sheet CSV feed is parsed and enriched with app word levels', () {
    const article = '{"id":"2026-10-03-1","date":"2026-10-03","category":"사회",'
        '"title":[{"p":[["台風","たいふう"]],"b":"台風"},{"p":[["が",""]]},{"p":[["来","く"],["る",""]],"b":"来る"}],'
        '"titleKo":"태풍이 온다","paragraphs":[{"t":[{"p":[["雨","あめ"]],"b":"雨"},{"p":[["が, 降る",""]]}],"ko":"비, \\"많이\\""}]}';
    final csv = 'id,date,json\n2026-10-03-1,2026-10-03,"${article.replaceAll('"', '""')}"\n';
    final articles = parseNewsFeed(csv);
    expect(articles.single.id, '2026-10-03-1');
    expect(articles.single.paragraphs.single.korean, '비, "많이"');

    Vocabulary v(String id, String jp, String rd, String ko, String lv) => Vocabulary(
        id: id, japanese: jp, reading: rd, korean: ko, exampleJapanese: '', exampleKorean: '',
        jlptLevel: lv, wordType: '명사', frequencyRank: 1);
    final lexicon = NewsLexicon.fromWords([v('a', '台風', 'たいふう', '태풍', 'N4'), v('b', '雨', 'あめ', '비', 'N5'),
        v('c', '来る', 'くる', '오다', 'N5'), v('d', '雨', 'あめ', '비', 'N3')]);
    final enriched = articles.single.enrich(lexicon);
    expect(enriched.title.first.level, 4);
    expect(enriched.paragraphs.single.tokens.first.level, 5); // 쉬운 급수 우선
    expect(enriched.distribution['N5'], 2);
    expect(enriched.words.first.japanese, '台風'); // 어려운 단어 먼저
  });

  test('today\'s article appears only from 7 AM', () {
    final a = parseNewsFeed(raw).first;
    final day = DateTime.parse(a.date);
    expect(isNewsVisible(a, DateTime(day.year, day.month, day.day, 6, 59)), isFalse);
    expect(isNewsVisible(a, DateTime(day.year, day.month, day.day, 7, 0)), isTrue);
    expect(isNewsVisible(a, DateTime(day.year, day.month, day.day + 1, 1)), isTrue);
    expect(isNewsVisible(a, DateTime(day.year, day.month, day.day - 1, 12)), isFalse);
  });
}
