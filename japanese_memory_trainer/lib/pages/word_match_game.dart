import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:kioku_japanese/models/vocabulary.dart';
import 'package:kioku_japanese/widgets/study_widgets.dart';

/// 2026-10-17 챕터 단어 짝맞추기 게임.
/// 일본어 카드와 한국어 카드를 뒤집어 같은 단어끼리 맞춘다.
/// 카드를 뒤집을 때마다 일본어 카드는 일본어 발음, 한국어 카드는 한국어 뜻을 읽어 준다.
class WordMatchGame extends StatefulWidget {
  const WordMatchGame({
    super.key,
    required this.words,
    required this.speakJapanese,
    this.speakKorean,
    this.random,
    this.pairs = 6,
  });

  final List<Vocabulary> words;
  final Future<void> Function(String text) speakJapanese;
  final Future<void> Function(String text)? speakKorean;
  final Random? random;
  final int pairs;

  @override
  State<WordMatchGame> createState() => _WordMatchGameState();
}

class _MatchCard {
  _MatchCard(this.word, this.japanese);
  final Vocabulary word;
  final bool japanese; // true: 일본어 카드, false: 한국어 카드
  bool open = false;
  bool matched = false;
}

const Color _navy = Color(0xFF233A6E);
const Color _gold = Color(0xFFD4B26A);
const Color _jpRed = Color(0xFFC8402F);
const Color _krGreen = Color(0xFF2F7D5B);

/// 괄호 안 보충 설명을 빼고 읽는다. 예: "눈(신체)" → "눈"
String matchSpeakKorean(String korean) =>
    korean.replaceAll(RegExp(r'\s*[\(（][^\)）]*[\)）]'), '').split(RegExp(r'[,，/]')).first.trim();

class _WordMatchGameState extends State<WordMatchGame> {
  late final Random _rnd = widget.random ?? Random();
  List<_MatchCard> _cards = [];
  _MatchCard? _first;
  bool _busy = false;
  bool _sound = true;
  int _tries = 0;
  int _score = 0;
  int _combo = 0;
  int _seconds = 0;
  Timer? _timer;
  bool get _done => _cards.isNotEmpty && _cards.every((c) => c.matched);
  int get _matchedPairs => _cards.where((c) => c.matched).length ~/ 2;
  int get _totalPairs => _cards.length ~/ 2;

