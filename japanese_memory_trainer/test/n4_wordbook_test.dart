import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kioku_japanese/pages/n4_wordbook_pages.dart';
import 'package:kioku_japanese/services/n4_wordbook.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes/fake_lesson_audio.dart';

/// 2026-10-09 N4 단어장(딱! 한권 JLPT 단어장 N4) 데이터·화면 검증
void main() {
  final book = N4Wordbook.parse(File(n4WordbookAsset).readAsStringSync());

  test('30 days of words with native audio spans', () {
    expect(book.days.length, 30);
    expect(book.wordCount, greaterThan(800));
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('assets/n4_wordbook/'));
    expect(pubspec, contains('assets/n4_wordbook_audio/'));
    final ids = <String>{};
    for (final d in book.days) {
      expect(File(d.audio).existsSync(), isTrue, reason: d.audio);
      expect(d.words.length, greaterThanOrEqualTo(15), reason: 'DAY ${d.day}');
      var previous = Duration.zero;
      for (final w in d.words) {
        expect(ids.add(w.id), isTrue, reason: w.id);
        expect(w.japanese, isNotEmpty);
        expect(w.korean, isNotEmpty, reason: w.id);
        expect(w.jaSpan.end, greaterThan(w.jaSpan.start), reason: w.id);
        expect(w.jaSpan.start, greaterThanOrEqualTo(previous), reason: w.id);
        if (w.koSpan != null) {
          expect(w.koSpan!.start, greaterThanOrEqualTo(w.jaSpan.end), reason: w.id);
          previous = w.koSpan!.start;
        } else {
          previous = w.jaSpan.start;
        }
      }
    }
  });

  test('kanji notes, reading passages and questions are present', () {
    final aisatsu = book.days.first.words.first;
    expect(aisatsu.kanji.map((k) => k.char).join(), '挨拶');
    expect(aisatsu.kanji.first.hunEum, isNotEmpty);
    for (final d in book.days) {
      final r = d.reading;
      expect(r, isNotNull, reason: 'DAY ${d.day}');
      expect(r!.sentences.length, greaterThanOrEqualTo(5));
      final ids = d.words.map((w) => w.id).toSet();
      var marked = 0;
      for (final s in r.sentences) {
        expect(s.tokens.map((t) => t.text).join(), s.japanese);
        expect(s.wordIds.length, s.tokens.length);
        for (final id in s.wordIds.whereType<String>()) {
          expect(ids, contains(id));
          marked++;
        }
      }
      expect(marked, greaterThanOrEqualTo(5), reason: 'DAY ${d.day}');
      for (final q in r.questions) {
        expect(q.answer, inInclusiveRange(0, q.options.length - 1));
      }
    }
  });

  test('spaced repetition: good answers push the next review further', () async {
    SharedPreferences.setMockInitialValues({});
    final progress = N4WordbookProgress(await SharedPreferences.getInstance());
    final w = book.days.first.words.first;
    final t0 = DateTime(2026, 10, 10, 9);
    expect(progress.isNew(w.id), isTrue);
    await progress.review(w.id, 3, t0);
    final first = progress.nextReview(w.id)!;
    expect(first.isAfter(t0), isTrue);
    expect(progress.isDue(w.id, t0), isFalse);
    expect(progress.isDue(w.id, first), isTrue);
    await progress.review(w.id, 3, first);
    final second = progress.nextReview(w.id)!;
    expect(second.difference(first), greaterThan(first.difference(t0)));
    await progress.review(w.id, 1, second);
    expect(progress.nextReview(w.id)!.difference(second).inMinutes, 10);
    expect(progress.dueWords(book, second.add(const Duration(hours: 1))).map((x) => x.id),
        contains(w.id));
  });

  test('daily goal limits new words and streak counts study days', () async {
    SharedPreferences.setMockInitialValues({});
    final progress = N4WordbookProgress(await SharedPreferences.getInstance());
    final today = DateTime(2026, 10, 10, 20);
    expect(progress.dailyGoal, 8);
    await progress.setDailyGoal(5);
    expect(progress.remainingNew(today), 5);
    final fresh = progress.nextNewWords(book, 5);
    expect(fresh.first.id, book.days.first.words.first.id);
    for (final w in fresh.take(3)) {
      await progress.review(w.id, 3, today);
    }
    expect(progress.newToday(today), 3);
    expect(progress.remainingNew(today), 2);
    expect(progress.nextNewWords(book, 2).first.id, fresh[3].id);
    expect(progress.streak(today), 1);
    await progress.review(fresh[3].id, 3, today.subtract(const Duration(days: 1)));
    expect(progress.streak(today), 2);
    // 다음 날: 새 단어 목표가 다시 채워진다.
    expect(progress.remainingNew(today.add(const Duration(days: 1))), 5);
  });

  test('quiz has 4 distinct choices with exactly one answer', () {
    final words = book.days.first.words;
    final quiz = buildN4Quiz(book, words, reverse: false, random: Random(1));
    expect(quiz.length, words.length);
    for (final q in quiz) {
      expect(q.choices.length, 4);
      expect(q.choices[q.answer].id, q.word.id);
      expect(q.choices.map((c) => c.korean).toSet().length, 4);
    }
  });

  testWidgets('word list plays clips; word game flips cards with clips',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final progress = N4WordbookProgress(prefs);
    final players = <FakeLessonAudio>[];
    final day = book.days.first;
    final w = day.words.first;
    await tester.pumpWidget(MaterialApp(
        home: N4DayPage(
            book: book,
            day: day,
            progress: progress,
            audioFactory: () {
              final p = FakeLessonAudio();
              players.add(p);
              return p;
            })));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('n4-play-ja-${w.id}')));
    await tester.pump();
    final audio = players.single;
    expect(audio.calls.last, startsWith('clip ${day.audio}'));

    // 2026-10-18 단어 게임 탭: 카드 12장, 카드를 뒤집으면 원어민 구간을 재생한다.
    await tester.tap(find.byKey(const ValueKey('n4-tab-game')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('match-card-11')), findsOneWidget);
    final before = audio.calls.length;
    await tester.tap(find.byKey(const ValueKey('match-card-0')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(audio.calls.length, greaterThan(before));
    expect(audio.calls.last, startsWith('clip ${day.audio}'));

    // 자동 학습 탭: 재생 → 멈춤
    await tester.tap(find.byKey(const ValueKey('n4-tab-auto')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('n4-auto-play')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('멈춤'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('n4-auto-play')));
    await tester.pump(const Duration(seconds: 10));
    expect(find.text('자동 재생'), findsOneWidget);
  });

  // 2026-10-23 DAY 화면의 객관식 탭에서 퀴즈를 시작하면 4개의 보기가 나온다.
  testWidgets('day page has a multiple choice quiz tab', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final progress = N4WordbookProgress(prefs);
    await tester.pumpWidget(MaterialApp(
        home: N4DayPage(
            book: book,
            day: book.days.first,
            progress: progress,
            audioFactory: FakeLessonAudio.new)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('n4-tab-quiz')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('n4-quiz-start')));
    await tester.pumpAndSettle();
    for (var i = 0; i < 4; i++) {
      expect(find.byKey(ValueKey('n4-choice-$i')), findsOneWidget);
    }
  });

  testWidgets('flashcard rates a word; reading word opens sheet', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final progress = N4WordbookProgress(prefs);
    final day = book.days.first;
    await tester.pumpWidget(MaterialApp(
        home: N4DayPage(
            book: book,
            day: day,
            progress: progress,
            audioFactory: FakeLessonAudio.new)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('n4-tab-cards')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('n4-flash-show')));
    await tester.pumpAndSettle();
    // 2026-10-11 JLPT 단어장과 같은 큰 한자 칸 + 쪼개 보기 버튼.
    expect(find.byKey(const ValueKey('kanji-挨')), findsOneWidget);
    expect(find.byKey(ValueKey('kanji-split-${day.words.first.id}')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('n4-rate-3')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('n4-rate-3')));
    await tester.pumpAndSettle();
    expect(progress.isNew(day.words.first.id), isFalse);

    await tester.tap(find.byKey(const ValueKey('n4-tab-reading')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('n4-reading')), findsOneWidget);
    final firstId = day.reading!.sentences
        .expand((s) => s.wordIds)
        .whereType<String>()
        .first;
    await tester.tap(find.byKey(ValueKey('n4-rword-$firstId')).first);
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
  });

  testWidgets('home lists 30 days', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(MaterialApp(
        home: N4WordbookHomePage(
            book: Future.value(book),
            preferences: Future.value(prefs),
            audioFactory: FakeLessonAudio.new)));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('n4-day-1')), findsOneWidget);
  });
}
