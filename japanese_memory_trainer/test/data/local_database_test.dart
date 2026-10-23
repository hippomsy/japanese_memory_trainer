import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kioku_japanese/data/local_database.dart';
import 'package:kioku_japanese/models/memory_state.dart';
import 'package:kioku_japanese/models/study_level.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const memoryKey = 'memory_states_v1';
  final fixedNow = DateTime(2026, 9, 26, 9, 0);

  Future<LocalDatabase> createDatabase([Map<String, Object> values = const {}]) async {
    SharedPreferences.setMockInitialValues(values);
    final preferences = await SharedPreferences.getInstance();
    return LocalDatabase(preferences, now: () => fixedNow);
  }

  test('save and load memory states preserves values', () async {
    final db = await createDatabase();
    final state = MemoryState.initial('w1').copyWith(
      stage: 4,
      correctCount: 5,
      wrongCount: 1,
      nextReviewAt: DateTime(2026, 10, 3),
      recognitionScore: 60,
      recallScore: 45,
    );

    await db.saveMemoryStates({'w1': state});
    final loaded = await db.loadMemoryStates();

    expect(loaded['w1']?.stage, 4);
    expect(loaded['w1']?.correctCount, 5);
    expect(loaded['w1']?.nextReviewAt, DateTime(2026, 10, 3));
  });

  test('corrupted stage is clamped while loading', () async {
    final raw = jsonEncode({
      'w1': MemoryState.initial('w1').toJson()..['stage'] = 99,
    });
    final db = await createDatabase({memoryKey: raw});

    final loaded = await db.loadMemoryStates();

    expect(loaded['w1']?.stage, 7);
  });

  test('invalid nextReviewAt falls back to a safe date', () async {
    final raw = jsonEncode({
      'w1': MemoryState.initial('w1').toJson()..['nextReviewAt'] = 'broken-date',
    });
    final db = await createDatabase({memoryKey: raw});

    final loaded = await db.loadMemoryStates();

    expect(loaded['w1']?.nextReviewAt, fixedNow);
  });

  test('daily learned ids survive reload', () async {
    final db = await createDatabase();
    final day = DateTime(2026, 9, 26);

    await db.saveDailyLearnedWordIds(day, {'w1', 'w2'});
    final loaded = await db.loadDailyLearnedWordIds(day);

    expect(loaded, {'w1', 'w2'});
  });

  test('recordLearningDay stores a date only once and supports streak reconstruction', () async {
    final db = await createDatabase();

    await db.recordLearningDay(DateTime(2026, 9, 25, 8));
    await db.recordLearningDay(DateTime(2026, 9, 25, 20));
    await db.recordLearningDay(DateTime(2026, 9, 26, 7));
    final days = await db.loadLearningDays();

    expect(days, {'2026-09-25', '2026-09-26'});
  });

  // 2026-09-27 학습 레벨(급수 + Lv) 저장 검증
  test('study level defaults to N5 Lv.1', () async {
    final db = await createDatabase();
    expect(await db.loadStudyLevel(), const StudyLevel('N5', 1));
  });

  test('study level is saved and loaded', () async {
    final db = await createDatabase();
    await db.saveStudyLevel(const StudyLevel('N2', 7));
    expect(await db.loadStudyLevel(), const StudyLevel('N2', 7));
  });

  test('broken study level falls back to N5 Lv.1', () async {
    for (final raw in ['N9:1', 'N3:11', 'N3:0', 'abc']) {
      final db = await createDatabase({'study_level_v1': raw});
      expect(await db.loadStudyLevel(), StudyLevel.initial, reason: raw);
    }
  });
}
