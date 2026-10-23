import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kioku_japanese/data/local_database.dart';
import 'package:kioku_japanese/models/memory_state.dart';
import 'package:kioku_japanese/models/vocabulary.dart';
import 'package:kioku_japanese/pages/boss_page.dart';
import 'package:kioku_japanese/services/learning_repository.dart';
import 'package:kioku_japanese/services/memory_evaluator.dart';
import 'package:kioku_japanese/services/quiz_generator.dart';
import 'package:shared_preferences/shared_preferences.dart';

const bossSeed = <Vocabulary>[
  Vocabulary(
    id: 'w1',
    japanese: '必要',
    reading: 'ひつよう',
    korean: '필요',
    exampleJapanese: '水が必要です。',
    exampleKorean: '물이 필요합니다.',
    jlptLevel: 'N4',
    wordType: '명사',
    frequencyRank: 1,
  ),
  Vocabulary(
    id: 'w2',
    japanese: '到着',
    reading: 'とうちゃく',
    korean: '도착',
    exampleJapanese: '駅に到着しました。',
    exampleKorean: '역에 도착했습니다.',
    jlptLevel: 'N4',
    wordType: '명사',
    frequencyRank: 2,
  ),
];

void main() {
  testWidgets('BossPage loads boss words and reports conquered and needs-practice counts', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = LocalDatabase(prefs);
    await db.saveMemoryStates({
      'w1': MemoryState.initial('w1').copyWith(dangerScore: 90),
      'w2': MemoryState.initial('w2').copyWith(dangerScore: 70),
    });
    final repo = LearningRepository(seed: bossSeed, database: db);

    await tester.pumpWidget(
      MaterialApp(
        home: BossPage(
          repository: repo,
          database: db,
          evaluator: MemoryEvaluator(),
          quizGenerator: QuizGenerator(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 / 2'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '必要');
    await tester.tap(find.text('기억함'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '틀림');
    await tester.tap(find.text('몰랐음'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('결과 보기'));
    await tester.pumpAndSettle();

    expect(find.text('정복 1개'), findsOneWidget);
    expect(find.text('연습 필요 1개'), findsOneWidget);
  });
}
