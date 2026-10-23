import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kioku_japanese/models/vocabulary.dart';
import 'package:kioku_japanese/services/similar_choices.dart';
import 'package:kioku_japanese/services/study_quiz.dart';

Vocabulary word(String id, String japanese, String reading) => Vocabulary(
      id: id,
      japanese: japanese,
      reading: reading,
      korean: '뜻$id',
      exampleJapanese: '$japanese。',
      exampleKorean: '예문',
      jlptLevel: 'N4',
      wordType: '동사',
      frequencyRank: 1,
    );

/// 2026-10-23 정답과 닮은 오답 보기 고르기 검증
void main() {
  test('similar text scores higher than unrelated text', () {
    expect(SimilarChoices.textSimilarity('食べる', '食べ物'),
        greaterThan(SimilarChoices.textSimilarity('食べる', '走る')));
    expect(SimilarChoices.textSimilarity('食べる', '走る'),
        greaterThan(SimilarChoices.textSimilarity('食べる', '犬')));
    expect(SimilarChoices.textSimilarity('공부하다', '운동하다'),
        greaterThan(SimilarChoices.textSimilarity('공부하다', '사과')));
    expect(SimilarChoices.textSimilarity('', '犬'), 0);
    expect(SimilarChoices.textSimilarity('犬', '犬'), closeTo(1, 1e-9));
  });

  test('pick takes the most similar candidates and skips clashes', () {
    final picked = SimilarChoices.pick<String>(
      answer: '食べる',
      candidates: const ['食べる', '犬', '飲む', '食べ物', '走る'],
      score: SimilarChoices.textSimilarity,
      clash: (a, b) => a == b,
      count: 2,
      spread: 1,
      random: Random(3),
    );
    expect(picked.toSet(), {'食べ物', '走る'});
  });

  test('pick returns fewer items when candidates run out', () {
    final picked = SimilarChoices.pick<String>(
      answer: 'a',
      candidates: const ['a', 'b'],
      score: (a, b) => 0,
      clash: (a, b) => a == b,
      random: Random(1),
    );
    expect(picked, ['b']);
  });

  test('chapter quiz choices still hold the answer and 3 unique others', () {
    final pool = [
      word('1', '食べる', 'たべる'),
      word('2', '食べ物', 'たべもの'),
      word('3', '飲む', 'のむ'),
      word('4', '走る', 'はしる'),
      word('5', '犬', 'いぬ'),
      word('6', '学校', 'がっこう'),
    ];
    for (var seed = 0; seed < 20; seed++) {
      final choices = StudyQuiz(pool: pool, random: Random(seed)).choicesFor(pool[0]);
      expect(choices, hasLength(4));
      expect(choices.toSet(), hasLength(4));
      expect(choices, contains('食べる'));
    }
  });
}
