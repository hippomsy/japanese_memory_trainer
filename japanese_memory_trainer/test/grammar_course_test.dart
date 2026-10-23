import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kioku_japanese/pages/grammar_pages.dart';
import 'package:kioku_japanese/services/grammar_course.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 2026-10-07 일본어 고급 문법: 데이터 검증과 빈칸·고르기·순서 맞추기 흐름.
void main() {
  test('bundled grammar lessons parse with answers', () {
    final lessons = GrammarLesson.parse(
        File('assets/grammar/grammar_lessons.json').readAsStringSync());
    expect(lessons.length, 30);
    for (final l in lessons) {
      expect(l.points, isNotEmpty, reason: l.label);
      for (final c in l.choices) {
        expect(c.answer, inInclusiveRange(0, c.options.length - 1));
      }
      for (final o in l.orders) {
        expect(o.chunks.length, greaterThanOrEqualTo(2));
      }
    }
    expect(fillGaps('雨が[降り]はじめた。'), '雨が降りはじめた。');
    expect(splitGaps('a[b]c').where((p) => p.blank).single.text, 'b');
  });

  testWidgets('choice and order questions check answers and speak',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final spoken = <String>[];
    final lessons = GrammarLesson.parse('''
{"lessons":[{"no":1,"title":"테스트","points":[{"head":"はじめる","form":"ます형+はじめる","meaning":"시작하다","notes":["시작"],
 "drills":[{"base":"降る","ja":"[降り]はじめる","ko":"오기 시작하다"}],"examples":[]}],
 "table":[],"choice":[{"ja":"風が[吹き]はじめた。","ko":"바람","options":["吹き","吹いき"],"answer":0}],
 "order":[{"ja":"[A][B]です。","ko":"","chunks":["A","B"]}],"words":[{"w":"風","r":"かぜ","m":"바람"}]}]}
''');
    await tester.pumpWidget(MaterialApp(
        home: GrammarListPage(
            speakJapanese: (t) async => spoken.add(t),
            lessons: Future.value(lessons))));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('grammar-lesson-1')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('gap-d0-0')));
    await tester.pumpAndSettle();
    expect(spoken.last, '降りはじめる');

    await tester.tap(find.byKey(const ValueKey('grammar-tab-practice')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('grammar-choice-0-0')));
    await tester.pumpAndSettle();
    expect(spoken.last, '風が吹きはじめた。');

    await tester.tap(find.byKey(const ValueKey('grammar-tab-quiz')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('grammar-order-0-chunk-0')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('grammar-order-0-chunk-1')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('grammar-order-0-check')));
    await tester.pumpAndSettle();
    expect(find.text('정답이에요!'), findsOneWidget);
    expect(spoken.last, 'ABです。');
  });
}
