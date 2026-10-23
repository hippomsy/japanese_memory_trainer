import 'package:kioku_japanese/models/vocabulary.dart';

/// 2026-09-27 급수 → 품사 → 챕터(14단어) 구조로 단어를 묶는다.
class Chapter {
  const Chapter({
    required this.grade,
    required this.category,
    required this.number,
    required this.words,
  });

  final String grade;
  final String category;
  final int number;
  final List<Vocabulary> words;

  /// 2026-09-27 화면 제목용 이름(예: "N5 · 副詞 · 第1章")이다.
  String get title =>
      '$grade · ${WordCatalog.categoryLabel(category)} · 第$number章';
}

/// 2026-09-27 전체 단어를 급수·품사·챕터로 한 번만 나눠 두고 화면에서 꺼내 쓴다.
class WordCatalog {
  WordCatalog(List<Vocabulary> words, {this.chapterSize = 14}) {
    for (final word in words) {
      final grade = word.jlptLevel.trim().toUpperCase();
      if (!grades.contains(grade) && !elementaryGrades.contains(grade)) {
        continue;
      }
      final category =
          word.wordType.trim().isEmpty ? '기타' : word.wordType.trim();
      _byGrade.putIfAbsent(grade, () => <String, List<Vocabulary>>{});
      _byGrade[grade]!.putIfAbsent(category, () => <Vocabulary>[]).add(word);
      _all.add(word);
    }
  }

  /// 2026-09-27 첫 화면에 보여줄 급수 순서(어려운 급수부터)다.
  static const List<String> grades = <String>['N1', 'N2', 'N3', 'N4', 'N5'];
  static const elementaryGrades = ['1학년', '2학년', '3학년', '4학년', '5학년', '6학년'];
  List<String> get availableGrades => [
        ...elementaryGrades.where(_byGrade.containsKey),
        ...grades.reversed.where(_byGrade.containsKey),
      ];

  /// 2026-09-27 품사 표시 순서다. 목록에 없는 품사는 뒤에 붙는다.
  static const List<String> categoryOrder = <String>[
    '명사',
    '동사',
    '형용사',
    '형용동사',
    '부사',
    '기타',
  ];

  static const Map<String, String> _labels = <String, String>{
    '명사': '名詞',
    '동사': '動詞',
    '형용사': '形容詞',
    '형용동사': '形容動詞',
    '부사': '副詞',
    '기타': 'その他',
  };

  /// 2026-09-27 품사 이름을 일본어 표기(名詞, 動詞 …)로 바꾼다.
  static String categoryLabel(String category) => _labels[category] ?? category;

  /// 2026-09-27 품사의 한국어 이름(명사, 동사 …)이다.
  static String categoryKorean(String category) => category;

  final int chapterSize;
  final Map<String, Map<String, List<Vocabulary>>> _byGrade =
      <String, Map<String, List<Vocabulary>>>{};
  final List<Vocabulary> _all = <Vocabulary>[];

  List<Vocabulary> get allWords => List<Vocabulary>.unmodifiable(_all);

  /// 2026-09-27 한 급수의 모든 단어다.
  List<Vocabulary> wordsOfGrade(String grade) => [
        for (final words
            in (_byGrade[grade]?.values ?? const <List<Vocabulary>>[]))
          ...words,
      ];

  /// 2026-09-27 한 급수 안에 단어가 있는 품사 목록(정해진 순서)이다.
  List<String> categoriesOf(String grade) {
    final present = _byGrade[grade]?.keys.toList() ?? const <String>[];
    return [
      ...categoryOrder.where(present.contains),
      ...present.where((category) => !categoryOrder.contains(category)),
    ];
  }

  /// 2026-09-27 한 품사의 단어 목록이다.
  List<Vocabulary> wordsOf(String grade, String category) =>
      List<Vocabulary>.unmodifiable(
          _byGrade[grade]?[category] ?? const <Vocabulary>[]);

  /// 2026-09-27 한 품사의 단어를 chapterSize개씩 챕터로 나눈다.
  List<Chapter> chaptersOf(String grade, String category) {
    final words = wordsOf(grade, category);
    final chapters = <Chapter>[];
    for (var start = 0; start < words.length; start += chapterSize) {
      final end = (start + chapterSize) > words.length
          ? words.length
          : start + chapterSize;
      chapters.add(
        Chapter(
          grade: grade,
          category: category,
          number: chapters.length + 1,
          words: words.sublist(start, end),
        ),
      );
    }
    return chapters;
  }
}
