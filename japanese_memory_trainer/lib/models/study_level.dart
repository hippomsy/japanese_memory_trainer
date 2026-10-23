/// 2026-09-27 학습 위치를 "JLPT 급수 + 급수 안의 레벨(1~10)"로 표현한다.
/// 각 급수의 단어를 빈도 순서대로 10등분해 레벨 1부터 차례로 공부한다.
class StudyLevel {
  const StudyLevel(this.grade, this.level);

  /// 2026-09-27 쉬운 급수부터 표시하는 순서다.
  static const List<String> grades = <String>['N5', 'N4', 'N3', 'N2', 'N1'];

  /// 2026-09-27 급수 하나를 나누는 레벨 수다.
  static const int levelsPerGrade = 10;

  /// 2026-09-27 저장된 설정이 없을 때 시작하는 위치다.
  static const StudyLevel initial = StudyLevel('N5', 1);

  final String grade;
  final int level;

  /// 2026-09-27 저장용 문자열("N5:3")로 변환한다.
  String encode() => '$grade:$level';

  /// 2026-09-27 저장 문자열을 읽는다. 형식이나 범위가 잘못되면 null을 돌려준다.
  static StudyLevel? decode(String? raw) {
    if (raw == null) return null;
    final parts = raw.split(':');
    if (parts.length != 2) return null;
    final grade = parts[0].trim().toUpperCase();
    final level = int.tryParse(parts[1].trim());
    if (!grades.contains(grade) || level == null) return null;
    if (level < 1 || level > levelsPerGrade) return null;
    return StudyLevel(grade, level);
  }

  /// 2026-09-27 화면에 보여줄 이름(예: "N5 · Lv.3")이다.
  String get label => '$grade · Lv.$level';

  @override
  bool operator ==(Object other) =>
      other is StudyLevel && other.grade == grade && other.level == level;

  @override
  int get hashCode => Object.hash(grade, level);
}

/// 2026-09-27 레벨 하나의 진행 상황(전체 단어 수, 한 번이라도 학습한 단어 수)이다.
class LevelProgressInfo {
  const LevelProgressInfo({
    required this.studyLevel,
    required this.total,
    required this.learned,
  });

  final StudyLevel studyLevel;
  final int total;
  final int learned;

  bool get isEmpty => total == 0;
  bool get isCompleted => total > 0 && learned >= total;
  double get ratio => total == 0 ? 0 : learned / total;
}
