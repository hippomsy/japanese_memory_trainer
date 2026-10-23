import 'package:kioku_japanese/data/kanji_dictionary.dart';
import 'package:kioku_japanese/widgets/kanji_breakdown.dart';
import 'package:kioku_japanese/widgets/kanji_parts_view.dart';
import 'package:kioku_japanese/widgets/chapter_art.dart';
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:kioku_japanese/models/vocabulary.dart';
import 'package:kioku_japanese/pages/word_match_game.dart';
import 'package:kioku_japanese/services/lesson_audio.dart';
import 'package:kioku_japanese/services/n4_wordbook.dart';
import 'package:kioku_japanese/widgets/ruby_text.dart';
import 'package:kioku_japanese/widgets/study_widgets.dart';
import 'package:kioku_japanese/widgets/word_picture.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _n4Color = Color(0xFF4F8F5B); // N4 若竹

/// 2026-10-09 원어민 음성 구간 재생 도우미(N4 단어장 화면들이 함께 쓴다). 재생이 끝날 때까지 기다릴 수 있다.
class N4ClipPlayer {
  N4ClipPlayer(this.audio);
  final LessonAudio audio;
  double speed = 1.0;
  int _generation = 0;

  /// [span]을 재생하고 끝날 때까지 기다린다. 도중에 [stop]/다른 재생이 오면 false.
  Future<bool> play(String asset, AudioSpan span, {bool wait = false}) async {
    final g = ++_generation;
    try {
      await audio.setSpeed(speed);
      await audio.playClip(asset, span.start, span.end);
    } catch (_) {
      return false;
    }
    if (!wait) return true;
    await Future<void>.delayed(
        span.length * (1 / speed) + const Duration(milliseconds: 250));
    return g == _generation;
  }

  Future<void> stop() async {
    _generation++;
    await audio.pause();
  }
}

/// 2026-10-09 「딱! 한권 JLPT 단어장 N4」 DAY 목록.
class N4WordbookHomePage extends StatefulWidget {
  const N4WordbookHomePage(
      {super.key,
      this.audioFactory,
      this.book,
      this.preferences,
      this.speakJapanese});
  final LessonAudio Function()? audioFactory;
  final Future<N4Wordbook>? book;
  final Future<SharedPreferences>? preferences;

  /// 예문 읽기(기기 일본어 TTS). 없으면 예문 듣기 버튼을 숨긴다.
  final Future<void> Function(String)? speakJapanese;

  @override
  State<N4WordbookHomePage> createState() => _N4WordbookHomePageState();
}

class _N4WordbookHomePageState extends State<N4WordbookHomePage> {
  late final Future<(N4Wordbook, N4WordbookProgress)> _data = () async {
    final book = await (widget.book ?? N4Wordbook.load());
    final prefs = await (widget.preferences ?? SharedPreferences.getInstance());
    return (book, N4WordbookProgress(prefs));
  }();

  Future<void> _push(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Washi.paper,
        appBar: washiAppBar(
            title: 'N4 단어장', subtitle: '딱! 한권 JLPT 단어장 N4 · 원어민 음성 30일'),
        body: FutureBuilder<(N4Wordbook, N4WordbookProgress)>(
          future: _data,
          builder: (context, snap) {
            if (snap.hasError) {
              return const Center(child: Text('단어장을 불러오지 못했어요.'));
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final (book, progress) = snap.data!;
            final known = progress.known;
            final wrongIds = progress.wrong;
            final wrongWords =
                book.allWords.where((w) => wrongIds.contains(w.id)).toList();
            final knownCount =
                book.allWords.where((w) => known.contains(w.id)).length;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
              children: [
                const SceneArt('cat_words', height: 145),
                const SizedBox(height: 12),
                HeroBanner(
                  colors: const [Color(0xFF2F5D3A), Color(0xFF4F8F5B)],
                  icon: Icons.record_voice_over_rounded,
                  eyebrow: 'JLPT N4 · 単語',
                  title: '듣고 따라 하며\n30일 완성',
                  subtitle:
                      '${book.days.length}일 · ${book.wordCount}단어 · 외운 단어 $knownCount개',
                  progress: book.wordCount == 0 ? 0 : knownCount / book.wordCount,
                  action: wrongWords.isEmpty
                      ? null
                      : FilledButton.tonalIcon(
                          key: const ValueKey('n4-wrong-quiz'),
                          onPressed: () => _push(N4QuizPage(
                              book: book,
                              progress: progress,
                              words: wrongWords,
                              title: '틀린 단어 퀴즈',
                              audioFactory: widget.audioFactory)),
                          icon: const Icon(Icons.replay_rounded),
                          label: Text('틀린 단어 ${wrongWords.length}개 다시 풀기')),
                ),
                const SizedBox(height: 14),
                _reviewCard(book, progress),
                const SizedBox(height: 20),
                const SectionTitle('DAY 목록', trailing: '단어 · 카드 · 독해 · 퀴즈'),
                const SizedBox(height: 10),
                for (final d in book.days)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _dayTile(book, progress, d, known),
                  ),
                const SizedBox(height: 6),
                const Text(
                    '※ 음성: 「딱! 한권 JLPT 단어장 N4」(시사일본어사) MP3. 단어·뜻은 녹음을 음성 인식으로 받아 적어 정리한 것이라 책 표기와 조금 다를 수 있어요.',
                    style: TextStyle(fontSize: 12, color: Washi.inkSoft, height: 1.6)),
              ],
            );
          },
        ),
      );

  /// 2026-10-10 오늘의 학습: 연속 학습일 · 새 단어 목표 · 복습 → 새 단어 순서로 시작.
  Widget _reviewCard(N4Wordbook book, N4WordbookProgress progress) {
    final now = DateTime.now();
    final due = progress.dueWords(book, now);
    final remaining = progress.remainingNew(now);
    final fresh = progress.nextNewWords(book, remaining);
    final goal = progress.dailyGoal;
    final doneNew = progress.newToday(now);
    final streak = progress.streak(now);
    final longTerm = progress.longTermCount(book.allWords);
    final total = due.length + fresh.length;
    return PaperCard(
      key: const ValueKey('n4-review-card'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const IconBadge(icon: Icons.event_repeat_rounded, color: _n4Color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('오늘의 학습',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
              Text(streak > 0 ? '🔥 $streak일 연속 공부 중' : '오늘부터 연속 기록을 시작해요',
                  style: const TextStyle(fontSize: 12.5, color: Washi.inkSoft)),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _stat('① 복습', due.isEmpty ? '완료 ✓' : '${due.length}개')),
          Expanded(child: _stat('② 새 단어', '$doneNew / $goal')),
          Expanded(child: _stat('장기 기억', '$longTerm개')),
        ]),
        const SizedBox(height: 8),
        SlimProgress(ratio: goal == 0 ? 0 : doneNew / goal, color: _n4Color),
        const SizedBox(height: 10),
        Row(children: [
          const Text('하루 새 단어', style: TextStyle(fontSize: 12.5, color: Washi.inkSoft)),
          const SizedBox(width: 6),
          for (final g in N4WordbookProgress.goalChoices)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: ChoiceChip(
                  key: ValueKey('n4-goal-$g'),
                  label: Text('$g'),
                  visualDensity: VisualDensity.compact,
                  selected: goal == g,
                  onSelected: (_) async {
                    await progress.setDailyGoal(g);
                    if (mounted) setState(() {});
                  }),
            ),
        ]),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
              key: const ValueKey('n4-review-start'),
              style: FilledButton.styleFrom(
                  backgroundColor: _n4Color, minimumSize: const Size.fromHeight(48)),
              onPressed: total == 0
                  ? null
                  : () => _push(N4ReviewPage(
                      words: [...due.take(100), ...fresh],
                      maxNew: fresh.length,
                      progress: progress,
                      audioFactory: widget.audioFactory)),
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(total == 0
                  ? '오늘 할 일 끝! 내일 또 만나요'
                  : due.isEmpty
                      ? '새 단어 ${fresh.length}개 외우기'
                      : '복습 ${due.length > 100 ? 100 : due.length}개 → 새 단어 ${fresh.length}개')),
        ),
        const SizedBox(height: 6),
        const Text('복습이 먼저 나오고, 새 단어는 하루 목표만큼만 열려요. 잊기 직전에 다시 보는 게 오래 기억하는 비결이에요.',
            style: TextStyle(fontSize: 11.5, color: Washi.inkSoft, height: 1.4)),
      ]),
    );
  }

  Widget _stat(String label, String value) => Column(children: [
        Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: _n4Color)),
        Text(label, style: const TextStyle(fontSize: 11.5, color: Washi.inkSoft)),
      ]);

  Widget _dayTile(N4Wordbook book, N4WordbookProgress progress, N4Day d,
      Set<String> known) {
    final k = d.words.where((w) => known.contains(w.id)).length;
    final best = progress.best(d.day);
    return PaperCard(
      key: ValueKey('n4-day-${d.day}'),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      onTap: () => _push(N4DayPage(
          book: book,
          day: d,
          progress: progress,
          audioFactory: widget.audioFactory,
          speakJapanese: widget.speakJapanese)),
      child: Row(children: [
        ChapterArt('n4', d.day, width: 78, height: 65),
        const SizedBox(width: 8),
        HankoBadge(
            text: d.day.toString().padLeft(2, '0'),
            color: _n4Color,
            size: 46,
            filled: k == d.words.length && d.words.isNotEmpty),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('DAY ${d.day.toString().padLeft(2, '0')}  ${d.title}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            Text(
                '${d.titleKorean} · ${d.words.length}단어'
                '${progress.studied(d.day) ? ' · 자동 학습 완료' : ''}',
                style: const TextStyle(fontSize: 12.5, color: Washi.inkSoft)),
            const SizedBox(height: 6),
            SlimProgress(
                ratio: d.words.isEmpty ? 0 : k / d.words.length, color: _n4Color),
          ]),
        ),
        const SizedBox(width: 10),
        Column(children: [
          Text(best == null ? '-' : '$best점',
              style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: best == null ? Washi.inkSoft : _n4Color)),
          const Text('최고', style: TextStyle(fontSize: 10.5, color: Washi.inkSoft)),
        ]),
      ]),
    );
  }
}

