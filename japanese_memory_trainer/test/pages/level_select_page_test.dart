import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kioku_japanese/data/local_database.dart';
import 'package:kioku_japanese/models/study_level.dart';
import 'package:kioku_japanese/models/vocabulary.dart';
import 'package:kioku_japanese/pages/level_select_page.dart';
import 'package:kioku_japanese/services/learning_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 2026-09-27 레벨 선택 화면이 레벨 목록을 보여주고, 누른 레벨을 저장하는지 검증한다.
void main() {
  Vocabulary word(int id) => Vocabulary(
        id: 'w$id',
        japanese: '日$id',
        reading: 'よみ$id',
        korean: '뜻$id',
        exampleJapanese: '日$id を覚えます。',
        exampleKorean: '뜻$id 을 외웁니다.',
        jlptLevel: 'N5',
        wordType: '명사',
        frequencyRank: id,
      );

  testWidgets('LevelSelectPage saves the tapped level and closes', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = LocalDatabase(prefs);
    final repository = LearningRepository(
      seed: List.generate(30, (i) => word(i + 1)),
      database: db,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => LevelSelectPage(repository: repository),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('레벨 선택'), findsOneWidget);
    expect(find.text('N5'), findsOneWidget);
    expect(find.text('N1'), findsOneWidget);
    expect(find.text('Lv.1'), findsWidgets);
    expect(find.text('학습 중'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('level-tile-N5:2')));
    await tester.pumpAndSettle();

    expect(await db.loadStudyLevel(), const StudyLevel('N5', 2));
    expect(find.text('open'), findsOneWidget);
  });
}
