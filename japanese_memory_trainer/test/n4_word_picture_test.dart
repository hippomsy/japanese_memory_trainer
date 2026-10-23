import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kioku_japanese/data/n4_word_icons.dart';
import 'package:kioku_japanese/services/n4_wordbook.dart';
import 'package:kioku_japanese/widgets/word_picture.dart';

/// 2026-10-21 N4 단어장 단어마다 그림이 있는지 확인.
void main() {
  final book = N4Wordbook.parse(File(n4WordbookAsset).readAsStringSync());

  test('every N4 word has its own picture', () {
    final ids = book.allWords.map((w) => w.id).toSet();
    final missing = ids.where((id) => !n4WordIcons.containsKey(id)).toList();
    expect(missing, isEmpty, reason: '그림 없는 단어: $missing');
    expect(n4WordIcons.keys.toSet().difference(ids), isEmpty);
  });

  // 2026-10-22 단어마다 뜻을 그린 일러스트 파일이 있어야 한다.
  test('every N4 word has its illustration file', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('assets/n4_word_images/'));
    final missing = [
      for (final w in book.allWords)
        if (!File(WordPicture.assetFor(w.id)).existsSync()) w.id
    ];
    expect(missing, isEmpty, reason: '그림 파일 없는 단어: $missing');
  });

  testWidgets('WordPicture shows the illustration image', (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: Center(child: WordPicture(wordId: 'd01_01', size: 120)))));
    expect(find.byKey(const ValueKey('word-picture-image-d01_01')), findsOneWidget);
    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as AssetImage).assetName, 'assets/n4_word_images/d01_01.webp');
  });
}