/// 2026-10-09 DAY 화면: 단어 · 자동 학습 · 독해. 2026-10-18 마지막 탭을 사지선다 퀴즈에서 단어 게임(카드 짝맞추기)으로 교체.
class N4DayPage extends StatefulWidget {
  const N4DayPage(
      {super.key,
      required this.book,
      required this.day,
      required this.progress,
      this.audioFactory,
      this.speakJapanese,
      this.initialTab = 0});
  final N4Wordbook book;
  final N4Day day;
  final N4WordbookProgress progress;
  final LessonAudio Function()? audioFactory;
  final Future<void> Function(String)? speakJapanese;
  final int initialTab;

  @override
  State<N4DayPage> createState() => _N4DayPageState();
}

class _N4DayPageState extends State<N4DayPage>
    with SingleTickerProviderStateMixin {
  late final LessonAudio _audio = (widget.audioFactory ?? JustLessonAudio.new)();
  late final N4ClipPlayer _player = N4ClipPlayer(_audio);
  final _autoKey = GlobalKey<_AutoStudyViewState>();
  late final TabController _tabs =
      TabController(length: 5, vsync: this, initialIndex: widget.initialTab)
        ..addListener(() {
          if (_tabs.indexIsChanging) {
            _autoKey.currentState?.pause();
            _player.stop();
          }
        });

  @override
  void dispose() {
    _tabs.dispose();
    _player.stop();
    _audio.dispose();
    super.dispose();
  }

  /// 2026-10-10 복습 먼저: 다른 DAY에 복습할 단어가 남아 있으면 새 단어는 잠그고,
  /// 새 단어는 하루 목표만큼만 연다.
  Widget _dayFlashcards(N4Day d) {
    final p = widget.progress, now = DateTime.now();
    final ids = {for (final w in d.words) w.id};
    final otherDue = p.dueWords(widget.book, now).where((w) => !ids.contains(w.id)).length;
    final remaining = p.remainingNew(now);
    String? notice;
    var maxNew = remaining;
    if (otherDue > 0) {
      maxNew = 0;
      notice = '다른 DAY에 복습할 단어가 $otherDue개 있어요. 첫 화면의 「오늘의 학습」으로 복습을 먼저 끝내면 새 단어가 열려요.';
    } else if (remaining == 0) {
      notice = '오늘 새 단어 목표(${p.dailyGoal}개)를 채웠어요. 새 단어는 내일 이어서! 오늘은 복습과 독해로 다지세요.';
    }
    return N4FlashcardView(
        words: d.words, progress: p, player: _player, maxNew: maxNew, notice: notice);
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.day;
    return Scaffold(
      backgroundColor: Washi.paper,
      appBar: AppBar(
        backgroundColor: Washi.paper,
        surfaceTintColor: Colors.transparent,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('DAY ${d.day.toString().padLeft(2, '0')} · ${d.title}',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
          Text('${d.titleKorean} · ${d.words.length}단어',
              style: const TextStyle(fontSize: 13, color: Washi.inkSoft)),
        ]),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: _n4Color,
          indicatorColor: _n4Color,
          tabs: const [
            Tab(key: ValueKey('n4-tab-list'), text: '단어'),
            Tab(key: ValueKey('n4-tab-cards'), text: '암기 카드'),
            Tab(key: ValueKey('n4-tab-auto'), text: '자동 학습'),
            Tab(key: ValueKey('n4-tab-reading'), text: '독해'),
            Tab(key: ValueKey('n4-tab-game'), text: '단어 게임'),
          ],
        ),
      ),
      body: TabBarView(controller: _tabs, children: [
        _WordListView(
            day: d,
            player: _player,
            progress: widget.progress,
            speakJapanese: widget.speakJapanese),
        _dayFlashcards(d),
        _AutoStudyView(
            key: _autoKey, day: d, player: _player, progress: widget.progress),
        _ReadingView(
            day: d,
            progress: widget.progress,
            player: _player,
            speakJapanese: widget.speakJapanese),
        _N4GameView(day: d, player: _player),
      ]),
    );
  }
}

/// 2026-10-18 DAY 단어로 일본어·한국어 카드 짝맞추기를 한다.
/// 카드를 뒤집을 때 일본어 카드는 원어민 일본어 녹음, 한국어 카드는 원어민 한국어 녹음 구간을 재생한다.
class _N4GameView extends StatelessWidget {
  const _N4GameView({required this.day, required this.player});
  final N4Day day;
  final N4ClipPlayer player;

  @override
  Widget build(BuildContext context) {
    final byJapanese = <String, N4Word>{};
    final byKorean = <String, N4Word>{};
    final vocab = <Vocabulary>[];
    for (final w in day.words) {
      byJapanese.putIfAbsent(w.reading.isNotEmpty ? w.reading : w.japanese, () => w);
      byKorean.putIfAbsent(matchSpeakKorean(w.korean), () => w);
      vocab.add(Vocabulary(
          id: w.id,
          japanese: w.japanese,
          reading: w.reading,
          korean: w.korean,
          exampleJapanese: w.exampleJapanese ?? '',
          exampleKorean: w.exampleKorean ?? '',
          jlptLevel: 'N4',
          wordType: '',
          frequencyRank: 0));
    }
    return WordMatchGame(
        key: ValueKey('n4-word-game-${day.day}'),
        words: vocab,
        speakJapanese: (text) async {
          final w = byJapanese[text];
          if (w != null) await player.play(w.audio, w.jaSpan);
        },
        speakKorean: (text) async {
          final w = byKorean[text];
          final span = w?.koSpan;
          if (w != null && span != null) await player.play(w.audio, span);
        });
  }
}

