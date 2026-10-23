import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kioku_japanese/pages/jlpt_n4_mock_pages.dart';
import 'package:kioku_japanese/services/jlpt_n4_mock.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 2026-10-10 JLPT N4 모의고사 데이터·화면 검증
void main() {
  final mock = JlptN4Mock.parse(File(jlptN4MockAsset).readAsStringSync());

  test('2 sets × (vocab 28 + grammar/reading 29) in the real N4 layout', () {
    expect(File('pubspec.yaml').readAsStringSync(),
        contains('assets/jlpt_n4_mock/'));
    expect(mock.sets.length, 2);
    for (final set in mock.sets) {
      final vocab = set.sections[0], grammar = set.sections[1];
      expect(vocab.id, 'vocab');
      expect(vocab.minutes, 25);
      expect([for (final m in vocab.mondai) m.questions.length],
          [7, 5, 8, 4, 4]);
      expect(grammar.id, 'grammar');
      expect(grammar.minutes, 55);
      expect([for (final m in grammar.mondai) m.questions.length],
          [13, 4, 4, 3, 3, 2]);
      for (final sec in set.sections) {
        final qs = sec.questions;
        expect([for (final q in qs) q.no],
            List.generate(qs.length, (i) => i + 1));
        for (final q in qs) {
          expect(q.options.length, 4, reason: q.stem);
          expect(q.options.toSet().length, 4, reason: q.stem);
          expect(q.answer, inInclusiveRange(0, 3));
          expect(q.explanation, isNotEmpty);
          // 연습 모드 해석: 정답 문장·해석·보기 뜻·후리가나 조각
          expect(q.korean, isNotEmpty, reason: q.stem);
          expect(q.answerTokens.map((t) => t.text).join(), q.answerSentence);
          expect(q.optionKorean.length, 4);
          expect(q.optionKorean[q.answer], isNotEmpty, reason: q.stem);
          expect(q.optionTokens.length, 4);
          for (var i = 0; i < 4; i++) {
            expect(q.optionTokens[i].map((t) => t.text).join(), q.options[i]);
          }
        }
        expect(sec.practiceCount, 6);
        expect([for (var i = 0; i < 6; i++) ...sec.practice(i)], qs);
        // 정답 위치가 한쪽으로 몰리지 않는다.
        for (var i = 0; i < 4; i++) {
          expect(qs.where((q) => q.answer == i).length, greaterThan(2));
        }
      }
      // 독해(問題4~6)는 모두 지문이 있고, 問題6은 표가 있다.
      for (final m in grammar.mondai.skip(2)) {
        expect(m.passages, isNotEmpty);
        for (final p in m.passages) {
          expect(p.korean, isNotEmpty);
        }
        expect(m.questions.every((q) => q.passage != null), isTrue);
      }
      expect(
          grammar.mondai.last.passages.first.blocks.any((b) => b.rows != null),
          isTrue);
    }
  });

  test('stem underline parts', () {
    final parts = stemParts('毎朝、【公園】を散歩します。');
    expect(parts.map((p) => p.text).join(), '毎朝、公園を散歩します。');
    expect(parts.where((p) => p.underline).single.text, '公園');
  });

  testWidgets('answers are kept, graded with explanations, best score saved',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final progress = JlptN4MockProgress(prefs);
    final set = mock.sets.first, sec = set.sections.first;
    final key = JlptN4MockProgress.sectionKey(set, sec);

    await tester.pumpWidget(MaterialApp(
        home: MockExamPage(set: set, section: sec, progress: progress)));
    await tester.pump();
    expect(find.text('問題1'), findsOneWidget);
    expect(find.byKey(const ValueKey('mock-timer')), findsOneWidget);

    // 1번은 정답, 2번은 오답을 고른다.
    final q1 = sec.questions[0], q2 = sec.questions[1];
    await tester.tap(find.byKey(ValueKey('mock-q1-opt${q1.answer}')));
    await tester.pump();
    final wrong = (q2.answer + 1) % 4;
    await tester.ensureVisible(find.byKey(ValueKey('mock-q2-opt$wrong')));
    await tester.tap(find.byKey(ValueKey('mock-q2-opt$wrong')));
    await tester.pump();
    expect(progress.answers(key), {1: q1.answer, 2: wrong});
    expect(find.text('2 / ${sec.questions.length} 문제 선택'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('mock-submit')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const ValueKey('mock-submit-confirm')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const ValueKey('mock-score')), findsOneWidget);
    expect(find.text('1 / ${sec.questions.length} 정답'), findsWidgets);
    expect(progress.graded(key), isTrue);
    expect(progress.best(key), 1);
    expect(find.textContaining(q1.explanation), findsOneWidget);

    // 틀린 문제만 보기: 1번(정답)의 해설이 사라진다.
    await tester.tap(find.byKey(const ValueKey('mock-only-wrong')));
    await tester.pump();
    expect(find.textContaining(q1.explanation), findsNothing);
    expect(find.textContaining(q2.explanation), findsOneWidget);

    // 다시 풀기: 답은 지워지고 최고 점수는 남는다.
    await tester.tap(find.byKey(const ValueKey('mock-retry')));
    await tester.pump();
    expect(progress.graded(key), isFalse);
    expect(progress.answers(key), isEmpty);
    expect(progress.best(key), 1);
    expect(find.byKey(const ValueKey('mock-submit')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('practice: 5 questions, instant grading with translation',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 3200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final progress = JlptN4MockProgress(prefs);
    final set = mock.sets.first, sec = set.sections.first;
    final key = JlptN4MockProgress.sectionKey(set, sec);
    final qs = sec.practice(0);
    expect(qs.map((q) => q.no), [1, 2, 3, 4, 5]);

    await tester.pumpWidget(MaterialApp(
        home: MockPracticePage(
            set: set, section: sec, index: 0, progress: progress)));
    await tester.pump();
    expect(find.byKey(const ValueKey('mock-q6-opt0')), findsNothing);
    expect(find.byKey(const ValueKey('mock-answer-1')), findsNothing);

    // 1번 정답 → 바로 정답 패널·해석·보기 뜻
    await tester.tap(find.byKey(ValueKey('mock-q1-opt${qs[0].answer}')));
    await tester.pump();
    expect(find.byKey(const ValueKey('mock-answer-1')), findsOneWidget);
    expect(find.text(qs[0].korean), findsOneWidget);
    expect(find.text(qs[0].optionKorean[qs[0].answer]), findsOneWidget);

    // 2~5번은 「정답·해석 보기」
    for (final q in qs.skip(1)) {
      await tester.ensureVisible(find.byKey(ValueKey('mock-reveal-${q.no}')));
      await tester.tap(find.byKey(ValueKey('mock-reveal-${q.no}')));
      await tester.pump();
    }
    expect(find.text('1 / 5 정답'), findsOneWidget);
    expect(progress.practiceBest(key, 0), 1);
    expect(find.byKey(const ValueKey('mock-practice-next')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('home lists both sets and opens a section', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 3200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(MaterialApp(
        home: JlptN4MockHomePage(
            mock: Future.value(mock),
            preferences: SharedPreferences.getInstance())));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mock-set-1-vocab')), findsOneWidget);
    expect(find.byKey(const ValueKey('mock-set-2-grammar')), findsOneWidget);
    expect(find.byKey(const ValueKey('mock-practice-1-vocab-5')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('mock-set-2-grammar')));
    await tester.tap(find.byKey(const ValueKey('mock-set-2-grammar')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(MockExamPage), findsOneWidget);
    expect(find.text('問題1'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
