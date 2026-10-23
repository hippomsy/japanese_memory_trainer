import 'package:flutter/material.dart';
import 'package:kioku_japanese/models/memory_state.dart';
import 'package:kioku_japanese/models/vocabulary.dart';
import 'package:kioku_japanese/services/learning_repository.dart';

/// 2026-09-26 자주 틀리거나 느리게 회상한 단어를 위험도 순으로 보여준다.
class DangerWordsPage extends StatefulWidget {
  const DangerWordsPage({super.key, required this.repository});

  final LearningRepository repository;

  @override
  State<DangerWordsPage> createState() => _DangerWordsPageState();
}

class _DangerWordsPageState extends State<DangerWordsPage> {
  late Future<List<({Vocabulary word, MemoryState state})>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  /// 2026-09-26 위험 단어와 해당 기억 상태를 한 행에서 쓸 수 있게 결합한다.
  Future<List<({Vocabulary word, MemoryState state})>> _load() async {
    final words = await widget.repository.getDangerWords();
    final states = await widget.repository.getMemoryStates();
    return words
        .where((word) => states.containsKey(word.id))
        .map((word) => (word: word, state: states[word.id]!))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('위험 단어')),
      body: FutureBuilder<List<({Vocabulary word, MemoryState state})>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('위험 단어를 불러오지 못했습니다.'));
          }
          final items = snapshot.data ?? const [];
          if (items.isEmpty) {
            return const Center(child: Text('현재 위험 단어가 없습니다.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
              final item = items[index];
              return Card(
                child: ListTile(
                  title: Text('${item.word.japanese}  ${item.word.reading}'),
                  subtitle: Text(item.word.korean),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('위험 ${item.state.dangerScore}'),
                      Text('오답 ${item.state.wrongCount}회'),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