/// 단어 목록: 단어마다 일본어 🔊 · 한국어 뜻 🔊 · 예문.
class _WordListView extends StatefulWidget {
  const _WordListView(
      {required this.day,
      required this.player,
      required this.progress,
      this.speakJapanese});
  final N4Day day;
  final N4ClipPlayer player;
  final N4WordbookProgress progress;
  final Future<void> Function(String)? speakJapanese;
  @override
  State<_WordListView> createState() => _WordListViewState();
}

class _WordListViewState extends State<_WordListView>
    with AutomaticKeepAliveClientMixin {
  bool _hideMeaning = false;
  final _revealed = <String>{};

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final known = widget.progress.known, wrong = widget.progress.wrong;
    final words = widget.day.words;
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
      children: [
        Row(children: [
          const Expanded(
              child: Text('🔊 일본어 발음  ·  🇰🇷 한국어 뜻 (원어민 음성)',
                  style: TextStyle(fontSize: 12.5, color: Washi.inkSoft))),
          FilterChip(
              key: const ValueKey('n4-hide-meaning'),
              label: const Text('뜻 가리기'),
              visualDensity: VisualDensity.compact,
              selected: _hideMeaning,
              onSelected: (v) => setState(() {
                    _hideMeaning = v;
                    _revealed.clear();
                  })),
        ]),
        const SizedBox(height: 8),
        for (var i = 0; i < words.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _row(i, words[i], known.contains(words[i].id),
                wrong.contains(words[i].id)),
          ),
      ],
    );
  }

  Widget _row(int i, N4Word w, bool known, bool wrong) {
    final hidden = _hideMeaning && !_revealed.contains(w.id);
    return PaperCard(
      key: ValueKey('n4-word-${w.id}'),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      onTap: () {
        setState(() => _revealed.add(w.id));
        widget.player.play(w.audio, w.jaSpan);
      },
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        SizedBox(
          width: 24,
          child: Text('${i + 1}',
              style: const TextStyle(color: Washi.inkSoft, fontWeight: FontWeight.w700)),
        ),
        // 2026-10-21 단어 뜻에 맞는 그림(고래 암기장처럼).
        Padding(
          padding: const EdgeInsets.only(right: 10),
          child: WordPicture(wordId: w.id, size: 50),
        ),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (w.hasReading)
              Text(w.reading,
                  style: const TextStyle(fontSize: 12, color: Washi.inkSoft)),
            Row(children: [
              Flexible(
                child: Text(w.japanese,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              ),
              if (known)
                const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: Icon(Icons.check_circle_rounded, size: 16, color: Washi.matcha)),
              if (wrong)
                const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: Icon(Icons.error_rounded, size: 16, color: Washi.shu)),
              const SizedBox(width: 8),
              N4StageDots(stage: widget.progress.stage(w.id)),
            ]),
            Text(hidden ? '눌러서 뜻 보기' : w.korean,
                style: TextStyle(
                    fontSize: 15,
                    color: hidden ? Washi.line : Washi.ink,
                    fontWeight: FontWeight.w600)),
            if (!hidden && w.kanji.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: N4KanjiLine(word: w),
              ),
            if (!hidden && w.exampleJapanese != null) ...[
              const SizedBox(height: 4),
              Row(children: [
                Expanded(
                  child: Text('${w.exampleJapanese}\n${w.exampleKorean ?? ''}',
                      style: const TextStyle(
                          fontSize: 12.5, color: Washi.inkSoft, height: 1.45)),
                ),
                if (widget.speakJapanese != null)
                  IconButton(
                      tooltip: '예문 듣기(TTS)',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => widget.speakJapanese!(w.exampleJapanese!),
                      icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18)),
              ]),
            ],
          ]),
        ),
        SpeakButton(
            key: ValueKey('n4-play-ja-${w.id}'),
            tooltip: '일본어 발음 듣기',
            color: _n4Color,
            onPressed: () => widget.player.play(w.audio, w.jaSpan)),
        if (w.koSpan != null)
          IconButton(
              key: ValueKey('n4-play-ko-${w.id}'),
              tooltip: '한국어 뜻 듣기',
              onPressed: () {
                setState(() => _revealed.add(w.id));
                widget.player.play(w.audio, w.koSpan!);
              },
              icon: const Text('🇰🇷', style: TextStyle(fontSize: 18))),
      ]),
    );
  }
}

/// 자동 학습: 일본어 발음 → (잠깐 생각) → 뜻 공개 + 한국어 음성 → 다음 단어.
class _AutoStudyView extends StatefulWidget {
  const _AutoStudyView(
      {super.key, required this.day, required this.player, required this.progress});
  final N4Day day;
  final N4ClipPlayer player;
  final N4WordbookProgress progress;
  @override
  State<_AutoStudyView> createState() => _AutoStudyViewState();
}

