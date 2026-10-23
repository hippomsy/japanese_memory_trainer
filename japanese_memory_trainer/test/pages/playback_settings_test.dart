// 2026-10-20 자동 재생 설정(단어/뜻 켜기, 회/초, 순서 변경) 검증
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kioku_japanese/data/study_store.dart';
import 'package:kioku_japanese/models/playback_settings.dart';
import 'package:kioku_japanese/models/vocabulary.dart';
import 'package:kioku_japanese/models/word_catalog.dart';
import 'package:kioku_japanese/pages/chapter_page.dart';
import 'package:kioku_japanese/pages/playback_settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

Vocabulary _word(int id, String japanese, String reading, String korean) =>
    Vocabulary(
      id: 'p$id',
      japanese: japanese,
      reading: reading,
      korean: korean,
      exampleJapanese: '$japanese。',
      exampleKorean: '예문',
      jlptLevel: 'N5',
      wordType: '부사',
      frequencyRank: id,
    );

final _words = [
  _word(1, '少し', 'すこし', '조금'),
  _word(2, '今', 'いま', '지금'),
];

void main() {
  test('settings round trip, clamp and broken data', () {
    const s = PlaybackSettings(wordRepeat: 3, meaningPause: 4, meaningFirst: true);
    final back = PlaybackSettings.fromJson(s.toJson());
    expect(back.wordRepeat, 3);
    expect(back.meaningPause, 4);
    expect(back.meaningFirst, isTrue);
    expect(back.order, [PlaybackItem.meaning, PlaybackItem.word]);
    expect(const PlaybackSettings().copyWith(wordRepeat: 99).wordRepeat,
        PlaybackSettings.maxRepeat);
    expect(PlaybackSettings.fromJson('{broken').isStandard, isTrue);
    expect(
        PlaybackSettings.fromJson(
                '{"wordOn":false,"meaningOn":false}')
            .isStandard,
        isTrue);
  });

  testWidgets('settings page changes count, unit, switch and order',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = StudyStore(await SharedPreferences.getInstance());
    await tester.pumpWidget(
        MaterialApp(home: PlaybackSettingsPage(store: store)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('playback-plus-word')));
    await tester.pumpAndSettle();
    expect(store.playback.wordRepeat, 2);

    // 회 → 초 로 바꾸고 + 를 누르면 쉬는 시간이 늘어난다.
    await tester.tap(find.byKey(const ValueKey('playback-unit-up-meaning')));
    await tester.pumpAndSettle();
    expect(find.text('초'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('playback-plus-meaning')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('playback-plus-meaning')));
    await tester.pumpAndSettle();
    expect(store.playback.meaningPause, 3);
    expect(store.playback.meaningRepeat, 1);

    // 단어를 끄면 뜻 스위치는 끌 수 없다.
    await tester.tap(find.byKey(const ValueKey('playback-switch-word')));
    await tester.pumpAndSettle();
    expect(store.playback.wordOn, isFalse);
    final meaningSwitch = tester.widget<Switch>(
        find.byKey(const ValueKey('playback-switch-meaning')));
    expect(meaningSwitch.onChanged, isNull);

    await tester.tap(find.byKey(const ValueKey('playback-swap-order')));
    await tester.pumpAndSettle();
    expect(store.playback.meaningFirst, isTrue);
  });

  testWidgets('auto mode follows order and repeat count', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = StudyStore(await SharedPreferences.getInstance());
    await store.setPlayback(const PlaybackSettings(
        meaningFirst: true, wordRepeat: 2, meaningRepeat: 1));
    final spoken = <String>[];
    final catalog = WordCatalog(_words);
    await tester.pumpWidget(MaterialApp(
      home: ChapterPage(
        chapter: catalog.chaptersOf('N5', '부사').first,
        catalog: catalog,
        store: store,
        speakJapanese: (t) async => spoken.add('ja:$t'),
        speakKorean: (t) async => spoken.add('ko:$t'),
        autoTiming: const AutoTiming(
          afterJapanese: Duration(milliseconds: 10),
          afterKorean: Duration(milliseconds: 10),
          flip: Duration(milliseconds: 10),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tab-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('study-auto')));
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.pumpAndSettle();
    expect(spoken, [
      'ko:조금', 'ja:すこし', 'ja:すこし',
      'ko:지금', 'ja:いま', 'ja:いま',
    ]);
    expect(find.byKey(const ValueKey('auto-settings')), findsOneWidget);
    await store.setAutoMode(false);
  });
}
