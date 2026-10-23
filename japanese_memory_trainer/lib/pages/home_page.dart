import 'package:kioku_japanese/config.dart';
import 'package:kioku_japanese/widgets/study_illustration.dart';
import 'package:flutter/material.dart';
import 'package:kioku_japanese/models/study_level.dart';
import 'package:kioku_japanese/services/statistics_service.dart';
import 'package:kioku_japanese/widgets/progress_card.dart';

/// 2026-09-26 오늘 해야 할 학습과 장기기억 성과를 한눈에 보여주는 홈 화면이다.
class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.statisticsService,
    required this.onStartQuest,
    required this.onDangerWords,
    required this.onBoss,
    required this.onStatistics,
    this.loadCurrentLevel,
    this.onSelectLevel,
  });

  final StatisticsService statisticsService;
  final VoidCallback onStartQuest;
  final VoidCallback onDangerWords;
  final VoidCallback onBoss;
  final VoidCallback onStatistics;

  /// 2026-09-27 현재 학습 레벨(급수 + Lv.1~10)과 진행 상황을 읽는다.
  /// onSelectLevel과 함께 주어질 때만 홈에 레벨 카드를 보여준다.
  final Future<LevelProgressInfo> Function()? loadCurrentLevel;

  /// 2026-09-27 레벨 선택 화면을 열고, 돌아오면 완료되는 콜백이다.
  final Future<void> Function()? onSelectLevel;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<StatisticsSnapshot> _snapshotFuture;

  @override
  void initState() {
    super.initState();
    _snapshotFuture = widget.statisticsService.buildSnapshot(DateTime.now());
  }

  /// 2026-09-26 다른 화면에서 돌아왔을 때 최신 기억 통계를 다시 읽는다.
  void refresh() {
    setState(() {
      _snapshotFuture = widget.statisticsService.buildSnapshot(DateTime.now());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('하루 일본어'),
            Text('v$appVersion',
                style: const TextStyle(fontSize: 11, color: Colors.white60, height: 1.1)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '통계',
            onPressed: widget.onStatistics,
            icon: const Icon(Icons.bar_chart_outlined),
          ),
        ],
      ),
      body: FutureBuilder<StatisticsSnapshot>(
        future: _snapshotFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorView(onRetry: refresh);
          }
          final data = snapshot.data ?? _emptySnapshot;
          return RefreshIndicator(
            onRefresh: () async => refresh(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const StudyIllustration('study', height: 160),
                const SizedBox(height: 12),
                Text(
                  '연속 학습 ${data.streakDays}일 🔥',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                ProgressCard(
                  label: '장기기억 단어',
                  value: '${data.longTermWordCount}개',
                  subtitle: '이번 주 새로 정착 ${data.newLongTermThisWeek}개',
                  prominent: true,
                  onTap: widget.onStatistics,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ProgressCard(
                        label: '오늘 복습',
                        value: '${data.dueReviewCount}개',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ProgressCard(
                        label: '위험 단어',
                        value: '${data.dangerWordCount}개',
                        onTap: widget.onDangerWords,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (widget.loadCurrentLevel != null && widget.onSelectLevel != null) ...[
                  _StudyLevelCard(
                    loadCurrentLevel: widget.loadCurrentLevel!,
                    onSelectLevel: () async {
                      await widget.onSelectLevel!();
                      refresh();
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                FilledButton.icon(
                  onPressed: widget.onStartQuest,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Text('오늘의 퀘스트 시작'),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: widget.onBoss,
                  icon: const Icon(Icons.sports_martial_arts_outlined),
                  label: const Text('주간 보스전'),
                ),
                const SizedBox(height: 20),
                Text('JLPT 장기기억 진행률', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                _LevelProgress(label: 'N5', value: data.n5Progress),
                _LevelProgress(label: 'N4', value: data.n4Progress),
                _LevelProgress(label: 'N3', value: data.n3Progress),
                _LevelProgress(label: 'N2', value: data.n2Progress),
                _LevelProgress(label: 'N1', value: data.n1Progress),
                const SizedBox(height: 24),
                const Center(
                  child: Text(
                    'v$appVersion',
                    style: TextStyle(fontSize: 11, color: Colors.black38),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      ),
    );
  }

  static const _emptySnapshot = StatisticsSnapshot(
    streakDays: 0,
    longTermWordCount: 0,
    newLongTermThisWeek: 0,
    dangerWordCount: 0,
    dueReviewCount: 0,
    todayNewWordCount: 0,
    retentionRate: 0,
    n5Progress: 0,
    n4Progress: 0,
    n3Progress: 0,
    n2Progress: 0,
    n1Progress: 0,
  );
}

/// 2026-09-27 지금 공부 중인 레벨(예: N5 · Lv.3)과 진행률을 보여주고,
/// 눌러서 레벨 선택 화면으로 이동하는 카드다.
class _StudyLevelCard extends StatelessWidget {
  const _StudyLevelCard({
    required this.loadCurrentLevel,
    required this.onSelectLevel,
  });

  final Future<LevelProgressInfo> Function() loadCurrentLevel;
  final Future<void> Function() onSelectLevel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        key: const ValueKey('study-level-card'),
        borderRadius: BorderRadius.circular(12),
        onTap: onSelectLevel,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FutureBuilder<LevelProgressInfo>(
            future: loadCurrentLevel(),
            builder: (context, snapshot) {
              final info = snapshot.data;
              return Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('학습 레벨', style: theme.textTheme.labelLarge),
                        const SizedBox(height: 4),
                        Text(
                          info?.studyLevel.label ?? '불러오는 중…',
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(value: info?.ratio ?? 0),
                        const SizedBox(height: 4),
                        Text(
                          info == null
                              ? ''
                              : info.isCompleted
                                  ? '이 레벨 완료! 다음 퀘스트는 다음 레벨 단어로 이어집니다.'
                                  : '${info.learned} / ${info.total} 단어 학습',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text('레벨 변경'),
                  const Icon(Icons.chevron_right),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LevelProgress extends StatelessWidget {
  const _LevelProgress({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final safeValue = (value / 100).clamp(0.0, 1.0).toDouble();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 34, child: Text(label)),
          Expanded(child: LinearProgressIndicator(value: safeValue)),
          const SizedBox(width: 10),
          SizedBox(width: 48, child: Text('${value.toStringAsFixed(0)}%')),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('학습 통계를 불러오지 못했습니다.'),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: onRetry, child: const Text('다시 시도')),
        ],
      ),
    );
  }
}
