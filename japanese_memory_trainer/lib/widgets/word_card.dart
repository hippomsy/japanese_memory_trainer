import 'package:flutter/material.dart';
import 'package:kioku_japanese/data/kanji_dictionary.dart';
import 'package:kioku_japanese/models/vocabulary.dart';
import 'package:kioku_japanese/widgets/kanji_parts_view.dart';

/// 2026-09-26 신규 단어를 표기/읽기/이미지/뜻/예문 순서로 보여주는 학습 카드다.
class WordCard extends StatelessWidget {
  const WordCard({
    super.key,
    required this.word,
    this.onSpeak,
    this.onSpeakExample,
  });

  final Vocabulary word;
  final VoidCallback? onSpeak;
  final VoidCallback? onSpeakExample;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 2026-10-11 단어 속 한자(중복 없이) — 부품 식과 쪼개 보기 버튼에 쓴다.
    final kanji = <String>[];
    for (final ch in word.japanese.split('')) {
      if (KanjiDictionary.isKanji(ch) && !kanji.contains(ch)) kanji.add(ch);
    }
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: Colors.pink.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    word.japanese,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: '발음 듣기',
                  onPressed: onSpeak,
                  icon: const Icon(Icons.volume_up_rounded),
                ),
              ],
            ),
            Text(
              word.reading,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: AspectRatio(
                aspectRatio: 2,
                child: Image.asset(
                  word.imageAsset,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.pink.shade50,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.image_outlined,
                        size: 72,
                        color: Colors.pinkAccent,
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              word.korean,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            if (kanji.isNotEmpty) ...[
              const SizedBox(height: 6),
              for (final k in kanji)
                Center(child: KanjiPartsInline(k, fontSize: 13.5)),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.pink.shade50,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    word.exampleJapanese,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    word.exampleKorean,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onSpeakExample,
              icon: const Icon(Icons.volume_up_outlined),
              label: const Text('예문 듣기'),
            ),
            if (kanji.isNotEmpty) ...[
              const SizedBox(height: 8),
              FilledButton.tonalIcon(
                key: const ValueKey('word-card-split'),
                onPressed: () => showKanjiPartsSheet(context, word.japanese),
                icon: const Icon(Icons.extension_rounded),
                label: const Text('한자 쪼개 보기'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
