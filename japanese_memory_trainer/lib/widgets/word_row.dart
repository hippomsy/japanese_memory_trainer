import 'package:flutter/material.dart';
import 'package:kioku_japanese/data/kanji_dictionary.dart';
import 'package:kioku_japanese/data/study_store.dart';
import 'package:kioku_japanese/models/vocabulary.dart';
import 'package:kioku_japanese/widgets/kanji_breakdown.dart';
import 'package:kioku_japanese/widgets/study_widgets.dart';
import 'package:kioku_japanese/widgets/word_memo.dart';

/// 2026-09-27 단어 목록 카드 한 장. 누르면 읽기·뜻·예문·발음 듣기가 펼쳐진다.
/// 2026-09-29 단어 아래에 한자 훈음 요약을, 펼치면 한자별 상세 풀이를 보여준다.
/// [compact]이면 뜻까지 한 줄에 보여주는 작은 카드가 된다.
class WordRow extends StatefulWidget {
  const WordRow({
    super.key,
    required this.number,
    required this.word,
    required this.favorite,
    required this.learned,
    required this.compact,
    required this.onToggleFavorite,
    required this.speakJapanese,
    this.accent = Washi.shu,
    this.store,
  });

  final int number;
  final Vocabulary word;
  final bool favorite;
  final bool learned;
  final bool compact;
  final VoidCallback onToggleFavorite;
  final Future<void> Function(String text) speakJapanese;
  final Color accent;

  /// 2026-10-23 넘겨 주면 펼친 카드 아래에 연상 메모 카드를 보여 준다. 없으면 메모 기능을 숨긴다.
  final StudyStore? store;

  @override
  State<WordRow> createState() => _WordRowState();
}

class _WordRowState extends State<WordRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final word = widget.word;
    final compact = widget.compact;
    final kanjiSummary = KanjiDictionary.instance.summary(word.japanese);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: PaperCard(
        radius: 14,
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: compact ? 8 : 12),
        onTap: () => setState(() => _expanded = !_expanded),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 34,
                  child: widget.learned
                      ? const HankoBadge(text: '済', color: Washi.shu, size: 30, filled: true)
                      : Text(
                          '${widget.number}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 15, color: Washi.inkSoft),
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: compact
                      ? Row(
                          children: [
                            Flexible(
                              child: Text(
                                word.japanese,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: Washi.ink,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                word.korean,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.right,
                                style: const TextStyle(fontSize: 14, color: Washi.inkSoft),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              word.japanese,
                              style: const TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w700,
                                color: Washi.ink,
                              ),
                            ),
                            if (word.reading != word.japanese)
                              Text(
                                word.reading,
                                style: const TextStyle(fontSize: 14, color: Washi.inkSoft),
                              ),
                            if (kanjiSummary.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  kanjiSummary,
                                  key: ValueKey('kanji-summary-${word.id}'),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: widget.accent,
                                  ),
                                ),
                              ),
                          ],
                        ),
                ),
                IconButton(
                  key: ValueKey('fav-${word.id}'),
                  tooltip: '즐겨찾기',
                  onPressed: widget.onToggleFavorite,
                  icon: Icon(
                    widget.favorite ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: widget.favorite ? const Color(0xFFE0A526) : Washi.inkSoft,
                    size: compact ? 26 : 30,
                  ),
                ),
              ],
            ),
            if (_expanded) ...[
              const Divider(height: 18, color: Washi.line),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${word.japanese}  【${word.reading}】',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Washi.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          word.korean,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: widget.accent,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(word.exampleJapanese, style: const TextStyle(fontSize: 15, color: Washi.ink)),
                        Text(
                          word.exampleKorean,
                          style: const TextStyle(fontSize: 13, color: Washi.inkSoft),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: '발음 듣기',
                    icon: const Icon(Icons.volume_up_rounded, color: Washi.ink),
                    onPressed: () => widget.speakJapanese(word.reading),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              KanjiBreakdown(word: word, accent: widget.accent),
              if (widget.store != null) ...[
                const SizedBox(height: 12),
                WordMemoTile(
                  store: widget.store!,
                  wordId: word.id,
                  accent: widget.accent,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
