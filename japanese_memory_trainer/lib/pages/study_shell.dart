import 'package:kioku_japanese/widgets/study_illustration.dart';
import 'package:flutter/material.dart';
import 'package:kioku_japanese/config.dart';
import 'package:kioku_japanese/data/study_store.dart';
import 'package:kioku_japanese/data/listening_bank.dart';
import 'package:kioku_japanese/models/word_catalog.dart';
import 'package:kioku_japanese/pages/grade_list_page.dart';
import 'package:kioku_japanese/pages/grammar_pages.dart';
import 'package:kioku_japanese/pages/radical_pages.dart';
import 'package:kioku_japanese/pages/hyakupa_pages.dart';
import 'package:kioku_japanese/pages/story_pages.dart';
import 'package:kioku_japanese/pages/jlpt_listening_pages.dart';
import 'package:kioku_japanese/pages/jlpt_n4_mock_pages.dart';
import 'package:kioku_japanese/pages/n4_wordbook_pages.dart';
import 'package:kioku_japanese/pages/category_list_page.dart';
import 'package:kioku_japanese/pages/daily_recall_page.dart';
import 'package:kioku_japanese/pages/favorites_page.dart';
import 'package:kioku_japanese/pages/news_pages.dart';
import 'package:kioku_japanese/pages/listening_page.dart';
import 'package:kioku_japanese/pages/bunka_reading_pages.dart';
import 'package:kioku_japanese/pages/screen_japanese_pages.dart';
import 'package:kioku_japanese/pages/sentence_building_pages.dart';
import 'package:kioku_japanese/pages/theme_listening_page.dart';
import 'package:kioku_japanese/services/listening_store.dart';
import 'package:kioku_japanese/services/news_service.dart';
import 'package:kioku_japanese/widgets/study_widgets.dart';

class StudyShell extends StatefulWidget {
  const StudyShell(
      {super.key,
      required this.catalog,
      required this.store,
      required this.listening,
      required this.news,
      required this.speakJapanese,
      required this.speakKorean,
      required this.speakListening,
      required this.stop,
      this.speakListeningAs});
  final WordCatalog catalog;
  final StudyStore store;
  final ListeningStore listening;
  final NewsRepository news;
  final Future<void> Function(String) speakJapanese, speakKorean;
  final ListeningVoice speakListening;
  final ListeningPitchVoice? speakListeningAs;
  final Future<void> Function() stop;
  @override
  State<StudyShell> createState() => _StudyShellState();
}

