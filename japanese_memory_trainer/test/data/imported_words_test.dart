import 'package:flutter_test/flutter_test.dart';
import 'package:kioku_japanese/data/imported_words.dart';

/// 2026-09-27 대량 수입한 JLPT 단어 JSON 자산이 실제로 올바르게 읽히는지 검증한다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('imported N5 word list loads with valid required fields', () async {
    final words = await loadImportedWords();

    expect(words, isNotEmpty);
    expect(words.length, greaterThanOrEqualTo(119));

    final ids = words.map((word) => word.id).toSet();
    expect(ids.length, words.length, reason: '단어 ID는 모두 유일해야 한다');

    for (final word in words) {
      expect(word.japanese, isNotEmpty, reason: '${word.id}: japanese 비어있음');
      expect(word.reading, isNotEmpty, reason: '${word.id}: reading 비어있음');
      expect(word.korean, isNotEmpty, reason: '${word.id}: korean 비어있음');
      expect(
        word.exampleJapanese,
        isNotEmpty,
        reason: '${word.id}: exampleJapanese 비어있음',
      );
      expect(
        word.exampleKorean,
        isNotEmpty,
        reason: '${word.id}: exampleKorean 비어있음',
      );

      final target = word.exampleTargetJapanese ?? word.japanese;
      expect(
        word.exampleJapanese.contains(target),
        isTrue,
        reason:
            '${word.id}: 예문 "${word.exampleJapanese}"에 "$target"이 포함돼야 빈칸 문제가 정상 동작함',
      );
    }
  });
}
