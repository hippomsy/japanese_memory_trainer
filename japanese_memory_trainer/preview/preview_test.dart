// 2026-09-27 앱 화면 미리보기 이미지를 만드는 개발용 테스트다(배포 앱에는 포함되지 않음).
// 실행: flutter test preview/preview_test.dart --update-goldens
// 결과: preview/out/*.png
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kioku_japanese/app.dart';
import 'package:kioku_japanese/data/imported_words.dart';
import 'package:kioku_japanese/data/kanji_dictionary.dart';
import 'package:kioku_japanese/data/sentence_bank.dart';
import 'package:kioku_japanese/pages/chapter_page.dart';
import 'package:kioku_japanese/pages/news_pages.dart';
import 'package:kioku_japanese/services/news_service.dart';
import 'package:kioku_japanese/services/daily_reading_service.dart';
import 'package:kioku_japanese/data/seed_words.dart';
import 'package:kioku_japanese/data/study_store.dart';
import 'package:kioku_japanese/models/vocabulary.dart';
import 'package:kioku_japanese/models/word_catalog.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _loadFont(String family, List<String> paths) async {
  final loader = FontLoader(family);
  var added = false;
  for (final path in paths) {
    final file = File(path);
    if (!file.existsSync()) continue;
    final bytes = file.readAsBytesSync();
    loader.addFont(Future<ByteData>.value(
        ByteData.view(Uint8List.fromList(bytes).buffer)));
    added = true;
  }
  if (added) await loader.load();
}

