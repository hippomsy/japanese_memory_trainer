import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kioku_japanese/data/local_database.dart';
import 'package:kioku_japanese/models/vocabulary.dart';
import 'package:kioku_japanese/pages/statistics_page.dart';
import 'package:kioku_japanese/services/learning_repository.dart';
import 'package:kioku_japanese/services/statistics_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('StatisticsPage shows long-term weekly retention danger and JLPT progress', (tester) async {
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

    await tester.pumpWidget(MaterialApp(home: StatisticsPage(statisticsService: service)));
    await tester.pumpAndSettle();

    expect(find.text('장기기억 단어'), findsOneWidget);
    expect(find.text('이번 주 새로 정착'), findsOneWidget);
    expect(find.text('기억률'), findsOneWidget);
    expect(find.text('위험 단어'), findsOneWidget);
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
}
