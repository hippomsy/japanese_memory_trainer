import 'package:flutter_test/flutter_test.dart';
import 'package:kioku_japanese/data/study_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 2026-09-27 학습 기록·즐겨찾기·학습 방식 저장 검증
void main() {
  test('aspect schedules survive reopening and preserve the weakest due date',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = StudyStore(prefs);
    final now = DateTime(2026, 10, 4, 12);
    await store.recordAspect('a', RecallAspect.reading, RecallRating.forgotten,
        now: now);
    await store.recordAspect('a', RecallAspect.meaning, RecallRating.remembered,
        now: now);
    final reopened = StudyStore(prefs);
    expect(reopened.aspectWeak('a', RecallAspect.reading), isTrue);
    expect(reopened.aspectWeak('a', RecallAspect.meaning), isFalse);
    expect(reopened.dueAt('a'), now.add(const Duration(minutes: 10)));
    await reopened.recordRecall('a', RecallRating.remembered, now: now);
    expect(reopened.dueAt('a'), now.add(const Duration(minutes: 10)));
    expect(reopened.wrongIds, {'a'});
    await reopened.recordAspect(
        'a', RecallAspect.meaning, RecallRating.remembered,
        now: now);
    expect(reopened.aspectDueAt('a', RecallAspect.meaning),
        now.add(const Duration(days: 2)));
    expect(reopened.dueAt('a'), now.add(const Duration(minutes: 10)));
    await reopened.resetLearned(['a']);
    expect(reopened.aspectWeak('a', RecallAspect.reading), isFalse);
    expect(reopened.aspectDueAt('a', RecallAspect.meaning), DateTime(2000));
  });
  test('review schedule persists, extends intervals and resets with chapter',
      () async {
    SharedPreferences.setMockInitialValues({
      StudyStore.learnedKey: ['legacy']
    });
    final preferences = await SharedPreferences.getInstance();
    final store = StudyStore(preferences);
    final now = DateTime(2026, 9, 30, 12);
    expect(store.isDue('legacy', now: now), isTrue);
    expect(store.isDue('new', now: now), isFalse);
    await store.recordRecall('new', RecallRating.forgotten, now: now);
    final reopened = StudyStore(preferences);
    expect(reopened.wrongIds, {'new'});
    expect(reopened.isDue('new', now: now.add(const Duration(minutes: 9))),
        isFalse);
    expect(reopened.isDue('new', now: now.add(const Duration(minutes: 10))),
        isTrue);
    await reopened.recordRecall('new', RecallRating.remembered, now: now);
    expect(reopened.dueAt('new'), now.add(const Duration(days: 1)));
    expect(reopened.wrongIds, isEmpty);
    await reopened.recordRecall('new', RecallRating.remembered, now: now);
    expect(reopened.dueAt('new'), now.add(const Duration(days: 2)));
    await reopened.recordRecall('new', RecallRating.unsure, now: now);
    expect(reopened.dueAt('new'), now.add(const Duration(days: 1)));
    expect(reopened.wrongIds, {'new'});
    await reopened.resetLearned(['new']);
    expect(reopened.isDue('new', now: now), isFalse);
    expect(reopened.wrongIds, isEmpty);
    expect(reopened.learnedIds, {'legacy'});
  });
  Future<StudyStore> createStore() async {
    SharedPreferences.setMockInitialValues({});
    return StudyStore(await SharedPreferences.getInstance());
  }

  test('learned words are saved and reset per chapter', () async {
    final store = await createStore();
    await store.markLearned('a');
    await store.markLearned('b');
    await store.markLearned('a');
    expect(store.learnedIds, {'a', 'b'});
    await store.resetLearned(['a']);
    expect(store.learnedIds, {'b'});
  });

  test('favorite toggles on and off', () async {
    final store = await createStore();
    expect(await store.toggleFavorite('x'), isTrue);
    expect(store.isFavorite('x'), isTrue);
    expect(await store.toggleFavorite('x'), isFalse);
    expect(store.favoriteIds, isEmpty);
  });

  test('study mode defaults to choice and is remembered', () async {
    final store = await createStore();
    expect(store.mode, StudyMode.choice);
    await store.setMode(StudyMode.assemble);
    expect(store.mode, StudyMode.assemble);
    expect(store.autoMode, isFalse);
    await store.setAutoMode(true);
    expect(store.autoMode, isTrue);
    expect(store.compactList, isFalse);
    await store.setCompactList(true);
    expect(store.compactList, isTrue);
  });
}
