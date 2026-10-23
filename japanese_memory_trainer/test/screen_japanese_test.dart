import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kioku_japanese/pages/screen_japanese_pages.dart';
import 'package:kioku_japanese/services/screen_japanese.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 2026-10-06 스크린 일본어: 데이터 파일 검증과 대사 듣기·퀴즈 정답 흐름.
void main() {
  test('bundled screen lessons parse and every quiz has an answer', () {
    final movies =
        ScreenMovie.parse(File('assets/screen/screen_lessons.json').readAsStringSync());
    expect(movies.length, 3);
    final lessons = movies.expand((m) => m.lessons).toList();
    expect(lessons.length, greaterThanOrEqualTo(100));
    for (final l in lessons) {
      expect(l.lines, isNotEmpty, reason: l.id);
      expect(l.quizzes, isNotEmpty, reason: l.id);
      for (final q in l.quizzes) {
        expect(q.japanese.trim(), isNotEmpty, reason: l.id);
        expect(q.korean.trim(), isNotEmpty, reason: l.id);
      }
    }
  });

  testWidgets('speaker button reads a line and answer button reveals Japanese',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final spoken = <String>[];
    final movies = ScreenMovie.parse('''
{"movies":[{"id":"t","volume":1,"title":"테스트 영화","ja_title":"テスト","lessons":[
 {"no":1,"title":"첫 장면","summary":"줄거리","keywords":[{"ja":"長い間","ko":"오랫동안"}],
  "script":[{"sp":"유지","ja":"おはようございます。","ko":"안녕하세요."}],
  "review":[{"pattern":"ずいぶん","meaning":"꽤","ja":"ずいぶん早いね。","ko":"꽤 빠르네."}],
  "quiz":[{"ko":"지각한다니까!","ja":"遅刻するよ。"}]}]}]}
''');
    await tester.pumpWidget(MaterialApp(
        home: ScreenMovieListPage(
            speakJapanese: (t) async => spoken.add(t),
            movies: Future.value(movies))));
    await tester.pumpAndSettle();
    expect(find.text('테스트 영화'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('screen-movie-t')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('screen-lesson-t-1')));
    await tester.pumpAndSettle();

    expect(find.text('おはようございます。'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('screen-speak-line-0')));
    await tester.pumpAndSettle();
    expect(spoken, ['おはようございます。']);

    await tester.tap(find.byKey(const ValueKey('screen-tab-quiz')));
    await tester.pumpAndSettle();
    expect(find.text('遅刻するよ。'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('screen-answer-0')));
    await tester.pumpAndSettle();
    expect(find.text('遅刻するよ。'), findsOneWidget);
    expect(spoken.last, '遅刻するよ。');
  });
}
