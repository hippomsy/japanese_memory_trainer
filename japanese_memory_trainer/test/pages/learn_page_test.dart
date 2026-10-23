import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kioku_japanese/models/vocabulary.dart';
import 'package:kioku_japanese/pages/learn_page.dart';

const sampleWord = Vocabulary(
  id: 'w1',
  japanese: '覚える',
  reading: 'おぼえる',
  korean: '외우다, 기억하다',
  exampleJapanese: '新しい単語を覚えます。',
  exampleKorean: '새 단어를 외웁니다.',
  jlptLevel: 'N4',
  wordType: '동사',
  frequencyRank: 1,
);

void main() {
  testWidgets('LearnPage shows full word card and next button', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LearnPage(
          words: const [sampleWord],
          speakJapanese: (_) async {},
          onFinished: () {},
        ),
      ),
    );

    expect(find.text('覚える'), findsOneWidget);
    expect(find.text('おぼえる'), findsOneWidget);
    expect(find.text('외우다, 기억하다'), findsOneWidget);
    expect(find.text('新しい単語を覚えます。'), findsOneWidget);
    expect(find.text('새 단어를 외웁니다.'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('예문 듣기'), findsOneWidget);
    expect(find.text('다음으로  →'), findsOneWidget);
  });

  testWidgets('speaker callback receives the kana pronunciation', (tester) async {
    String? spoken;
    await tester.pumpWidget(
      MaterialApp(
        home: LearnPage(
          words: const [sampleWord],
          speakJapanese: (text) async => spoken = text,
          onFinished: () {},
        ),
      ),
    );

    await tester.tap(find.byTooltip('발음 듣기'));
    await tester.pump();
    expect(spoken, 'おぼえる');
  });
}
