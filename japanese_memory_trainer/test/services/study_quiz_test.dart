import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kioku_japanese/models/vocabulary.dart';
import 'package:kioku_japanese/services/study_quiz.dart';

Vocabulary quizWord(String id, String japanese, String reading, {String type = '부사'}) =>
    Vocabulary(
      id: id,
      japanese: japanese,
      reading: reading,
      korean: '뜻',
      exampleJapanese: '$japanese。',
      exampleKorean: '예문',
      jlptLevel: 'N5',
      wordType: type,
      frequencyRank: 1,
    );

/// 2026-09-27 챕터 학습 문제 생성·채점 검증
void main() {
  final pool = [
    quizWord('1', '今', 'いま'),
    quizWord('2', 'いつも', 'いつも'),
    quizWord('3', '少し', 'すこし'),
    quizWord('4', '大変', 'たいへん'),
    quizWord('5', '学校', 'がっこう', type: '명사'),
    quizWord('6', '後', 'あと'),
  ];

  test('choices contain the answer and 3 other unique words', () {
    final quiz = StudyQuiz(pool: pool, random: Random(1));
    final choices = quiz.choicesFor(pool[2]);
    expect(choices, hasLength(4));
    expect(choices, contains('少し'));
    expect(choices.toSet(), hasLength(4));
  });

  test('tiles include every answer character and have 20 slots', () {
    final quiz = StudyQuiz(pool: pool, random: Random(2));
    final tiles = quiz.tilesFor(pool[3]);
    expect(tiles, hasLength(20));
    expect(tiles, containsAll(['大', '変']));
    expect(tiles.toSet(), hasLength(20));
  });

  test('typed answers accept word, reading and katakana reading', () {
    final word = pool[2];
    expect(StudyQuiz.isCorrect(word, '少し'), isTrue);
    expect(StudyQuiz.isCorrect(word, ' すこし '), isTrue);
    expect(StudyQuiz.isCorrect(word, 'スコシ'), isTrue);
    expect(StudyQuiz.isCorrect(word, 'すこ'), isFalse);
    expect(StudyQuiz.isCorrect(word, ''), isFalse);
  });
}
