import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kioku_japanese/data/local_database.dart';
import 'package:kioku_japanese/models/memory_state.dart';
import 'package:kioku_japanese/models/vocabulary.dart';
import 'package:kioku_japanese/pages/review_page.dart';
import 'package:kioku_japanese/services/learning_repository.dart';
import 'package:kioku_japanese/services/learning_session_controller.dart';
import 'package:kioku_japanese/services/memory_evaluator.dart';
import 'package:kioku_japanese/services/quiz_generator.dart';
import 'package:shared_preferences/shared_preferences.dart';

const reviewWord = Vocabulary(
  id: 'w1',
  japanese: '必要',
  reading: 'ひつよう',
  korean: '필요',
  exampleJapanese: '水が必要です。',
  exampleKorean: '물이 필요합니다.',
  jlptLevel: 'N4',
  wordType: '명사',
  frequencyRank: 1,
);

class FailingReviewDatabase extends LocalDatabase {
  FailingReviewDatabase(SharedPreferences preferences) : super(preferences);

  @override
  Future<void> saveMemoryStates(Map<String, MemoryState> states) async {
    throw StateError('save failed');
  }
}

Future<LearningSessionController> createController({bool failSave = false}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final LocalDatabase db = failSave ? FailingReviewDatabase(prefs) : LocalDatabase(prefs);
  final controller = LearningSessionController(
    repository: LearningRepository(seed: const [reviewWord], database: db),
    database: db,
    evaluator: MemoryEvaluator(),
    quizGenerator: QuizGenerator(words: const [reviewWord]),
    newWordLimit: 1,
  );
  await controller.startTodayQuest(DateTime(2026, 9, 26, 8));
  return controller;
}

void main() {
  testWidgets('review uses four choice buttons and no text field', (tester) async {
    final controller = await createController();
    await tester.pumpWidget(
      MaterialApp(
        home: ReviewPage(
          controller: controller,
          speakJapanese: (_) async {},
          onFinished: () {},
        ),
      ),
    );

    expect(find.byType(TextField), findsNothing);
    expect(find.text('필요'), findsOneWidget);
    expect(find.text('일본어 → 한국어 퀴즈'), findsOneWidget);
  });

  testWidgets('wrong choice renders correction feedback', (tester) async {
    final controller = await createController();
    await tester.pumpWidget(
      MaterialApp(
        home: ReviewPage(
          controller: controller,
          speakJapanese: (_) async {},
          onFinished: () {},
        ),
      ),
    );

    await tester.tap(find.text('출발'));
    await tester.pumpAndSettle();

    expect(find.text('정답: 필요'), findsOneWidget);
    expect(find.text('다음 문제  →'), findsOneWidget);
  });

  testWidgets('persistence error is visible while next remains available', (tester) async {
    final controller = await createController(failSave: true);
    await tester.pumpWidget(
      MaterialApp(
        home: ReviewPage(
          controller: controller,
          speakJapanese: (_) async {},
          onFinished: () {},
        ),
      ),
    );

    await tester.tap(find.text('필요'));
    await tester.pumpAndSettle();

    expect(find.textContaining('저장하지 못했습니다'), findsOneWidget);
    expect(find.text('다음 문제  →'), findsOneWidget);
  });
}
