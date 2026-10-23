import 'dart:convert';

import 'package:kioku_japanese/models/memory_state.dart';
import 'package:kioku_japanese/models/study_level.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 2026-09-26 SharedPreferences를 사용해 학습 상태를 로컬에 보관한다.
class LocalDatabase {
  LocalDatabase(
    this._preferences, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  static const String memoryStatesKey = 'memory_states_v1';
  static const String learningDaysKey = 'learning_days_v1';
  static const String _dailyPrefix = 'daily_learned_ids_v1_';

  /// 2026-09-27 사용자가 고른 학습 위치(급수 + 레벨)를 저장하는 키다.
  static const String studyLevelKey = 'study_level_v1';

  final SharedPreferences _preferences;
  final DateTime Function() _now;

  /// 2026-09-26 저장된 기억 상태를 읽고 손상된 복습 날짜를 즉시 복습 가능 상태로 복구한다.
  Future<Map<String, MemoryState>> loadMemoryStates() async {
    final raw = _preferences.getString(memoryStatesKey);
    if (raw == null || raw.trim().isEmpty) {
      return <String, MemoryState>{};
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return <String, MemoryState>{};
      }

      final result = <String, MemoryState>{};
      for (final entry in decoded.entries) {
        if (entry.value is! Map) continue;
        final key = entry.key.toString();
        final json = Map<String, dynamic>.from(entry.value as Map);
        json['wordId'] = (json['wordId']?.toString().isNotEmpty ?? false)
            ? json['wordId']
            : key;
        var state = MemoryState.fromJson(json);
        if (state.nextReviewAt == null) {
          state = state.copyWith(nextReviewAt: _now());
        }
        result[key] = state;
      }
      return result;
    } catch (_) {
      return <String, MemoryState>{};
    }
  }

  /// 2026-09-26 전체 기억 상태를 하나의 JSON으로 원자적으로 저장한다.
  Future<void> saveMemoryStates(Map<String, MemoryState> states) async {
    final encoded = jsonEncode(
      states.map((key, value) => MapEntry(key, value.toJson())),
    );
    final saved = await _preferences.setString(memoryStatesKey, encoded);
    if (!saved) {
      throw StateError('기억 상태를 저장하지 못했습니다.');
    }
  }

  /// 2026-09-26 지정 날짜에 이미 신규 학습으로 선택된 단어 ID를 읽는다.
  Future<Set<String>> loadDailyLearnedWordIds(DateTime day) async {
    return (_preferences.getStringList(_dailyKey(day)) ?? const <String>[])
        .toSet();
  }

  /// 2026-09-26 지정 날짜의 신규 학습 단어 ID를 저장한다.
  Future<void> saveDailyLearnedWordIds(DateTime day, Set<String> ids) async {
    final sorted = ids.toList()..sort();
    final saved = await _preferences.setStringList(_dailyKey(day), sorted);
    if (!saved) {
      throw StateError('오늘의 학습 단어를 저장하지 못했습니다.');
    }
  }

  /// 2026-09-26 학습한 날짜 집합을 YYYY-MM-DD 문자열로 읽는다.
  Future<Set<String>> loadLearningDays() async {
    return (_preferences.getStringList(learningDaysKey) ?? const <String>[])
        .toSet();
  }

  /// 2026-09-26 하루에 여러 번 호출되어도 학습 날짜를 한 번만 기록한다.
  Future<void> recordLearningDay(DateTime day) async {
    final days = await loadLearningDays();
    days.add(formatDay(day));
    final sorted = days.toList()..sort();
    final saved = await _preferences.setStringList(learningDaysKey, sorted);
    if (!saved) {
      throw StateError('학습 날짜를 저장하지 못했습니다.');
    }
  }

  /// 2026-09-27 저장된 학습 위치(급수 + 레벨)를 읽는다. 없거나 손상되었으면
  /// 처음 위치(N5 · Lv.1)를 돌려준다.
  Future<StudyLevel> loadStudyLevel() async {
    return StudyLevel.decode(_preferences.getString(studyLevelKey)) ??
        StudyLevel.initial;
  }

  /// 2026-09-27 학습 위치를 저장한다.
  Future<void> saveStudyLevel(StudyLevel studyLevel) async {
    final saved = await _preferences.setString(studyLevelKey, studyLevel.encode());
    if (!saved) {
      throw StateError('학습 레벨을 저장하지 못했습니다.');
    }
  }

  /// 2026-09-26 날짜를 저장 키에서 사용하는 YYYY-MM-DD 형식으로 변환한다.
  static String formatDay(DateTime day) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${day.year}-${two(day.month)}-${two(day.day)}';
  }

  String _dailyKey(DateTime day) => '$_dailyPrefix${formatDay(day)}';
}
