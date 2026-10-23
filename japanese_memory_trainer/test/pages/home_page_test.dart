import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kioku_japanese/data/local_database.dart';
import 'package:kioku_japanese/models/study_level.dart';
import 'package:kioku_japanese/models/vocabulary.dart';
import 'package:kioku_japanese/pages/home_page.dart';
import 'package:kioku_japanese/services/learning_repository.dart';
import 'package:kioku_japanese/services/statistics_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('HomePage shows core memory dashboard labels', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = LocalDatabase(prefs);
    const word = Vocabulary(
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
    final service = StatisticsService(
      repository: LearningRepository(seed: const [word], database: db),
      database: db,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          statisticsService: service,
          onStartQuest: () {},
          onDangerWords: () {},
          onBoss: () {},
          onStatistics: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('장기기억 단어'), findsOneWidget);
    expect(find.text('위험 단어'), findsOneWidget);
    expect(find.text('오늘 복습'), findsOneWidget);
    expect(find.text('오늘의 퀘스트 시작'), findsOneWidget);
    expect(find.textContaining('연속 학습'), findsOneWidget);
    // 2026-09-27 급수 막대가 N5~N1 다섯 개로 늘어 화면 아래쪽 항목은 지연 생성될 수 있으므로
    // 위에서부터 차례로 스크롤해 가며 각 급수 라벨을 확인한다.
    for (final label in const ['N5', 'N4', 'N3', 'N2', 'N1']) {
      await tester.scrollUntilVisible(
        find.text(label),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(label), findsOneWidget);
    }
  });

  // 2026-09-27 홈 화면의 학습 레벨 카드 검증
  testWidgets('HomePage shows study level card and opens level selection',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = LocalDatabase(prefs);
    final repository = LearningRepository(seed: const [], database: db);
    final service = StatisticsService(repository: repository, database: db);
    var opened = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          statisticsService: service,
          onStartQuest: () {},
          onDangerWords: () {},
          onBoss: () {},
          onStatistics: () {},
          loadCurrentLevel: () async => const LevelProgressInfo(
            studyLevel: StudyLevel('N4', 3),
            total: 60,
            learned: 12,
          ),
          onSelectLevel: () async {
            opened++;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('N4 · Lv.3'), findsOneWidget);
    expect(find.text('12 / 60 단어 학습'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('study-level-card')));
    await tester.pumpAndSettle();
    expect(opened, 1);
  });
}
