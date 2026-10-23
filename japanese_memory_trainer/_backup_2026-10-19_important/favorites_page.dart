import 'package:flutter/material.dart';
import 'package:kioku_japanese/data/study_store.dart';
import 'package:kioku_japanese/pages/chapter_page.dart';
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
              Expanded(child: ListView.builder(
              padding: const EdgeInsets.only(top: 8),
              itemCount: words.length,
              itemBuilder: (context, index) {
                final word = words[index];
                return WordRow(
                  key: ValueKey('fav-row-${word.id}'),
                  number: index + 1,
                  word: word,
                  favorite: true,
                  learned: learned.contains(word.id),
                  compact: true,
                  speakJapanese: widget.speakJapanese,
                  onToggleFavorite: () async {
                    await widget.store.toggleFavorite(word.id);
                    if (mounted) setState(() {});
                  },
                );
              },
            )),
          ]),
    );
  }
}
