import 'package:flutter/material.dart';
import 'package:kioku_japanese/data/study_store.dart';
import 'package:kioku_japanese/models/word_catalog.dart';
import 'package:kioku_japanese/pages/category_list_page.dart';
import 'package:kioku_japanese/pages/favorites_page.dart';
import 'package:kioku_japanese/pages/daily_recall_page.dart';
import 'package:kioku_japanese/pages/news_pages.dart';
import 'package:kioku_japanese/services/news_service.dart';
import 'package:kioku_japanese/widgets/study_widgets.dart';

/// 2026-09-27 첫 화면: 전체 학습 단어 수와 N1~N5 급수별 진행 상황을 보여준다.
class GradeListPage extends StatefulWidget {
  const GradeListPage({
    super.key,
    required this.catalog,
    required this.store,
    required this.speakJapanese,
    this.speakKorean,
    this.stopSpeaking,
    this.newsRepository,
  });

  final WordCatalog catalog;
  final StudyStore store;
  final Future<void> Function(String text) speakJapanese;

  /// 2026-09-29 자동 학습에서 한국어 뜻을 읽어 줄 함수(없으면 소리 없이 진행)와 음성 중지 함수다.
  final Future<void> Function(String text)? speakKorean;
  final Future<void> Function()? stopSpeaking;

  /// 2026-10-01 쉬운 뉴스 기사 보관소(없으면 뉴스 카드를 숨긴다).
  final NewsRepository? newsRepository;

  @override
  State<GradeListPage> createState() => _GradeListPageState();
}

class _GradeListPageState extends State<GradeListPage> {
  Future<void> _open(Widget page) async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => page));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final learned = widget.store.learnedIds;
    final all = widget.catalog.allWords;
    final totalLearned = all.where((word) => learned.contains(word.id)).length;
    final ratio = all.isEmpty ? 0.0 : totalLearned / all.length;
    final dueIds = widget.store.dueIds();
    final due = all.where((word) => dueIds.contains(word.id)).toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    final wrongIds = widget.store.wrongIds;
    final wrong = all.where((word) => wrongIds.contains(word.id)).toList();

    return Scaffold(
      backgroundColor: Washi.paper,
      // 2026-10-06 학습 탭에서 열리는 화면이 되어 뒤로가기를 왼쪽, 메뉴를 오른쪽에 둔다.
      appBar: AppBar(
        backgroundColor: Washi.paper,
        foregroundColor: Washi.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: Navigator.of(context).canPop() ? const BackButton() : null,
        actions: [
          Builder(
            builder: (context) => IconButton(
              tooltip: '메뉴',
              icon: const Icon(Icons.menu_rounded),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
        ],
      ),
      drawer: _MenuDrawer(
        onFavorites: () {
          Navigator.of(context).pop();
          _open(FavoritesPage(
            catalog: widget.catalog,
            store: widget.store,
            speakJapanese: widget.speakJapanese,
            speakKorean: widget.speakKorean,
            stopSpeaking: widget.stopSpeaking,
          ));
        },
        onHelp: () {
          Navigator.of(context).pop();
          showHelpDialog(context);
        },
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
        children: [
          // 상단: 앱 이름 + 전체 진행 링
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '今日も一歩ずつ',
                      style: TextStyle(
                          fontSize: 14,
                          color: Washi.shu,
                          fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      '하루 일본어',
                      style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          color: Washi.ink),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '학습한 단어',
                      style: TextStyle(
                          fontSize: 14,
                          color: Washi.inkSoft.withValues(alpha: 0.9)),
                    ),
                    Text(
                      '$totalLearned / ${all.length}',
                      key: const ValueKey('total-progress'),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Washi.ink,
                      ),
                    ),
                  ],
                ),
              ),
              ProgressRing(
                ratio: ratio,
                color: Washi.shu,
                size: 96,
                stroke: 9,
                child: Text(
                  '${(ratio * 100).floor()}%',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Washi.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          PaperCard(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('오늘의 복습',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Text(due.isEmpty
                  ? '복습할 단어가 없어요. 챕터에서 먼저 학습해 보세요.'
                  : '복습할 단어 ${due.length}개 · 한 번에 최대 20개'),
              const SizedBox(height: 8),
              FilledButton(
                  key: const ValueKey('start-daily-recall'),
                  onPressed: due.isEmpty
                      ? null
                      : () => _open(DailyRecallPage(
                          words: due.take(20).toList(),
                          store: widget.store,
                          speakJapanese: widget.speakJapanese)),
                  child: const Text('복습 시작')),
              OutlinedButton(
                  key: const ValueKey('start-wrong-recall'),
                  onPressed: wrong.isEmpty
                      ? null
                      : () => _open(DailyRecallPage(
                          words: wrong.take(20).toList(),
                          store: widget.store,
                          speakJapanese: widget.speakJapanese)),
                  child: Text('헷갈린 단어 다시 (${wrong.length}개)')),
            ],
          )),
          if (widget.newsRepository != null) ...[
            const SizedBox(height: 12),
            PaperCard(
              key: const ValueKey('open-news'),
              onTap: () => _open(NewsListPage(
                repository: widget.newsRepository!,
                speakJapanese: widget.speakJapanese,
              )),
              child: const Row(
                children: [
                  HankoBadge(
                      text: '新', color: Washi.shu, size: 46, filled: true),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('하루의 일기',
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Washi.ink)),
                        Text('매일 한 편 · 듣기·번역·문제 · 총 365편',
                            style:
                                TextStyle(fontSize: 13, color: Washi.inkSoft)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: Washi.inkSoft),
                ],
              ),
            ),
          ],
          const SizedBox(height: 22),
          const Text(
            '급수 선택',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Washi.inkSoft),
          ),
          const SizedBox(height: 10),
          // 쉬운 급수(N5)부터 위에 놓는다.
          for (final grade in widget.catalog.availableGrades) ...[
            _gradeCard(grade, learned),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _gradeCard(String grade, Set<String> learned) {
    final words = widget.catalog.wordsOfGrade(grade);
    final count = words.where((word) => learned.contains(word.id)).length;
    final colors = GradeColors.of(grade);
    final ratio = words.isEmpty ? 0.0 : count / words.length;
    return PaperCard(
      key: ValueKey('grade-$grade'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      onTap: () => _open(grade.contains('학년')
          ? ChapterListPage(
              grade: grade,
              category: '한자 어휘',
              catalog: widget.catalog,
              store: widget.store,
              speakJapanese: widget.speakJapanese,
              speakKorean: widget.speakKorean,
              stopSpeaking: widget.stopSpeaking,
            )
          : CategoryListPage(
              grade: grade,
              catalog: widget.catalog,
              store: widget.store,
              speakJapanese: widget.speakJapanese,
              speakKorean: widget.speakKorean,
              stopSpeaking: widget.stopSpeaking,
            )),
      child: Row(
        children: [
          HankoBadge(text: grade, color: colors.main, size: 58),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  grade.contains('학년') ? '초등 $grade' : 'JLPT $grade',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Washi.ink,
                  ),
                ),
                Text(
                  colors.nickname,
                  style: const TextStyle(fontSize: 13, color: Washi.inkSoft),
                ),
                const SizedBox(height: 8),
                SlimProgress(ratio: ratio, color: colors.main),
                const SizedBox(height: 4),
                Text(
                  '$count / ${words.length}',
                  style: const TextStyle(fontSize: 13, color: Washi.inkSoft),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right, color: Washi.inkSoft),
        ],
      ),
    );
  }
}

