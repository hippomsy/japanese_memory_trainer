import 'package:kioku_japanese/data/local_database.dart';
import 'package:kioku_japanese/models/memory_state.dart';
import 'package:kioku_japanese/services/learning_repository.dart';
import 'package:kioku_japanese/services/review_scheduler.dart';

/// 2026-09-26 홈과 통계 화면에서 사용하는 집계 결과다.
class StatisticsSnapshot {
  const StatisticsSnapshot({
    required this.streakDays,
    required this.longTermWordCount,
    required this.newLongTermThisWeek,
    required this.dangerWordCount,
    required this.dueReviewCount,
    required this.todayNewWordCount,
    required this.retentionRate,
    required this.n5Progress,
    required this.n4Progress,
    required this.n3Progress,
    required this.n2Progress,
    required this.n1Progress,
  });

  final int streakDays;
  final int longTermWordCount;
  final int newLongTermThisWeek;
  final int dangerWordCount;
  final int dueReviewCount;
  final int todayNewWordCount;
  final double retentionRate;
  // 2026-09-27 N5·N1 단어도 수입되어 급수별 진도에 N5와 N1을 추가했다.
  final double n5Progress;
  final double n4Progress;
  final double n3Progress;
  final double n2Progress;
  final double n1Progress;
}

/// 2026-09-26 저장된 학습 기록을 사용자에게 의미 있는 기억 통계로 변환한다.
class StatisticsService {
  StatisticsService({
    required LearningRepository repository,
    required LocalDatabase database,
    ReviewScheduler? scheduler,
  })  : _repository = repository,
        _database = database,
        _scheduler = scheduler ?? ReviewScheduler();

  final LearningRepository _repository;
  final LocalDatabase _database;
  final ReviewScheduler _scheduler;

  /// 2026-09-26 현재 시점의 장기기억/위험/복습/JLPT 진행률을 계산한다.
  Future<StatisticsSnapshot> buildSnapshot(DateTime now) async {
    final states = await _repository.getMemoryStates();
    final learningDays = await _database.loadLearningDays();
    final todayIds = await _database.loadDailyLearnedWordIds(now);
    final values = states.values.toList(growable: false);

    final longTerm = values.where((state) => state.stage >= 6).toList();
    final weekStart = _startOfWeek(now);
    final weekEnd = weekStart.add(const Duration(days: 7));
    final newLongTermThisWeek = longTerm.where((state) {
      final reachedAt = state.longTermReachedAt;
      return reachedAt != null &&
          !reachedAt.isBefore(weekStart) &&
          reachedAt.isBefore(weekEnd);
    }).length;

    final dangerCount = values.where((state) => state.dangerScore >= 50).length;
    final dueCount = values.where((state) => _scheduler.isDue(state, now)).length;

    final correct = values.fold<int>(0, (sum, state) => sum + state.correctCount);
    final wrong = values.fold<int>(0, (sum, state) => sum + state.wrongCount);
    final totalReviews = correct + wrong;
    final retentionRate = totalReviews == 0 ? 0.0 : (correct / totalReviews) * 100;

    return StatisticsSnapshot(
      streakDays: _calculateStreak(learningDays, now),
      longTermWordCount: longTerm.length,
      newLongTermThisWeek: newLongTermThisWeek,
      dangerWordCount: dangerCount,
      dueReviewCount: dueCount,
      todayNewWordCount: todayIds.length,
      retentionRate: retentionRate,
      n5Progress: _levelProgress('N5', states),
      n4Progress: _levelProgress('N4', states),
      n3Progress: _levelProgress('N3', states),
      n2Progress: _levelProgress('N2', states),
      n1Progress: _levelProgress('N1', states),
    );
  }

  double _levelProgress(String level, Map<String, MemoryState> states) {
    final words = _repository.allWords
        .where((word) => word.jlptLevel.toUpperCase() == level)
        .toList(growable: false);
    if (words.isEmpty) return 0;
    final longTermCount = words
        .where((word) => (states[word.id]?.stage ?? 0) >= 6)
        .length;
    return (longTermCount / words.length) * 100;
  }

  int _calculateStreak(Set<String> days, DateTime now) {
    if (days.isEmpty) return 0;
    final today = DateTime(now.year, now.month, now.day);
    var cursor = today;
    if (!days.contains(LocalDatabase.formatDay(cursor))) {
      cursor = cursor.subtract(const Duration(days: 1));
    }

    var streak = 0;
    while (days.contains(LocalDatabase.formatDay(cursor))) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  DateTime _startOfWeek(DateTime now) {
    final day = DateTime(now.year, now.month, now.day);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }
}
