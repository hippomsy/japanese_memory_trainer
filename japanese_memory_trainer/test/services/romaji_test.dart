import 'package:flutter_test/flutter_test.dart';
import 'package:kioku_japanese/services/romaji.dart';

/// 2026-09-27 로마자 → 히라가나 변환 검증
void main() {
  test('common words convert correctly', () {
    const cases = <String, String>{
      'sukoshi': 'すこし',
      'gakkou': 'がっこう',
      'konnichiha': 'こんにちは',
      'konnnichiha': 'こんにちは',
      'onna': 'おんな',
      'hon': 'ほん',
      'honn': 'ほん',
      'kyou': 'きょう',
      'shinbun': 'しんぶん',
      "kin'en": 'きんえん',
      'matcha': 'まっちゃ',
      'benkyou': 'べんきょう',
      'chotto': 'ちょっと',
      'ra-men': 'らーめん',
      'densha': 'でんしゃ',
      'SUKOSHI': 'すこし',
    };
    cases.forEach((input, expected) {
      expect(Romaji.toHiragana(input, finalize: true), expected, reason: input);
    });
  });

  test('kana and kanji are left untouched', () {
    expect(Romaji.toHiragana('学校', finalize: true), '学校');
    expect(Romaji.toHiragana('すこし', finalize: true), 'すこし');
  });

  test('unfinished input keeps trailing letters when not finalized', () {
    expect(Romaji.toHiragana('suk'), 'すk');
    expect(Romaji.toHiragana('hon'), 'ほn');
  });
}
