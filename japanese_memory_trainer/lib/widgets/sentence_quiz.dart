import 'dart:math';

import 'package:flutter/material.dart';
import 'package:kioku_japanese/data/sentence_bank.dart';
import 'package:kioku_japanese/widgets/study_widgets.dart';

/// 2026-09-30 문장 만들기: 한국어 뜻을 보고 일본어 조각을 순서대로 눌러 문장을 완성한다.
/// 스크롤 없이 한 화면에 들어가도록 뜻(위) · 내가 만든 문장 · 조각판 · 버튼 순으로 나눈다.
class SentenceQuiz extends StatefulWidget {
  const SentenceQuiz({
    super.key,
    required this.items,
    required this.speakJapanese,
    this.accent = Washi.shu,
    this.random,
  });

  final List<SentenceItem> items;
  final Future<void> Function(String text) speakJapanese;
  final Color accent;
  final Random? random;

  @override
  State<SentenceQuiz> createState() => _SentenceQuizState();
}

class _SentenceQuizState extends State<SentenceQuiz> {
  late final Random _random = widget.random ?? Random();
  late List<SentenceItem> _order;
  int _index = 0;
  List<int> _shuffled = const <int>[];
  final List<int> _placed = <int>[];
  bool _answered = false;
  bool _correct = false;
  bool _finished = false;
  int _score = 0;
  final List<SentenceItem> _wrong = <SentenceItem>[];

  SentenceItem get _current => _order[_index];

  @override
  void initState() {
    super.initState();
    _start(widget.items);
  }

  void _start(List<SentenceItem> items) {
    _order = List<SentenceItem>.of(items);
    _index = 0;
    _score = 0;
    _wrong.clear();
    _finished = _order.isEmpty;
    if (!_finished) _prepare();
  }

  void _prepare() {
    _answered = false;
    _correct = false;
    _placed.clear();
    final n = _current.chunks.length;
    final list = List<int>.generate(n, (i) => i);
    // 이미 정답 순서로 섞이는 일이 없도록 한다.
    for (var tries = 0; tries < 10; tries++) {
      list.shuffle(_random);
      if (n < 2 || !_isIdentity(list)) break;
    }
    _shuffled = list;
  }

  static bool _isIdentity(List<int> list) {
    for (var i = 0; i < list.length; i++) {
      if (list[i] != i) return false;
    }
    return true;
  }

  void _place(int chunk) {
    if (_answered || _placed.contains(chunk)) return;
    setState(() => _placed.add(chunk));
  }

  void _unplace(int chunk) {
    if (_answered) return;
    setState(() => _placed.remove(chunk));
  }

  void _check() {
    if (_answered || _placed.length != _current.chunks.length) return;
    final built = _placed.map((i) => _current.chunks[i]).join();
    final ok = built == _current.japanese;
    setState(() {
      _answered = true;
      _correct = ok;
      if (ok) {
        _score++;
      } else {
        _wrong.add(_current);
      }
    });
    widget.speakJapanese(_current.japanese);
  }

