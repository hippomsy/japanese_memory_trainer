import 'package:flutter_test/flutter_test.dart';
import 'package:kioku_japanese/models/vocabulary.dart';
import 'package:kioku_japanese/services/news_service.dart';
import 'package:kioku_japanese/services/daily_reading_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

final readingLexicon = NewsLexicon.fromWords([
  const Vocabulary(
      id: 'book',
      japanese: '本',
      reading: 'ほん',
      korean: '책',
      exampleJapanese: '',
      exampleKorean: '',
      jlptLevel: 'N5',
      wordType: '명사',
      frequencyRank: 1),
]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'diary unlocks at seven, persists start date and ends with 365 unique episodes',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    var now = DateTime(2026, 10, 4, 6, 59);
    final service =
        DailyReadingService(prefs, readingLexicon, clock: () => now);
    expect(await service.diaries(), isEmpty);
    now = DateTime(2026, 10, 4, 7);
    expect((await service.diaries()).length, 1);
    now = DateTime(2026, 10, 5, 7);
    expect(
        (await DailyReadingService(prefs, readingLexicon, clock: () => now)
                .diaries())
            .length,
        2);
    now = DateTime(2028);
    final diaries = await service.diaries();
    expect(diaries.length, 365);
    expect(diaries.map((a) => a.id).toSet().length, 365);
    expect(diaries.first.category, '하루의 일기 · 1화');
    expect(diaries.last.category, '하루의 일기 · 365화');
    for (final a in diaries) {
      expect(a.paragraphs.length, inInclusiveRange(3, 4));
      expect(a.question!.options.toSet().length, 4);
      expect(a.question!.answer, inInclusiveRange(0, 3));
      expect(a.paragraphs.every((p) => p.korean.isNotEmpty), isTrue);
      expect(
          a.paragraphs
              .expand((p) => p.tokens)
              .expand((t) => t.parts)
              .any((p) => p.$2.isNotEmpty),
          isTrue);
    }
  });
}