class _AutoStudyViewState extends State<_AutoStudyView>
    with AutomaticKeepAliveClientMixin {
  int _index = 0, _run = 0, _repeat = 1;
  bool _running = false, _showMeaning = false, _koVoice = true, _shuffle = false;
  late List<N4Word> _order = widget.day.words;

  @override
  bool get wantKeepAlive => true;

  N4Word get _word => _order[_index];

  void pause() {
    if (!_running) return;
    _run++;
    widget.player.stop();
    if (mounted) setState(() => _running = false);
  }

  Future<void> _start() async {
    if (_order.isEmpty) return;
    final run = ++_run;
    setState(() => _running = true);
    bool alive() => mounted && run == _run;
    while (alive()) {
      final w = _word;
      setState(() => _showMeaning = false);
      for (var r = 0; r < _repeat; r++) {
        if (!await widget.player.play(w.audio, w.jaSpan, wait: true) || !alive()) return;
        await Future<void>.delayed(const Duration(milliseconds: 500));
        if (!alive()) return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (!alive()) return;
      setState(() => _showMeaning = true);
      if (_koVoice && w.koSpan != null) {
        if (!await widget.player.play(w.audio, w.koSpan!, wait: true) || !alive()) return;
      } else {
        await Future<void>.delayed(const Duration(milliseconds: 1200));
      }
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (!alive()) return;
      if (_index >= _order.length - 1) {
        setState(() => _running = false);
        await widget.progress.markStudied(widget.day.day);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('DAY 자동 학습을 마쳤어요. 퀴즈로 확인해 보세요!')));
        }
        return;
      }
      setState(() => _index++);
    }
  }

  void _go(int delta) {
    final was = _running;
    pause();
    setState(() {
      _index = (_index + delta).clamp(0, _order.length - 1).toInt();
      _showMeaning = false;
    });
    if (was) _start();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_order.isEmpty) return const Center(child: Text('단어가 없어요.'));
    final w = _word;
    return ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 24), children: [
      Row(children: [
        Text('${_index + 1} / ${_order.length}',
            style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(width: 10),
        Expanded(child: SlimProgress(ratio: (_index + 1) / _order.length, color: _n4Color)),
      ]),
      const SizedBox(height: 14),
      PaperCard(
        key: const ValueKey('n4-auto-card'),
        padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 16),
        onTap: () => setState(() => _showMeaning = !_showMeaning),
        child: Column(children: [
          // 2026-10-21 카드 위 단어 그림.
          WordPicture(wordId: w.id, size: 112),
          const SizedBox(height: 14),
          if (w.hasReading)
            Text(w.reading,
                style: const TextStyle(fontSize: 17, color: Washi.inkSoft)),
          FittedBox(
            child: Text(w.japanese,
                style: const TextStyle(fontSize: 46, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 18),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 250),
            opacity: _showMeaning ? 1 : 0,
            child: Column(children: [
              Text(w.korean,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w800, color: _n4Color)),
              if (w.kanji.isNotEmpty) ...[
                const SizedBox(height: 10),
                N4KanjiTiles(word: w),
              ],
              if (w.exampleJapanese != null) ...[
                const SizedBox(height: 10),
                Text('${w.exampleJapanese}\n${w.exampleKorean ?? ''}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, color: Washi.inkSoft, height: 1.5)),
              ],
            ]),
          ),
          if (!_showMeaning)
            const Text('카드를 누르면 뜻이 보여요',
                style: TextStyle(fontSize: 12, color: Washi.line)),
        ]),
      ),
      const SizedBox(height: 16),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        IconButton.filledTonal(
            key: const ValueKey('n4-auto-prev'),
            onPressed: _index > 0 ? () => _go(-1) : null,
            icon: const Icon(Icons.skip_previous_rounded)),
        const SizedBox(width: 14),
        FilledButton.icon(
            key: const ValueKey('n4-auto-play'),
            style: FilledButton.styleFrom(
                backgroundColor: _n4Color, minimumSize: const Size(150, 52)),
            onPressed: _running ? pause : _start,
            icon: Icon(_running ? Icons.pause_rounded : Icons.play_arrow_rounded),
            label: Text(_running ? '멈춤' : '자동 재생')),
        const SizedBox(width: 14),
        IconButton.filledTonal(
            key: const ValueKey('n4-auto-next'),
            onPressed: _index < _order.length - 1 ? () => _go(1) : null,
            icon: const Icon(Icons.skip_next_rounded)),
      ]),
      const SizedBox(height: 18),
      Wrap(spacing: 8, runSpacing: 6, alignment: WrapAlignment.center, children: [
        for (final s in const [0.8, 1.0])
          ChoiceChip(
              label: Text(s == 1.0 ? '보통 속도' : '천천히'),
              selected: widget.player.speed == s,
              onSelected: (_) => setState(() => widget.player.speed = s)),
        ChoiceChip(
            key: const ValueKey('n4-auto-repeat'),
            label: Text('일본어 $_repeat번'),
            selected: _repeat > 1,
            onSelected: (_) => setState(() => _repeat = _repeat == 1 ? 2 : 1)),
        FilterChip(
            label: const Text('한국어 음성'),
            selected: _koVoice,
            onSelected: (v) => setState(() => _koVoice = v)),
        FilterChip(
            key: const ValueKey('n4-auto-shuffle'),
            label: const Text('섞기'),
            selected: _shuffle,
            onSelected: (v) {
              pause();
              setState(() {
                _shuffle = v;
                _order = v
                    ? ([...widget.day.words]..shuffle(Random()))
                    : widget.day.words;
                _index = 0;
                _showMeaning = false;
              });
            }),
      ]),
      const SizedBox(height: 14),
      const Text('일본어 발음 → 잠깐 떠올리기 → 뜻(한국어 음성) 순서로 자동으로 넘어가요.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Washi.inkSoft)),
    ]);
  }
}

/// 2026-10-09 틀린 단어처럼 여러 DAY에 걸친 단어를 퀴즈로 푸는 화면.
class N4QuizPage extends StatefulWidget {
  const N4QuizPage(
      {super.key,
      required this.book,
      required this.progress,
      required this.words,
      required this.title,
      this.audioFactory});
  final N4Wordbook book;
  final N4WordbookProgress progress;
  final List<N4Word> words;
  final String title;
  final LessonAudio Function()? audioFactory;
  @override
  State<N4QuizPage> createState() => _N4QuizPageState();
}

class _N4QuizPageState extends State<N4QuizPage> {
  late final LessonAudio _audio = (widget.audioFactory ?? JustLessonAudio.new)();
  late final N4ClipPlayer _player = N4ClipPlayer(_audio);

  @override
  void dispose() {
    _player.stop();
    _audio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Washi.paper,
        appBar: washiAppBar(title: widget.title, subtitle: '${widget.words.length}단어 · 사지선다'),
        body: N4QuizView(
            book: widget.book,
            words: widget.words,
            progress: widget.progress,
            player: _player),
      );
}

/// 2026-10-09 사지선다 퀴즈: 일본어→뜻 / 뜻→일본어, 10문제 또는 전체.
class N4QuizView extends StatefulWidget {
  const N4QuizView(
      {super.key,
      required this.book,
      required this.words,
      required this.progress,
      required this.player,
      this.day,
      this.random});
  final N4Wordbook book;
  final List<N4Word> words;
  final N4WordbookProgress progress;
  final N4ClipPlayer player;

  /// DAY 퀴즈면 최고 점수를 저장한다.
  final int? day;
  final Random? random;
  @override
  State<N4QuizView> createState() => _N4QuizViewState();
}

