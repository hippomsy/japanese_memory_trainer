import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kioku_japanese/app.dart';
import 'package:kioku_japanese/models/vocabulary.dart';
import 'package:shared_preferences/shared_preferences.dart';

Vocabulary flowWord(int index, {String type = '부사'}) => Vocabulary(
      id: 'w$index',
      japanese: '単語$index',
      reading: 'たんご$index',
      korean: '단어$index',
      exampleJapanese: '単語$indexを覚えます。',
      exampleKorean: '단어$index를 외웁니다.',
      jlptLevel: 'N5',
      wordType: type,
      frequencyRank: index,
    );

/// 2026-09-27 새 화면 구조 전체 흐름: 급수 → 품사 → 챕터 → 학습(4지선다) → 진행률 반영
void main() {
  testWidgets('grade → category → chapter → study updates progress',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final seed = [
      for (var i = 1; i <= 16; i++) flowWord(i),
      for (var i = 17; i <= 19; i++) flowWord(i, type: '명사'),
    ];

    await tester.pumpWidget(
      KiokuJapaneseApp(
          preferences: prefs, seed: seed, speakJapanese: (_) async {}),
    );
    await tester.pumpAndSettle();

    expect(find.text('하루 일본어'), findsOneWidget);
    expect(find.text('0 / 19'), findsWidgets);

    await tester.tap(find.text('학습').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('category-words')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('category-words')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const ValueKey('grade-N5')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('grade-N5')));
    await tester.pumpAndSettle();

    expect(find.text('名詞'), findsOneWidget);
    expect(find.text('副詞'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('category-부사')));
    await tester.pumpAndSettle();

    expect(find.text('N5 · 副詞'), findsOneWidget);
    expect(find.text('第1章'), findsOneWidget);
    expect(find.text('第2章'), findsOneWidget);
    expect(find.text('0 / 14'), findsOneWidget);
    expect(find.text('0 / 2'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('chapter-1')));
    await tester.pumpAndSettle();
    expect(find.text('N5 · 副詞 · 14단어'), findsOneWidget);
    expect(find.text('単語1'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('tab-1')));
    await tester.pumpAndSettle();
    expect(find.text('1 / 14'), findsOneWidget);
    expect(find.text('단어1'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('choice-単語1')));
    await tester.pumpAndSettle();
    expect(find.text('정답입니다!'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('next-question')));
    await tester.pumpAndSettle();
    expect(find.text('2 / 14'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('1 / 14'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('1 / 19'), findsWidgets);
  });
}
