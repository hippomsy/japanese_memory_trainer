import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kioku_japanese/data/kanji_parts.dart';
import 'package:kioku_japanese/pages/radical_pages.dart';
import 'package:kioku_japanese/services/radical_course.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 2026-10-11 기본 부수 과정 확인.
void main() {
  final course =
      RadicalCourse.parse(File('assets/kanji/radicals.json').readAsStringSync());
  final bank = KanjiPartsBank.parse(
      File('assets/kanji/kanji_parts.json').readAsStringSync());

  test('12과 · 부수 97개 · 모두 획 데이터와 예시 한자가 있다', () {
    expect(course.lessons.length, 12);
    expect(course.radicals.length, 97);
    for (final r in course.radicals) {
      expect(bank.has(r.form), isTrue, reason: r.form);
      expect(r.examples.length, greaterThanOrEqualTo(2), reason: r.form);
      expect(r.story, isNotEmpty);
      for (final e in r.examples) {
        expect(e.strokes, isNotEmpty, reason: '${r.form} ${e.kanji}');
        expect(e.strokes.every((s) => s < bank[e.kanji]!.strokeCount), isTrue);
      }
    }
    final sansui = course.byForm('氵')!;
    expect(sansui.nickname, '삼수변');
    expect(sansui.position, RadicalPosition.hen);
    expect(sansui.examples.first.kanji, '海');
    expect(sansui.examples.first.strokes, [0, 1, 2]);
  });

  test('퀴즈 보기는 4개, 정답 하나, 중복 없음, 한자 속 다른 부수는 오답에서 빠진다', () {
    final builder = RadicalQuizBuilder(course.radicals, random: Random(1));
    for (final r in course.radicals) {
      for (final kind in RadicalQuizKind.values) {
        final q = builder.question(r, kind);
        expect(q.options.toSet().length, q.options.length, reason: '${r.form} $kind');
        expect(q.options.length, 4, reason: '${r.form} $kind');
        expect(q.answer, inInclusiveRange(0, 3));
        if (q.kind == RadicalQuizKind.find) {
          expect(q.options[q.answer], r.form);
          for (final o in q.options) {
            if (o != r.form) expect(q.kanji!.alsoContains.contains(o), isFalse);
          }
        }
      }
    }
    expect(builder.build(course.lessons.first.radicals).length, 8);
  });

  test('간격 복습: 맞히면 단계가 오르고 틀리면 1단계로', () async {
    SharedPreferences.setMockInitialValues({});
    final p = RadicalProgress(await SharedPreferences.getInstance());
    final now = DateTime(2026, 10, 11, 9);
    expect(p.isNew('氵'), isTrue);
    await p.markLearned('氵', now);
    expect(p.stage('氵'), 1);
    expect(p.isDue('氵', now), isFalse);
    expect(p.isDue('氵', now.add(const Duration(minutes: 11))), isTrue);
    await p.record('氵', true, now);
    expect(p.stage('氵'), 2);
    expect(p.dueAt('氵'), now.add(const Duration(days: 1)));
    for (var i = 0; i < 5; i++) {
      await p.record('氵', true, now);
    }
    expect(p.isMastered('氵'), isTrue);
    await p.record('氵', false, now);
    expect(p.stage('氵'), 1);
    expect(p.nextLesson(course)!.number, 1);
  });

  testWidgets('첫 화면 → 과 카드 → 확인 퀴즈', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(MaterialApp(
        home: RadicalHomePage(course: course, bank: bank)));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('radical-home')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('radical-today')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('radical-card-亻')), findsOneWidget);
    for (var i = 0; i < 8; i++) {
      await tester.tap(find.byKey(const ValueKey('radical-next')));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byKey(const ValueKey('radical-next')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('radical-quiz-0')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('radical-option-0')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('radical-feedback')), findsOneWidget);
  });
}
