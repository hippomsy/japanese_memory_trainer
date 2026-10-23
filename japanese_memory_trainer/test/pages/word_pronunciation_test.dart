import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kioku_japanese/data/elementary_words.dart';
import 'package:kioku_japanese/widgets/word_row.dart';

void main() {
  testWidgets('空く speaker uses PDF reading あく instead of ambiguous kanji', (tester) async {
    final words = await tester.runAsync(loadElementaryWords);
    final word = words!.firstWhere((w) => w.japanese == '空く' && w.reading == 'あく');
    final spoken = <String>[];
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(
      child: WordRow(number: 1, word: word, favorite: false,
        learned: false, compact: false, onToggleFavorite: () {},
        speakJapanese: (text) async { spoken.add(text); }),
    ))));
    await tester.tap(find.text('空く'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('발음 듣기'));
    await tester.tap(find.byTooltip('발음 듣기'));
    await tester.pumpAndSettle();
    expect(spoken, ['あく']);
  });
}
