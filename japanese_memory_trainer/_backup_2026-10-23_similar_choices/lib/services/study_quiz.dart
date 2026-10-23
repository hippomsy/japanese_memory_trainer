import 'dart:math';

import 'package:kioku_japanese/models/vocabulary.dart';

/// 2026-09-27 챕터 학습 문제(4지선다 보기, 글자 조합 글자판)를 만들고 답을 채점한다.
class StudyQuiz {
  StudyQuiz({required List<Vocabulary> pool, Random? random})
      : _pool = pool,
        _random = random ?? Random();

  final List<Vocabulary> _pool;
  final Random _random;

  /// 2026-09-27 정답 1개 + 같은 품사를 우선한 오답 3개를 섞어 돌려준다.
  List<String> choicesFor(Vocabulary word, {int count = 4}) {
    final result = <String>[word.japanese];
    final sameType = _pool
        .where((other) => other.wordType == word.wordType)
        .map((other) => other.japanese)
        .toList()
      ..shuffle(_random);
    final others = _pool.map((other) => other.japanese).toList()..shuffle(_random);
    for (final candidate in [...sameType, ...others]) {
      if (result.length >= count) break;
      if (!result.contains(candidate)) result.add(candidate);
    }
    return result..shuffle(_random);
  }

  /// 2026-09-27 정답 글자를 모두 포함하고 나머지는 다른 단어 글자로 채운 글자판이다.
  /// 기본 20칸(5×4)이며, 정답 글자가 더 많으면 5칸 단위로 늘린다.
  List<String> tilesFor(Vocabulary word, {int size = 20}) {
    final needed = <String>[];
    for (final char in splitChars(word.japanese)) {
      if (!needed.contains(char)) needed.add(char);
    }
    var total = size;
    while (total < needed.length) {
      total += 5;
    }

    final tiles = <String>[...needed];
    final extras = <String>[
      for (final other in _pool)
        if (other.id != word.id) ...splitChars(other.japanese),
    ]..shuffle(_random);
    for (final char in extras) {
      if (tiles.length >= total) break;
      if (char.trim().isEmpty || tiles.contains(char)) continue;
      tiles.add(char);
    }
    const fallback = 'あいうえおかきくけこさしすせそたちつてとなにぬねのはひふへほまみむめもやゆよらりるれろわをん';
    for (final char in splitChars(fallback)) {
      if (tiles.length >= total) break;
      if (!tiles.contains(char)) tiles.add(char);
    }
    return tiles..shuffle(_random);
  }

  /// 2026-09-27 문자열을 글자(유니코드 코드포인트) 단위로 나눈다.
  static List<String> splitChars(String text) =>
      text.runes.map(String.fromCharCode).toList(growable: false);

  /// 2026-09-27 입력한 답이 단어 표기나 읽기와 같으면 정답이다.
  /// 공백은 무시하고, 가타카나로 입력해도 히라가나와 같게 본다.
  static bool isCorrect(Vocabulary word, String answer) {
    final input = normalize(answer);
    if (input.isEmpty) return false;
    final targets = <String>{
      normalize(word.japanese),
      for (final reading in word.reading.split(RegExp(r'[;；,、/]'))) normalize(reading),
    }..remove('');
    return targets.contains(input);
  }

  static String normalize(String value) {
    final buffer = StringBuffer();
    for (final rune in value.trim().runes) {
      if (rune == 0x20 || rune == 0x3000) continue;
      // 가타카나(ァ~ヶ)를 히라가나로 바꿔 비교한다.
      if (rune >= 0x30A1 && rune <= 0x30F6) {
        buffer.writeCharCode(rune - 0x60);
      } else {
        buffer.writeCharCode(rune);
      }
    }
    return buffer.toString();
  }
}