class _MenuDrawer extends StatelessWidget {
  const _MenuDrawer({required this.onFavorites, required this.onHelp});

  final VoidCallback onFavorites;
  final VoidCallback onHelp;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          children: [
            const ListTile(
              title: Text(
                '하루 일본어',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              subtitle: Text('일본 초등학교 한자 어휘 학습'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.star_outline),
              title: const Text('즐겨찾기 단어'),
              onTap: onFavorites,
            ),
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: const Text('도움말'),
              onTap: onHelp,
            ),
            const Divider(),
            // 2026-09-27 단어 목록(표기·읽기·급수) 원본의 MIT 라이선스 출처를 밝힌다.
            const ListTile(
              dense: true,
              title: Text('단어 데이터 출처'),
              subtitle: Text(
                  'elzup/jlpt-word-list (MIT License)\n한국어 뜻과 예문은 이 앱에서 새로 작성했습니다.'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 2026-09-27 앱 사용 방법 안내 창이다.
Future<void> showHelpDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('도움말'),
      content: const SingleChildScrollView(
        child: Text(
          '아래 메뉴에서 오늘·단어·청해·읽기·기록을 선택하세요. 오늘의 10분 학습은 단어 → 청해 → 읽기로 이어집니다.\n\n'
          '1. 급수(N5~N1)를 고르고, 품사(名詞·動詞 등)를 고르세요.\n'
          '2. 단어는 14개씩 챕터(第1章, 第2章 …)로 나뉘어 있습니다.\n'
          '3. [단어 목록]에서 단어를 누르면 읽기·뜻·예문을 보고 발음을 들을 수 있습니다. '
          '☆를 누르면 즐겨찾기에 추가됩니다.\n'
          '4. [학습] 수동: 뜻을 보고 일본어 단어를 맞힙니다(4지선다 / 글자 조합), 문장 만들기는 챕터 단어로 만든 5문장을 순서대로 맞춥니다.\n'
          '5. [학습] 자동: 일본어 단어를 보여주고 읽어 준 뒤, 카드를 뒤집어 한국어 뜻을 읽어 주며 '
          '다음 단어로 넘어갑니다. ▶/⏸ 로 재생·멈춤, 멈춘 상태에서 카드를 누르면 직접 뒤집을 수 있습니다.\n'
          '6. 첫 화면의 오늘의 복습에서 뜻을 보고 일본어를 떠올린 뒤 정답을 확인하세요. '
          '기억남은 복습 간격이 늘어나고, 헷갈림은 내일, 모름은 10분 뒤 다시 나옵니다. '
          '헷갈린 단어 기록은 앱을 종료해도 유지됩니다.\n'
          '7. 수동 학습에서 한 번 맞힌 단어에는 済 도장이 찍히고 진행률에 반영됩니다. '
          '챕터 화면 위쪽의 ↻ 버튼으로 그 챕터 기록을 초기화할 수 있습니다.\n'
          '8. N4 청해는 먼저 대화를 끝까지 듣고 답을 선택하세요. 답을 제출하면 대본·번역·해설이 열립니다. '
          '천천히 듣거나 문장별로 반복해서 따라 읽을 수 있습니다. 틀린 문제는 다음 날부터 복습 대상이 됩니다. '
          '기기의 일본어 음성이 설치되어 있어야 하며, 소리가 안 나면 휴대폰의 음량과 텍스트 음성 변환 설정을 확인하세요.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('닫기'),
        ),
      ],
    ),
  );
}
