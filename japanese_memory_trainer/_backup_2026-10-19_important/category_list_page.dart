import 'package:kioku_japanese/widgets/chapter_art.dart';
import 'package:flutter/material.dart';
import 'package:kioku_japanese/data/study_store.dart';
import 'package:kioku_japanese/models/word_catalog.dart';
import 'package:kioku_japanese/pages/chapter_page.dart';
import 'package:kioku_japanese/widgets/study_widgets.dart';

/// 2026-09-27 급수 화면: 품사(名詞·動詞·副詞 …)를 2열 카드로 보여준다.
class CategoryListPage extends StatefulWidget {
  const CategoryListPage({
    super.key,
    required this.grade,
    required this.catalog,
    required this.store,
    required this.speakJapanese,
    this.speakKorean,
    this.stopSpeaking,
  });

  final String grade;
  final WordCatalog catalog;
  final StudyStore store;
  final Future<void> Function(String text) speakJapanese;

  /// 2026-09-29 자동 학습에서 한국어 뜻을 읽어 줄 함수(없으면 소리 없이 진행)와 음성 중지 함수다.
  final Future<void> Function(String text)? speakKorean;
  final Future<void> Function()? stopSpeaking;

  @override
  State<CategoryListPage> createState() => _CategoryListPageState();
}

class _CategoryListPageState extends State<CategoryListPage> {
  Future<void> _open(Widget page) async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => page));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = GradeColors.of(widget.grade);
    final learned = widget.store.learnedIds;
    final categories = widget.catalog.categoriesOf(widget.grade);
    return Scaffold(
      backgroundColor: Washi.paper,
      appBar: washiAppBar(
          title: widget.grade.contains('학년')
              ? '초등 ${widget.grade}'
              : 'JLPT ${widget.grade}',
          subtitle: colors.nickname),
      body: GridView.count(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.05,
        children: [
          for (final category in categories)
            Builder(builder: (context) {
              final words = widget.catalog.wordsOf(widget.grade, category);
              final count =
                  words.where((word) => learned.contains(word.id)).length;
              return PaperCard(
                key: ValueKey('category-$category'),
                padding: const EdgeInsets.all(14),
                onTap: () => _open(ChapterListPage(
                  grade: widget.grade,
                  category: category,
                  catalog: widget.catalog,
                  store: widget.store,
                  speakJapanese: widget.speakJapanese,
                  speakKorean: widget.speakKorean,
                  stopSpeaking: widget.stopSpeaking,
                )),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                          color: colors.main, shape: BoxShape.circle),
                    ),
                    const Spacer(),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        WordCatalog.categoryLabel(category),
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          color: Washi.ink,
                        ),
                      ),
                    ),
                    Text(category,
                        style: const TextStyle(
                            fontSize: 14, color: Washi.inkSoft)),
                    const SizedBox(height: 10),
                    SlimProgress(
                      ratio: words.isEmpty ? 0 : count / words.length,
                      color: colors.main,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$count / ${words.length}',
                      style:
                          const TextStyle(fontSize: 13, color: Washi.inkSoft),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

/// 2026-09-27 품사 화면: 14단어 챕터를 동그란 진행 링 격자로 보여준다. 다 외운 챕터는 "済" 도장.
class ChapterListPage extends StatefulWidget {
  const ChapterListPage({
    super.key,
    required this.grade,
    required this.category,
    required this.catalog,
    required this.store,
    required this.speakJapanese,
    this.speakKorean,
    this.stopSpeaking,
  });

  final String grade;
  final String category;
  final WordCatalog catalog;
  final StudyStore store;
  final Future<void> Function(String text) speakJapanese;

  /// 2026-09-29 자동 학습에서 한국어 뜻을 읽어 줄 함수(없으면 소리 없이 진행)와 음성 중지 함수다.
  final Future<void> Function(String text)? speakKorean;
  final Future<void> Function()? stopSpeaking;

  @override
  State<ChapterListPage> createState() => _ChapterListPageState();
}

class _ChapterListPageState extends State<ChapterListPage> {
  @override
  Widget build(BuildContext context) {
    final colors = GradeColors.of(widget.grade);
    final learned = widget.store.learnedIds;
    final chapters = widget.catalog.chaptersOf(widget.grade, widget.category);
    final label = WordCatalog.categoryLabel(widget.category);
    return Scaffold(
      backgroundColor: Washi.paper,
      appBar: washiAppBar(
        title: '${widget.grade} · $label',
        subtitle:
            '${chapters.length}개 챕터 · 챕터당 ${widget.catalog.chapterSize}단어',
      ),
      body: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.82,
        ),
        itemCount: chapters.length,
        itemBuilder: (context, index) {
          final chapter = chapters[index];
          final count =
              chapter.words.where((word) => learned.contains(word.id)).length;
          final total = chapter.words.length;
          final done = total > 0 && count >= total;
          return PaperCard(
            key: ValueKey('chapter-${chapter.number}'),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ChapterPage(
                    chapter: chapter,
                    catalog: widget.catalog,
                    store: widget.store,
                    speakJapanese: widget.speakJapanese,
                    speakKorean: widget.speakKorean,
                    stopSpeaking: widget.stopSpeaking,
                  ),
                ),
              );
              if (mounted) setState(() {});
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ChapterArt('vocab', chapter.number, height: 48),
                const SizedBox(height: 4),
                Text(
                  '第${chapter.number}章',
                  style: const TextStyle(fontSize: 13, color: Washi.inkSoft),
                ),
                const SizedBox(height: 6),
                done
                    ? const HankoBadge(
                        text: '済', color: Washi.shu, size: 58, filled: true)
                    : ProgressRing(
                        ratio: total == 0 ? 0 : count / total,
                        color: colors.main,
                        size: 58,
                        child: Text(
                          '${chapter.number}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Washi.ink,
                          ),
                        ),
                      ),
                const SizedBox(height: 6),
                Text(
                  '$count / $total',
                  style: const TextStyle(fontSize: 13, color: Washi.inkSoft),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