Future<void> _loadFonts() async {
  // 앱 기본 글꼴(Roboto) 자리에 한국어·일본어가 모두 있는 Noto Sans CJK를 넣어 실제 폰처럼 보이게 한다.
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

  testWidgets('capture Haru Play Store assets', (tester) async {
    await tester.runAsync(_loadFonts);
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final imported = await tester.runAsync(loadImportedWords) ?? <Vocabulary>[];
    final words = [...seedWords, ...imported];
    Future<void> storeShot(String name) async {
      await tester.pumpAndSettle();
      await expectLater(find.byType(MaterialApp),
          matchesGoldenFile('../store_assets/$name.png'));
    }

    await tester.pumpWidget(KiokuJapaneseApp(
        preferences: prefs, seed: words, speakJapanese: (_) async {}));
    await storeShot('01_today');
    await tester.tap(find.text('학습').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('category-listening')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('category-listening')));
    await storeShot('02_listening');
    await tester.tap(find.text('이어서 듣기'));
    await storeShot('03_listen_first');
    await tester.tap(find.byKey(const ValueKey('play-listening')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('listening-answer-2')), 160,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byKey(const ValueKey('listening-answer-2')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('listening-feedback')), 160,
        scrollable: find.byType(Scrollable).first);
    await storeShot('04_listening_review');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack(); // 2026-10-06 청해 목록도 학습 탭에서 연 화면이다.
    await tester.pumpAndSettle();
    await tester.tap(find.text('학습').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('category-words')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('category-words')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('grade-N4')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('grade-N4')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('category-명사')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('chapter-1')));
    await storeShot('05_vocabulary');
    final reading = DailyReadingService(prefs, NewsLexicon.fromWords(words),
        clock: () => DateTime(2026, 10, 4, 8));
    final diary = (await tester.runAsync(reading.diaries))!.first;
    await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true),
        home: NewsArticlePage(article: diary, speakJapanese: (_) async {})));
    await storeShot('06_diary');

    // Original marketing layout at Google's exact feature-graphic dimensions.
    tester.view.physicalSize = const Size(1024, 500);
    tester.view.devicePixelRatio = 1;
    final bannerIcon = await tester.runAsync(() async {
      final codec = await ui.instantiateImageCodec(
          File('store_assets/app_icon_512.png').readAsBytesSync());
      final frame = await codec.getNextFrame();
      codec.dispose();
      return frame.image;
    });
    await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
            backgroundColor: const Color(0xFF1F2A44),
            body: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 64, vertical: 54),
                child: Row(children: [
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                        const Text('하루 일본어',
                            style: TextStyle(
                                fontSize: 58,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFFFF9EE))),
                        const SizedBox(height: 18),
                        const Text('조금씩 듣고,\n오래 기억해요.',
                            style: TextStyle(
                                fontSize: 31,
                                height: 1.45,
                                color: Color(0xFFFFF9EE))),
                        const SizedBox(height: 30),
                        Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 10),
                            decoration: BoxDecoration(
                                color: const Color(0xFFC8412E),
                                borderRadius: BorderRadius.circular(12)),
                              child: const Text('단어 · N4 청해 · 하루의 일기',
                                style: TextStyle(
                                    fontSize: 19,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600))),
                      ])),
                  const SizedBox(width: 32),
                  SizedBox(
                      width: 320,
                      height: 320,
                      child: RawImage(image: bannerIcon)),
                ])))));
    await storeShot('feature_graphic_haru_1024x500');
  });

  testWidgets('capture new dashboard and N4 listening', (tester) async {
    await tester.runAsync(_loadFonts);
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final imported = await tester.runAsync(loadImportedWords) ?? <Vocabulary>[];
    await tester.pumpWidget(KiokuJapaneseApp(
        preferences: prefs,
        seed: [...seedWords, ...imported],
        speakJapanese: (_) async {}));
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('out/23_today_dashboard.png'));
    await tester.tap(find.text('학습').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('category-listening')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('category-listening')));
    await tester.pumpAndSettle();
    await expectLater(
        find.byType(MaterialApp), matchesGoldenFile('out/24_n4_listening.png'));
    await tester.tap(find.text('이어서 듣기'));
    await tester.pumpAndSettle();
    await expectLater(
        find.byType(MaterialApp), matchesGoldenFile('out/25_listen_first.png'));
    await tester.tap(find.byKey(const ValueKey('play-listening')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('listening-answer-2')), 180,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byKey(const ValueKey('listening-answer-2')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('listening-feedback')), 160,
        scrollable: find.byType(Scrollable).first);
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('out/26_listening_review.png'));
  });

  testWidgets('capture haru reading', (tester) async {
    await tester.runAsync(_loadFonts);
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final imported =
        await tester.runAsync(loadImportedWords) ?? const <Vocabulary>[];
    final reading = DailyReadingService(
        prefs, NewsLexicon.fromWords([...seedWords, ...imported]),
        clock: () => DateTime(2026, 10, 4, 8));
    final diary = (await tester.runAsync(reading.diaries))!.first;
    await tester.pumpWidget(MaterialApp(
        theme: ThemeData(
            useMaterial3: true, colorSchemeSeed: const Color(0xFF26354A)),
        debugShowCheckedModeBanner: false,
        home: NewsArticlePage(article: diary, speakJapanese: (_) async {})));
    await tester.pumpAndSettle();
    await expectLater(
        find.byType(MaterialApp), matchesGoldenFile('out/19_haru_diary.png'));
    final token = diary.paragraphs
        .expand((p) => p.tokens)
        .firstWhere((t) => t.meaning.isNotEmpty);
    await tester.tap(find.text(token.parts.first.$1).first);
    await tester.pumpAndSettle();
    await expectLater(
        find.byType(MaterialApp), matchesGoldenFile('out/20_reading_word.png'));
    Navigator.of(tester.element(find.text(token.meaning))).pop();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('reading-answer-0')), 250,
        scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(
        find.byKey(ValueKey('reading-answer-${diary.question!.answer}')));
    await tester.pumpAndSettle();
    await tester
        .tap(find.byKey(ValueKey('reading-answer-${diary.question!.answer}')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('reading-feedback')), 250,
        scrollable: find.byType(Scrollable).first);
    await expectLater(
        find.byType(MaterialApp), matchesGoldenFile('out/21_reading_quiz.png'));
  });

  testWidgets('capture preview screens', (tester) async {
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

    // 진행 막대가 보이도록 N5 일부 단어를 학습 완료로 표시해 둔다.
    final store = StudyStore(prefs);
    final catalog = WordCatalog(words);
    for (final word in catalog.wordsOfGrade('N5').take(142)) {
      await store.markLearned(word.id);
    }
    final firstAdverbs = catalog.chaptersOf('N5', '부사').first.words;
    await store.toggleFavorite(firstAdverbs[1].id);

    await tester.pumpWidget(
      KiokuJapaneseApp(
        preferences: prefs,
        seed: words,
        speakJapanese: (_) async {},
      ),
    );
    await tester.pumpAndSettle();

    Future<void> shot(String name) async {
      await tester.pumpAndSettle();
      await expectLater(
          find.byType(MaterialApp), matchesGoldenFile('out/$name.png'));
    }

    await shot('01_home');

    await tester.tap(find.text('학습').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('category-words')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('category-words')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const ValueKey('grade-N5')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('grade-N5')));
    await shot('02_grade_N5');

    await tester.tap(find.byKey(const ValueKey('category-부사')));
    await shot('03_chapters');

    await tester.tap(find.byKey(const ValueKey('chapter-1')));
    await shot('04_chapter_list');

    await tester.tap(find.byKey(const ValueKey('tab-1')));
    await shot('05_study_choice');

    await tester.tap(find.byKey(const ValueKey('mode-assemble')));
    await shot('06_study_assemble');

    await tester.tap(find.byKey(const ValueKey('mode-choice')));
    await tester.pumpAndSettle();
    await tester
        .tap(find.byKey(ValueKey('choice-${firstAdverbs.first.japanese}')));
    await shot('07_study_feedback');

    // 2026-09-30 문장 만들기: 첫 화면, 조각 두 개를 놓은 모습, 채점 결과.
    await tester.tap(find.byKey(const ValueKey('next-question')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mode-sentence')));
    await shot('12_sentence');
    final firstItem = SentenceBank.instance
        .forChapter(catalog.chaptersOf('N5', '부사').first)
        .first;
    for (var i = 0; i < firstItem.chunks.length; i++) {
      await tester.tap(find.byKey(ValueKey('sentence-chunk-$i')));
      await tester.pump();
      if (i == 1) await shot('13_sentence_building');
    }
    await tester.tap(find.byKey(const ValueKey('sentence-check')));
    await shot('14_sentence_feedback');
    await tester.tap(find.byKey(const ValueKey('mode-choice')));
    await tester.pumpAndSettle();

    // 2026-09-29 자동 모드: 앞면(일본어)과 뒤집힌 뒷면(한국어)을 찍는다.
    // 자동 재생이 계속 진행되므로 pumpAndSettle 대신 정해진 시간만큼만 진행한다.
    Future<void> rawShot(String name) async {
      await expectLater(
          find.byType(MaterialApp), matchesGoldenFile('out/$name.png'));
    }

    await tester.tap(find.byKey(const ValueKey('study-auto')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    await rawShot('08_auto_front');
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    await rawShot('09_auto_back');
    await tester.tap(find.byKey(const ValueKey('auto-play'))); // 일시정지
    await tester.pumpAndSettle();
    await store.setAutoMode(false);

    // 다음 실행에서 기본 방식이 4지선다가 되도록 되돌린다.
    await store.setMode(StudyMode.choice);
  });

  // 2026-09-29 명사 챕터의 단어 목록에서 한자 풀이를 펼친 모습.
  testWidgets('capture kanji breakdown', (tester) async {
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
    final catalog = WordCatalog(words);
    final chapter = catalog.chaptersOf('N5', '명사').first;
    final target = chapter.words.firstWhere(
        (w) => kanji.breakdown(w.japanese).length >= 2,
        orElse: () => chapter.words.first);
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(
          useMaterial3: true, scaffoldBackgroundColor: const Color(0xFFF7F1E3)),
      home: ChapterPage(
        chapter: chapter,
        catalog: catalog,
        store: StudyStore(prefs),
        speakJapanese: (_) async {},
      ),
    ));
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('out/10_kanji_summary.png'));
    await tester.ensureVisible(find.byKey(ValueKey('row-${target.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(target.japanese).first);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    await expectLater(
        find.byType(MaterialApp), matchesGoldenFile('out/11_kanji_detail.png'));
  });

  // 2026-10-01 쉬운 뉴스: 목록, 기사 위쪽, 핵심 단어.
  testWidgets('capture news', (tester) async {
    await tester.runAsync(_loadFonts);
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final articles = parseNewsFeed(
        File('test/fixtures/news_sample.json').readAsStringSync());
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(
          useMaterial3: true, scaffoldBackgroundColor: const Color(0xFFF7F1E3)),
      home: NewsListPage(
          repository: NewsRepository(prefs, bundled: articles),
          speakJapanese: (_) async {}),
    ));
    await tester.pumpAndSettle();
    await expectLater(
        find.byType(MaterialApp), matchesGoldenFile('out/15_news_list.png'));
    await tester.tap(find.byKey(ValueKey('news-${articles.last.id}')));
    await tester.pumpAndSettle();
    await expectLater(
        find.byType(MaterialApp), matchesGoldenFile('out/16_news_article.png'));
    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pumpAndSettle();
    await expectLater(
        find.byType(MaterialApp), matchesGoldenFile('out/17_news_body.png'));
    await tester.drag(find.byType(ListView), const Offset(0, -3000));
    await tester.pumpAndSettle();
    await expectLater(
        find.byType(MaterialApp), matchesGoldenFile('out/18_news_words.png'));
  });
}
