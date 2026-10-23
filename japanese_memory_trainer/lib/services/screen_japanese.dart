import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 2026-10-06 스크린 일본어: 영화 대사로 배우는 회화.
/// 사용자 제공 강의 노트(스크린일본어1~3 PDF)를 문자 인식으로 받아 적어 정리한 데이터다.
/// 스크립트를 고치려면 `tool/screen/spec/`의 텍스트를 수정한 뒤
/// `python tool/screen/build_screen.py`를 실행한다.
const screenLessonsAsset = 'assets/screen/screen_lessons.json';

/// 키워드(또는 체크포인트 표현) 한 줄. [plain]은 같은 뜻의 표준어(체크포인트에만 있음).
class ScreenKeyword {
  const ScreenKeyword(this.japanese, this.korean, {this.plain = ''});
  final String japanese, korean, plain;
  factory ScreenKeyword.fromJson(Map<String, dynamic> j) => ScreenKeyword(
      j['ja'] as String, j['ko'] as String? ?? '',
      plain: j['plain'] as String? ?? '');
}

/// 대사 한 줄. 화자가 없으면 내레이션이다.
class ScreenLine {
  const ScreenLine(
      {required this.japanese,
      required this.korean,
      this.speaker = '',
      this.image = ''});
  final String speaker, japanese, korean;

  /// 2026-10-10 이 대사 바로 앞에 보여 줄 장면 그림 이름(없으면 '').
  final String image;
  factory ScreenLine.fromJson(Map<String, dynamic> j) => ScreenLine(
      speaker: j['sp'] as String? ?? '',
      japanese: j['ja'] as String,
      korean: j['ko'] as String? ?? '',
      image: j['img'] as String? ?? '');
}

/// 오늘의 복습(おさらい): 표현 + 뜻 + 예문.
class ScreenPattern {
  const ScreenPattern(
      {required this.pattern,
      required this.meaning,
      required this.japanese,
      required this.korean});
  final String pattern, meaning, japanese, korean;
  factory ScreenPattern.fromJson(Map<String, dynamic> j) => ScreenPattern(
      pattern: j['pattern'] as String,
      meaning: j['meaning'] as String? ?? '',
      japanese: j['ja'] as String? ?? '',
      korean: j['ko'] as String? ?? '');
}

/// 퀴즈: 한국어 문장을 보고 일본어로 바꾸기.
class ScreenQuiz {
  const ScreenQuiz(this.korean, this.japanese);
  final String korean, japanese;
  factory ScreenQuiz.fromJson(Map<String, dynamic> j) =>
      ScreenQuiz(j['ko'] as String, j['ja'] as String);
}

class ScreenLesson {
  const ScreenLesson(
      {required this.movieId,
      required this.number,
      required this.title,
      required this.summary,
      required this.keywords,
      required this.lines,
      required this.patterns,
      required this.quizzes,
      this.scene = ''});
  final String movieId;

  /// 2026-10-10 이 강의 대표 장면 그림 이름(assets/illustrations/<scene>.webp).
  final String scene;
  final int number;
  final String title, summary;
  final List<ScreenKeyword> keywords;
  final List<ScreenLine> lines;
  final List<ScreenPattern> patterns;
  final List<ScreenQuiz> quizzes;

  String get id => '$movieId-$number';
  String get label => '#${number.toString().padLeft(2, '0')}';

  factory ScreenLesson.fromJson(String movieId, Map<String, dynamic> j) =>
      ScreenLesson(
        movieId: movieId,
        number: j['no'] as int,
        title: j['title'] as String,
        summary: j['summary'] as String? ?? '',
        scene: j['scene'] as String? ?? '',
        keywords: [
          for (final k in (j['keywords'] as List<dynamic>? ?? const []))
            ScreenKeyword.fromJson(k as Map<String, dynamic>)
        ],
        lines: [
          for (final l in (j['script'] as List<dynamic>? ?? const []))
            ScreenLine.fromJson(l as Map<String, dynamic>)
        ],
        patterns: [
          for (final p in (j['review'] as List<dynamic>? ?? const []))
            ScreenPattern.fromJson(p as Map<String, dynamic>)
        ],
        quizzes: [
          for (final q in (j['quiz'] as List<dynamic>? ?? const []))
            ScreenQuiz.fromJson(q as Map<String, dynamic>)
        ],
      );
}

class ScreenMovie {
  const ScreenMovie(
      {required this.id,
      required this.volume,
      required this.title,
      required this.japaneseTitle,
      required this.year,
      required this.description,
      required this.lessons});
  final String id;
  final int volume;
  final String title, japaneseTitle, description;
  final int year;
  final List<ScreenLesson> lessons;

  factory ScreenMovie.fromJson(Map<String, dynamic> j) {
    final id = j['id'] as String;
    return ScreenMovie(
      id: id,
      volume: j['volume'] as int,
      title: j['title'] as String,
      japaneseTitle: j['ja_title'] as String? ?? '',
      year: j['year'] as int? ?? 0,
      description: j['description'] as String? ?? '',
      lessons: [
        for (final l in (j['lessons'] as List<dynamic>))
          ScreenLesson.fromJson(id, l as Map<String, dynamic>)
      ],
    );
  }

  static List<ScreenMovie>? _cache;

  /// 앱 번들의 JSON을 읽는다(한 번만 읽고 기억).
  static Future<List<ScreenMovie>> load([AssetBundle? bundle]) async {
    final cached = _cache;
    if (cached != null && bundle == null) return cached;
    final raw = await (bundle ?? rootBundle).loadString(screenLessonsAsset);
    final movies = parse(raw);
    if (bundle == null) _cache = movies;
    return movies;
  }

  static List<ScreenMovie> parse(String raw) {
    final data = jsonDecode(raw) as Map<String, dynamic>;
    return [
      for (final m in (data['movies'] as List<dynamic>))
        ScreenMovie.fromJson(m as Map<String, dynamic>)
    ];
  }
}

/// 2026-10-06 강의별 학습 완료 표시와 퀴즈 정답 확인 수를 기기에 저장한다.
class ScreenProgress {
  ScreenProgress(this._prefs);
  final SharedPreferences _prefs;
  static const _doneKey = 'screen_done_v1';
  static const _lastKey = 'screen_last_v1';

  Set<String> get done => (_prefs.getStringList(_doneKey) ?? const []).toSet();
  bool isDone(String lessonId) => done.contains(lessonId);
  int doneCount(ScreenMovie movie) =>
      movie.lessons.where((l) => done.contains(l.id)).length;

  Future<void> setDone(String lessonId, bool value) async {
    final set = done;
    value ? set.add(lessonId) : set.remove(lessonId);
    await _prefs.setStringList(_doneKey, set.toList()..sort());
  }

  /// 마지막으로 연 강의(이어 보기용).
  String? get lastLesson => _prefs.getString(_lastKey);
  Future<void> setLast(String lessonId) =>
      _prefs.setString(_lastKey, lessonId);
}
