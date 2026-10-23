import 'dart:convert';
import 'package:kioku_japanese/models/playback_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum RecallRating { remembered, unsure, forgotten }

enum RecallAspect { meaning, reading, listening, kanji }

extension RecallAspectLabel on RecallAspect {
  String get label => switch (this) {
        RecallAspect.meaning => '뜻 떠올리기',
        RecallAspect.reading => '한자 보고 발음하기',
        RecallAspect.listening => '듣고 뜻 떠올리기',
        RecallAspect.kanji => '한자 뜻 떠올리기',
      };
}

/// 2026-09-27 챕터 학습 방식이다. 학습 화면 아래 "학습선택"으로 바꾼다.
/// 2026-09-29 직접 입력 방식은 요청에 따라 삭제했다(예전에 저장된 값은 4지선다로 처리).
enum StudyMode { choice, assemble, sentence }

extension StudyModeLabel on StudyMode {
  String get label {
    switch (this) {
      case StudyMode.choice:
        return '4지선다';
      case StudyMode.assemble:
        return '글자 조합';
      case StudyMode.sentence:
        return '문장 만들기';
    }
  }

  String get description {
    switch (this) {
      case StudyMode.choice:
        return '뜻을 보고 알맞은 일본어 단어를 4개 중에서 고릅니다.';
      case StudyMode.assemble:
        return '글자판의 한자·가나를 눌러 단어를 완성합니다.';
      case StudyMode.sentence:
        return '챕터 단어로 만든 문장 조각을 순서대로 늘어놓습니다(챕터마다 5문제).';
    }
  }
}

/// 2026-09-27 학습한 단어, 즐겨찾기, 학습 방식, 목록 보기 방식을 기기에 저장한다.
class StudyStore {
  StudyStore(this._preferences);

  static const String learnedKey = 'study_learned_ids_v1';
  static const String favoriteKey = 'study_favorite_ids_v1';
  static const String modeKey = 'study_mode_v1';
  static const String compactKey = 'study_compact_list_v1';
  static const String autoKey = 'study_auto_mode_v1';

  final SharedPreferences _preferences;

  static const reviewKey = 'study_review_schedule_v1';
  static const aspectKey = 'study_recall_aspects_v1';

