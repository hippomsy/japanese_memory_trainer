import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kioku_japanese/pages/bunka_reading_pages.dart';
import 'package:kioku_japanese/services/bunka_reading.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes/fake_lesson_audio.dart';

/// 2026-10-05 문화 독해 데이터·화면 검증
void main() {
  final lessons =
      BunkaLesson.parse(File(bunkaLessonsAsset).readAsStringSync());

  test('40 lessons with timed sentences, bundled audio and valid quizzes', () {
    expect(lessons.length, 40);
    expect(lessons.where((l) => l.part == 1).length, 20);
    expect(lessons.where((l) => l.part == 2).length, 20);
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('assets/reading/'));
    expect(pubspec, contains('assets/reading_audio/'));
    for (final l in lessons) {
      expect(File(l.audio).existsSync(), isTrue, reason: l.audio);
      expect(File(l.questionAudio).existsSync(), isTrue, reason: l.questionAudio);
      expect(l.sentences.length, greaterThanOrEqualTo(5), reason: l.title);
      expect(l.titleStart, isNotNull);
      var previous = Duration.zero;
      for (final s in l.sentences) {
        expect(s.end, greaterThan(s.start), reason: s.japanese);
        expect(s.start, greaterThanOrEqualTo(previous), reason: s.japanese);
        previous = s.start;
        expect(s.tokens.map((t) => t.text).join(), s.japanese);
        expect(s.korean, isNotEmpty);
      }
      expect(l.questions, isNotEmpty, reason: l.title);
      for (final q in l.questions) {
        expect(q.options.length, 4);
        expect(q.answer, inInclusiveRange(0, 3));
        expect(q.start, isNotNull);
        expect(q.end! > q.start!, isTrue);
      }
      expect(l.koreanFull, contains(l.sentences.last.korean));
    }
  });

  testWidgets('sentence buttons play their clip; toggles; quiz saves score',
      (tester) async {
    // 아래쪽 토글 막대에 가리지 않도록 화면 위쪽으로 스크롤한다.
    Future<void> show(Finder finder) async {
      if (finder.evaluate().isEmpty) {
        await tester.scrollUntilVisible(finder, 300,
            scrollable: find.byType(Scrollable).first);
      }
      Scrollable.ensureVisible(tester.element(finder), alignment: 0.3);
      await tester.pumpAndSettle();
    }

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final progress = BunkaProgress(prefs);
    final players = <FakeLessonAudio>[];
    final lesson = lessons.first;
    await tester.pumpWidget(MaterialApp(
        home: BunkaLessonPage(
      lesson: lesson,
      progress: progress,
      audioFactory: () {
        final p = FakeLessonAudio();
        players.add(p);
        return p;
      },
    )));
    await tester.pump();
    expect(players.length, 2);
    final full = players[0], clip = players[1];
    expect(full.loaded, lesson.audio);

    // 문장 듣기 → 그 문장 구간만 재생
    await show(find.byKey(const ValueKey('bunka-speak-s0')));
    await tester.tap(find.byKey(const ValueKey('bunka-speak-s0')));
    await tester.pump();
    final s0 = lesson.sentences.first;
    expect(clip.calls.last,
        'clip ${lesson.audio} ${s0.start.inMilliseconds}-${s0.end.inMilliseconds}');

    // 전체 듣기
    await show(find.byKey(const ValueKey('bunka-play-all')));
    await tester.tap(find.byKey(const ValueKey('bunka-play-all')));
    await tester.pump();
    expect(full.calls, contains('play'));
    expect(find.text('일시정지'), findsOneWidget);

    // 해석 끄기
    expect(find.byKey(const ValueKey('bunka-korean-0')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('bunka-toggle-해석')));
    await tester.pump();
    expect(find.byKey(const ValueKey('bunka-korean-0')), findsNothing);

    // 빈칸 모드 → 정답 보기 버튼이 생긴다
    await tester.tap(find.byKey(const ValueKey('bunka-toggle-빈칸')));
    await tester.pump();
    expect(find.byTooltip('빈칸 정답 보기'), findsWidgets);

    // 문제 풀기 → 점수 저장
    for (var i = 0; i < lesson.questions.length; i++) {
      final option = find.byKey(
          ValueKey('bunka-q$i-option-${lesson.questions[i].answer}'));
      await show(option);
      await tester.tap(option);
      await tester.pump();
      expect(find.byKey(ValueKey('bunka-q$i-feedback')), findsOneWidget);
    }
    expect(progress.score(lesson.id), lesson.questions.length);
    expect(progress.read(lesson.id), isTrue);

    await tester.pumpWidget(const SizedBox());
    expect(full.disposed && clip.disposed, isTrue);
  });

  testWidgets('list shows both parts and opens a lesson', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(MaterialApp(
        home: BunkaReadingListPage(
      lessons: Future.value(lessons),
      preferences: SharedPreferences.getInstance(),
      audioFactory: FakeLessonAudio.new,
    )));
    await tester.pumpAndSettle();
    expect(find.text('PART 1 · 기초'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('bunka-lesson-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('bunka-title')), findsOneWidget);
  });
}
