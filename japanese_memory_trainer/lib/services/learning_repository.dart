import 'dart:math' as math;

import 'package:kioku_japanese/data/local_database.dart';
import 'package:kioku_japanese/models/memory_state.dart';
import 'package:kioku_japanese/models/study_level.dart';
import 'package:kioku_japanese/models/vocabulary.dart';
import 'package:kioku_japanese/services/review_scheduler.dart';

/// 2026-09-26 신규/복습/위험/보스전 단어 선택 규칙을 한곳에서 관리한다.
class LearningRepository {
  LearningRepository({
    required List<Vocabulary> seed,
    required LocalDatabase database,
    ReviewScheduler? scheduler,
  })  : _seed = List<Vocabulary>.unmodifiable(seed),
        _database = database,
        _scheduler = scheduler ?? ReviewScheduler(),
        _byId = {for (final word in seed) word.id: word};

  final List<Vocabulary> _seed;
  final LocalDatabase _database;
  final ReviewScheduler _scheduler;
  final Map<String, Vocabulary> _byId;

  /// 2026-09-26 같은 날짜에는 최초 선택된 신규 단어 집합을 그대로 반환한다.
  /// 2026-09-27 신규 단어는 사용자가 고른 급수·레벨부터 순서대로 고른다. 고른 레벨의
  /// 단어를 다 배웠으면 같은 급수의 다음 레벨 단어로 자연스럽게 이어진다.
  /// 오늘 고른 단어를 아직 한 번도 풀지 않았다면 레벨을 바꿀 때 새 레벨 기준으로 다시 고른다.
  Future<List<Vocabulary>> getNewWordsForDay(
    DateTime day, {
    int limit = 5,
  }) async {
    if (limit <= 0) return const <Vocabulary>[];

    final studyLevel = await _database.loadStudyLevel();
    final states = await _database.loadMemoryStates();
    final candidates = _candidatesFrom(studyLevel);
    final candidateIds = candidates.map((word) => word.id).toSet();

    final savedIds = await _database.loadDailyLearnedWordIds(day);
    if (savedIds.isNotEmpty) {
      final saved = _seed.where((word) => savedIds.contains(word.id)).toList();
      final alreadyStudied = saved.any((word) => states.containsKey(word.id));
      final matchesLevel = saved.every((word) => candidateIds.contains(word.id));
      if (alreadyStudied || matchesLevel) {
        return saved.take(limit).toList();
      }
    }

    final selected = candidates
        .where((word) => !states.containsKey(word.id))
        .take(limit)
        .toList(growable: false);

    await _database.saveDailyLearnedWordIds(
      day,
      selected.map((word) => word.id).toSet(),
    );
    return selected;
  }

  /// 2026-09-27 한 급수의 단어를 원래 순서(빈도순) 그대로 10개 레벨로 나눈다.
  /// 단어 수가 10으로 나누어떨어지지 않으면 앞쪽 레벨이 한 개씩 더 많거나 같게 나뉜다.
  List<List<Vocabulary>> wordsByLevel(String grade) {
    final words = _seed
        .where((word) => word.jlptLevel.trim().toUpperCase() == grade)
        .toList(growable: false);
    const count = StudyLevel.levelsPerGrade;
    final size = (words.length / count).ceil();
    return List<List<Vocabulary>>.generate(count, (index) {
      if (size == 0) return const <Vocabulary>[];
      final start = index * size;
      if (start >= words.length) return const <Vocabulary>[];
      final end = math.min(start + size, words.length);
      return words.sublist(start, end);
    }, growable: false);
  }

  /// 2026-09-27 선택 레벨부터 같은 급수의 마지막 레벨까지 단어를 순서대로 모은다.
  /// 데이터에 해당 급수 단어가 하나도 없으면(테스트용 소규모 목록 등) 전체 단어를 쓴다.
  List<Vocabulary> _candidatesFrom(StudyLevel studyLevel) {
    final levels = wordsByLevel(studyLevel.grade);
    if (levels.every((words) => words.isEmpty)) return _seed;
    return [
      for (var i = studyLevel.level - 1; i < levels.length; i++) ...levels[i],
    ];
  }