class _N4QuizViewState extends State<N4QuizView>
    with AutomaticKeepAliveClientMixin {
  bool _reverse = false, _all = false;
  List<N4QuizQuestion>? _questions;
  int _index = 0, _correct = 0;
  int? _chosen;
  final _wrong = <N4Word>[];

  @override
  bool get wantKeepAlive => true;

  void _begin([List<N4Word>? only]) {
    final rnd = widget.random ?? Random();
    final pool = [...(only ?? widget.words)]..shuffle(rnd);
    final targets = only != null || _all ? pool : pool.take(10).toList();
    setState(() {
      _questions = buildN4Quiz(widget.book, targets, reverse: _reverse, random: rnd);
      _index = 0;
      _correct = 0;
      _chosen = null;
      _wrong.clear();
    });
    _speakQuestion();
  }

  void _speakQuestion() {
    final q = _questions?[_index];
    if (q == null) return;
    if (!q.reverse) widget.player.play(q.word.audio, q.word.jaSpan);
  }

  Future<void> _choose(int i) async {
    final qs = _questions!;
    if (_chosen != null) return;
    final q = qs[_index];
    final ok = i == q.answer;
    setState(() {
      _chosen = i;
      if (ok) {
        _correct++;
      } else {
        _wrong.add(q.word);
      }
    });
    widget.player.play(q.word.audio, q.word.jaSpan);
    await widget.progress.record(q.word.id, ok);
  }

  Future<void> _next() async {
    final qs = _questions!;
    if (_index < qs.length - 1) {
      setState(() {
        _index++;
        _chosen = null;
      });
      _speakQuestion();
      return;
    }
    final score = (_correct * 100 / qs.length).round();
    if (widget.day != null) await widget.progress.saveScore(widget.day!, score);
    setState(() => _index = qs.length); // 결과 화면
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final qs = _questions;
    if (qs == null) return _setup();
    if (_index >= qs.length) return _result(qs);
    return _question(qs[_index], qs.length);
  }

  Widget _setup() => ListView(padding: const EdgeInsets.all(18), children: [
        const Text('사지선다 퀴즈',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text('${widget.words.length}단어 중에서 출제해요. 답을 고르면 원어민 발음이 나와요.',
            style: const TextStyle(color: Washi.inkSoft)),
        const SizedBox(height: 18),
        const Text('문제 유형', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('일본어 → 뜻')),
            ButtonSegment(value: true, label: Text('뜻 → 일본어')),
          ],
          selected: {_reverse},
          onSelectionChanged: (v) => setState(() => _reverse = v.first),
        ),
        const SizedBox(height: 14),
        const Text('문제 수', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        SegmentedButton<bool>(
          segments: [
            ButtonSegment(
                value: false,
                label: Text('${min(10, widget.words.length)}문제')),
            ButtonSegment(value: true, label: Text('전체 ${widget.words.length}문제')),
          ],
          selected: {_all},
          onSelectionChanged: (v) => setState(() => _all = v.first),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
            key: const ValueKey('n4-quiz-start'),
            style: FilledButton.styleFrom(
                backgroundColor: _n4Color, minimumSize: const Size.fromHeight(52)),
            onPressed: widget.words.isEmpty ? null : _begin,
            icon: const Icon(Icons.quiz_rounded),
            label: const Text('퀴즈 시작')),
      ]);

  Widget _question(N4QuizQuestion q, int total) {
    final w = q.word;
    return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
      Row(children: [
        Text('${_index + 1} / $total', style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(width: 10),
        Expanded(child: SlimProgress(ratio: (_index + 1) / total, color: _n4Color)),
        const SizedBox(width: 10),
        Text('⭕ $_correct', style: const TextStyle(color: Washi.matcha, fontWeight: FontWeight.w800)),
      ]),
      const SizedBox(height: 14),
      PaperCard(
        padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 16),
        child: Column(children: [
          Text(q.reverse ? '이 뜻의 일본어는?' : '이 단어의 뜻은?',
              style: const TextStyle(color: Washi.inkSoft, fontSize: 13)),
          const SizedBox(height: 10),
          if (q.reverse)
            Text(w.korean,
                key: const ValueKey('n4-quiz-prompt'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900))
          else ...[
            if (w.hasReading && _chosen != null)
              Text(w.reading, style: const TextStyle(color: Washi.inkSoft, fontSize: 15)),
            FittedBox(
              child: Text(w.japanese,
                  key: const ValueKey('n4-quiz-prompt'),
                  style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800)),
            ),
          ],
          const SizedBox(height: 6),
          IconButton(
              key: const ValueKey('n4-quiz-listen'),
              tooltip: q.reverse ? '뜻 듣기' : '발음 듣기',
              onPressed: () => q.reverse && w.koSpan != null && _chosen == null
                  ? widget.player.play(w.audio, w.koSpan!)
                  : widget.player.play(w.audio, w.jaSpan),
              icon: const Icon(Icons.volume_up_rounded, color: _n4Color)),
        ]),
      ),
      const SizedBox(height: 14),
      for (var i = 0; i < q.choices.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _choice(q, i),
        ),
      if (_chosen != null) ...[
        const SizedBox(height: 4),
        Text(
            _chosen == q.answer ? '정답이에요! 👏' : '오답 — 정답: ${w.japanese}(${w.reading}) = ${w.korean}',
            style: TextStyle(
                fontWeight: FontWeight.w800,
                color: _chosen == q.answer ? Washi.matcha : Washi.shu)),
        if (w.kanji.isNotEmpty) ...[
          const SizedBox(height: 4),
          N4KanjiLine(word: w, fontSize: 12.5),
        ],
        const SizedBox(height: 10),
        FilledButton(
            key: const ValueKey('n4-quiz-next'),
            style: FilledButton.styleFrom(
                backgroundColor: _n4Color, minimumSize: const Size.fromHeight(48)),
            onPressed: _next,
            child: Text(_index < (_questions!.length - 1) ? '다음 문제' : '결과 보기')),
      ],
    ]);
  }

  Widget _choice(N4QuizQuestion q, int i) {
    final c = q.choices[i];
    Color? color;
    if (_chosen != null) {
      if (i == q.answer) {
        color = Washi.matcha;
      } else if (i == _chosen) {
        color = Washi.shu;
      }
    }
    return PaperCard(
      key: ValueKey('n4-choice-$i'),
      onTap: _chosen == null ? () => _choose(i) : null,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      borderColor: color ?? Washi.line,
      color: color == null ? Washi.card : color.withValues(alpha: 0.08),
      child: Row(children: [
        Text('${i + 1}',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w900, color: color ?? _n4Color)),
        const SizedBox(width: 14),
        Expanded(
          child: q.reverse
              ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(c.japanese,
                      style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
                  if (_chosen != null && c.hasReading)
                    Text('${c.reading} · ${c.korean}',
                        style: const TextStyle(fontSize: 12, color: Washi.inkSoft)),
                ])
              : Text(c.korean,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
        if (color != null)
          Icon(i == q.answer ? Icons.circle_outlined : Icons.close_rounded, color: color),
      ]),
    );
  }

  Widget _result(List<N4QuizQuestion> qs) {
    final score = (_correct * 100 / qs.length).round();
    return ListView(padding: const EdgeInsets.all(18), children: [
      PaperCard(
        key: const ValueKey('n4-quiz-result'),
        padding: const EdgeInsets.all(22),
        child: Column(children: [
          Text(score >= 80 ? '🎉' : score >= 50 ? '💪' : '📖',
              style: const TextStyle(fontSize: 44)),
          Text('$score점',
              style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: _n4Color)),
          Text('${qs.length}문제 중 $_correct문제 정답',
              style: const TextStyle(color: Washi.inkSoft)),
        ]),
      ),
      const SizedBox(height: 14),
      if (_wrong.isNotEmpty) ...[
        const SectionTitle('틀린 단어'),
        const SizedBox(height: 8),
        for (final w in _wrong)
          ListTile(
            dense: true,
            title: Text('${w.japanese}  ${w.hasReading ? w.reading : ''}',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            subtitle: Text(w.korean),
            trailing: IconButton(
                onPressed: () => widget.player.play(w.audio, w.jaSpan),
                icon: const Icon(Icons.volume_up_rounded, color: _n4Color)),
          ),
        const SizedBox(height: 8),
        FilledButton.icon(
            key: const ValueKey('n4-quiz-retry-wrong'),
            style: FilledButton.styleFrom(backgroundColor: Washi.shu),
            onPressed: () => _begin(List.of(_wrong)),
            icon: const Icon(Icons.replay_rounded),
            label: const Text('틀린 단어만 다시')),
      ],
      const SizedBox(height: 8),
      OutlinedButton.icon(
          key: const ValueKey('n4-quiz-again'),
          onPressed: () => setState(() => _questions = null),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('새 퀴즈')),
    ]);
  }
}

// ===========================================================================
// 2026-10-10 한자 풀이 · 암기 카드(간격 반복) · 독해
// ===========================================================================

/// 한자 풀이 한 줄(목록용): 挨 밀칠 애 · 拶 핍박할 찰
class N4KanjiLine extends StatelessWidget {
  const N4KanjiLine({super.key, required this.word, this.fontSize = 12});
  final N4Word word;
  final double fontSize;
  @override
  Widget build(BuildContext context) {
    if (word.kanji.isEmpty) return const SizedBox.shrink();
    // 2026-10-11 누르면 부품으로 쪼개 보기.
    return InkWell(
      onTap: () => showKanjiPartsSheet(context, word.japanese, accent: _n4Color),
      child: Text.rich(
      TextSpan(children: [
        for (var i = 0; i < word.kanji.length; i++) ...[
          if (i > 0) const TextSpan(text: '  ·  '),
          TextSpan(
              text: word.kanji[i].char,
              style: TextStyle(
                  fontWeight: FontWeight.w900, color: _n4Color, fontSize: fontSize + 2)),
          TextSpan(text: ' ${word.kanji[i].hunEum}'),
        ],
      ]),
      style: TextStyle(fontSize: fontSize, color: Washi.inkSoft),
    ),
    );
  }
}