  Map<String, dynamic> get _aspects {
    try {
      return jsonDecode(_preferences.getString(aspectKey) ?? '{}')
          as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  DateTime aspectDueAt(String id, RecallAspect aspect) =>
      DateTime.tryParse(_aspects[id]?[aspect.name]?['due'] as String? ?? '') ??
      DateTime(2000);

  bool aspectWeak(String id, RecallAspect aspect) =>
      _aspects[id]?[aspect.name]?['weak'] == true;

  Future<void> recordAspect(String id, RecallAspect aspect, RecallRating rating,
      {DateTime? now}) async {
    final time = now ?? DateTime.now();
    final all = _aspects;
    final entries = Map<String, dynamic>.from(all[id] as Map? ?? {});
    final previous = entries[aspect.name]?['days'] as int? ?? 0;
    final days = rating == RecallRating.remembered
        ? (previous == 0 ? 1 : (previous * 2).clamp(1, 60))
        : rating == RecallRating.unsure
            ? 1
            : 0;
    entries[aspect.name] = {
      'days': days,
      'due': time
          .add(days == 0 ? const Duration(minutes: 10) : Duration(days: days))
          .toIso8601String(),
      'weak': rating != RecallRating.remembered,
    };
    all[id] = entries;
    if (!await _preferences.setString(aspectKey, jsonEncode(all))) {
      throw StateError('기억 상태를 저장하지 못했습니다.');
    }
    final dates = entries.values
        .map((e) => DateTime.parse(e['due'] as String))
        .toList()
      ..sort();
    final reviews = _reviews;
    reviews[id] = {
      'days': days,
      'due': dates.first.toIso8601String(),
      'wrong': entries.values.any((e) => e['weak'] == true)
    };
    if (!await _preferences.setString(reviewKey, jsonEncode(reviews))) {
      throw StateError('복습 일정을 저장하지 못했습니다.');
    }
    if (rating == RecallRating.remembered) await markLearned(id);
  }

  Map<String, dynamic> get _reviews {
    try {
      return jsonDecode(_preferences.getString(reviewKey) ?? '{}')
          as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  Set<String> get wrongIds => _reviews.entries
      .where((entry) => entry.value['wrong'] == true)
      .map((entry) => entry.key)
      .toSet();

  Set<String> dueIds({DateTime? now}) {
    final reviews = _reviews;
    final time = now ?? DateTime.now();
    return {...learnedIds, ...reviews.keys}.where((id) {
      final due = DateTime.tryParse(reviews[id]?['due'] as String? ?? '') ??
          DateTime(2000);
      return !due.isAfter(time);
    }).toSet();
  }

  DateTime dueAt(String id) {
    final value = _reviews[id];
    return DateTime.tryParse(value?['due'] as String? ?? '') ?? DateTime(2000);
  }

  bool isDue(String id, {DateTime? now}) =>
      (learnedIds.contains(id) || _reviews.containsKey(id)) &&
      !dueAt(id).isAfter(now ?? DateTime.now());

  /// 2026-09-30 기억 상태에 따라 복습 간격을 조절하며 오답을 영구 저장한다.
  Future<void> recordRecall(String id, RecallRating rating,
      {DateTime? now}) async {
    final reviews = _reviews;
    final previous = (reviews[id]?['days'] as int?) ?? 0;
    final days = switch (rating) {
      RecallRating.remembered =>
        previous == 0 ? 1 : (previous * 2).clamp(1, 60),
      RecallRating.unsure => 1,
      RecallRating.forgotten => 0,
    };
    final delay = rating == RecallRating.forgotten
        ? const Duration(minutes: 10)
        : Duration(days: days);
    reviews[id] = {
      'days': days,
      'due': (now ?? DateTime.now()).add(delay).toIso8601String(),
      'wrong': rating != RecallRating.remembered,
    };
    final aspects = _aspects[id] as Map?;
    if (aspects != null && aspects.isNotEmpty) {
      final dates = aspects.values
          .map((e) => DateTime.parse(e['due'] as String))
          .toList()
        ..sort();
      if (dates.first.isBefore(DateTime.parse(reviews[id]['due'] as String))) {
        reviews[id]['due'] = dates.first.toIso8601String();
      }
      reviews[id]['wrong'] = reviews[id]['wrong'] == true ||
          aspects.values.any((e) => e['weak'] == true);
    }
    if (!await _preferences.setString(reviewKey, jsonEncode(reviews))) {
      throw StateError('복습 기록을 저장하지 못했습니다.');
    }
    if (rating == RecallRating.remembered) await markLearned(id);
  }

  /// 2026-09-27 한 번이라도 맞힌(학습 완료) 단어 ID 목록이다.
  Set<String> get learnedIds =>
      (_preferences.getStringList(learnedKey) ?? const <String>[]).toSet();

  /// 2026-09-27 별표(즐겨찾기)한 단어 ID 목록이다.
  Set<String> get favoriteIds =>
      (_preferences.getStringList(favoriteKey) ?? const <String>[]).toSet();

  bool isLearned(String wordId) => learnedIds.contains(wordId);

  bool isFavorite(String wordId) => favoriteIds.contains(wordId);

  /// 2026-09-27 단어를 학습 완료로 기록한다.
  Future<void> markLearned(String wordId) async {
    final ids = learnedIds;
    if (!ids.add(wordId)) return;
    await _preferences.setStringList(learnedKey, ids.toList()..sort());
  }

  /// 2026-09-27 챕터 "초기화": 주어진 단어들의 학습 기록을 지운다.
  Future<void> resetLearned(Iterable<String> wordIds) async {
    final removed = wordIds.toSet();
    final ids = learnedIds..removeAll(removed);
    await _preferences.setStringList(learnedKey, ids.toList()..sort());
    final reviews = _reviews..removeWhere((id, _) => removed.contains(id));
    await _preferences.setString(reviewKey, jsonEncode(reviews));
    final aspects = _aspects..removeWhere((id, _) => removed.contains(id));
    await _preferences.setString(aspectKey, jsonEncode(aspects));
  }

  /// 2026-09-27 즐겨찾기를 켜고 끈다. 바뀐 뒤의 상태를 돌려준다.
  Future<bool> toggleFavorite(String wordId) async {
    final ids = favoriteIds;
    final nowFavorite = !ids.remove(wordId);
    if (nowFavorite) ids.add(wordId);
    await _preferences.setStringList(favoriteKey, ids.toList()..sort());
    return nowFavorite;
  }

  /// 2026-09-27 마지막으로 고른 학습 방식이다. 처음에는 4지선다다.
  StudyMode get mode {
    final saved = _preferences.getString(modeKey);
    return StudyMode.values.firstWhere(
      (mode) => mode.name == saved,
      orElse: () => StudyMode.choice,
    );
  }

  Future<void> setMode(StudyMode mode) async {
    await _preferences.setString(modeKey, mode.name);
  }

  /// 2026-09-27 목록 탭을 작게(뜻까지 한 줄에) 볼지 여부다.
  bool get compactList => _preferences.getBool(compactKey) ?? false;

  Future<void> setCompactList(bool value) async {
    await _preferences.setBool(compactKey, value);
  }

  /// 2026-09-29 학습 탭을 자동 모드(단어 카드를 자동으로 넘기며 읽어 줌)로 볼지 여부다.
  /// 기본은 수동(문제 풀기).
  bool get autoMode => _preferences.getBool(autoKey) ?? false;

  Future<void> setAutoMode(bool value) async {
    await _preferences.setBool(autoKey, value);
  }

  // 2026-10-20 자동 재생 설정(단어/뜻 켜기, 반복 회수, 쉬는 초, 순서)을 저장한다.
  static const String playbackKey = 'study_auto_playback_v1';

  PlaybackSettings get playback =>
      PlaybackSettings.fromJson(_preferences.getString(playbackKey));

  Future<void> setPlayback(PlaybackSettings value) async {
    await _preferences.setString(playbackKey, value.toJson());
  }
}
