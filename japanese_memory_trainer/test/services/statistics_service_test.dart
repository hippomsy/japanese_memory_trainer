import 'package:flutter_test/flutter_test.dart';
import 'package:kioku_japanese/data/local_database.dart';
import 'package:kioku_japanese/models/memory_state.dart';
import 'package:kioku_japanese/models/vocabulary.dart';
import 'package:kioku_japanese/services/learning_repository.dart';
import 'package:kioku_japanese/services/statistics_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Vocabulary word(String id, String level) => Vocabulary(
      id: id,
      japanese: id,
      reading: id,
      korean: id,
      exampleJapanese: '$id です。',
      exampleKorean: '$id 입니다.',
      jlptLevel: level,
      wordType: '명사',
      frequencyRank: 1,
    );

Future<(StatisticsService, LocalDatabase)> createService() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final db = LocalDatabase(prefs, now: () => DateTime(2026, 9, 26, 10));
  final seed = <Vocabulary>[
    word('n4a', 'N4'),
    word('n4b', 'N4'),
    word('n3a', 'N3'),
    word('n3b', 'N3'),
    word('n2a', 'N2'),
    word('n2b', 'N2'),
  ];
  final repo = LearningRepository(seed: seed, database: db);
  return (StatisticsService(repository: repo, database: db), db);
}

void main() {
  test('statistics snapshot calculates long term danger retention and JLPT progress', () async {
    final (service, db) = await createService();
    final now = DateTime(2026, 9, 26, 10);
    await db.saveMemoryStates({
      'n4a': MemoryState.initial('n4a').copyWith(
        stage: 6,
        correctCount: 8,
        wrongCount: 2,
        dangerScore: 20,
        nextReviewAt: DateTime(2026, 10, 20),
        longTermReachedAt: DateTime(2026, 9, 22),
      ),
      'n3a': MemoryState.initial('n3a').copyWith(
        stage: 7,
        correctCount: 3,
        wrongCount: 1,
        dangerScore: 55,
        nextReviewAt: DateTime(2026, 9, 25),
        longTermReachedAt: DateTime(2026, 9, 10),
      ),
      'n2a': MemoryState.initial('n2a').copyWith(
        stage: 3,
        correctCount: 1,
        wrongCount: 1,
        dangerScore: 65,
        nextReviewAt: now,
      ),
    });
    await db.saveDailyLearnedWordIds(now, {'n2b'});

    final snapshot = await service.buildSnapshot(now);

    expect(snapshot.longTermWordCount, 2);
    expect(snapshot.newLongTermThisWeek, 1);
    expect(snapshot.dangerWordCount, 2);
    expect(snapshot.dueReviewCount, 2);
    expect(snapshot.todayNewWordCount, 1);
    expect(snapshot.retentionRate, closeTo(75, 0.001));
    expect(snapshot.n4Progress, 50);
    expect(snapshot.n3Progress, 50);
    expect(snapshot.n2Progress, 0);
    // 2026-09-27 테스트 저장소에 N5·N1 단어가 없으므로 진도는 0이어야 한다.
    expect(snapshot.n5Progress, 0);
    expect(snapshot.n1Progress, 0);
  });

  test('streak counts consecutive dates ending today or yesterday', () async {
    final (service, db) = await createService();
    final now = DateTime(2026, 9, 26, 10);
    for (final day in [24, 25, 26]) {
      await db.recordLearningDay(DateTime(2026, 9, day));
    }
    expect((await service.buildSnapshot(now)).streakDays, 3);

    final (service2, db2) = await createService();
    for (final day in [23, 24, 25]) {
      await db2.recordLearningDay(DateTime(2026, 9, day));
    }
    expect((await service2.buildSnapshot(now)).streakDays, 3);
  });

  test('retention rate is zero when no reviews exist', () async {
    final (service, _) = await createService();
    final snapshot = await service.buildSnapshot(DateTime(2026, 9, 26));
    expect(snapshot.retentionRate, 0);
  });
}
