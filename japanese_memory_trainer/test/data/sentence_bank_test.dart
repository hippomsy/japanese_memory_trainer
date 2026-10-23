import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kioku_japanese/data/imported_words.dart';
import 'package:kioku_japanese/data/seed_words.dart';
import 'package:kioku_japanese/data/sentence_bank.dart';
import 'package:kioku_japanese/models/vocabulary.dart';
import 'package:kioku_japanese/models/word_catalog.dart';

/// 2026-09-30 챕터별 문장 만들기 문제 데이터 검증
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every chapter has 5 sentence items built from its own words', () async {
    final bank = SentenceBank.parse(File(SentenceBank.assetPath).readAsStringSync());
    final imported = await loadImportedWords();
    final catalog = WordCatalog(<Vocabulary>[...seedWords, ...imported]);
    final problems = <String>[];
    var chapters = 0;
    for (final grade in WordCatalog.grades) {
      for (final category in catalog.categoriesOf(grade)) {
        for (final chapter in catalog.chaptersOf(grade, category)) {
          chapters++;
          final items = bank.forChapter(chapter);
          final ids = chapter.words.map((w) => w.id).toSet();
          if (items.length != 5) problems.add('${SentenceBank.keyOf(chapter)}: ${items.length} items');
          for (final item in items) {
            if (!ids.contains(item.wordId)) problems.add('${SentenceBank.keyOf(chapter)}: foreign ${item.wordId}');
            if (item.chunks.length < 3 || item.chunks.toSet().length != item.chunks.length) {
              problems.add('${SentenceBank.keyOf(chapter)}: bad chunks ${item.chunks}');
            }
          }
        }
      }
    }
    expect(chapters, bank.chapterCount);
    expect(problems, isEmpty);
  });
}
