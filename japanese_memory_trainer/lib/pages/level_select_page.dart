import 'package:flutter/material.dart';
import 'package:kioku_japanese/models/study_level.dart';
import 'package:kioku_japanese/services/learning_repository.dart';

/// 2026-09-27 JLPT 급수(N5~N1)별로 10개 레벨의 진행 상황을 보여주고,
/// 사용자가 공부할 레벨을 고르는 화면이다. 레벨을 고르면 저장한 뒤 이전 화면으로 돌아간다.
class LevelSelectPage extends StatefulWidget {
  const LevelSelectPage({super.key, required this.repository});

  final LearningRepository repository;

  @override
  State<LevelSelectPage> createState() => _LevelSelectPageState();
}

class _LevelSelectPageState extends State<LevelSelectPage> {
  late Future<_LevelData> _future;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_LevelData> _load() async {
    final current = await widget.repository.loadStudyLevel();
    final progress = <String, List<LevelProgressInfo>>{
      for (final grade in StudyLevel.grades)
        grade: await widget.repository.levelProgress(grade),
    };
    return _LevelData(current: current, progress: progress);
  }

  Future<void> _select(StudyLevel studyLevel) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.repository.saveStudyLevel(studyLevel);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('학습 레벨을 저장하지 못했습니다. 다시 시도해 주세요.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_LevelData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            appBar: AppBar(title: const Text('레벨 선택')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        final data = snapshot.data;
        if (snapshot.hasError || data == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('레벨 선택')),
            body: Center(
              child: OutlinedButton(
                onPressed: () => setState(() => _future = _load()),
                child: const Text('다시 시도'),
              ),
            ),
          );
        }

        return DefaultTabController(
          length: StudyLevel.grades.length,
          initialIndex: StudyLevel.grades.indexOf(data.current.grade),
          child: Scaffold(
            appBar: AppBar(
              title: const Text('레벨 선택'),
              bottom: TabBar(
                tabs: [
                  for (final grade in StudyLevel.grades) Tab(text: grade),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                for (final grade in StudyLevel.grades)
                  _GradeLevelList(
                    levels: data.progress[grade] ?? const <LevelProgressInfo>[],
                    current: data.current,
                    enabled: !_saving,
                    onSelect: _select,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LevelData {
  const _LevelData({required this.current, required this.progress});

  final StudyLevel current;
  final Map<String, List<LevelProgressInfo>> progress;
}

class _GradeLevelList extends StatelessWidget {
  const _GradeLevelList({
    required this.levels,
    required this.current,
    required this.enabled,
    required this.onSelect,
  });

  final List<LevelProgressInfo> levels;
  final StudyLevel current;
  final bool enabled;
  final ValueChanged<StudyLevel> onSelect;

  @override
  Widget build(BuildContext context) {
    final totalWords = levels.fold<int>(0, (sum, info) => sum + info.total);
    if (totalWords == 0) {
      return const Center(child: Text('이 급수에는 아직 단어가 없습니다.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: levels.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final info = levels[index];
        final isCurrent = info.studyLevel == current;
        final theme = Theme.of(context);
        return ListTile(
          key: ValueKey('level-tile-${info.studyLevel.encode()}'),
          enabled: enabled && !info.isEmpty,
          selected: isCurrent,
          leading: CircleAvatar(
            backgroundColor: info.isCompleted
                ? theme.colorScheme.primary
                : theme.colorScheme.surfaceContainerHighest,
            foregroundColor: info.isCompleted
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onSurface,
            child: info.isCompleted
                ? const Icon(Icons.check, size: 20)
                : Text('${info.studyLevel.level}'),
          ),
          title: Text('Lv.${info.studyLevel.level}'),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              LinearProgressIndicator(value: info.ratio),
              const SizedBox(height: 4),
              Text(
                info.isEmpty
                    ? '단어 없음'
                    : '${info.learned} / ${info.total} 단어 학습',
              ),
            ],
          ),
          trailing: isCurrent
              ? const Chip(label: Text('학습 중'))
              : const Icon(Icons.chevron_right),
          onTap: info.isEmpty ? null : () => onSelect(info.studyLevel),
        );
      },
    );
  }
}
