import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kioku_japanese/services/listening_store.dart';
import 'package:kioku_japanese/data/listening_bank.dart';

void main() {
  test('misses persist and become due next day, a correct retry clears them',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    var now = DateTime(2026, 10, 4, 21);
    final store = ListeningStore(prefs, clock: () => now);
    await store.start('time');
    await store.record('time', false);
    expect(store.dueCount, 0);
    expect(store.todayCount, 1);
    expect(store.nextLesson.id, 'umbrella');
    expect(store.days, contains('2026-10-04'));
    now = DateTime(2026, 10, 5);
    final reopened = ListeningStore(prefs, clock: () => now);
    expect(reopened.dueCount, 1);
    expect(reopened.nextLesson.id, 'time');
    await reopened.record('time', true);
    expect(reopened.dueCount, 0);
    expect(reopened.correctCount, 1);
    expect(reopened.nextLesson.id, 'umbrella');
    expect(reopened.records['time']['attempts'], 2);
  });
  test('every exercise has unique choices, bilingual lines and a valid answer',
      () {
    expect(n4ListeningLessons.length, 50);
    expect(n4ListeningLessons.map((l) => l.id).toSet().length, 50);
    for (final lesson in n4ListeningLessons) {
      expect(lesson.options.toSet().length, 4);
      expect(lesson.answer, inInclusiveRange(0, 3));
      expect(lesson.explanation, isNotEmpty);
      expect(lesson.expression, isNotEmpty);
      for (final line in lesson.lines) {
        expect(line.japanese, isNotEmpty);
        expect(line.korean, isNotEmpty);
      }
    }
  });
}
