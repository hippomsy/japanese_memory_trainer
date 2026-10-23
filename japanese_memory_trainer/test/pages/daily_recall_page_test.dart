import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kioku_japanese/data/study_store.dart';
import 'package:kioku_japanese/pages/daily_recall_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'chapter_page_test.dart' show chapterWords;

void main() {
  testWidgets('answer stays hidden until revealed and forgotten word is saved',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = StudyStore(await SharedPreferences.getInstance());
    await tester.pumpWidget(MaterialApp(
        home: DailyRecallPage(
            words: [chapterWords.first],
            store: store,
            speakJapanese: (_) async {})));
    expect(find.text('조금'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('reveal-answer')));
    await tester.pumpAndSettle();
    expect(find.text('少し'), findsOneWidget);
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('rate-forgotten')), 200);
    await tester.tap(find.byKey(const ValueKey('rate-forgotten')));
    await tester.pumpAndSettle();
    expect(find.textContaining('한자 보고 발음하기'), findsOneWidget);
    expect(store.wrongIds, {'c1'});
    expect(store.learnedIds, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('listening prompt hides spelling and plays reading',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = StudyStore(await SharedPreferences.getInstance());
    await store.recordAspect(
        'c1', RecallAspect.meaning, RecallRating.remembered);
    await store.recordAspect(
        'c1', RecallAspect.reading, RecallRating.remembered);
    final spoken = <String>[];
    await tester.pumpWidget(MaterialApp(
        home: DailyRecallPage(
      words: [chapterWords.first],
      store: store,
      speakJapanese: (text) async {
        spoken.add(text);
      },
    )));
    expect(find.text('少し'), findsNothing);
    expect(find.text('조금'), findsNothing);
    await tester.tap(find.text('단어 듣기'));
    await tester.pumpAndSettle();
    expect(spoken, [chapterWords.first.reading]);
    await tester.tap(find.byKey(const ValueKey('reveal-answer')));
    await tester.pumpAndSettle();
    expect(find.text('조금'), findsOneWidget);
  });
}
