import 'package:flutter/material.dart';
import 'package:kioku_japanese/data/study_store.dart';
import 'package:kioku_japanese/pages/chapter_page.dart';
import 'package:kioku_japanese/models/vocabulary.dart';
import 'package:kioku_japanese/models/word_catalog.dart';
import 'package:kioku_japanese/widgets/study_widgets.dart';
import 'package:kioku_japanese/widgets/word_row.dart';

/// 2026-09-27 ☆로 표시한 단어만 모아 보는 화면이다.
class FavoritesPage extends StatefulWidget {
  const FavoritesPage({
    super.key,
    required this.catalog,
    required this.store,
    required this.speakJapanese,
    this.speakKorean,
    this.stopSpeaking,
  });

  final WordCatalog catalog;
  final StudyStore store;
  final Future<void> Function(String text) speakJapanese;
  final Future<void> Function(String text)? speakKorean;
  final Future<void> Function()? stopSpeaking;

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  @override
  Widget build(BuildContext context) {
    final favorites = widget.store.favoriteIds;
    final learned = widget.store.learnedIds;
    final words = widget.catalog.allWords.where((word) => favorites.contains(word.id)).toList();
    return Scaffold(
      backgroundColor: Washi.paper,
      appBar: washiAppBar(title: '중요 단어', subtitle: '${words.length}단어', actions: [
        IconButton(
          key: const ValueKey('study-important-words'),
          tooltip: '중요 단어 학습',
          icon: const Icon(Icons.school_outlined),
          onPressed: words.isEmpty ? null : () async {
            await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ChapterPage(
              chapter: Chapter(grade: words.first.jlptLevel, category: words.first.wordType,
                  number: 1, words: List.of(words)),
              catalog: widget.catalog,
              store: widget.store,
              speakJapanese: widget.speakJapanese,
              speakKorean: widget.speakKorean,
              stopSpeaking: widget.stopSpeaking,
              initialStudy: true,
              titleOverride: '중요 단어 학습',
            )));
            if (mounted) setState(() {});
          },
        ),
      ]),
      body: words.isEmpty
          ? const Center(child: Text('아직 즐겨찾기한 단어가 없습니다.\n목록에서 ☆를 눌러 추가해 보세요.', textAlign: TextAlign.center))
          : Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: SizedBox(width: double.infinity, child: FilledButton.icon(
                  key: const ValueKey('start-important-study'),
                  onPressed: () async {
                    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ChapterPage(
                      chapter: Chapter(grade: words.first.jlptLevel, category: words.first.wordType, number: 1, words: List.of(words)),
                      catalog: widget.catalog, store: widget.store,
                      speakJapanese: widget.speakJapanese, speakKorean: widget.speakKorean,
                      stopSpeaking: widget.stopSpeaking, initialStudy: true,
                      titleOverride: '중요 단어 학습',
                    )));
                    if (mounted) setState(() {});
                  },
                  icon: const Icon(Icons.school_outlined),
                  label: Text('중요 단어 ${words.length}개 학습하기'),
                )),
              ),
              // 2026-10-19 중요 단어를 챕터별로 묶어, 챕터 단위로 나눠 학습할 수 있게 한다.
              Expanded(child: ListView(
                padding: const EdgeInsets.only(top: 4, bottom: 16),
                children: [
                  for (final group in _groups(favorites)) ...[
                    _groupHeader(group),
                    for (final word in group.words)
                      WordRow(
                        key: ValueKey('fav-row-${word.id}'),
                        number: group.chapter.words.indexOf(word) + 1,
                        word: word,
                        favorite: true,
                        learned: learned.contains(word.id),
                        compact: true,
                        store: widget.store,
                        speakJapanese: widget.speakJapanese,
                        onToggleFavorite: () async {
                          await widget.store.toggleFavorite(word.id);
                          if (mounted) setState(() {});
                        },
                      ),
                  ],
                ],
              )),
          ]),
    );
  }

  /// 2026-10-19 중요 단어가 들어 있는 챕터를 급수·품사·챕터 순서로 모은다(단어는 처음 나온 챕터에만 둔다).
  List<_ChapterGroup> _groups(Set<String> favorites) {
    final groups = <_ChapterGroup>[];
    final seen = <String>{};
    for (final grade in widget.catalog.availableGrades) {
      for (final category in widget.catalog.categoriesOf(grade)) {
        for (final chapter in widget.catalog.chaptersOf(grade, category)) {
          final words = chapter.words
              .where((w) => favorites.contains(w.id) && seen.add(w.id))
              .toList();
          if (words.isNotEmpty) groups.add(_ChapterGroup(chapter, words));
        }
      }
    }
    return groups;
  }

  Widget _groupHeader(_ChapterGroup group) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 4),
        child: Row(children: [
          const Icon(Icons.star_rounded, size: 18, color: Color(0xFFE0A526)),
          const SizedBox(width: 6),
          Expanded(
              child: Text('${group.chapter.title} · ${group.words.length}개',
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Washi.ink))),
          TextButton.icon(
            key: ValueKey(
                'fav-chapter-study-${group.chapter.grade}-${group.chapter.category}-${group.chapter.number}'),
            onPressed: () async {
              await Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => ChapterPage(
                  chapter: group.chapter,
                  catalog: widget.catalog,
                  store: widget.store,
                  speakJapanese: widget.speakJapanese,
                  speakKorean: widget.speakKorean,
                  stopSpeaking: widget.stopSpeaking,
                  initialImportantOnly: true,
                ),
              ));
              if (mounted) setState(() {});
            },
            icon: const Icon(Icons.school_outlined, size: 18),
            label: const Text('학습'),
          ),
        ]),
      );
}

class _ChapterGroup {
  _ChapterGroup(this.chapter, this.words);
  final Chapter chapter;
  final List<Vocabulary> words;
}