class _StudyShellState extends State<StudyShell> {
  int _tab = 0;
  Future<void> _open(Widget page) async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => page));
    if (mounted) setState(() {});
  }

  Widget _words() => GradeListPage(
      catalog: widget.catalog,
      store: widget.store,
      speakJapanese: widget.speakJapanese,
      speakKorean: widget.speakKorean,
      stopSpeaking: widget.stop);
  Widget _listening() => ListeningPage(
      store: widget.listening,
      speak: widget.speakListening,
      speakAs: widget.speakListeningAs,
      stop: widget.stop);
  Widget _reading() => NewsListPage(
      repository: widget.news, speakJapanese: widget.speakJapanese);
  Future<void> _listenNext() async {
    final lesson = widget.listening.nextLesson;
    await widget.listening.start(lesson.id);
    if (!mounted) return;
    await _open(ListeningExercisePage(
        lesson: lesson,
        store: widget.listening,
        speak: widget.speakListening,
        speakAs: widget.speakListeningAs,
        stop: widget.stop));
  }

  Future<void> _wordPractice() async {
    final dueIds = widget.store.dueIds();
    final candidates =
        widget.catalog.allWords.where((w) => dueIds.contains(w.id)).toList();
    final wrong = widget.store.wrongIds;
    candidates.sort((a, b) {
      final weak = (wrong.contains(b.id) ? 1 : 0)
          .compareTo(wrong.contains(a.id) ? 1 : 0);
      return weak != 0
          ? weak
          : widget.store.dueAt(a.id).compareTo(widget.store.dueAt(b.id));
    });
    final due = candidates.take(5).toList();
    if (due.isNotEmpty) {
      await _open(DailyRecallPage(
          words: due,
          store: widget.store,
          speakJapanese: widget.speakJapanese));
    } else {
      await _open(CategoryListPage(
          grade: widget.catalog.availableGrades.contains('1학년') ? '1학년' : 'N4',
          catalog: widget.catalog,
          store: widget.store,
          speakJapanese: widget.speakJapanese,
          speakKorean: widget.speakKorean,
          stopSpeaking: widget.stop));
    }
  }

  Future<void> _routine() async {
    await _wordPractice();
    if (!mounted) return;
    await _listenNext();
    if (!mounted) return;
    await _open(_reading());
  }

  Widget _screen() => ScreenMovieListPage(
      speakJapanese: widget.speakJapanese, stop: widget.stop);

  /// 2026-10-06 학습 카테고리 목록. 메뉴가 늘어나면 여기 한 줄씩 추가한다.
  List<_Category> get _categories => [
        _Category('words', '단어', 'JLPT 단어', '급수 → 품사 → 챕터 학습',
            Icons.style_rounded, Washi.shu, () => _open(_words())),
        _Category(
            'n4-wordbook',
            '단어',
            'N4 단어장 30일',
            '원어민 음성 · 자동 학습 · 사지선다',
            Icons.record_voice_over_rounded,
            const Color(0xFF4F8F5B),
            () => _open(N4WordbookHomePage(speakJapanese: widget.speakJapanese)),
            badge: 'NEW'),
        // 2026-10-11 기본 부수: 그림(획순)·이야기·퀴즈·간격 복습으로 확실하게.
        _Category(
            'radicals',
            '한자',
            '기본 부수 97',
            '쪼개서 외우는 한자의 부품 · 12과',
            Icons.extension_rounded,
            radicalColor,
            () => _open(RadicalHomePage(speakJapanese: widget.speakJapanese)),
            badge: 'NEW'),
        _Category('recall', '단어', '오늘의 복습', '기억이 흐려질 때 다시 보기',
            Icons.replay_rounded, Washi.yamabuki, _wordPractice),
        _Category(
            'grammar',
            '문법',
            '일본어 고급 문법',
            '표현 · 활용 · 예문 · 퀴즈 30강',
            Icons.account_tree_rounded,
            const Color(0xFF3D5A98),
            () => _open(GrammarListPage(
                speakJapanese: widget.speakJapanese, stop: widget.stop)),
            badge: 'NEW'),
        // 2026-10-16 N4·N3 문장 만들기: 빈칸 고르기 → 조각 배열 → 듣고 배열(자판 없이).
        _Category(
            'sentence-building',
            '문법',
            '문장 만들기 N4·N3',
            '문법 24개 · 96문장 · 터치로 조립',
            Icons.extension_rounded,
            sbColor,
            () => _open(SentenceBuildingHomePage(speak: widget.speakJapanese)),
            badge: 'NEW'),
        // 2026-10-11 백퍼 일본어 회화 456: 원어민 음성 + 대화문 + 쉐도잉 + 퀴즈.
        _Category(
            'hyakupa',
            '회화',
            '백퍼 일본어 회화',
            '원어민 음성 · 회화체 표현 456',
            Icons.record_voice_over_rounded,
            hyakupaColor,
            () => _open(const HyakupaHomePage()),
            badge: 'NEW'),
        _Category('listening', '듣기', 'N4 청해', '${n4ListeningLessons.length}문제 · 듣고 답하고 따라 읽기',
            Icons.headphones_rounded, Washi.sora, () => _open(_listening()),
            badge: 'UP'),
        _Category(
            'theme-listening',
            '듣기',
            '테마별 기초 청취',
            '원어민 대화 25강',
            Icons.graphic_eq_rounded,
            Washi.fuji,
            () => _open(ThemeListeningPage(
                speak: widget.speakListening, stop: widget.stop))),
        _Category(
            'jlpt-n5',
            '듣기',
            'N5 청해',
            '실전 2회 + 모의고사 2회 · 96문제',
            Icons.quiz_rounded,
            const Color(0xFFCF7A93),
            () => _open(const JlptListeningHomePage()),
            badge: 'NEW'),
        _Category(
            'jlpt-n4-mock',
            '시험',
            'N4 모의고사',
            '문자·어휘 · 문법 · 독해 2회분',
            Icons.assignment_rounded,
            const Color(0xFF6B5BAF),
            () => _open(const JlptN4MockHomePage()),
            badge: 'NEW'),
        _Category('reading', '읽기', '하루의 일기', '매일 한 편 · 365편',
            Icons.auto_stories_rounded, Washi.sakura, () => _open(_reading())),
        _Category('bunka', '읽기', '문화 독해', '원어민 낭독 40강',
            Icons.menu_book_rounded, Washi.wakatake,
            () => _open(const BunkaReadingListPage())),
        _Category('screen', '영상', '스크린 일본어', '영화 3편 · 115강',
            Icons.movie_filter_rounded, Washi.night, () => _open(_screen()),
            badge: 'NEW'),
        // 2026-10-14 N4 이야기 극장: 직접 쓴 N4 단편 10편(전체·문장 듣기, 해석, 단어, 문법, 문제).
        _Category(
            'story',
            '읽기',
            'N4 이야기 극장',
            '재미있는 단편 10편 · 듣기 · 단어 · 문법',
            Icons.theater_comedy_rounded,
            storyColor,
            () => _open(StoryListPage(
                speak: widget.speakListening, stop: widget.stop)),
            badge: 'NEW'),
      ];

  @override
  Widget build(BuildContext context) => Scaffold(
        body: switch (_tab) {
          1 => _learn(),
          2 => _records(),
          _ => _today()
        },
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (index) {
            widget.stop();
            setState(() => _tab = index);
          },
          height: 68,
          backgroundColor: Washi.card,
          surfaceTintColor: Colors.transparent,
          indicatorColor: Washi.shu.withValues(alpha: 0.13),
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.wb_sunny_outlined),
                selectedIcon: Icon(Icons.wb_sunny_rounded, color: Washi.shu),
                label: '오늘'),
            NavigationDestination(
                icon: Icon(Icons.grid_view_outlined),
                selectedIcon: Icon(Icons.grid_view_rounded, color: Washi.shu),
                label: '학습'),
            NavigationDestination(
                icon: Icon(Icons.insights_outlined),
                selectedIcon: Icon(Icons.insights_rounded, color: Washi.shu),
                label: '기록'),
          ],
        ),
      );

  /// 2026-10-06 학습 탭: 분야별(단어·듣기·읽기·영상) 카테고리 격자.
  Widget _learn() {
    final groups = <String, List<_Category>>{};
    for (final c in _categories) {
      (groups[c.group] ??= []).add(c);
    }
    return Scaffold(
      appBar: washiAppBar(title: '학습', subtitle: '오늘은 무엇을 공부할까요?'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 28),
        children: [
          for (final entry in groups.entries) ...[
            SectionTitle(entry.key, trailing: '${entry.value.length}개'),
            const SizedBox(height: 10),
            _grid(entry.value),
            const SizedBox(height: 22),
          ],
        ],
      ),
    );
  }

  Widget _grid(List<_Category> items) => LayoutBuilder(builder: (context, c) {
        final columns = c.maxWidth >= 560 ? 3 : 2;
        final width = (c.maxWidth - 12 * (columns - 1)) / columns;
        return Wrap(spacing: 12, runSpacing: 12, children: [
          for (final item in items)
            SizedBox(
              width: width,
              child: CategoryTile(
                key: ValueKey('category-${item.id}'),
                title: item.title,
                subtitle: item.subtitle,
                icon: item.icon,
                color: item.color,
                badge: item.badge,
                onTap: item.onTap,
              ),
            ),
        ]);
      });

  Widget _today() {
    final all = widget.catalog.allWords;
    final learnedIds = widget.store.learnedIds;
    final dueIds = widget.store.dueIds();
    final learned = all.where((w) => learnedIds.contains(w.id)).length;
    final due = all.where((w) => dueIds.contains(w.id)).length;
    final now = DateTime.now();
    const weekdays = ['月', '火', '水', '木', '金', '土', '日'];
    return Scaffold(
      appBar: AppBar(
          // 2026-10-17 메인 화면 제목 아래에 앱 버전 표시.
          title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('하루 일본어',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22)),
                Text('v$appVersion',
                    key: const ValueKey('app-version'),
                    style: const TextStyle(fontSize: 11.5, color: Washi.inkSoft)),
              ]),
          actions: [
            IconButton(
                tooltip: '도움말',
                onPressed: () => showHelpDialog(context),
                icon: const Icon(Icons.help_outline_rounded))
          ]),
      body: ListView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
          children: [
            Text(
                '${now.month}월 ${now.day}일 (${weekdays[now.weekday - 1]})  ·  今日も一歩ずつ',
                style: const TextStyle(
                    color: Washi.shu,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4)),
            const SizedBox(height: 8),
            const Text('조금씩 듣고,\n오래 기억해요.',
                style: TextStyle(
                    fontSize: 30,
                    height: 1.25,
                    fontWeight: FontWeight.w900,
                    color: Washi.ink)),
            const SizedBox(height: 18),
            const StudyIllustration('study', height: 150),
            const SizedBox(height: 12),
            HeroBanner(
              colors: const [Color(0xFF26304F), Color(0xFF3B3463)],
              icon: Icons.timelapse_rounded,
              eyebrow: 'DAILY PRACTICE',
              title: '오늘의 10분 학습',
              subtitle: '단어 3분  →  청해 4분  →  읽기 3분\n부담 없이 시작하는 하루의 일본어',
              action: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                      key: const ValueKey('start-daily-routine'),
                      onPressed: _routine,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('오늘의 학습 시작'))),
            ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                  child: _metric('학습한 단어', '$learned / ${all.length}',
                      Icons.style_outlined)),
              const SizedBox(width: 12),
              Expanded(
                  child: _metric('오늘 청해', '${widget.listening.todayCount}개',
                      Icons.headphones_rounded))
            ]),
            const SizedBox(height: 24),
            SectionTitle('카테고리',
                trailing: '${_categories.length}개 메뉴'),
            const SizedBox(height: 12),
            SizedBox(
              height: 92,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length + 1,
                separatorBuilder: (context, index) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  if (i == _categories.length) {
                    return _shortcut('전체 보기', Icons.grid_view_rounded,
                        Washi.inkSoft, () => setState(() => _tab = 1));
                  }
                  final c = _categories[i];
                  return _shortcut(c.title, c.icon, c.color, c.onTap,
                      key: ValueKey('shortcut-${c.id}'));
                },
              ),
            ),
            const SizedBox(height: 18),
            _featureScreen(),
            const SizedBox(height: 24),
            const SectionTitle('내 페이스로 이어가기'),
            const SizedBox(height: 12),
            _action('N4 청해 이어서 듣기', widget.listening.nextLesson.title,
                Icons.graphic_eq_rounded, _listenNext,
                key: const ValueKey('continue-listening'), color: Washi.sora),
            const SizedBox(height: 10),
            _action(
                '오늘의 단어 복습',
                due > 0 ? '$due개 · 뜻·발음·듣기·한자 따로 복습' : '학습 탭의 JLPT 단어에서 시작해요',
                Icons.replay_rounded,
                _wordPractice,
                color: Washi.yamabuki),
            const SizedBox(height: 10),
            _action('하루의 일기', '문장 듣기 · 단어 뜻 · 읽기 문제',
                Icons.auto_stories_outlined, () => _open(_reading()),
                key: const ValueKey('open-news'), color: Washi.sakura),
            const SizedBox(height: 24),
            _week(),
          ]),
    );
  }

  Widget _shortcut(String label, IconData icon, Color color, VoidCallback onTap,
          {Key? key}) =>
      SizedBox(
        key: key,
        width: 76,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Column(children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Washi.card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Washi.line),
                boxShadow: [
                  BoxShadow(
                      color: Washi.ink.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4))
                ],
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 6),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
          ]),
        ),
      );

  /// 2026-10-06 새 카테고리 소개 카드(스크린 일본어).
  Widget _featureScreen() => Material(
        color: Colors.transparent,
        child: InkWell(
          key: const ValueKey('feature-screen'),
          borderRadius: BorderRadius.circular(24),
          onTap: () => _open(_screen()),
          child: Ink(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                  colors: [Color(0xFFF2876B), Color(0xFF8B6CD9)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
            ),
            child: Row(children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16)),
                child: const Icon(Icons.movie_filter_rounded,
                    color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('NEW · 스크린 일본어',
                          style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5)),
                      SizedBox(height: 2),
                      Text('영화 대사로 배우는 진짜 회화',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w800)),
                      SizedBox(height: 2),
                      Text('대사 듣기 · 해석 · 표현 · 퀴즈',
                          style: TextStyle(color: Colors.white70, fontSize: 12.5)),
                    ]),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white),
            ]),
          ),
        ),
      );

  Widget _metric(String label, String value, IconData icon) => PaperCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        IconBadge(icon: icon, color: Washi.shu, size: 38),
        const SizedBox(height: 10),
        Text(label, style: const TextStyle(color: Washi.inkSoft, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800))
      ]));
  Widget _action(
          String title, String subtitle, IconData icon, VoidCallback action,
          {Key? key, Color color = Washi.shu}) =>
      PaperCard(
          key: key,
          onTap: action,
          child: Row(children: [
            IconBadge(icon: icon, color: color),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style:
                          const TextStyle(color: Washi.inkSoft, fontSize: 13))
                ])),
            const Icon(Icons.chevron_right_rounded, color: Washi.inkSoft)
          ]));
  Widget _week() {
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final days = widget.listening.days;
    return PaperCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('이번 주 청해 기록',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      const SizedBox(height: 16),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        for (var i = 0; i < 7; i++)
          Column(children: [
            Text(['월', '화', '수', '목', '금', '토', '일'][i],
                style: const TextStyle(color: Washi.inkSoft)),
            const SizedBox(height: 8),
            Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: days.contains(ListeningStore.dateKey(
                            monday.add(Duration(days: i))))
                        ? Washi.shu
                        : Washi.line.withValues(alpha: 0.5)),
                child: days.contains(
                        ListeningStore.dateKey(monday.add(Duration(days: i))))
                    ? const Icon(Icons.check_rounded,
                        size: 18, color: Colors.white)
                    : null)
          ])
      ]),
      const SizedBox(height: 12),
      const Text('청해 문제에 답하면 오늘의 기록이 남아요.',
          style: TextStyle(fontSize: 12, color: Washi.inkSoft)),
    ]));
  }

  Widget _records() {
    final all = widget.catalog.allWords;
    final learnedIds = widget.store.learnedIds;
    final learned = all.where((w) => learnedIds.contains(w.id)).length;
    return Scaffold(
        appBar: washiAppBar(title: '나의 기록', subtitle: '작은 공부가 쌓이는 곳'),
        body: ListView(padding: const EdgeInsets.all(22), children: [
          _week(),
          const SizedBox(height: 16),
          _metric(
              'N4 청해 정답',
              '${widget.listening.correctCount} / ${n4ListeningLessons.length}',
              Icons.headphones_rounded),
          const SizedBox(height: 12),
          _metric('학습한 단어', '$learned / ${all.length}', Icons.style_outlined),
          const SizedBox(height: 12),
          _action('다시 들을 청해', '복습할 문제 ${widget.listening.dueCount}개',
              Icons.history_rounded, () => _open(_listening())),
          const SizedBox(height: 12),
          _action(
              '즐겨찾기 단어',
              '${widget.store.favoriteIds.length}개를 모았어요',
              Icons.star_outline_rounded,
              () => _open(FavoritesPage(
                  catalog: widget.catalog,
                  store: widget.store,
                  speakJapanese: widget.speakJapanese))),
        ]));
  }
}


/// 2026-10-06 학습 카테고리 한 칸.
class _Category {
  const _Category(this.id, this.group, this.title, this.subtitle, this.icon,
      this.color, this.onTap,
      {this.badge});
  final String id, group, title, subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String? badge;
}