  void _next() {
    setState(() {
      if (_index >= _order.length - 1) {
        _finished = true;
      } else {
        _index++;
        _prepare();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return const Center(
        child: Text('이 챕터에는 문장 문제가 없습니다.', style: TextStyle(fontSize: 16, color: Washi.inkSoft)),
      );
    }
    if (_finished) return _buildFinished();
    final item = _current;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              '${_index + 1} / ${_order.length}',
              key: const ValueKey('sentence-progress'),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Washi.inkSoft),
            ),
            const SizedBox(width: 10),
            Expanded(child: SlimProgress(ratio: (_index + 1) / _order.length, color: widget.accent)),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          flex: 3,
          child: PaperCard(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '이 뜻이 되도록 문장을 만드세요',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Washi.shu),
                ),
                Expanded(
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width - 64),
                        child: Text(
                          item.korean,
                          key: const ValueKey('sentence-prompt'),
                          textAlign: TextAlign.center,
                          maxLines: 3,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Washi.ink,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          flex: 7,
          child: _answered ? _buildFeedback(item) : _buildBoard(item),
        ),
      ],
    );
  }

  Widget _chunkButton({
    required Key key,
    required String text,
    required VoidCallback? onTap,
    bool placed = false,
  }) {
    return Material(
      color: placed ? widget.accent.withValues(alpha: 0.12) : Washi.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: placed ? widget.accent : Washi.line, width: placed ? 1.4 : 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: key,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Text(
            text,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Washi.ink),
          ),
        ),
      ),
    );
  }

  Widget _buildBoard(SentenceItem item) {
    final remaining = _shuffled.where((i) => !_placed.contains(i)).toList();
    final complete = _placed.length == item.chunks.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 내가 만든 문장
        Expanded(
          flex: 4,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Washi.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: widget.accent.withValues(alpha: 0.45), width: 1.4),
            ),
            child: _placed.isEmpty
                ? const Center(
                    child: Text(
                      '아래 조각을 순서대로 누르세요',
                      style: TextStyle(fontSize: 14, color: Washi.inkSoft),
                    ),
                  )
                : Align(
                    alignment: Alignment.topLeft,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.topLeft,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width - 60),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final i in _placed)
                              _chunkButton(
                                key: ValueKey('sentence-placed-$i'),
                                text: item.chunks[i],
                                placed: true,
                                onTap: () => _unplace(i),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 10),
        // 조각판
        Expanded(
          flex: 5,
          child: Align(
            alignment: Alignment.topCenter,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width - 40),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final i in remaining)
                      _chunkButton(
                        key: ValueKey('sentence-chunk-$i'),
                        text: item.chunks[i],
                        onTap: () => _place(i),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const ValueKey('sentence-clear'),
                onPressed: _placed.isEmpty ? null : () => setState(_placed.clear),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: const StadiumBorder(),
                  foregroundColor: Washi.ink,
                  side: const BorderSide(color: Washi.line),
                ),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('다시', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                key: const ValueKey('sentence-check'),
                onPressed: complete ? _check : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: const StadiumBorder(),
                  backgroundColor: Washi.ink,
                ),
                icon: const Icon(Icons.check_rounded),
                label: const Text('확인', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFeedback(SentenceItem item) {
    final color = _correct ? Washi.shu : Washi.ink;
    final mine = _placed.map((i) => item.chunks[i]).join();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: PaperCard(
            borderColor: color.withValues(alpha: 0.5),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    HankoBadge(text: _correct ? '正' : '誤', color: color, size: 48, filled: _correct),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _correct ? '정답입니다!' : '틀렸습니다',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color),
                      ),
                    ),
                    IconButton(
                      tooltip: '문장 듣기',
                      icon: const Icon(Icons.volume_up_rounded, color: Washi.ink, size: 30),
                      onPressed: () => widget.speakJapanese(item.japanese),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.topLeft,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width - 70),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.japanese,
                            key: const ValueKey('sentence-answer'),
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Washi.ink),
                          ),
                          if (item.kana.isNotEmpty)
                            Text(item.kana, style: const TextStyle(fontSize: 14, color: Washi.inkSoft)),
                          const SizedBox(height: 6),
                          Text(item.korean, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: widget.accent)),
                          if (!_correct) ...[
                            const SizedBox(height: 8),
                            Text('내 답: $mine', style: const TextStyle(fontSize: 14, color: Washi.inkSoft)),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        FilledButton(
          key: const ValueKey('sentence-next'),
          onPressed: _next,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            shape: const StadiumBorder(),
            backgroundColor: Washi.ink,
          ),
          child: Text(
            _index >= _order.length - 1 ? '결과 보기' : '다음 문제',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }

  Widget _buildFinished() {
    final total = _order.length;
    final perfect = _score == total;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          HankoBadge(text: perfect ? '満点' : '済', color: Washi.shu, size: 88, filled: true),
          const SizedBox(height: 16),
          Text(
            '$total문제 중 $_score문제 정답',
            key: const ValueKey('sentence-score'),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Washi.ink),
          ),
          const SizedBox(height: 20),
          if (_wrong.isNotEmpty)
            FilledButton(
              key: const ValueKey('sentence-retry-wrong'),
              onPressed: () => setState(() => _start(List<SentenceItem>.of(_wrong))),
              style: FilledButton.styleFrom(shape: const StadiumBorder(), backgroundColor: Washi.shu),
              child: Text('틀린 ${_wrong.length}문제 다시 풀기'),
            ),
          const SizedBox(height: 8),
          OutlinedButton(
            key: const ValueKey('sentence-retry-all'),
            onPressed: () => setState(() => _start(widget.items)),
            style: OutlinedButton.styleFrom(shape: const StadiumBorder(), foregroundColor: Washi.ink),
            child: const Text('처음부터 다시'),
          ),
        ],
      ),
    );
  }
}