  @override
  void initState() {
    super.initState();
    _newGame();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _newGame() {
    _timer?.cancel();
    final pool = [...widget.words]..shuffle(_rnd);
    // 한국어 뜻이 같은 단어가 한 판에 겹치지 않게 고른다.
    final picked = <Vocabulary>[];
    final meanings = <String>{};
    for (final w in pool) {
      if (picked.length >= widget.pairs) break;
      if (meanings.add(w.korean)) picked.add(w);
    }
    _cards = [
      for (final w in picked) ...[_MatchCard(w, true), _MatchCard(w, false)]
    ]..shuffle(_rnd);
    _first = null;
    _busy = false;
    _tries = 0;
    _score = 0;
    _combo = 0;
    _seconds = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _done) return;
      setState(() => _seconds++);
    });
  }

  Future<void> _say(_MatchCard c) async {
    if (!_sound) return;
    try {
      if (c.japanese) {
        await widget.speakJapanese(c.word.reading.isNotEmpty ? c.word.reading : c.word.japanese);
      } else {
        await widget.speakKorean?.call(matchSpeakKorean(c.word.korean));
      }
    } catch (_) {
      // 음성 실패는 게임을 막지 않는다.
    }
  }

  Future<void> _tap(_MatchCard c) async {
    if (_busy || c.open || c.matched) return;
    setState(() => c.open = true);
    _say(c);
    final first = _first;
    if (first == null) {
      _first = c;
      return;
    }
    _first = null;
    _tries++;
    if (first.word.id == c.word.id && first.japanese != c.japanese) {
      _combo++;
      setState(() {
        first.matched = true;
        c.matched = true;
        _score += 100 + (_combo - 1) * 20;
      });
      if (_done) {
        _timer?.cancel();
        setState(() => _score += max(0, 300 - _seconds * 2));
      }
      return;
    }
    _combo = 0;
    _busy = true;
    await Future<void>.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;
    setState(() {
      first.open = false;
      c.open = false;
      _busy = false;
    });
  }

  String get _clock => '${_seconds ~/ 60}:${(_seconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    if (_cards.length < 4) {
      return const Center(
          child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('짝맞추기를 하려면 단어가 2개 이상 있어야 해요.',
                  style: TextStyle(color: Washi.inkSoft))));
    }
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Row(children: [
          _stat('시간', _clock),
          _stat('시도', '$_tries'),
          _stat('짝', '$_matchedPairs/$_totalPairs'),
          _stat('점수', '$_score'),
          IconButton(
            key: const ValueKey('match-sound'),
            tooltip: _sound ? '소리 끄기' : '소리 켜기',
            onPressed: () => setState(() => _sound = !_sound),
            icon: Icon(_sound ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                color: _navy),
          ),
          IconButton(
            key: const ValueKey('match-restart'),
            tooltip: '새 게임',
            onPressed: () => setState(_newGame),
            icon: const Icon(Icons.refresh_rounded, color: _navy),
          ),
        ]),
      ),
      if (_done) _finish(),
      Expanded(
        child: LayoutBuilder(builder: (context, box) {
          const cols = 3;
          final rows = (_cards.length / cols).ceil();
          const gap = 10.0;
          final w = (box.maxWidth - 32 - gap * (cols - 1)) / cols;
          final h = min(w / 0.74, (box.maxHeight - 8 - gap * (rows - 1)) / rows);
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Wrap(spacing: gap, runSpacing: gap, children: [
              for (var i = 0; i < _cards.length; i++)
                SizedBox(
                  width: w,
                  height: max(90, h),
                  child: _FlipCard(
                    key: ValueKey('match-card-$i'),
                    card: _cards[i],
                    onTap: () => _tap(_cards[i]),
                  ),
                ),
            ]),
          );
        }),
      ),
    ]);
  }

  Widget _stat(String label, String value) => Expanded(
        child: Container(
          margin: const EdgeInsets.only(right: 6),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
              color: Washi.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Washi.line)),
          child: Column(children: [
            Text(label, style: const TextStyle(fontSize: 10.5, color: Washi.inkSoft)),
            Text(value,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w900, color: _navy,
                    fontFeatures: [FontFeature.tabularFigures()])),
          ]),
        ),
      );

  Widget _finish() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: Container(
          key: const ValueKey('match-finish'),
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          decoration: BoxDecoration(
              color: _navy, borderRadius: BorderRadius.circular(16)),
          child: Row(children: [
            const Icon(Icons.emoji_events_rounded, color: _gold, size: 30),
            const SizedBox(width: 10),
            Expanded(
              child: Text('모두 맞혔어요! $_clock · 시도 $_tries번 · $_score점',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            ),
            FilledButton(
                style: FilledButton.styleFrom(backgroundColor: _gold, foregroundColor: _navy),
                onPressed: () => setState(_newGame),
                child: const Text('한 판 더')),
          ]),
        ),
      );
}

/// 뒤집히는 카드 한 장.
class _FlipCard extends StatelessWidget {
  const _FlipCard({super.key, required this.card, required this.onTap});
  final _MatchCard card;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final up = card.open || card.matched;
    return GestureDetector(
      onTap: onTap,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: up ? 1 : 0),
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutBack,
        builder: (context, t, _) {
          final angle = t * pi;
          final showFront = angle > pi / 2;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0012)
              ..rotateY(angle),
            child: showFront
                ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(pi),
                    child: _front(),
                  )
                : _back(),
          );
        },
      ),
    );
  }

  Widget _back() => Container(
        decoration: BoxDecoration(
          color: _navy,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 8, offset: Offset(0, 4))],
        ),
        padding: const EdgeInsets.all(6),
        child: Container(
          decoration: BoxDecoration(
              border: Border.all(color: _gold.withValues(alpha: 0.8), width: 1.5),
              borderRadius: BorderRadius.circular(10)),
          alignment: Alignment.center,
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                shape: BoxShape.circle, border: Border.all(color: _gold, width: 1.5)),
            child: const Text('言',
                style: TextStyle(color: _gold, fontSize: 22, fontWeight: FontWeight.w700)),
          ),
        ),
      );

  Widget _front() {
    final w = card.word;
    final jp = card.japanese;
    final color = jp ? _jpRed : _krGreen;
    return Container(
      decoration: BoxDecoration(
        color: jp ? const Color(0xFFFFFBF2) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: card.matched ? _gold : Washi.line, width: card.matched ? 2.5 : 1),
        boxShadow: [
          BoxShadow(
              color: card.matched ? _gold.withValues(alpha: 0.45) : const Color(0x22000000),
              blurRadius: card.matched ? 14 : 6,
              offset: const Offset(0, 3)),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
            child: Text(jp ? '日本語' : '한국어',
                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
          ),
        ),
        Expanded(
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (jp && w.reading.isNotEmpty && w.reading != w.japanese)
                  Text(w.reading,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF9A7B4F))),
                Text(jp ? w.japanese : w.korean,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: jp ? Washi.ink : _krGreen)),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}