/// 한자 풀이 카드(자동 학습·암기 카드용).
/// 2026-10-11 JLPT 단어장과 같은 큰 한자 칸(훈음·음독·훈독·획수·관련 단어) + 쪼개 보기.
class N4KanjiTiles extends StatelessWidget {
  const N4KanjiTiles({super.key, required this.word});
  final N4Word word;

  /// 사전에 있으면 사전 풀이(획수·급수 포함), 없으면 N4 단어장 자체 풀이.
  static List<KanjiInfo> infosOf(N4Word word) => [
        for (final k in word.kanji)
          KanjiDictionary.instance.lookup(k.char) ??
              KanjiInfo(
                kanji: k.char,
                hun: k.hunEum,
                eum: '',
                onReadings: k.on.isEmpty ? const [] : [k.on],
                kunReadings: k.kun.isEmpty ? const [] : [k.kun],
              ),
      ];

  @override
  Widget build(BuildContext context) {
    if (word.kanji.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      width: double.infinity,
      child: KanjiBreakdown.text(
        key: ValueKey('n4-kanji-${word.id}'),
        japanese: word.japanese,
        wordId: word.id,
        items: infosOf(word),
        accent: _n4Color,
      ),
    );
  }
}

/// 기억 단계 점 7개(0 = 아직 안 봄).
class N4StageDots extends StatelessWidget {
  const N4StageDots({super.key, required this.stage});
  final int stage;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 1; i <= 7; i++)
          Container(
            width: 5,
            height: 5,
            margin: const EdgeInsets.only(right: 2),
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i <= stage ? _n4Color : Washi.line),
          ),
      ]);
}

String _intervalLabel(DateTime from, DateTime to) {
  final d = to.difference(from);
  if (d.inMinutes < 60) return '${d.inMinutes < 1 ? 1 : d.inMinutes}분';
  if (d.inHours < 24) return '${d.inHours}시간';
  if (d.inDays < 30) return '${d.inDays}일';
  if (d.inDays < 365) return '${(d.inDays / 30).round()}개월';
  return '${(d.inDays / 365).toStringAsFixed(1)}년';
}

/// 단어 하나를 아래에서 올라오는 시트로 보여준다(독해 본문에서 단어를 눌렀을 때).
Future<void> showN4WordSheet(
    BuildContext context, N4Word w, N4ClipPlayer player) {
  player.play(w.audio, w.jaSpan);
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (w.hasReading)
          Text(w.reading, style: const TextStyle(color: Washi.inkSoft, fontSize: 15)),
        Text(w.japanese,
            style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(w.korean,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w800, color: _n4Color)),
        const SizedBox(height: 12),
        N4KanjiTiles(word: w),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          FilledButton.tonalIcon(
              onPressed: () => player.play(w.audio, w.jaSpan),
              icon: const Icon(Icons.volume_up_rounded),
              label: const Text('발음')),
          const SizedBox(width: 8),
          if (w.koSpan != null)
            FilledButton.tonalIcon(
                onPressed: () => player.play(w.audio, w.koSpan!),
                icon: const Text('🇰🇷'),
                label: const Text('뜻')),
        ]),
      ]),
    ),
    ),
  );
}

/// 2026-10-10 암기 카드(간격 반복). 앞면 일본어(발음) → 뜻 보기 → 모름/헷갈림/기억남/쉬움.
/// 고른 등급으로 다음 복습 시각을 정하므로, 「오늘의 복습」에 맞춰 다시 보면 오래 기억된다.
class N4FlashcardView extends StatefulWidget {
  const N4FlashcardView(
      {super.key,
      required this.words,
      required this.progress,
      required this.player,
      this.onDone,
      this.clock,
      this.maxNew,
      this.notice});
  final List<N4Word> words;
  final N4WordbookProgress progress;
  final N4ClipPlayer player;
  final VoidCallback? onDone;

  /// 2026-10-10 이번에 새로 보여 줄 단어 수 상한(하루 목표). null이면 제한 없음.
  final int? maxNew;

  /// 카드 위에 보여 줄 안내(예: 다른 DAY 복습을 먼저 하세요).
  final String? notice;

  /// 테스트에서 현재 시각을 고정할 때.
  final DateTime Function()? clock;
  @override
  State<N4FlashcardView> createState() => _N4FlashcardViewState();
}

