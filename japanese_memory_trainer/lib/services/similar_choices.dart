import 'dart:math';

/// 2026-10-23 객관식 오답 보기를 정답과 닮은 순서로 고르는 공용 도구다.
/// 글자가 겹치고, 길이와 앞뒤 글자가 비슷할수록 헷갈리기 쉬운 보기로 본다.
class SimilarChoices {
  const SimilarChoices._();

  /// 2026-10-23 두 문자열이 얼마나 닮았는지 0~1 점수로 돌려준다.
  /// 겹치는 글자 비율 50%, 편집거리 30%, 첫 글자 일치 10%, 끝 글자 일치 10%로 합친다.
  static double textSimilarity(String a, String b) {
    final ra = a.trim().runes.toList(growable: false);
    final rb = b.trim().runes.toList(growable: false);
    if (ra.isEmpty || rb.isEmpty) return 0;
    final sa = ra.toSet();
    final sb = rb.toSet();
    final shared = sa.intersection(sb).length;
    final dice = 2 * shared / (sa.length + sb.length);
    final longest = max(ra.length, rb.length);
    final edit = 1 - _editDistance(ra, rb) / longest;
    final prefix = ra.first == rb.first ? 1.0 : 0.0;
    final suffix = ra.last == rb.last ? 1.0 : 0.0;
    return 0.5 * dice + 0.3 * edit + 0.1 * prefix + 0.1 * suffix;
  }

  /// 2026-10-23 일본어 단어는 표기(한자)와 읽기(히라가나) 둘 다 비슷할수록 헷갈리므로
  /// 표기 60%, 읽기 40%로 합쳐 점수를 낸다. 읽기가 비어 있으면 표기를 그대로 쓴다.
  static double japaneseSimilarity(
    String wordA,
    String readingA,
    String wordB,
    String readingB,
  ) {
    final ra = readingA.isEmpty ? wordA : readingA;
    final rb = readingB.isEmpty ? wordB : readingB;
    return 0.6 * textSimilarity(wordA, wordB) + 0.4 * textSimilarity(ra, rb);
  }

  /// 2026-10-23 정답과 겹치면 안 되는 후보(같은 단어·같은 뜻)를 빼고, 점수가 높은 후보
  /// 상위 `count * spread`개 안에서 무작위로 [count]개를 고른다. 같은 문제가 매번 같은 보기로
  /// 나오지 않도록 상위권 안에서만 섞는다. [spread]가 1이면 항상 점수 상위 [count]개다.
  static List<T> pick<T>({
    required T answer,
    required Iterable<T> candidates,
    required double Function(T answer, T candidate) score,
    required bool Function(T a, T b) clash,
    int count = 3,
    int spread = 2,
    Random? random,
  }) {
    if (count <= 0) return <T>[];
    final rnd = random ?? Random();
    final shuffled = candidates.toList()..shuffle(rnd);
    final scored = <({T item, double value})>[
      for (final item in shuffled)
        if (!clash(answer, item)) (item: item, value: score(answer, item)),
    ]..sort((a, b) => b.value.compareTo(a.value));

    final window = count * (spread < 1 ? 1 : spread);
    final top = <T>[];
    for (final entry in scored) {
      if (top.length >= window) break;
      if (top.any((chosen) => clash(chosen, entry.item))) continue;
      top.add(entry.item);
    }
    top.shuffle(rnd);
    return top.take(count).toList();
  }

  static int _editDistance(List<int> a, List<int> b) {
    var previous = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 1; i <= a.length; i++) {
      final current = List<int>.filled(b.length + 1, 0)..[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        current[j] = min(
          min(current[j - 1] + 1, previous[j] + 1),
          previous[j - 1] + cost,
        );
      }
      previous = current;
    }
    return previous[b.length];
  }
}
