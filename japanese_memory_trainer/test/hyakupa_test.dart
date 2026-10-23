import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kioku_japanese/pages/hyakupa_pages.dart';
import 'package:kioku_japanese/services/hyakupa_course.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes/fake_lesson_audio.dart';

/// 2026-10-11 백퍼 일본어 회화 456 확인.
void main() {
  final book = HyakupaBook.parse(File('assets/hyakupa/hyakupa.json').readAsStringSync());

  test('표현 456개 · 모든 음성 파일 · 대사 시간 순서', () {
    expect(book.tracks.length, 456);
    expect(book.units.length, 23);
    for (final t in book.tracks) {
      expect(File(t.audio).existsSync(), isTrue, reason: t.audio);
      expect(t.lines, isNotEmpty, reason: t.label);
      expect(t.titleEnd, greaterThan(t.titleStart));
      for (final l in t.lines) {
        expect(l.end, greaterThan(l.start));
        expect(l.end, lessThanOrEqualTo(t.duration + 0.1));
        expect(l.japanese, isNotEmpty);
        expect(l.korean, isNotEmpty);
      }
    }
    final t101 = book.byNumber(101)!;
    expect(t101.title, 'シャッターチャンス');
    expect(t101.blankLine, isNotNull);
    expect(book.search('シャッター').first.number, 101);
  });

  test('퀴즈 보기는 4개, 정답 하나, 중복 없음', () {
    final b = HyakupaQuizBuilder(book.tracks, random: Random(2));
    for (final t in book.tracks) {
      for (final k in HyakupaQuizKind.values) {
        final q = b.question(t, k);
        expect(q.options.length, 4, reason: '${t.label} $k');
        expect(q.options.toSet().length, 4, reason: '${t.label} $k');
        if (q.kind == HyakupaQuizKind.blank) {
          expect(q.blanked, contains('＿＿＿'));
          expect(q.line!.japanese, contains(q.options[q.answer]));
        }
      }
    }
  });

  test('간격 복습 · 즐겨찾기', () async {
    SharedPreferences.setMockInitialValues({});
    final p = HyakupaProgress(await SharedPreferences.getInstance());
    final now = DateTime(2026, 10, 11, 9);
    await p.markLearned(5, now);
    expect(p.stage(5), 1);
    await p.record(5, true, now);
    expect(p.dueAt(5), now.add(const Duration(days: 1)));
    await p.record(5, false, now);
    expect(p.stage(5), 1);
    await p.toggleFavorite(7);
    expect(p.isFavorite(7), isTrue);
    expect(p.nextNew(book)!.number, 1);
  });

  testWidgets('첫 화면 → 단원 → 표현 → 대사 듣기', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final audio = FakeLessonAudio();
    await tester.pumpWidget(MaterialApp(
        home: HyakupaHomePage(book: book, audioFactory: () => audio)));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('hyakupa-home')), findsOneWidget);
    await tester.scrollUntilVisible(find.byKey(const ValueKey('hyakupa-unit-6')), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byKey(const ValueKey('hyakupa-unit-6')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('hyakupa-track-101')));
    await tester.pumpAndSettle();
    expect(find.text('シャッターチャンス'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('hyakupa-line-0')));
    await tester.pump(const Duration(seconds: 4));
    expect(audio.calls.any((c) => c.startsWith('clip assets/hyakupa_audio/101.mp3')), isTrue);
    await tester.tap(find.byKey(const ValueKey('hyakupa-learned')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('hyakupa-page-102')), findsOneWidget);
  });
}
