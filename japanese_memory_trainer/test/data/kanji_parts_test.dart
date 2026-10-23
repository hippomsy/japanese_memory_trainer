import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kioku_japanese/data/kanji_parts.dart';

/// 2026-10-11 한자 부품(쪼개기) 사전 확인.
void main() {
  final bank = KanjiPartsBank.parse(
      File('assets/kanji/kanji_parts.json').readAsStringSync());

  test('休는 亻 + 木 으로 쪼개진다', () {
    final p = bank['休']!;
    expect(p.parts, ['亻', '木']);
    expect(p.strokeCount, 6);
    expect(p.isPhonoSemantic, isFalse);
    expect(bank.storyOf('休'), contains('나무'));
    expect(bank.nameOf('亻'), contains('사람'));
  });

  test('清은 소리 부품 青을 가진 형성자이고 같은 소리 가족이 있다', () {
    final p = bank['清']!;
    expect(p.phoneticPart, '青');
    expect(p.isPhonoSemantic, isTrue);
    expect(bank.soundFamily('清'), containsAll(['晴', '静']));
    expect(bank.soundFamily('清'), isNot(contains('清')));
  });

  test('모든 획 경로를 그릴 수 있다', () {
    var n = 0;
    for (final ch in ['休', '学', '語', '働', '鬱', '日']) {
      final p = bank[ch]!;
      expect(p.strokeParts.length, p.strokes.length);
      for (final d in p.strokes) {
        expect(parseSvgPath(d).getBounds().isEmpty, isFalse);
        n++;
      }
    }
    expect(n, greaterThan(40));
    expect(bank.length, greaterThan(2000));
  });
}
