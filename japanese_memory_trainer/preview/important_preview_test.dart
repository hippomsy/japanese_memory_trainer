// 2026-10-19 중요 단어(★) 기능 미리보기 이미지를 만드는 개발용 테스트다(배포 앱에는 포함되지 않음).
// 실행: flutter test preview/important_preview_test.dart --update-goldens
// 결과: preview/out/27~32_important_*.png
import 'dart:io';
import 'dart:typed_data'; // ignore: unnecessary_import

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kioku_japanese/data/imported_words.dart';
import 'package:kioku_japanese/data/kanji_dictionary.dart';
import 'package:kioku_japanese/data/seed_words.dart';
import 'package:kioku_japanese/data/sentence_bank.dart';
import 'package:kioku_japanese/data/study_store.dart';
import 'package:kioku_japanese/models/vocabulary.dart';
import 'package:kioku_japanese/models/word_catalog.dart';
import 'package:kioku_japanese/pages/category_list_page.dart';
import 'package:kioku_japanese/pages/chapter_page.dart';
import 'package:kioku_japanese/pages/favorites_page.dart';
import 'package:kioku_japanese/pages/playback_settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _loadFont(String family, List<String> paths) async {
  final loader = FontLoader(family);
  var added = false;
  for (final path in paths) {
    final file = File(path);
    if (!file.existsSync()) continue;
    loader.addFont(Future<ByteData>.value(
        ByteData.view(Uint8List.fromList(file.readAsBytesSync()).buffer)));
    added = true;
  }
  if (added) await loader.load();
}

Future<void> _loadFonts() async {
  final dir = Directory.current.path;
  await _loadFont('Roboto', [
    '$dir/preview/fonts/PreviewCJK-Regular.otf',
    '$dir/preview/fonts/PreviewCJK-Bold.otf',
  ]);
  final flutterRoot = Platform.environment['FLUTTER_ROOT'] ?? '';
  await _loadFont('MaterialIcons', [
    '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  ]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('capture important words', (tester) async {
    await tester.runAsync(_loadFonts);
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final imported =
        await tester.runAsync(loadImportedWords) ?? const <Vocabulary>[];
    final words = <Vocabulary>[...seedWords, ...imported];
    final kanji = await tester.runAsync(KanjiDictionary.load);
    kanji!.attachWords(words);
    KanjiDictionary.instance = kanji;
    SentenceBank.instance = (await tester.runAsync(SentenceBank.load))!;

    final store = StudyStore(prefs);
    final catalog = WordCatalog(words);
    final chapter = catalog.chaptersOf('N5', '부사').first;
    // 챕터 단어 중 4개를 중요 단어로 표시하고, 다른 챕터 단어도 2개 표시한다.
    for (final i in [1, 3, 4, 7]) {
      if (i < chapter.words.length) await store.toggleFavorite(chapter.words[i].id);
    }
    final other = catalog.chaptersOf('N5', '명사').first.words;
    await store.toggleFavorite(other[0].id);
    await store.toggleFavorite(other[2].id);

    final theme = ThemeData(
        useMaterial3: true, scaffoldBackgroundColor: const Color(0xFFF7F1E3));
    Future<void> shot(String name) async {
      await tester.pumpAndSettle();
      await expectLater(
          find.byType(MaterialApp), matchesGoldenFile('out/$name.png'));
    }

    // 0) 챕터 목록: 챕터 카드 오른쪽 위 ★개수 배지
    await tester.pumpWidget(MaterialApp(
      key: UniqueKey(),
      theme: theme,
      home: ChapterListPage(
        grade: 'N5',
        category: '부사',
        catalog: catalog,
        store: store,
        speakJapanese: (_) async {},
      ),
    ));
    await shot('27_important_chapters');

    // 1) 챕터 단어 목록: 오른쪽 ★
    await tester.pumpWidget(MaterialApp(
      key: UniqueKey(),
      theme: theme,
      home: ChapterPage(
        chapter: chapter,
        catalog: catalog,
        store: store,
        speakJapanese: (_) async {},
      ),
    ));
    await shot('28_important_list');

    // 2) 학습 탭 → ★ 중요 단어만 켜고 4지선다
    await tester.tap(find.byKey(const ValueKey('tab-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mode-choice')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('important-only-filter')));
    await shot('29_important_choice');

    // 3) 글자 조합
    await tester.tap(find.byKey(const ValueKey('mode-assemble')));
    await shot('30_important_assemble');

    // 4) 전체 중요 단어 화면
    await tester.pumpWidget(MaterialApp(
      key: UniqueKey(),
      theme: theme,
      home: FavoritesPage(
        catalog: catalog,
        store: store,
        speakJapanese: (_) async {},
      ),
    ));
    await shot('31_important_all');

    // 5) 전체 중요 단어 학습 시작
    await tester.tap(find.byKey(const ValueKey('start-important-study')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mode-choice')));
    await shot('32_important_study');

    // 6) 2026-10-20 자동 재생 설정 화면(단어 2회, 뜻은 초 단위로 3초).
    await tester.pumpWidget(MaterialApp(
      key: UniqueKey(),
      theme: theme,
      home: PlaybackSettingsPage(store: store),
    ));
    await tester.pumpAndSettle();
    for (final k in ['playback-plus-word', 'playback-unit-up-meaning',
        'playback-plus-meaning', 'playback-plus-meaning']) {
      await tester.tap(find.byKey(ValueKey(k)));
      await tester.pumpAndSettle();
    }
    await shot('33_playback_settings');

    await store.setMode(StudyMode.choice);
  });
}