  /// 2026-09-27 급수 하나의 레벨별 진행 상황(전체/학습한 단어 수)을 계산한다.
  Future<List<LevelProgressInfo>> levelProgress(String grade) async {
    final states = await _database.loadMemoryStates();
    final levels = wordsByLevel(grade);
    return [
      for (var i = 0; i < levels.length; i++)
        LevelProgressInfo(
          studyLevel: StudyLevel(grade, i + 1),
          total: levels[i].length,
          learned: levels[i].where((word) => states.containsKey(word.id)).length,
        ),
    ];
  }

  /// 2026-09-27 현재 선택된 학습 레벨과 그 레벨의 진행 상황을 함께 돌려준다.
  Future<LevelProgressInfo> currentLevelProgress() async {
    final studyLevel = await _database.loadStudyLevel();
    final progress = await levelProgress(studyLevel.grade);
    return progress[studyLevel.level - 1];
  }

  /// 2026-09-27 현재 학습 레벨을 읽는다.
  Future<StudyLevel> loadStudyLevel() => _database.loadStudyLevel();

  /// 2026-09-27 학습 레벨을 바꾼다. 다음 퀘스트의 신규 단어부터 반영된다.
  Future<void> saveStudyLevel(StudyLevel studyLevel) =>
      _database.saveStudyLevel(studyLevel);

  /// 2026-09-26 현재 시각에 복습할 단어만 위험도 높은 순으로 반환한다.
  Future<List<Vocabulary>> getDueWords(DateTime now) async {
    final states = await _database.loadMemoryStates();
    final dueStates = states.values
        .where((state) => _byId.containsKey(state.wordId) && _scheduler.isDue(state, now))
        .toList();

    dueStates.sort((a, b) {
      final danger = b.dangerScore.compareTo(a.dangerScore);
      if (danger != 0) return danger;
      final aTime = a.nextReviewAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.nextReviewAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return aTime.compareTo(bTime);
    });
    return dueStates.map((state) => _byId[state.wordId]!).toList();
  }

  /// 2026-09-26 위험 점수가 있는 단어를 높은 점수부터 반환한다.
  Future<List<Vocabulary>> getDangerWords({int limit = 20}) async {
    if (limit <= 0) return const <Vocabulary>[];
    final states = await _database.loadMemoryStates();
    final dangerous = states.values
        .where((state) => state.dangerScore > 0 && _byId.containsKey(state.wordId))
        .toList();
    dangerous.sort((a, b) {
      final danger = b.dangerScore.compareTo(a.dangerScore);
      if (danger != 0) return danger;
      return b.wrongCount.compareTo(a.wrongCount);
    });
    return dangerous.take(limit).map((state) => _byId[state.wordId]!).toList();
  }

  /// 2026-09-26 주간 보스전은 위험도가 같으면 최근 복습한 단어를 먼저 고른다.
  Future<List<Vocabulary>> getBossWords({int limit = 10}) async {
    if (limit <= 0) return const <Vocabulary>[];
    final states = await _database.loadMemoryStates();
    final candidates = states.values
        .where((state) => state.dangerScore > 0 && _byId.containsKey(state.wordId))
        .toList();
    candidates.sort((a, b) {
      final danger = b.dangerScore.compareTo(a.dangerScore);
      if (danger != 0) return danger;
      final aTime = a.lastReviewedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.lastReviewedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });
    return candidates.take(limit).map((state) => _byId[state.wordId]!).toList();
  }

  /// 2026-09-26 화면/통계 계층에서 필요한 전체 기억 상태를 읽는다.
  Future<Map<String, MemoryState>> getMemoryStates() {
    return _database.loadMemoryStates();
  }

  /// 2026-09-26 단어 ID로 원본 단어를 찾는다.
  Vocabulary? wordById(String wordId) => _byId[wordId];

  /// 2026-09-26 통계 계산에 사용하는 전체 seed를 읽기 전용으로 제공한다.
  List<Vocabulary> get allWords => _seed;
}
