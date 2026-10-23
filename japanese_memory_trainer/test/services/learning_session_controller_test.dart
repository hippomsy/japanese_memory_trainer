import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kioku_japanese/data/local_database.dart';
import 'package:kioku_japanese/models/memory_state.dart';
import 'package:kioku_japanese/models/review_result.dart';
import 'package:kioku_japanese/models/vocabulary.dart';
import 'package:kioku_japanese/services/learning_repository.dart';
import 'package:kioku_japanese/services/learning_session_controller.dart';
import 'package:kioku_japanese/services/memory_evaluator.dart';
import 'package:kioku_japanese/services/quiz_generator.dart';
import 'package:shared_preferences/shared_preferences.dart';

Vocabulary word(int id) => Vocabulary(
      id: 'w$id',
      japanese: '日$id',
      reading: 'よみ$id',
      korean: '뜻$id',
      exampleJapanese: '日$id を覚えます。',
      exampleKorean: '뜻$id 을 외웁니다.',
      jlptLevel: 'N4',
      wordType: '명사',
      frequencyRank: id,
    );

class DelayedSaveDatabase extends LocalDatabase {
  DelayedSaveDatabase(SharedPreferences preferences, {required DateTime Function() now})
      : super(preferences, now: now);

  final Completer<void> saveCompleter = Completer<void>();

  @override
  Future<void> saveMemoryStates(Map<String, MemoryState> states) async {
    await saveCompleter.future;
    await super.saveMemoryStates(states);
  }
}

class FailingSaveDatabase extends LocalDatabase {
  FailingSaveDatabase(SharedPreferences preferences, {required DateTime Function() now})
      : super(preferences, now: now);

  @override
  Future<void> saveMemoryStates(Map<String, MemoryState> states) async {
    throw StateError('disk full');
  }
}

Future<SharedPreferences> freshPreferences() async {
  SharedPreferences.setMockInitialValues({});
  return SharedPreferences.getInstance();
}

LearningSessionController controllerFor(
  LocalDatabase db, {
  List<Vocabulary>? words,
  int newWordLimit = 5,
}) {
  final repository = LearningRepository(
    seed: words ?? List.generate(8, (i) => word(i + 1)),
    database: db,
  );
  return LearningSessionController(
    repository: repository,
    database: db,
    evaluator: MemoryEvaluator(),
    quizGenerator: QuizGenerator(),
    newWordLimit: newWordLimit,
  );
}

void main() {
  test('starting quest loads new words first and then due review words', () async {
    final prefs = await freshPreferences();
    final db = LocalDatabase(prefs, now: () => DateTime(2026, 9, 26, 8));
    await db.saveMemoryStates({
      'w4': MemoryState.initial('w4').copyWith(
        stage: 2,
        nextReviewAt: DateTime(2026, 9, 25),
      ),
    });
    final controller = controllerFor(
      db,
      words: List.generate(5, (i) => word(i + 1)),
      newWordLimit: 2,
    );

    await controller.startTodayQuest(DateTime(2026, 9, 26, 8));

    expect(controller.state.newWords.map((e) => e.id).toList(), ['w1', 'w2']);
    final ids = controller.state.questions.map((e) => e.wordId).toList();
    expect(ids.take(8).toSet(), {'w1', 'w2'});
    expect(ids.last, 'w4');
  });

  test('submitting an answer updates in-memory state before persistence completes', () async {
    final prefs = await freshPreferences();
    final db = DelayedSaveDatabase(prefs, now: () => DateTime(2026, 9, 26, 8));
    final controller = controllerFor(db, words: [word(1)], newWordLimit: 1);
    await controller.startTodayQuest(DateTime(2026, 9, 26, 8));

    final pending = controller.submitAnswer(
      answer: controller.state.currentQuestion!.correctAnswer,
      feeling: MemoryFeeling.remembered,
      responseMs: 1500,
      now: DateTime(2026, 9, 26, 8, 1),
    );
    await Future<void>.delayed(Duration.zero);

    expect(controller.state.results, hasLength(1));
    expect(controller.state.currentAnswered, isTrue);
    db.saveCompleter.complete();
    await pending;
  });

  test('persistence exception sets persistenceError but keeps answered result', () async {
    final prefs = await freshPreferences();
    final db = FailingSaveDatabase(prefs, now: () => DateTime(2026, 9, 26, 8));
    final controller = controllerFor(db, words: [word(1)], newWordLimit: 1);
    await controller.startTodayQuest(DateTime(2026, 9, 26, 8));

    await controller.submitAnswer(
      answer: controller.state.currentQuestion!.correctAnswer,
      feeling: MemoryFeeling.remembered,
      responseMs: 1500,
      now: DateTime(2026, 9, 26, 8, 1),
    );

    expect(controller.persistenceError, isNotNull);
    expect(controller.state.results, hasLength(1));
    expect(controller.state.currentAnswered, isTrue);
  });

  test('completing the last question marks session complete', () async {
    final prefs = await freshPreferences();
    final db = LocalDatabase(prefs, now: () => DateTime(2026, 9, 26, 8));
    final controller = controllerFor(db, words: [word(1)], newWordLimit: 1);
    await controller.startTodayQuest(DateTime(2026, 9, 26, 8));

    while (!controller.state.isComplete) {
      final question = controller.state.currentQuestion!;
      await controller.submitAnswer(
        answer: question.correctAnswer,
        feeling: MemoryFeeling.remembered,
        responseMs: 1200,
        now: DateTime(2026, 9, 26, 8, 2),
      );
      controller.moveNext();
    }

    expect(controller.state.isComplete, isTrue);
    expect(controller.state.results, hasLength(4));
  });

  // 2026-09-27 FSRS 도입 이후에는 같은 세션 안의 연속 문제라도 매번 stability를
  // 다시 계산한다. 첫 문제(Good 등급)로 초기 stability가 잡히고, 이어지는
  // 3문제는 몇 초 간격이라 회상 확률(R)이 거의 1이라 stability가 거의 늘지
  // 않으므로, 최종 stage/복습 간격은 "최초 Good 등급의 초기 stability(약
  // 3.1262일)" 근방에 머무른다.
  test('multiple immediate questions for one new word stay near the first rating\'s initial stability', () async {
    final prefs = await freshPreferences();
    final db = LocalDatabase(prefs, now: () => DateTime(2026, 9, 26, 8));
    final controller = controllerFor(db, words: [word(1)], newWordLimit: 1);
    final firstReviewAt = DateTime(2026, 9, 26, 8, 1);
    await controller.startTodayQuest(DateTime(2026, 9, 26, 8));

    for (var i = 0; i < 4; i++) {
      final question = controller.state.currentQuestion!;
      await controller.submitAnswer(
        answer: question.correctAnswer,
        feeling: MemoryFeeling.remembered,
        responseMs: 1200,
        now: firstReviewAt.add(Duration(seconds: i * 10)),
      );
      controller.moveNext();
    }

    final stored = await db.loadMemoryStates();
    expect(stored['w1']!.stage, 3);
    expect(
      stored['w1']!.nextReviewAt!.isAfter(firstReviewAt.add(const Duration(days: 2))),
      isTrue,
    );
    expect(
      stored['w1']!.nextReviewAt!.isBefore(firstReviewAt.add(const Duration(days: 4))),
      isTrue,
    );
  });
}