class _N4FlashcardViewState extends State<N4FlashcardView>
    with AutomaticKeepAliveClientMixin {
  late List<N4Word> _queue = _order();
  int _done = 0, _again = 0;
  bool _back = false;

  @override
  bool get wantKeepAlive => true;

  DateTime get _now => (widget.clock ?? DateTime.now)();

  /// 복습할 때가 된 단어 → 처음 보는 단어 → 나머지(다음 복습이 가까운 순).
  List<N4Word> _order() {
    final p = widget.progress, now = _now;
    final due = [for (final w in widget.words) if (p.isDue(w.id, now)) w];
    final fresh = [for (final w in widget.words) if (p.isNew(w.id)) w];
    return [...due, ...fresh.take(widget.maxNew ?? fresh.length)];
  }

  void _show() {
    setState(() => _back = true);
    final w = _queue.first;
    if (w.koSpan != null) widget.player.play(w.audio, w.koSpan!);
  }

  Future<void> _rate(int rating) async {
    final w = _queue.first;
    await widget.progress.review(w.id, rating, _now);
    setState(() {
      _queue.removeAt(0);
      _back = false;
      _done++;
      if (rating == 1) {
        _again++;
        // 모르는 단어는 몇 장 뒤에 한 번 더 나온다.
        _queue.insert(_queue.length < 4 ? _queue.length : 4, w);
      }
    });
    if (_queue.isEmpty) {
      widget.onDone?.call();
    } else {
      _speakFront();
    }
  }

  void _speakFront() {
    if (_queue.isEmpty) return;
    final w = _queue.first;
    widget.player.play(w.audio, w.jaSpan);
  }

  /// 이미 외우기 시작한 단어만 한 번 더(새 단어는 하루 목표를 지키도록 빼고).
  List<N4Word> get _seen =>
      [for (final w in widget.words) if (!widget.progress.isNew(w.id)) w];

  void _restartAll() => setState(() {
        _queue = _seen..shuffle();
        _done = 0;
        _again = 0;
        _back = false;
      });

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_queue.isEmpty) return _finished();
    final w = _queue.first;
    final p = widget.progress;
    final now = _now;
    return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
      if (widget.notice != null) _noticeBox(widget.notice!),
      Row(children: [
        Text('남은 카드 ${_queue.length}장',
            style: const TextStyle(fontWeight: FontWeight.w800)),
        const Spacer(),
        Text('본 카드 $_done · 다시 $_again',
            style: const TextStyle(fontSize: 12, color: Washi.inkSoft)),
      ]),
      const SizedBox(height: 10),
      PaperCard(
        key: const ValueKey('n4-flashcard'),
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
        onTap: _back ? null : _show,
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(p.isNew(w.id) ? '새 단어' : 'DAY ${w.day} 복습',
                style: const TextStyle(fontSize: 11.5, color: Washi.inkSoft)),
            const SizedBox(width: 8),
            N4StageDots(stage: p.stage(w.id)),
          ]),
          const SizedBox(height: 14),
          // 2026-10-21 카드 위 단어 그림(뜻을 떠올리는 실마리).
          WordPicture(wordId: w.id, size: 120),
          const SizedBox(height: 14),
          if (_back && w.hasReading)
            Text(w.reading, style: const TextStyle(fontSize: 17, color: Washi.inkSoft)),
          FittedBox(
            child: Text(w.japanese,
                style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w800)),
          ),
          IconButton(
              tooltip: '발음 듣기',
              onPressed: () => widget.player.play(w.audio, w.jaSpan),
              icon: const Icon(Icons.volume_up_rounded, color: _n4Color)),
          if (!_back) ...[
            const SizedBox(height: 8),
            const Text('뜻을 떠올린 다음 카드를 누르세요',
                style: TextStyle(fontSize: 12.5, color: Washi.inkSoft)),
          ] else ...[
            Text(w.korean,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w900, color: _n4Color)),
            const SizedBox(height: 12),
            N4KanjiTiles(word: w),
            if (w.exampleJapanese != null) ...[
              const SizedBox(height: 12),
              Text('${w.exampleJapanese}\n${w.exampleKorean ?? ''}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: Washi.inkSoft, height: 1.5)),
            ],
          ],
        ]),
      ),
      const SizedBox(height: 14),
      if (!_back)
        FilledButton(
            key: const ValueKey('n4-flash-show'),
            style: FilledButton.styleFrom(
                backgroundColor: _n4Color, minimumSize: const Size.fromHeight(52)),
            onPressed: _show,
            child: const Text('뜻 보기'))
      else
        Row(children: [
          for (final (r, label, color) in const [
            (1, '모름', Washi.shu),
            (2, '헷갈림', Washi.yamabuki),
            (3, '기억남', _n4Color),
            (4, '쉬움', Washi.sora),
          ])
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: FilledButton(
                  key: ValueKey('n4-rate-$r'),
                  style: FilledButton.styleFrom(
                      backgroundColor: color,
                      padding: const EdgeInsets.symmetric(vertical: 10)),
                  onPressed: () => _rate(r),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text(
                        _intervalLabel(
                            now,
                            DateTime.parse(
                                p.preview(w.id, r, now)['next'] as String)),
                        style: const TextStyle(fontSize: 10.5)),
                  ]),
                ),
              ),
            ),
        ]),
      const SizedBox(height: 14),
      const Text(
          '버튼 아래 시간은 다음에 다시 볼 때까지의 간격이에요. 잊을 때쯤 다시 보면 장기 기억으로 남아요.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11.5, color: Washi.inkSoft)),
    ]);
  }

  Widget _noticeBox(String text) => Container(
        key: const ValueKey('n4-flash-notice'),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: Washi.yamabuki.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          const Icon(Icons.info_outline_rounded, color: Washi.yamabuki),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(height: 1.45))),
        ]),
      );

  Widget _finished() => ListView(padding: const EdgeInsets.all(20), children: [
        if (widget.notice != null) _noticeBox(widget.notice!),
        PaperCard(
          key: const ValueKey('n4-flash-done'),
          padding: const EdgeInsets.all(22),
          child: Column(children: [
            const Text('🎉', style: TextStyle(fontSize: 42)),
            Text(_done == 0 ? '지금 복습할 카드가 없어요' : '오늘 카드를 다 봤어요!',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(
                _done == 0
                    ? '복습할 때가 된 단어와 오늘 목표만큼의 새 단어만 나와요.'
                    : '$_done장을 봤고 $_again번 다시 봤어요. 다음 복습 날짜에 다시 만나요.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Washi.inkSoft, height: 1.5)),
          ]),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
            key: const ValueKey('n4-flash-all'),
            onPressed: _seen.isEmpty ? null : _restartAll,
            icon: const Icon(Icons.style_rounded),
            label: const Text('외우기 시작한 카드 한 번 더 보기')),
      ]);
}

/// 2026-10-10 「오늘의 복습」: 여러 DAY에서 복습할 때가 된 단어를 암기 카드로.
class N4ReviewPage extends StatefulWidget {
  const N4ReviewPage(
      {super.key,
      required this.words,
      required this.progress,
      this.audioFactory,
      this.maxNew = 0,
      this.title = '오늘의 학습'});
  final List<N4Word> words;
  final N4WordbookProgress progress;
  final LessonAudio Function()? audioFactory;

  /// 이번에 함께 볼 새 단어 수(복습 카드가 먼저 나온다).
  final int maxNew;
  final String title;
  @override
  State<N4ReviewPage> createState() => _N4ReviewPageState();
}

class _N4ReviewPageState extends State<N4ReviewPage> {
  late final LessonAudio _audio = (widget.audioFactory ?? JustLessonAudio.new)();
  late final N4ClipPlayer _player = N4ClipPlayer(_audio);

  @override
  void dispose() {
    _player.stop();
    _audio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Washi.paper,
        appBar: washiAppBar(
            title: widget.title, subtitle: '복습 먼저 → 새 단어 ${widget.maxNew}개'),
        body: N4FlashcardView(
            words: widget.words,
            progress: widget.progress,
            player: _player,
            maxNew: widget.maxNew),
      );
}

/// 2026-10-10 독해: DAY 단어로 쓴 지문(밑줄 = 이 DAY 단어, 누르면 뜻·한자·원어민 발음),
/// 문장 듣기(TTS) · 해석 · 내용 확인 문제 · 문장 빈칸 퀴즈.
class _ReadingView extends StatefulWidget {
  const _ReadingView(
      {required this.day,
      required this.progress,
      required this.player,
      this.speakJapanese});
  final N4Day day;
  final N4WordbookProgress progress;
  final N4ClipPlayer player;
  final Future<void> Function(String)? speakJapanese;
  @override
  State<_ReadingView> createState() => _ReadingViewState();
}

class _ClozeItem {
  const _ClozeItem(this.before, this.after, this.korean, this.word, this.choices);
  final String before, after, korean;
  final N4Word word;
  final List<N4Word> choices;
}

class _ReadingViewState extends State<_ReadingView>
    with AutomaticKeepAliveClientMixin {
  bool _ruby = true, _korean = false;
  final _answers = <int, int>{};
  List<_ClozeItem>? _cloze;
  int _clozeIndex = 0, _clozeRight = 0;
  int? _clozeChosen;

  @override
  bool get wantKeepAlive => true;

  N4Word? _word(String? id) {
    if (id == null) return null;
    for (final w in widget.day.words) {
      if (w.id == id) return w;
    }
    return null;
  }

  /// 빈칸 문제: 지문 속 DAY 단어 + 예문 속 단어(표기가 그대로 들어 있는 것).
  List<_ClozeItem> _buildCloze() {
    final rnd = Random();
    final items = <_ClozeItem>[];
    final seen = <String>{};
    final reading = widget.day.reading;
    if (reading != null) {
      for (final s in reading.sentences) {
        for (var i = 0; i < s.tokens.length; i++) {
          final w = _word(s.wordIds[i]);
          if (w == null || seen.contains(w.id)) continue;
          seen.add(w.id);
          items.add(_ClozeItem(
              s.tokens.take(i).map((t) => t.text).join(),
              s.tokens.skip(i + 1).map((t) => t.text).join(),
              s.korean,
              w,
              const []));
        }
      }
    }
    for (final w in widget.day.words) {
      final ex = w.exampleJapanese;
      if (seen.contains(w.id) || ex == null || !ex.contains(w.japanese)) continue;
      final at = ex.indexOf(w.japanese);
      seen.add(w.id);
      items.add(_ClozeItem(ex.substring(0, at), ex.substring(at + w.japanese.length),
          w.exampleKorean ?? '', w, const []));
    }
    items.shuffle(rnd);
    return [
      for (final it in items.take(10))
        _ClozeItem(it.before, it.after, it.korean, it.word, () {
          final others = [...widget.day.words]
            ..removeWhere((x) => x.id == it.word.id || x.korean == it.word.korean)
            ..shuffle(rnd);
          return [it.word, ...others.take(3)]..shuffle(rnd);
        }())
    ];
  }

  Future<void> _chooseCloze(int i) async {
    final item = _cloze![_clozeIndex];
    if (_clozeChosen != null) return;
    final ok = item.choices[i].id == item.word.id;
    setState(() {
      _clozeChosen = i;
      if (ok) _clozeRight++;
    });
    widget.player.play(item.word.audio, item.word.jaSpan);
    await widget.progress.record(item.word.id, ok);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final r = widget.day.reading;
    if (r == null) return const Center(child: Text('이 DAY에는 독해 지문이 없어요.'));
    return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 28), children: [
      Text(r.title,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
      Text(r.titleKorean, style: const TextStyle(color: Washi.inkSoft)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
        FilterChip(
            label: const Text('후리가나'),
            selected: _ruby,
            onSelected: (v) => setState(() => _ruby = v)),
        FilterChip(
            key: const ValueKey('n4-reading-korean'),
            label: const Text('해석'),
            selected: _korean,
            onSelected: (v) => setState(() => _korean = v)),
        if (widget.speakJapanese != null)
          TextButton.icon(
              onPressed: () async {
                for (final s in r.sentences) {
                  if (!mounted) return;
                  await widget.speakJapanese!(s.japanese);
                }
              },
              icon: const Icon(Icons.record_voice_over_rounded),
              label: const Text('전체 읽어 주기')),
      ]),
      const Text('초록 밑줄은 이 DAY의 단어예요. 누르면 뜻·한자·원어민 발음이 나와요.',
          style: TextStyle(fontSize: 12, color: Washi.inkSoft)),
      const SizedBox(height: 10),
      PaperCard(
        key: const ValueKey('n4-reading'),
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (var i = 0; i < r.sentences.length; i++) _sentence(i, r.sentences[i]),
        ]),
      ),
      const SizedBox(height: 18),
      const SectionTitle('내용 확인'),
      const SizedBox(height: 8),
      for (var i = 0; i < r.questions.length; i++) _question(i, r.questions[i]),
      const SizedBox(height: 14),
      const SectionTitle('문장 빈칸 퀴즈', trailing: '지문·예문 속 단어'),
      const SizedBox(height: 8),
      _clozeBlock(),
    ]);
  }

  Widget _sentence(int i, N4Sentence s) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _SentenceRuby(
                  sentence: s,
                  showRuby: _ruby,
                  onWord: (id) {
                    final w = _word(id);
                    if (w != null) showN4WordSheet(context, w, widget.player);
                  }),
              if (_korean)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(s.korean,
                      style: const TextStyle(fontSize: 13, color: Washi.inkSoft, height: 1.45)),
                ),
            ]),
          ),
          if (widget.speakJapanese != null)
            IconButton(
                key: ValueKey('n4-reading-tts-$i'),
                tooltip: '문장 듣기',
                onPressed: () => widget.speakJapanese!(s.japanese),
                icon: const Icon(Icons.volume_up_rounded, size: 20, color: _n4Color)),
        ]),
      );

  Widget _question(int qi, N4ReadingQuestion q) {
    final chosen = _answers[qi];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PaperCard(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Q${qi + 1}. ${q.japanese}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          Text(q.korean, style: const TextStyle(fontSize: 12.5, color: Washi.inkSoft)),
          const SizedBox(height: 8),
          for (var i = 0; i < q.options.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: OutlinedButton(
                key: ValueKey('n4-rq-$qi-$i'),
                style: OutlinedButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  foregroundColor: chosen == null
                      ? Washi.ink
                      : i == q.answer
                          ? Washi.matcha
                          : i == chosen
                              ? Washi.shu
                              : Washi.inkSoft,
                  side: BorderSide(
                      color: chosen != null && i == q.answer
                          ? Washi.matcha
                          : chosen == i
                              ? Washi.shu
                              : Washi.line),
                ),
                onPressed: chosen == null ? () => setState(() => _answers[qi] = i) : null,
                child: Text('${i + 1}. ${q.options[i]}'),
              ),
            ),
          if (chosen != null)
            Text('${chosen == q.answer ? '⭕ 정답!' : '❌ 정답은 ${q.answer + 1}번'}  ${q.explanation}',
                style: TextStyle(
                    height: 1.5,
                    color: chosen == q.answer ? Washi.matcha : Washi.shu)),
        ]),
      ),
    );
  }

  Widget _clozeBlock() {
    final items = _cloze;
    if (items == null) {
      return FilledButton.icon(
          key: const ValueKey('n4-cloze-start'),
          style: FilledButton.styleFrom(
              backgroundColor: _n4Color, minimumSize: const Size.fromHeight(48)),
          onPressed: () => setState(() {
                _cloze = _buildCloze();
                _clozeIndex = 0;
                _clozeRight = 0;
                _clozeChosen = null;
              }),
          icon: const Icon(Icons.edit_note_rounded),
          label: const Text('빈칸 퀴즈 시작'));
    }
    if (_clozeIndex >= items.length) {
      return PaperCard(
        key: const ValueKey('n4-cloze-result'),
        child: Column(children: [
          Text('${items.length}문제 중 $_clozeRight문제 정답',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          OutlinedButton(
              onPressed: () => setState(() => _cloze = null),
              child: const Text('다시 풀기')),
        ]),
      );
    }
    final it = items[_clozeIndex];
    return PaperCard(
      key: const ValueKey('n4-cloze'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${_clozeIndex + 1} / ${items.length}',
            style: const TextStyle(fontSize: 12, color: Washi.inkSoft)),
        const SizedBox(height: 6),
        Text.rich(TextSpan(children: [
          TextSpan(text: it.before),
          TextSpan(
              text: _clozeChosen == null ? '（　　　）' : '【${it.word.japanese}】',
              style: const TextStyle(color: _n4Color, fontWeight: FontWeight.w900)),
          TextSpan(text: it.after),
        ]), style: const TextStyle(fontSize: 18, height: 1.6)),
        Text(it.korean, style: const TextStyle(fontSize: 12.5, color: Washi.inkSoft)),
        const SizedBox(height: 10),
        for (var i = 0; i < it.choices.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: OutlinedButton(
              key: ValueKey('n4-cloze-$i'),
              style: OutlinedButton.styleFrom(
                alignment: Alignment.centerLeft,
                foregroundColor: _clozeChosen == null
                    ? Washi.ink
                    : it.choices[i].id == it.word.id
                        ? Washi.matcha
                        : i == _clozeChosen
                            ? Washi.shu
                            : Washi.inkSoft,
              ),
              onPressed: _clozeChosen == null ? () => _chooseCloze(i) : null,
              child: Text(
                  '${it.choices[i].japanese}${_clozeChosen != null ? '  ${it.choices[i].korean}' : ''}',
                  style: const TextStyle(fontSize: 16)),
            ),
          ),
        if (_clozeChosen != null)
          FilledButton(
              key: const ValueKey('n4-cloze-next'),
              style: FilledButton.styleFrom(backgroundColor: _n4Color),
              onPressed: () => setState(() {
                    _clozeIndex++;
                    _clozeChosen = null;
                  }),
              child: const Text('다음')),
      ]),
    );
  }
}

/// 후리가나 문장. DAY 단어(초록 밑줄)를 누르면 [onWord]로 단어 id를 넘긴다.
class _SentenceRuby extends StatelessWidget {
  const _SentenceRuby({required this.sentence, required this.showRuby, required this.onWord});
  final N4Sentence sentence;
  final bool showRuby;
  final void Function(String id) onWord;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < sentence.tokens.length; i++) {
      final t = sentence.tokens[i];
      final id = sentence.wordIds[i];
      final ruby = RubyText(
          tokens: [t],
          fontSize: 19,
          showRuby: showRuby,
          showUnderline: id != null);
      children.add(id == null
          ? ruby
          : InkWell(
              key: ValueKey('n4-rword-$id'),
              onTap: () => onWord(id),
              child: ruby));
    }
    return Wrap(crossAxisAlignment: WrapCrossAlignment.end, children: children);
  }
}
