import 'package:flutter_test/flutter_test.dart';
import 'package:kioku_japanese/models/vocabulary.dart';
import 'package:kioku_japanese/models/word_catalog.dart';

Vocabulary catalogWord(int id, String grade, String type) => Vocabulary(
      id: 'w$id',
      japanese: '語$id',
      reading: 'ご$id',
      korean: '뜻$id',
      exampleJapanese: '語$idです。',
      exampleKorean: '뜻$id입니다.',
      jlptLevel: grade,
      wordType: type,
      frequencyRank: id,
    );

/// 2026-09-27 급수 → 품사 → 14단어 챕터 나누기 검증
void main() {
  test('words are grouped by grade and category in fixed order', () {
    final catalog = WordCatalog([
      catalogWord(1, 'N5', '부사'),
      catalogWord(2, 'N5', '명사'),
      catalogWord(3, 'N4', '동사'),
      catalogWord(4, 'N5', '동사'),
      catalogWord(5, 'N9', '명사'),
    ]);
    expect(catalog.categoriesOf('N5'), ['명사', '동사', '부사']);
    expect(catalog.wordsOfGrade('N5'), hasLength(3));
    expect(catalog.allWords, hasLength(4));
    expect(WordCatalog.categoryLabel('부사'), '副詞');
  });

  test('chapters hold 14 words and the last one keeps the rest', () {
    final catalog = WordCatalog([
      for (var i = 1; i <= 33; i++) catalogWord(i, 'N5', '부사'),
    ]);
    final chapters = catalog.chaptersOf('N5', '부사');
    expect(chapters.map((c) => c.words.length).toList(), [14, 14, 5]);
    expect(chapters[1].words.first.id, 'w15');
    expect(chapters[0].title, 'N5 · 副詞 · 第1章');
    expect(chapters[2].number, 3);
  });
}
