/// 2026-09-26 일본어 단어 원본 데이터를 표현한다.
class Vocabulary {
  const Vocabulary({
    required this.id,
    required this.japanese,
    required this.reading,
    required this.korean,
    required this.exampleJapanese,
    required this.exampleKorean,
    required this.jlptLevel,
    required this.wordType,
    required this.frequencyRank,
    this.exampleTargetJapanese,
  });

  final String id;
  final String japanese;
  final String reading;
  final String korean;
  final String exampleJapanese;
  final String exampleKorean;
  final String jlptLevel;
  final String wordType;
  final int frequencyRank;

  /// 2026-09-26 예문에서 빈칸으로 가릴 실제 활용형이다. 없으면 기본형을 그대로 사용한다.
  final String? exampleTargetJapanese;

  /// 2026-09-26 단어 ID와 같은 이름의 로컬 학습 이미지를 사용한다. 이미지가 번들에 없는
  /// 단어(대량 수입된 JLPT 단어 등)는 WordCard의 errorBuilder가 대체 아이콘을 보여준다.
  String get imageAsset => 'assets/word_images/$id.png';

  /// 2026-09-27 JLPT 공개 단어 목록(assets/data/*.json)에서 대량으로 불러온 단어를
  /// 이 모델로 변환한다. 필수 필드가 비어 있으면 예외를 던져 데이터 결함을 빌드 시점에 잡는다.
  factory Vocabulary.fromJson(Map<String, dynamic> json) {
    return Vocabulary(
      id: json['id'] as String,
      japanese: json['japanese'] as String,
      reading: json['reading'] as String,
      korean: json['korean'] as String,
      exampleJapanese: json['exampleJapanese'] as String,
      exampleKorean: json['exampleKorean'] as String,
      jlptLevel: json['jlptLevel'] as String,
      wordType: json['wordType'] as String,
      frequencyRank: json['frequencyRank'] as int,
      exampleTargetJapanese: json['exampleTargetJapanese'] as String?,
    );
  }
}
