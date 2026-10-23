import 'package:flutter/material.dart';
import 'package:kioku_japanese/data/kanji_dictionary.dart';
import 'package:kioku_japanese/models/vocabulary.dart';
import 'package:kioku_japanese/widgets/kanji_parts_view.dart';
import 'package:kioku_japanese/widgets/study_widgets.dart';

/// 2026-09-29 단어에 들어 있는 한자를 한 글자씩 풀어 보여준다.
/// 훈음(배울 학), 한국 정자, 음독·훈독, 획수·급수, 같은 한자가 들어간 다른 단어까지.
class KanjiBreakdown extends StatelessWidget {
  KanjiBreakdown({super.key, required Vocabulary word, this.accent = Washi.shu, KanjiDictionary? dictionary})
      : japanese = word.japanese,
        wordId = word.id,
        items = null,
        _dictionary = dictionary;

  /// 2026-10-11 다른 단어장(N4 단어장 등)에서도 같은 크기로 쓰기 위한 생성자.
  /// [items]를 주면 그 풀이를 쓰고, 없으면 사전에서 찾는다.
  const KanjiBreakdown.text({
    super.key,
    required this.japanese,
    required this.wordId,
    this.items,
    this.accent = Washi.shu,
    KanjiDictionary? dictionary,
  }) : _dictionary = dictionary;

  final String japanese;
  final String wordId;
  final List<KanjiInfo>? items;
  final Color accent;
  final KanjiDictionary? _dictionary;

  @override
  Widget build(BuildContext context) {
    final dict = _dictionary ?? KanjiDictionary.instance;
    final list = items ?? dict.breakdown(japanese);
    if (list.isEmpty) return const SizedBox.shrink();
    return Column(
      key: ValueKey('kanji-breakdown-$wordId'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            HankoBadge(text: '漢', color: accent, size: 22, filled: true),
            const SizedBox(width: 8),
            const Text(
              '한자 풀이',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Washi.ink),
            ),
            const Spacer(),
            // 2026-10-11 단어 속 한자를 부품으로 쪼개 보는 시트.
            TextButton.icon(
              key: ValueKey('kanji-split-$wordId'),
              onPressed: () => showKanjiPartsSheet(context, japanese, accent: accent),
              icon: const Icon(Icons.extension_rounded, size: 18),
              label: const Text('쪼개 보기'),
              style: TextButton.styleFrom(foregroundColor: accent),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final info in list)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _KanjiTile(
              info: info,
              accent: accent,
              related: dict.relatedWords(info.kanji, excludeId: wordId, excludeJapanese: japanese),
            ),
          ),
      ],
    );
  }
}

class _KanjiTile extends StatelessWidget {
  const _KanjiTile({required this.info, required this.accent, required this.related});

  final KanjiInfo info;
  final Color accent;
  final List<Vocabulary> related;

  @override
  Widget build(BuildContext context) {
    final meta = <String>[
      if (info.strokes != null) '${info.strokes}획',
      if (info.jlpt != null) 'N${info.jlpt}',
    ].join(' · ');
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => showKanjiPartsSheet(context, info.kanji, accent: accent),
      child: Container(
      key: ValueKey('kanji-${info.kanji}'),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Washi.paper,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Washi.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Washi.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: accent, width: 1.6),
            ),
            child: Text(
              info.kanji,
              style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700, color: Washi.ink, height: 1.1),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        info.hunEum,
                        key: ValueKey('kanji-hun-${info.kanji}'),
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: accent),
                      ),
                    ),
                    if (info.koreanForm.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Washi.line),
                          color: Washi.card,
                        ),
                        child: Text(
                          '정자 ${info.koreanForm}',
                          style: const TextStyle(fontSize: 12, color: Washi.inkSoft),
                        ),
                      ),
                    ],
                    const Spacer(),
                    if (meta.isNotEmpty)
                      Text(meta, style: const TextStyle(fontSize: 12, color: Washi.inkSoft)),
                  ],
                ),
                if (info.note.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(info.note, style: const TextStyle(fontSize: 12.5, color: Washi.inkSoft)),
                  ),
                // 2026-10-11 부품 식(亻사람 + 木나무 = 休)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: KanjiPartsInline(info.kanji, fontSize: 12.5),
                ),
                const SizedBox(height: 4),
                if (info.onReadings.isNotEmpty) _readingLine('음독', info.onReadings.join(' · ')),
                if (info.kunReadings.isNotEmpty) _readingLine('훈독', info.kunReadings.join(' · ')),
                if (related.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    related.map((w) => '${w.japanese}(${_short(w.korean)})').join('  '),
                    style: const TextStyle(fontSize: 12.5, color: Washi.ink),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
    );
  }

  static String _short(String korean) {
    final first = korean.split(RegExp(r'[,;/]')).first.trim();
    return first.length > 10 ? '${first.substring(0, 10)}…' : first;
  }

  Widget _readingLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(right: 6, top: 1),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(color: Washi.line, borderRadius: BorderRadius.circular(5)),
            child: Text(label, style: const TextStyle(fontSize: 11, color: Washi.ink)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 14, color: Washi.ink)),
          ),
        ],
      ),
    );
  }
}
