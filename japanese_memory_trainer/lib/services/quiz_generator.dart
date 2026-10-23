import 'package:kioku_japanese/data/seed_words.dart';
import 'package:kioku_japanese/models/quiz_question.dart';
import 'package:kioku_japanese/models/review_result.dart';
import 'package:kioku_japanese/models/vocabulary.dart';

/// 2026-09-26 한 단어를 네 가지 객관식 인출 문제 형식으로 변환한다.
class QuizGenerator {
  QuizGenerator({List<Vocabulary> words = seedWords})
      : _words = List<Vocabulary>.unmodifiable(words);

  final List<Vocabulary> _words;

  /// 2026-09-26 모든 문제는 미리보기와 같은 4지선다 선택지를 만든다.
  QuizQuestion buildQuestion(Vocabulary word, QuizDirection direction) {
    switch (direction) {
      case QuizDirection.japaneseToKorean:
        return QuizQuestion(
          wordId: word.id,
          direction: direction,
          prompt: '${word.japanese}\n${word.reading}',
          correctAnswer: word.korean,
          choices: _buildChoices(
            word: word,
            direction: direction,
            correctAnswer: word.korean,
            candidates: _words.map((item) => item.korean),
          ),
          ttsText: word.japanese,
          exampleJapanese: word.exampleJapanese,
          exampleKorean: word.exampleKorean,
        );
      case QuizDirection.koreanToJapanese:
        return QuizQuestion(
          wordId: word.id,
          direction: direction,
          prompt: word.korean,
          correctAnswer: word.japanese,
          choices: _buildChoices(
            word: word,
            direction: direction,
            correctAnswer: word.japanese,
            candidates: _words.map((item) => item.japanese),
          ),
          ttsText: null,
          exampleJapanese: word.exampleJapanese,
          exampleKorean: word.exampleKorean,
        );
      case QuizDirection.sentenceBlank:
        // 2026-09-26 기본형이 예문에서 활용된 경우 실제 활용형을 찾아 문장 안에서 빈칸 처리한다.
        final exampleTarget = word.exampleTargetJapanese ?? word.japanese;
        final prompt = word.exampleJapanese.contains(exampleTarget)
            ? word.exampleJapanese.replaceFirst(exampleTarget, '______')
            : '${word.exampleJapanese}\n______';
        return QuizQuestion(
          wordId: word.id,
          direction: direction,
          prompt: prompt,
          correctAnswer: word.japanese,
          choices: _buildChoices(
            word: word,
            direction: direction,
            correctAnswer: word.japanese,
            candidates: _words.map((item) => item.japanese),
          ),
          ttsText: null,
          exampleJapanese: word.exampleJapanese,
          exampleKorean: word.exampleKorean,
        );
      case QuizDirection.listening:
        return QuizQuestion(
          wordId: word.id,
          direction: direction,
          prompt: '무슨 단어입니까?',
          correctAnswer: word.japanese,
          choices: _buildChoices(
            word: word,
            direction: direction,
            correctAnswer: word.japanese,
            candidates: _words.map((item) => item.japanese),
          ),
          ttsText: word.japanese,
          exampleJapanese: word.exampleJapanese,
          exampleKorean: word.exampleKorean,
        );
    }
  }

  /// 2026-09-26 정답은 반드시 1개 포함하고, 중복 없는 오답 3개만 골라 4지선다를 만든다.
  List<String> _buildChoices({
    required Vocabulary word,
    required QuizDirection direction,
    required String correctAnswer,
    required Iterable<String> candidates,
  }) {
    final seen = <String>{correctAnswer};
    final distractors = <String>[];

    // 2026-09-26 정답과 같은 값은 제외하고 실제 단어 DB에서 오답 후보를 모은다.
    for (final candidate in candidates) {
      if (seen.add(candidate)) {
        distractors.add(candidate);
      }
    }

    // 2026-09-26 단어 수가 적은 테스트 환경에서도 4지선다가 되도록 보충 후보를 사용한다.
    final fallbacks = direction == QuizDirection.japaneseToKorean
        ? const <String>['출발', '예약', '경험', '관계', '준비']
        : const <String>['出発', '予約', '経験', '関係', '準備'];
    for (final fallback in fallbacks) {
      if (distractors.length >= 3) break;
      if (seen.add(fallback)) {
        distractors.add(fallback);
      }
    }

    if (distractors.length < 3) {
      throw StateError('4지선다 오답 후보가 부족합니다: ${word.id} / $direction');
    }

    // 2026-09-26 오답 후보를 안정적으로 섞은 뒤 3개만 선택한다.
    distractors.sort((a, b) {
      final aScore = _stableScore(
        '${word.id}|${direction.index}|distractor|$a',
      );
      final bScore = _stableScore(
        '${word.id}|${direction.index}|distractor|$b',
      );
      return aScore.compareTo(bScore);
    });

    final choices = <String>[
      correctAnswer,
      ...distractors.take(3),
    ];

    // 2026-09-26 정답 위치도 문제마다 달라지도록 최종 4개만 다시 안정적으로 섞는다.
    choices.sort((a, b) {
      final aScore = _stableScore('${word.id}|${direction.index}|choice|$a');
      final bScore = _stableScore('${word.id}|${direction.index}|choice|$b');
      return aScore.compareTo(bScore);
    });

    // 2026-09-26 릴리스 빌드에서도 정답 누락/중복 문제를 조용히 표시하지 않도록 최종 검증한다.
    final correctCount =
        choices.where((choice) => choice == correctAnswer).length;
    if (choices.length != 4 ||
        choices.toSet().length != 4 ||
        correctCount != 1) {
      throw StateError(
        '잘못된 4지선다 구성: ${word.id} / $direction / $choices',
      );
    }

    return List<String>.unmodifiable(choices);
  }

  int _stableScore(String value) {
    var result = 17;
    for (final unit in value.codeUnits) {
      result = (result * 31 + unit) & 0x7fffffff;
    }
    return result;
  }
}
