import 'package:flutter/material.dart';
import 'package:kioku_japanese/services/statistics_service.dart';
import 'package:kioku_japanese/widgets/progress_card.dart';

/// 2026-09-26 문제 수보다 장기기억 정착 수를 중심으로 학습 성과를 보여준다.
class StatisticsPage extends StatelessWidget {
  const StatisticsPage({
    super.key,
    required this.statisticsService,
  });

  final StatisticsService statisticsService;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('기억 통계')),
      body: FutureBuilder<StatisticsSnapshot>(
        future: statisticsService.buildSnapshot(DateTime.now()),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || snapshot.data == null) {
            return const Center(child: Text('통계를 불러오지 못했습니다.'));
          }
          final data = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ProgressCard(
                label: '장기기억 단어',
                value: '${data.longTermWordCount}개',
                prominent: true,
              ),
              ProgressCard(
                label: '이번 주 새로 정착',
                value: '${data.newLongTermThisWeek}개',
              ),
              ProgressCard(
                label: '기억률',
                value: '${data.retentionRate.toStringAsFixed(1)}%',
              ),
              ProgressCard(
                label: '위험 단어',
                value: '${data.dangerWordCount}개',
              ),
              const SizedBox(height: 16),
              Text('JLPT 진행률', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              _LevelBar(label: 'N5', value: data.n5Progress),
              _LevelBar(label: 'N4', value: data.n4Progress),
              _LevelBar(label: 'N3', value: data.n3Progress),
              _LevelBar(label: 'N2', value: data.n2Progress),
              _LevelBar(label: 'N1', value: data.n1Progress),
              const SizedBox(height: 24),
              // 2026-09-27 대량 수입한 JLPT 단어 목록(표기·읽기·급수)이 MIT 라이선스인
              // elzup/jlpt-word-list에서 왔음을 밝힌다. 한국어 뜻과 예문은 이 앱에서
              // 새로 작성한 것이라 별도 출처 표시 의무는 없지만, 원 데이터 출처는 남긴다.
              Text(
                '일부 단어 데이터 출처: elzup/jlpt-word-list (MIT License)',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LevelBar extends StatelessWidget {
  const _LevelBar({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final progress = (value / 100).clamp(0.0, 1.0).toDouble();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(width: 38, child: Text(label)),
          Expanded(child: LinearProgressIndicator(value: progress)),
          const SizedBox(width: 10),
          Text('${value.toStringAsFixed(0)}%'),
        ],
      ),
    );
  }
}
