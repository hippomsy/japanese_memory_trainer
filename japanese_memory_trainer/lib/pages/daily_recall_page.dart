import 'package:flutter/material.dart';
import 'package:kioku_japanese/data/study_store.dart';
import 'package:kioku_japanese/models/vocabulary.dart';
import 'package:kioku_japanese/widgets/study_widgets.dart';
import 'package:kioku_japanese/data/kanji_dictionary.dart';
import 'package:kioku_japanese/widgets/kanji_breakdown.dart';
import 'package:kioku_japanese/widgets/word_memo.dart';

/// 2026-09-30 보기를 가리고 떠올린 뒤 기억 상태를 기록하는 복습 화면.
class DailyRecallPage extends StatefulWidget {
  const DailyRecallPage(
      {super.key,
      required this.words,
      required this.store,
      required this.speakJapanese});
  final List<Vocabulary> words;
  final StudyStore store;
  final Future<void> Function(String) speakJapanese;

  @override
  State<DailyRecallPage> createState() => _DailyRecallPageState();
}

class _DailyRecallPageState extends State<DailyRecallPage> {
  late final List<({Vocabulary word, RecallAspect aspect})> _tasks;
  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _tasks = [
      for (final word in widget.words)
        for (final aspect in RecallAspect.values)
          if ((aspect != RecallAspect.kanji ||
                  KanjiDictionary.instance
                      .breakdown(word.japanese)
                      .isNotEmpty) &&
              !widget.store.aspectDueAt(word.id, aspect).isAfter(now))
            (word: word, aspect: aspect)
    ];
    _tasks.sort((a, b) {
      final weak = (widget.store.aspectWeak(b.word.id, b.aspect) ? 1 : 0)
          .compareTo(widget.store.aspectWeak(a.word.id, a.aspect) ? 1 : 0);
      if (weak != 0) return weak;
      return widget.store
          .aspectDueAt(a.word.id, a.aspect)
          .compareTo(widget.store.aspectDueAt(b.word.id, b.aspect));
    });
  }

  int _index = 0;
  int _remembered = 0;
  bool _revealed = false;
  bool _saving = false;
  String? _error;

  Future<void> _rate(RecallRating rating) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.store
          .recordAspect(_tasks[_index].word.id, _tasks[_index].aspect, rating);
      if (!mounted) return;
      setState(() {
        if (rating == RecallRating.remembered) _remembered++;
        _index++;
        _revealed = false;
      });
    } catch (_) {
      if (mounted) setState(() => _error = '저장하지 못했습니다. 다시 눌러 주세요.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final complete = _index >= _tasks.length;
    final word = complete ? null : _tasks[_index].word;
    final aspect = complete ? null : _tasks[_index].aspect;
    return Scaffold(
      backgroundColor: Washi.paper,
      appBar: AppBar(title: const Text('떠올리기 복습')),
      body: SafeArea(
          child: ListView(
        padding: const EdgeInsets.all(20),
        children: complete
            ? [
                const Icon(Icons.task_alt, size: 64, color: Washi.shu),
                const SizedBox(height: 20),
                const Text('복습 완료',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                Text('기억난 항목 $_remembered / ${_tasks.length}개',
                    textAlign: TextAlign.center),
                const SizedBox(height: 16),
                const Text('헷갈린 단어는 내일, 모르는 단어는 10분 뒤 다시 복습할 수 있어요.',
                    textAlign: TextAlign.center),
                const SizedBox(height: 20),
                FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('돌아가기')),
              ]
            : [
                Text('${_index + 1} / ${_tasks.length} · ${aspect!.label}',
                    textAlign: TextAlign.center),
                const SizedBox(height: 12),
                LinearProgressIndicator(value: _index / _tasks.length),
                const SizedBox(height: 24),
                Text(
                    switch (aspect) {
                      RecallAspect.meaning => '일본어를 보고 뜻을 소리 내어 말해 보세요.',
                      RecallAspect.reading => '읽는 법을 가린 채 일본어 발음을 말해 보세요.',
                      RecallAspect.listening => '글자를 보지 않고 듣고 뜻을 떠올려 보세요.',
                      _ => '각 한자의 뜻을 떠올려 보세요. 모든 음독·훈독을 외울 필요는 없어요.',
                    },
                    textAlign: TextAlign.center),
                const SizedBox(height: 20),
                PaperCard(
                    child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 30),
                  child: aspect == RecallAspect.listening
                      ? TextButton.icon(
                          onPressed: () => _speak(word!.reading),
                          icon: const Icon(Icons.volume_up),
                          label: const Text('단어 듣기'))
                      : Text(
                          aspect == RecallAspect.meaning
                              ? '${word!.japanese}\n${word.reading}'
                              : word!.japanese,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 30, fontWeight: FontWeight.bold)),
                )),
                const SizedBox(height: 20),
                if (_error != null)
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                if (!_revealed)
                  FilledButton(
                      key: const ValueKey('reveal-answer'),
                      onPressed: () => setState(() => _revealed = true),
                      child: const Text('정답 확인')),
                if (_revealed) ...[
                  Text(word!.japanese,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 36, fontWeight: FontWeight.bold)),
                  Text(word.reading,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 22)),
                  TextButton.icon(
                      onPressed: () => _speak(word.reading),
                      icon: const Icon(Icons.volume_up),
                      label: const Text('발음 듣기')),
                  Text(word.korean,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 22)),
                  if (word.exampleJapanese.isNotEmpty) ...[
                    Text(word.exampleJapanese, textAlign: TextAlign.center),
                    Text(word.exampleKorean, textAlign: TextAlign.center),
                  ],
                  const SizedBox(height: 12),
                  KanjiBreakdown(word: word),
                  const SizedBox(height: 8),
                  WordMemoTile(store: widget.store, wordId: word.id),
                  const Text(
                      '뜻·발음·한자 중 지금 묻는 항목만 평가하세요.\n답을 읽고 익숙해진 느낌보다, 확인 전에 떠올렸는지가 중요해요.',
                      textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  for (final rating in RecallRating.values)
                    Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: FilledButton.tonal(
                          key: ValueKey('rate-${rating.name}'),
                          onPressed: _saving ? null : () => _rate(rating),
                          child: Text(switch (rating) {
                            RecallRating.remembered => '기억남',
                            RecallRating.unsure => '헷갈림 · 내일 복습',
                            RecallRating.forgotten => '모름 · 10분 뒤 복습',
                          }),
                        )),
                ],
              ],
      )),
    );
  }

  Future<void> _speak(String text) async {
    try {
      await widget.speakJapanese(text);
    } catch (_) {
      if (mounted) {
        setState(() => _error = '발음을 재생하지 못했어요. 일본어 음성 설정을 확인해 주세요.');
      }
    }
  }
}
