import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kioku_japanese/data/kanji_dictionary.dart';
import 'package:kioku_japanese/data/imported_words.dart';
import 'package:kioku_japanese/data/seed_words.dart';
import 'package:kioku_japanese/models/vocabulary.dart';

/// 2026-09-29 한자 풀이 사전 검증
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  KanjiDictionary fromFile() {
    final map = jsonDecode(File(KanjiDictionary.assetPath).readAsStringSync()) as Map<String, dynamic>;
    return KanjiDictionary({
      for (final e in map.entries) e.key: KanjiInfo.fromJson(e.key, e.value as Map<String, dynamic>),
    });
  }

  test('every kanji used in the word lists has a 훈음 entry', () async {
    final dict = fromFile();
    final imported = await loadImportedWords();
    final words = <Vocabulary>[...seedWords, ...imported];
    final missing = <String>{};
    for (final w in words) {
      for (final ch in w.japanese.split('')) {
        if (!KanjiDictionary.isKanji(ch)) continue;
        final info = dict.lookup(ch);
        if (info == null || info.hun.isEmpty) missing.add(ch);
      }
    }
    expect(missing, isEmpty);
  });

  test('breakdown gives 훈음, readings and related words', () {
    final dict = fromFile();
    final gaku = dict.lookup('学')!;
    expect(gaku.hunEum, '배울 학');
    expect(gaku.koreanForm, '學');
    expect(gaku.onReadings, contains('ガク'));
    expect(dict.summary('学生'), '배울 학 · 날 생');
    expect(dict.breakdown('お土産').map((k) => k.kanji), ['土', '産']);

    Vocabulary w(String id, String jp, String level) => Vocabulary(
          id: id, japanese: jp, reading: '', korean: '뜻', exampleJapanese: '', exampleKorean: '',
          jlptLevel: level, wordType: '명사', frequencyRank: 1);
    dict.attachWords([w('a', '学生', 'N5'), w('b', '大学', 'N5'), w('c', '学問', 'N3')]);
    expect(dict.relatedWords('学', excludeId: 'a').map((v) => v.id), ['b', 'c']);
  });
}
