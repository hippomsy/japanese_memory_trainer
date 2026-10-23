// 2026-10-21 N4 단어장 단어 그림 미리보기 이미지를 만드는 개발용 테스트다(배포 앱에는 포함되지 않음).
// 실행: flutter test preview/word_picture_preview_test.dart --update-goldens
// 결과: preview/out/33~36_word_picture_*.png
import 'dart:io';
import 'dart:typed_data'; // ignore: unnecessary_import

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kioku_japanese/pages/n4_wordbook_pages.dart';
import 'package:kioku_japanese/services/n4_wordbook.dart';
import 'package:kioku_japanese/widgets/study_widgets.dart';
import 'package:kioku_japanese/widgets/word_picture.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/fakes/fake_lesson_audio.dart';

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

  testWidgets('capture word pictures', (tester) async {
    await tester.runAsync(_loadFonts);
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final progress = N4WordbookProgress(prefs);
    final book = N4Wordbook.parse(File(n4WordbookAsset).readAsStringSync());
    final theme = ThemeData(useMaterial3: true, scaffoldBackgroundColor: Washi.paper);

    // 2026-10-22 단어 그림(webp)을 미리 읽어 두어야 골든 이미지에 그림이 찍힌다.
    Future<void> precacheAll() async {
      await tester.runAsync(() async {
        for (final e in find.byType(Image).evaluate()) {
          await precacheImage((e.widget as Image).image, e);
        }
      });
    }

    Future<void> shot(String name) async {
      await tester.pumpAndSettle(const Duration(milliseconds: 400));
      await precacheAll();
      await tester.pumpAndSettle();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('out/$name.png'));
    }

    // 1) DAY 1 단어 목록
    final day = book.days.first;
    await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme,
        home: N4DayPage(
            book: book, day: day, progress: progress, audioFactory: FakeLessonAudio.new)));
    await shot('33_word_picture_list');

    // 2) 암기 카드(앞면 → 뒷면)
    await tester.tap(find.byKey(const ValueKey('n4-tab-cards')));
    await shot('34_word_picture_card');
    await tester.tap(find.byKey(const ValueKey('n4-flash-show')));
    await shot('35_word_picture_card_back');

    // 3) 여러 DAY 그림 모음(그림 확인용)
    final sample = [
      for (final d in [book.days[5], book.days[9], book.days[18], book.days[21]])
        ...d.words.take(8)
    ];
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: Scaffold(
        appBar: AppBar(title: const Text('단어 그림 모음 (DAY 6·10·19·22)')),
        body: GridView.count(
          padding: const EdgeInsets.all(12),
          crossAxisCount: 4,
          mainAxisSpacing: 10,
          crossAxisSpacing: 8,
          childAspectRatio: 0.78,
          children: [
            for (final w in sample)
              Column(children: [
                WordPicture(wordId: w.id, size: 64),
                const SizedBox(height: 4),
                Text(w.japanese,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(w.korean.split(',').first,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: Washi.inkSoft)),
              ]),
          ],
        ),
      ),
    ));
    await shot('36_word_picture_gallery');
  });
}
