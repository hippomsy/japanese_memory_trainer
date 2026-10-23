import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kioku_japanese/data/kanji_dictionary.dart';
import 'package:kioku_japanese/data/sentence_bank.dart';
import 'package:kioku_japanese/data/study_store.dart';
import 'package:kioku_japanese/models/vocabulary.dart';
import 'package:kioku_japanese/models/word_catalog.dart';
import 'package:kioku_japanese/pages/chapter_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

Vocabulary chapterWord(int id, String japanese, String reading, String korean) => Vocabulary(
      id: 'c$id',
      japanese: japanese,
      reading: reading,
      korean: korean,
      exampleJapanese: '$japanese。',
      exampleKorean: '예문',
      jlptLevel: 'N5',
      wordType: '부사',
      frequencyRank: id,
    );

final chapterWords = [
  chapterWord(1, '少し', 'すこし', '조금'),
  chapterWord(2, '今', 'いま', '지금'),
  chapterWord(3, '大変', 'たいへん', '몹시'),
  chapterWord(4, 'いつも', 'いつも', '언제나'),
];

/// 2026-09-27 챕터 화면(목록·학습 세 가지 방식) 검증
void main() {
  final spoken = <String>[];

  Future<StudyStore> pumpChapter(WidgetTester tester, {StudyMode? mode}) async {
    spoken.clear();
    SharedPreferences.setMockInitialValues({});
    final store = StudyStore(await SharedPreferences.getInstance());
    if (mode != null) await store.setMode(mode);
    final catalog = WordCatalog(chapterWords);
    await tester.pumpWidget(
      MaterialApp(
        home: ChapterPage(
          chapter: catalog.chaptersOf('N5', '부사').first,
          catalog: catalog,
          store: store,
          speakJapanese: (text) async => spoken.add('ja:$text'),
          speakKorean: (text) async => spoken.add('ko:$text'),
          random: Random(3),
          autoTiming: const AutoTiming(
            afterJapanese: Duration(milliseconds: 10),
            afterKorean: Duration(milliseconds: 10),
            flip: Duration(milliseconds: 10),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return store;
  }

  testWidgets('list tab toggles favorite and shows details on tap', (tester) async {
    final store = await pumpChapter(tester);
    expect(find.text('少し'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('fav-c1')));
    await tester.pumpAndSettle();
    expect(store.isFavorite('c1'), isTrue);

    await tester.tap(find.text('少し'));
    await tester.pumpAndSettle();
    expect(find.text('少し  【すこし】'), findsOneWidget);
    expect(find.text('조금'), findsOneWidget);
  });

  testWidgets('sentence mode: tap chunks in order, check, then finish', (tester) async {
    SentenceBank.instance = SentenceBank({
      'N5|부사|1': const [
        SentenceItem(wordId: 'c1', korean: '물을 조금 마셨습니다.', kana: 'みずをすこしのみました。', chunks: ['水を', '少し', '飲みました。']),
        SentenceItem(wordId: 'c2', korean: '지금 갑니다.', kana: 'いまいきます。', chunks: ['今', '行きます。', 'すぐ']),
      ],
    });
    addTearDown(() => SentenceBank.instance = SentenceBank(const {}));
    final store = await pumpChapter(tester);
    await tester.tap(find.byKey(const ValueKey('tab-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mode-sentence')));
    await tester.pumpAndSettle();
    expect(store.mode, StudyMode.sentence);
    expect(find.text('물을 조금 마셨습니다.'), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byKey(ValueKey('sentence-chunk-$i')));
      await tester.pump();
    }
    await tester.tap(find.byKey(const ValueKey('sentence-check')));
    await tester.pumpAndSettle();
    expect(find.text('정답입니다!'), findsOneWidget);
    expect(find.text('水を少し飲みました。'), findsOneWidget);
    expect(spoken, contains('ja:水を少し飲みました。'));

    await tester.tap(find.byKey(const ValueKey('sentence-next')));
    await tester.pumpAndSettle();
    // 두 번째 문제는 일부러 틀린 순서로 놓는다(0,1,2 = 今 行きます。 すぐ 는 정답 순서와 같으므로 2,0,1).
    for (final i in [2, 1, 0]) {
      await tester.tap(find.byKey(ValueKey('sentence-chunk-$i')));
      await tester.pump();
    }
    await tester.tap(find.byKey(const ValueKey('sentence-check')));
    await tester.pumpAndSettle();
    expect(find.text('틀렸습니다'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('sentence-next')));
    await tester.pumpAndSettle();
    expect(find.text('2문제 중 1문제 정답'), findsOneWidget);
    expect(find.byKey(const ValueKey('sentence-retry-wrong')), findsOneWidget);
  });

  testWidgets('list shows kanji 훈음 summary and detail when expanded', (tester) async {
    KanjiDictionary.instance = KanjiDictionary({
      '大': const KanjiInfo(kanji: '大', hun: '큰', eum: '대', onReadings: ['ダイ', 'タイ'], kunReadings: ['おお(きい)'], strokes: 3, jlpt: 5),
      '変': const KanjiInfo(kanji: '変', hun: '변할', eum: '변', koreanForm: '變', onReadings: ['ヘン'], kunReadings: ['か(わる)']),
    });
    addTearDown(() => KanjiDictionary.instance = KanjiDictionary(const {}));
    await pumpChapter(tester);
    expect(find.text('큰 대 · 변할 변'), findsOneWidget);

    await tester.tap(find.text('大変'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('kanji-大')), findsOneWidget);
    expect(find.text('정자 變'), findsOneWidget);
    expect(find.text('ダイ · タイ'), findsOneWidget);
    expect(find.text('3획 · N5'), findsOneWidget);
  });

  testWidgets('wrong choice shows answer and is not marked learned', (tester) async {
    final store = await pumpChapter(tester);
    await tester.tap(find.byKey(const ValueKey('tab-1')));
    await tester.pumpAndSettle();
    expect(find.text('조금'), findsOneWidget);

    final wrong = find.byWidgetPredicate((widget) {
      final key = widget.key;
      return key is ValueKey<String> &&
          key.value.startsWith('choice-') &&
          key.value != 'choice-少し';
    }).first;
    await tester.tap(wrong);
    await tester.pumpAndSettle();
    expect(find.text('틀렸습니다'), findsOneWidget);
    expect(store.learnedIds, isEmpty);
  });

  testWidgets('assemble mode builds the word from tiles', (tester) async {
    final store = await pumpChapter(tester, mode: StudyMode.assemble);
    await tester.tap(find.byKey(const ValueKey('tab-1')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('少').first);
    await tester.pump();
    await tester.tap(find.text('し').first);
    await tester.pump();
    expect(find.text('少し'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('input-submit')));
    await tester.pumpAndSettle();
    expect(find.text('정답입니다!'), findsOneWidget);
    expect(store.learnedIds, {'c1'});
  });


  testWidgets('study mode can be changed from the mode chips', (tester) async {
    final store = await pumpChapter(tester);
    await tester.tap(find.byKey(const ValueKey('tab-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mode-assemble')));
    await tester.pumpAndSettle();
    expect(store.mode, StudyMode.assemble);
    expect(find.byKey(const ValueKey('input-submit')), findsOneWidget);
  });


  // 2026-09-29 자동 모드: 일본어 → (카드 뒤집기) → 한국어 순서로 읽고 다음 단어로 넘어간다.
  testWidgets('auto mode reads Japanese then Korean and moves on', (tester) async {
    final store = await pumpChapter(tester);
    await tester.tap(find.byKey(const ValueKey('tab-1')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('study-auto')));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(store.autoMode, isTrue);
    expect(spoken.take(2).toList(), ['ja:すこし', 'ko:조금']);

    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.pumpAndSettle();
    expect(spoken, [
      'ja:すこし', 'ko:조금',
      'ja:いま', 'ko:지금',
      'ja:たいへん', 'ko:몹시',
      'ja:いつも', 'ko:언제나',
    ]);
    expect(find.text('4 / 4'), findsOneWidget);

    // 수동으로 돌아가면 문제 풀기 화면이 나온다.
    await tester.tap(find.byKey(const ValueKey('study-manual')));
    await tester.pumpAndSettle();
    expect(store.autoMode, isFalse);
    expect(find.byKey(const ValueKey('mode-choice')), findsOneWidget);
  });

  testWidgets('auto mode can be paused and moved by hand', (tester) async {
    await pumpChapter(tester);
    await tester.tap(find.byKey(const ValueKey('tab-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('study-auto')));
    await tester.pump(const Duration(milliseconds: 5));

    await tester.tap(find.byKey(const ValueKey('auto-play'))); // 일시정지
    await tester.pumpAndSettle();
    final countAfterPause = spoken.length;
    await tester.pump(const Duration(seconds: 1));
    expect(spoken.length, countAfterPause);

    await tester.tap(find.byKey(const ValueKey('auto-next')));
    await tester.pumpAndSettle();
    expect(find.text('2 / 4'), findsOneWidget);
    expect(find.text('今'), findsOneWidget);
  });

  // 2026-10-24 저장된 오답 기록이 있는 단어만 골라 다시 학습하는 필터를 검증한다.
  testWidgets('wrong-only filter studies only saved wrong words', (tester) async {
    spoken.clear();
    SharedPreferences.setMockInitialValues({});
    final store = StudyStore(await SharedPreferences.getInstance());
    await store.recordRecall('c2', RecallRating.forgotten);
    final catalog = WordCatalog(chapterWords);
    await tester.pumpWidget(
      MaterialApp(
        home: ChapterPage(
          chapter: catalog.chaptersOf('N5', '부사').first,
          catalog: catalog,
          store: store,
          speakJapanese: (text) async => spoken.add('ja:$text'),
          random: Random(3),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tab-1')));
    await tester.pumpAndSettle();

    expect(find.text('✗ 틀린 단어만 (1)'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('wrong-only-filter')));
    await tester.pumpAndSettle();
    expect(find.text('1 / 1'), findsOneWidget);
    expect(find.text('지금'), findsOneWidget);

    // 2026-10-24 마지막 틀린 단어를 맞혀도 오답 기록에서 빠지기 전의 목록으로 결과를 끝까지 보여준다.
    await tester.tap(find.byKey(const ValueKey('choice-今')));
    await tester.pumpAndSettle();
    expect(find.text('정답입니다!'), findsOneWidget);
    expect(store.wrongIds, isEmpty);
    await tester.tap(find.byKey(const ValueKey('next-question')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('finish-score')), findsOneWidget);
  });

  testWidgets('wrong-only filter shows a message when nothing was missed', (tester) async {
    await pumpChapter(tester);
    await tester.tap(find.byKey(const ValueKey('tab-1')));
    await tester.pumpAndSettle();
    expect(find.text('✗ 틀린 단어만 (0)'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('wrong-only-filter')));
    await tester.pumpAndSettle();
    expect(find.textContaining('틀린 단어가 없습니다'), findsOneWidget);
  });

  // 2026-10-24 답한 뒤 모드를 바꿔도 같은 문제를 다시 풀어 점수가 중복 집계되지 않는다.
  testWidgets('changing mode after answering keeps the answered state', (tester) async {
    await pumpChapter(tester);
    await tester.tap(find.byKey(const ValueKey('tab-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('choice-少し')));
    await tester.pumpAndSettle();
    expect(find.text('정답입니다!'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('mode-assemble')));
    await tester.pumpAndSettle();
    expect(find.text('정답입니다!'), findsOneWidget);
    expect(find.byKey(const ValueKey('input-submit')), findsNothing);
  });
}
