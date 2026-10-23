import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kioku_japanese/models/vocabulary.dart';
import 'package:kioku_japanese/pages/word_match_game.dart';

// 2026-10-17 단어 짝맞추기: 카드 수, 뒤집을 때 소리, 괄호 뜻 읽기.
Vocabulary _w(int i) => Vocabulary(
    id: 'w$i',
    japanese: '語$i',
    reading: 'ご$i',
    korean: '뜻$i',
    exampleJapanese: '',
    exampleKorean: '',
    jlptLevel: 'N5',
    wordType: '명사',
    frequencyRank: i);

void main() {
  test('korean speech drops bracket notes', () {
    expect(matchSpeakKorean('눈(신체)'), '눈');
    expect(matchSpeakKorean('가다, 오다'), '가다');
  });

  testWidgets('12 cards; flipping speaks Japanese or Korean', (tester) async {
    final jp = <String>[], ko = <String>[];
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: WordMatchGame(
                words: [for (var i = 1; i <= 8; i++) _w(i)],
                random: Random(1),
                speakJapanese: (t) async => jp.add(t),
                speakKorean: (t) async => ko.add(t)))));
    await tester.pump();
    expect(find.byKey(const ValueKey('match-card-11')), findsOneWidget);
    expect(find.byKey(const ValueKey('match-card-12')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('match-card-0')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(jp.length + ko.length, 1);
  });
}
