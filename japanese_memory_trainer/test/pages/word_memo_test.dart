import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kioku_japanese/data/study_store.dart';
import 'package:kioku_japanese/pages/daily_recall_page.dart';
import 'package:kioku_japanese/widgets/word_memo.dart';
import 'package:kioku_japanese/widgets/word_row.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'chapter_page_test.dart' show chapterWords;

/// 2026-10-23 연상 메모 카드가 목록 펼침 화면과 복습 정답 화면에서 동작하는지 검증한다.
void main() {
  testWidgets('word row memo can be written, saved and cleared', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = StudyStore(await SharedPreferences.getInstance());
    final word = chapterWords.first;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: WordRow(
            number: 1,
            word: word,
            favorite: false,
            learned: false,
            compact: false,
            store: store,
            onToggleFavorite: () {},
            speakJapanese: (_) async {},
          ),
        ),
      ),
    ));
    expect(find.byType(WordMemoTile), findsNothing);
    await tester.tap(find.text(word.japanese));
    await tester.pumpAndSettle();
    expect(find.byType(WordMemoTile), findsOneWidget);
    expect(find.textContaining('나만의 연상 메모 쓰기'), findsOneWidget);

    await tester.ensureVisible(find.byKey(ValueKey('memo-${word.id}')));
    await tester.tap(find.byKey(ValueKey('memo-${word.id}')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('memo-field')), '조금 = 스고시 먹기');
    await tester.tap(find.byKey(const ValueKey('memo-save')));
    await tester.pumpAndSettle();
    expect(find.text('조금 = 스고시 먹기'), findsOneWidget);
    expect(store.memoOf(word.id), '조금 = 스고시 먹기');

    await tester.tap(find.byKey(ValueKey('memo-${word.id}')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('memo-field')), '');
    await tester.tap(find.byKey(const ValueKey('memo-save')));
    await tester.pumpAndSettle();
    expect(store.memoOf(word.id), '');
    expect(find.textContaining('나만의 연상 메모 쓰기'), findsOneWidget);
  });

  testWidgets('cancel keeps the existing memo', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = StudyStore(await SharedPreferences.getInstance());
    await store.setMemo('c1', '기존 메모');
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: WordMemoTile(store: store, wordId: 'c1')),
    ));
    await tester.tap(find.byKey(const ValueKey('memo-c1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('memo-field')), '바뀐 글');
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(store.memoOf('c1'), '기존 메모');
    expect(find.text('기존 메모'), findsOneWidget);
  });

  testWidgets('daily recall shows the saved memo only after reveal',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = StudyStore(await SharedPreferences.getInstance());
    await store.setMemo('c1', '이 단어는 고양이 소리');
    await tester.pumpWidget(MaterialApp(
      home: DailyRecallPage(
        words: [chapterWords.first],
        store: store,
        speakJapanese: (_) async {},
      ),
    ));
    expect(find.text('이 단어는 고양이 소리'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('reveal-answer')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(const ValueKey('memo-c1')), 200);
    expect(find.text('이 단어는 고양이 소리'), findsOneWidget);
  });
}
