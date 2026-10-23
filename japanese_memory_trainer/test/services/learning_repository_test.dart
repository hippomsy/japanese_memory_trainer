import 'package:flutter_test/flutter_test.dart';
import 'package:kioku_japanese/data/local_database.dart';
import 'package:kioku_japanese/models/memory_state.dart';
import 'package:kioku_japanese/models/study_level.dart';
import 'package:kioku_japanese/models/vocabulary.dart';
import 'package:kioku_japanese/services/learning_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

Vocabulary word(int id, {String level = 'N4'}) => Vocabulary(
      id: 'w$id',
      japanese: '日$id',
      reading: 'よみ$id',
      korean: '뜻$id',
      exampleJapanese: '日$id を覚えます。',
      exampleKorean: '뜻$id 을 외웁니다.',
      jlptLevel: level,
      wordType: '명사',
      frequencyRank: id,
    );

Future<(LearningRepository, LocalDatabase)> createRepository({
  List<Vocabulary>? words,
}) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final db = LocalDatabase(preferences, now: () => DateTime(2026, 9, 26));
  return (
    LearningRepository(seed: words ?? List.generate(10, (i) => word(i + 1)), database: db),
    db,
  );
}

void main() {
  test('new day returns at most 5 unseen words', () async {
    final (repo, _) = await createRepository();
    final result = await repo.getNewWordsForDay(DateTime(2026, 9, 26));
    expect(result, hasLength(5));
    expect(result.map((e) => e.id).toSet(), hasLength(5));
  });

  test('repeated call same day returns the same learned set without adding duplicates', () async {
    final (repo, db) = await createRepository();
    final day = DateTime(2026, 9, 26);
    final first = await repo.getNewWordsForDay(day);
    final second = await repo.getNewWordsForDay(day);
    final saved = await db.loadDailyLearnedWordIds(day);
    expect(second.map((e) => e.id).toList(), first.map((e) => e.id).toList());
    expect(saved, hasLength(5));
  });

  test('fewer than 5 unseen words returns only remaining words', () async {
    final (repo, db) = await createRepository(words: List.generate(4, (i) => word(i + 1)));
    await db.saveMemoryStates({
      'w1': MemoryState.initial('w1').copyWith(stage: 1),
      'w2': MemoryState.initial('w2').copyWith(stage: 1),
    });
    final result = await repo.getNewWordsForDay(DateTime(2026, 9, 26));
    expect(result.map((e) => e.id).toList(), ['w3', 'w4']);
  });

  test('due words include only nextReviewAt less than or equal to now', () async {
    final (repo, db) = await createRepository();
    final now = DateTime(2026, 9, 26, 12);
    await db.saveMemoryStates({
      'w1': MemoryState.initial('w1').copyWith(nextReviewAt: now.subtract(const Duration(minutes: 1))),
      'w2': MemoryState.initial('w2').copyWith(nextReviewAt: now),
      'w3': MemoryState.initial('w3').copyWith(nextReviewAt: now.add(const Duration(minutes: 1))),
    });
    final result = await repo.getDueWords(now);
    expect(result.map((e) => e.id).toList(), containsAll(['w1', 'w2']));
    expect(result.map((e) => e.id), isNot(contains('w3')));
  });

  test('danger words are sorted descending by dangerScore', () async {
    final (repo, db) = await createRepository();
    await db.saveMemoryStates({
      'w1': MemoryState.initial('w1').copyWith(dangerScore: 20),
      'w2': MemoryState.initial('w2').copyWith(dangerScore: 80),
      'w3': MemoryState.initial('w3').copyWith(dangerScore: 50),
    });
    final result = await repo.getDangerWords();
    expect(result.map((e) => e.id).take(3).toList(), ['w2', 'w3', 'w1']);
  });

  test('boss words prefer dangerous words reviewed recently', () async {
    final (repo, db) = await createRepository();
    await db.saveMemoryStates({
      'w1': MemoryState.initial('w1').copyWith(
        dangerScore: 70,
        lastReviewedAt: DateTime(2026, 9, 20),
      ),
      'w2': MemoryState.initial('w2').copyWith(
        dangerScore: 70,
        lastReviewedAt: DateTime(2026, 9, 25),
      ),
      'w3': MemoryState.initial('w3').copyWith(
        dangerScore: 40,
        lastReviewedAt: DateTime(2026, 9, 26),
      ),
    });
    final result = await repo.getBossWords(limit: 3);
    expect(result.map((e) => e.id).toList(), ['w2', 'w1', 'w3']);
  });

  // 2026-09-27 급수별 10레벨 학습 기능 검증
  List<Vocabulary> gradeWords(String grade, int count, {int startId = 1}) =>
      List.generate(count, (i) => word(startId + i, level: grade));

  test('grade words are split into 10 levels in order', () async {
    final (repo, _) = await createRepository(words: gradeWords('N5', 25));
    final levels = repo.wordsByLevel('N5');
    expect(levels, hasLength(10));
    expect(levels[0].map((e) => e.id).toList(), ['w1', 'w2', 'w3']);
    expect(levels[8].map((e) => e.id).toList(), ['w25']);
    expect(levels[9], isEmpty);
    expect(levels.expand((e) => e).length, 25);
  });

  test('new words start from the selected level', () async {
    final (repo, db) = await createRepository(words: gradeWords('N5', 100));
    await db.saveStudyLevel(const StudyLevel('N5', 3));
    final result = await repo.getNewWordsForDay(DateTime(2026, 9, 26));
    expect(result.map((e) => e.id).toList(), ['w21', 'w22', 'w23', 'w24', 'w25']);
  });

  test('finished level continues into the next level of the same grade', () async {
    final (repo, db) = await createRepository(words: [
      ...gradeWords('N5', 20),
      ...gradeWords('N4', 20, startId: 21),
    ]);
    await db.saveStudyLevel(const StudyLevel('N5', 10));
    await db.saveMemoryStates({'w19': MemoryState.initial('w19')});
    final result = await repo.getNewWordsForDay(DateTime(2026, 9, 26));
    expect(result.map((e) => e.id).toList(), ['w20']);
  });

  test('default level is N5 Lv.1', () async {
    final (repo, _) = await createRepository(words: [
      ...gradeWords('N4', 10),
      ...gradeWords('N5', 10, startId: 11),
    ]);
    final result = await repo.getNewWordsForDay(DateTime(2026, 9, 26));
    expect(result.map((e) => e.id).toList(), ['w11', 'w12', 'w13', 'w14', 'w15']);
  });

  test('changing level before studying reselects today words', () async {
    final (repo, db) = await createRepository(words: gradeWords('N5', 100));
    final day = DateTime(2026, 9, 26);
    final first = await repo.getNewWordsForDay(day);
    expect(first.first.id, 'w1');

    await db.saveStudyLevel(const StudyLevel('N5', 2));
    final second = await repo.getNewWordsForDay(day);
    expect(second.first.id, 'w11');
  });

  test('changing level after studying keeps today words', () async {
    final (repo, db) = await createRepository(words: gradeWords('N5', 100));
    final day = DateTime(2026, 9, 26);
    await repo.getNewWordsForDay(day);
    await db.saveMemoryStates({'w1': MemoryState.initial('w1')});

    await db.saveStudyLevel(const StudyLevel('N5', 5));
    final result = await repo.getNewWordsForDay(day);
    expect(result.first.id, 'w1');
  });

  test('level progress counts learned words per level', () async {
    final (repo, db) = await createRepository(words: gradeWords('N3', 20));
    await db.saveMemoryStates({
      'w1': MemoryState.initial('w1'),
      'w3': MemoryState.initial('w3'),
    });
    final progress = await repo.levelProgress('N3');
    expect(progress[0].total, 2);
    expect(progress[0].learned, 1);
    expect(progress[1].learned, 1);
    expect(progress[0].isCompleted, isFalse);

    await db.saveStudyLevel(const StudyLevel('N3', 2));
    final current = await repo.currentLevelProgress();
    expect(current.studyLevel, const StudyLevel('N3', 2));
    expect(current.learned, 1);
  });
}
