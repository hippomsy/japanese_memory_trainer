import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kioku_japanese/pages/jlpt_listening_pages.dart';
import 'package:kioku_japanese/services/jlpt_listening.dart';
import 'package:kioku_japanese/data/kanji_dictionary.dart';
import 'package:kioku_japanese/widgets/ruby_text.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes/fake_lesson_audio.dart';

/// 2026-10-08 JLPT N5 청해 데이터·화면 검증
void main() {
  final book =
      JlptListeningBook.parse(File(jlptN5ListeningAsset).readAsStringSync());

  test('4 tests × 問題1~4 with audio, timed script and one answer each', () {
    expect(book.tests.length, 4);
    expect(book.questions.length, 96);
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('assets/jlpt_n5/'));
    expect(pubspec, contains('assets/jlpt_n5_audio/'));
    for (final t in book.tests) {
      expect(book.section(t.id, 1).length, 7, reason: t.title);
      expect(book.section(t.id, 2).length, 6, reason: t.title);
      expect(book.section(t.id, 3).length, 5, reason: t.title);
      expect(book.section(t.id, 4).length, 6, reason: t.title);
    }
    final ids = <String>{};
    for (final q in book.questions) {
      expect(ids.add(q.id), isTrue, reason: q.id);
      expect(File(q.audio).existsSync(), isTrue, reason: q.audio);
      expect(q.options.length, q.optionsSpoken ? 3 : 4, reason: q.id);
      expect(q.answer, inInclusiveRange(0, q.options.length - 1));
      expect(q.explanation, isNotEmpty, reason: q.id);
      expect(q.lines, isNotEmpty, reason: q.id);
      if (q.mondai <= 2) {
        expect(q.ask, isNotNull, reason: q.id);
        expect(q.options.every((o) => o.emoji != null), isTrue, reason: q.id);
      } else {
        expect(q.options.every((o) => o.span != null), isTrue, reason: q.id);
      }
      if (q.mondai == 3) expect(q.scene, isNotNull, reason: q.id);
      for (final l in q.lines) {
        expect(l.span.end, greaterThan(l.span.start), reason: l.japanese);
        expect(l.span.end, lessThanOrEqualTo(q.duration), reason: l.japanese);
        expect(l.tokens.map((t) => t.text).join(), l.japanese);
        expect(l.korean, isNotEmpty);
      }
    }
  });

  testWidgets('answer is graded and saved; script lines replay their clip',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final progress = JlptListeningProgress(prefs);
    final players = <FakeLessonAudio>[];
    final questions = book.section(1, 1);
    final q = questions.first;
    await tester.pumpWidget(MaterialApp(
        home: JlptQuestionPage(
      book: book,
      progress: progress,
      questions: questions,
      title: '第1回 問題1',
      audioFactory: () {
        final p = FakeLessonAudio();
        players.add(p);
        return p;
      },
    )));
    await tester.pump();
    expect(players.length, 2);
    final full = players[0], clip = players[1];
    expect(full.loaded, q.audio);

    await tester.tap(find.byKey(const ValueKey('jlpt-play')));
    await tester.pump();
    expect(full.calls, contains('play'));

    await tester.tap(find.byKey(const ValueKey('jlpt-loop')));
    await tester.pump();
    expect(full.calls, contains('loop true'));

    // 오답을 고르면 오답 표시와 정답 번호, 기록 저장
    final wrong = q.answer == 0 ? 1 : 0;
    final option = find.byKey(ValueKey('jlpt-option-$wrong'));
    await tester.ensureVisible(option);
    await tester.tap(option);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('jlpt-result')), findsOneWidget);
    expect(find.textContaining('아쉬워요'), findsOneWidget);
    expect(progress.correct(q.id), isFalse);

    // 다시 풀기 → 정답
    await tester.ensureVisible(find.byKey(const ValueKey('jlpt-retry')));
    await tester.tap(find.byKey(const ValueKey('jlpt-retry')));
    await tester.pumpAndSettle();
    final right = find.byKey(ValueKey('jlpt-option-${q.answer}'));
    await tester.ensureVisible(right);
    await tester.tap(right);
    await tester.pumpAndSettle();
    expect(find.text('정답이에요!'), findsOneWidget);
    expect(progress.correct(q.id), isTrue);

    // 스크립트 보기 → 문장 다시 듣기
    final toggle = find.byKey(const ValueKey('jlpt-script-toggle'));
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('jlpt-script')), findsOneWidget);
    final line = find.byKey(const ValueKey('jlpt-line-1'));
    await tester.ensureVisible(line);
    await tester.tap(line);
    await tester.pump();
    expect(clip.calls.last, startsWith('clip ${q.audio}'));

    KanjiDictionary.instance = KanjiDictionary({
      '犬': const KanjiInfo(kanji: '犬', hun: '개', eum: '견'),
    });
    final ruby = find
        .descendant(
            of: find.byKey(const ValueKey('jlpt-script')),
            matching: find.byType(RubyText))
        .evaluate()
        .map((e) => e.widget as RubyText);
    expect(ruby.every((w) => w.showUnderline && w.onWordTap != null), isTrue);
    final word = find
        .byWidgetPredicate(
            (w) => w is Semantics && w.properties.label == '犬, 뜻 보기')
        .first;
    await tester.ensureVisible(word);
    await tester.tap(word);
    await tester.pumpAndSettle();
    expect(find.text('발음: いぬ'), findsOneWidget);
    expect(find.text('뜻: 개'), findsOneWidget);
    expect(find.text('犬 · 개 견'), findsOneWidget);
    expect(find.textContaining('해석: '), findsOneWidget);
    await tester.tap(find.byTooltip('닫기'));
    await tester.pumpAndSettle();

    // 다음 문제로 넘어가면 새 음성을 불러온다.
    await tester.tap(find.byKey(const ValueKey('jlpt-next')));
    await tester.pumpAndSettle();
    expect(players.last.disposed, isFalse);
    expect(players[players.length - 2].loaded, questions[1].audio);
    expect(full.disposed, isTrue);
  });

  testWidgets('home lists every section and shows saved score', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await JlptListeningProgress(prefs)
        .answer(book.section(1, 4).first.id, 0, false);
    await tester.pumpWidget(MaterialApp(
        home: JlptListeningHomePage(
            book: Future.value(book),
            preferences: Future.value(prefs),
            audioFactory: FakeLessonAudio.new)));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('jlpt-section-1-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('jlpt-retry-wrong')), findsOneWidget);
  });
}
