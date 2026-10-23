import 'package:flutter_test/flutter_test.dart';
import 'package:kioku_japanese/data/elementary_words.dart';
import 'package:kioku_japanese/data/kanji_dictionary.dart';
import 'package:kioku_japanese/models/word_catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('PDF vocabulary replaces JLPT groups and has readings and meanings',
      () async {
    final words = await loadElementaryWords();
    expect(words.length, 2328);
    expect(words.map((w) => w.id).toSet().length, words.length);
    expect(
        words.every((w) =>
            w.japanese.isNotEmpty &&
            w.reading.isNotEmpty &&
            w.korean.isNotEmpty),
        isTrue);
    final catalog = WordCatalog(words);
    expect(catalog.allWords.length, words.length);
    expect(catalog.availableGrades, WordCatalog.elementaryGrades);
    expect(catalog.wordsOfGrade('N4'), isEmpty);
    final dog = words.firstWhere((w) => w.japanese == '犬');
    expect(dog.reading, 'いぬ');
    expect(dog.korean, '개');
    final dictionary = await KanjiDictionary.load();
    expect(dictionary.lookup('犬')!.hunEum, '개 견');
    expect(dictionary.lookup('犬')!.onReadings, ['けん']);
  });
}
