import 'package:flutter_test/flutter_test.dart';
import 'package:kioku_japanese/data/seed_words.dart';
import 'package:kioku_japanese/models/review_result.dart';
import 'package:kioku_japanese/models/vocabulary.dart';
import 'package:kioku_japanese/services/quiz_generator.dart';

const sample = Vocabulary(
  id: 'n4_001',
  japanese: '到着',
  reading: 'とうちゃく',
  korean: '도착',
  exampleJapanese: '駅に到着しました。',
  exampleKorean: '역에 도착했습니다.',
  jlptLevel: 'N4',
  wordType: '명사',
  frequencyRank: 1,
);

void main() {
  final generator = QuizGenerator();

  test('Japanese to Korean question always contains the correct answer', () {
    final question =
        generator.buildQuestion(sample, QuizDirection.japaneseToKorean);
    expect(question.prompt, contains('到着'));
    expect(question.prompt, isNot(contains('도착')));
    expect(question.correctAnswer, '도착');
    expect(question.choices, hasLength(4));
    expect(question.choices.toSet(), hasLength(4));
    expect(question.choices, contains('도착'));
  });

  test('Korean to Japanese question always contains the correct answer', () {
    final question =
        generator.buildQuestion(sample, QuizDirection.koreanToJapanese);
    expect(question.prompt, '도착');
    expect(question.correctAnswer, '到着');
    expect(question.choices, hasLength(4));
    expect(question.choices.toSet(), hasLength(4));
    expect(question.choices, contains('到着'));
  });

  test('sentence blank always contains the correct answer', () {
    final question = generator.buildQuestion(sample, QuizDirection.sentenceBlank);
    expect(question.prompt, '駅に______しました。');
    expect(question.correctAnswer, '到着');
    expect(question.choices, hasLength(4));
    expect(question.choices.toSet(), hasLength(4));
    expect(question.choices, contains('到着'));
  });

  test('listening question always contains the correct answer', () {
    final question = generator.buildQuestion(sample, QuizDirection.listening);
    expect(question.ttsText, '到着');
    expect(question.prompt, '무슨 단어입니까?');
    expect(question.correctAnswer, '到着');
    expect(question.choices, hasLength(4));
    expect(question.choices.toSet(), hasLength(4));
    expect(question.choices, contains('到着'));
  });

  test('all sentence blank questions replace the target inside the sentence', () {
    for (final word in seedWords) {
      final question =
          generator.buildQuestion(word, QuizDirection.sentenceBlank);
      expect(
        question.prompt,
        contains('______'),
        reason: '${word.id} must contain a blank',
      );
      expect(
        question.prompt.endsWith('\n______'),
        isFalse,
        reason: '${word.id} must blank the word inside the example sentence',
      );
    }
  });

  test('all seed words in all four quiz types have exactly one correct choice', () {
    for (final word in seedWords) {
      for (final direction in QuizDirection.values) {
        final question = generator.buildQuestion(word, direction);
        expect(
          question.choices,
          hasLength(4),
          reason: '${word.id} $direction must have four choices',
        );
        expect(
          question.choices.toSet(),
          hasLength(4),
          reason: '${word.id} $direction must not contain duplicate choices',
        );
        expect(
          question.choices.where((choice) => choice == question.correctAnswer),
          hasLength(1),
          reason: '${word.id} $direction must contain the correct answer once',
        );
      }
    }
  });
}
