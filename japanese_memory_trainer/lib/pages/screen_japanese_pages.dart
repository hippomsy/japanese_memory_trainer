import 'package:kioku_japanese/widgets/study_illustration.dart';
import 'package:flutter/material.dart';
import 'package:kioku_japanese/services/screen_japanese.dart';
import 'package:kioku_japanese/widgets/study_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef SpeakFn = Future<void> Function(String text);

/// 2026-10-06 영화별 대표 색(포스터 대신 그라데이션 표지에 쓴다).
String screenMovieIllustration(int volume) => switch (volume) {
  1 => 'rain',
  2 => 'siblings',
  3 => 'forest',
  _ => 'study',
};

/// 2026-10-10 챕터별 장면 그림. 내용에 맞춘 장면(scene)이 있으면 그것을, 없으면 기존 챕터 그림을 쓴다.
String screenChapterIllustration(ScreenMovie movie, ScreenLesson lesson) =>
    lesson.scene.isNotEmpty ? '${lesson.scene}.webp' : 'chapters/screen_v${movie.volume}_${lesson.number.toString().padLeft(2, '0')}';

List<Color> screenMovieColors(int volume) => switch (volume) {
      1 => const [Color(0xFF5B8DEF), Color(0xFF2E4A8C)], // 비의 계절
      2 => const [Color(0xFFF2876B), Color(0xFFB8436A)], // 오노데라 남매
      3 => const [Color(0xFF4DB38A), Color(0xFF22735F)], // 갓파 쿠
      _ => const [Color(0xFF7B6BA8), Color(0xFF3E3566)],
    };

/// 2026-10-06 스크린 일본어 첫 화면: 영화 목록.
class ScreenMovieListPage extends StatefulWidget {
  const ScreenMovieListPage(
      {super.key,
      required this.speakJapanese,
      this.stop,
      this.movies,
      this.preferences});
  final SpeakFn speakJapanese;
  final Future<void> Function()? stop;

  /// 테스트용 데이터·저장소.
  final Future<List<ScreenMovie>>? movies;
  final Future<SharedPreferences>? preferences;

  @override
  State<ScreenMovieListPage> createState() => _ScreenMovieListPageState();
}

class _ScreenMovieListPageState extends State<ScreenMovieListPage> {
  late final Future<(List<ScreenMovie>, ScreenProgress)> _data = () async {
    final movies = await (widget.movies ?? ScreenMovie.load());
    final prefs = await (widget.preferences ?? SharedPreferences.getInstance());
    return (movies, ScreenProgress(prefs));
  }();

  Future<void> _openMovie(ScreenMovie movie, ScreenProgress progress) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => ScreenLessonListPage(
            movie: movie,
            progress: progress,
            speakJapanese: widget.speakJapanese,
            stop: widget.stop)));
    if (mounted) setState(() {});
  }

  Future<void> _openLesson(
      ScreenMovie movie, ScreenLesson lesson, ScreenProgress progress) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => ScreenLessonPage(
            movie: movie,
            lesson: lesson,
            progress: progress,
            speakJapanese: widget.speakJapanese,
            stop: widget.stop)));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: washiAppBar(title: '스크린 일본어', subtitle: '영화 대사로 배우는 살아있는 회화'),
        body: FutureBuilder<(List<ScreenMovie>, ScreenProgress)>(
          future: _data,
          builder: (context, snap) {
            if (snap.hasError) {
              return const Center(child: Text('스크린 일본어 자료를 불러오지 못했어요.'));
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final (movies, progress) = snap.data!;
            final total = movies.fold<int>(0, (s, m) => s + m.lessons.length);
            final done = movies.fold<int>(0, (s, m) => s + progress.doneCount(m));
            ScreenMovie? lastMovie;
            ScreenLesson? last;
            for (final m in movies) {
              for (final l in m.lessons) {
                if (l.id == progress.lastLesson) {
                  lastMovie = m;
                  last = l;
                }
              }
            }
            final lm = lastMovie, ll = last;
            return ListView(
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 28),
              children: [
                const StudyIllustration('study', height: 162),
                const SizedBox(height: 10),
                HeroBanner(
                  colors: const [Color(0xFF2B2D42), Color(0xFF4A3F6B)],
                  icon: Icons.movie_filter_rounded,
                  eyebrow: 'SCREEN JAPANESE',
                  title: '영화 속 한 장면,\n그대로 따라 말해요',
                  subtitle: '${movies.length}편 · $total강 중 $done강 완료',
                  progress: total == 0 ? 0 : done / total,
                ),
                if (ll != null && lm != null) ...[
                  const SizedBox(height: 14),
                  PaperCard(
                    key: const ValueKey('screen-continue'),
                    onTap: () => _openLesson(lm, ll, progress),
                    child: Row(children: [
                      IconBadge(
                          icon: Icons.play_arrow_rounded,
                          color: screenMovieColors(lm.volume).first),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            const Text('이어서 보기',
                                style: TextStyle(
                                    fontSize: 12, color: Washi.inkSoft)),
                            Text('${lm.title} ${ll.label} ${ll.title}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 16)),
                          ])),
                      const Icon(Icons.chevron_right_rounded,
                          color: Washi.inkSoft),
                    ]),
                  ),
                ],
                const SizedBox(height: 22),
                const SectionTitle('작품 선택', trailing: '대사 · 해석 · 표현 · 퀴즈'),
                const SizedBox(height: 10),
                for (final m in movies) ...[
                  _MovieCard(
                      movie: m,
                      done: progress.doneCount(m),
                      onTap: () => _openMovie(m, progress)),
                  const SizedBox(height: 14),
                ],
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                      '강의 노트의 대사를 문자 인식으로 옮겨 정리했어요. 드물게 원문과 다를 수 있으며, '
                      '🔊 버튼은 기기의 일본어 음성(TTS)으로 읽어 줍니다.',
                      style: TextStyle(
                          fontSize: 12, color: Washi.inkSoft, height: 1.6)),
                ),
              ],
            );
          },
        ),
      );
}

class _MovieCard extends StatelessWidget {
  const _MovieCard(
      {required this.movie, required this.done, required this.onTap});
  final ScreenMovie movie;
  final int done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = screenMovieColors(movie.volume);
    final ratio = movie.lessons.isEmpty ? 0.0 : done / movie.lessons.length;
    return Material(
      key: ValueKey('screen-movie-${movie.id}'),
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
                colors: colors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
            boxShadow: [
              BoxShadow(
                  color: colors.last.withValues(alpha: 0.28),
                  blurRadius: 18,
                  offset: const Offset(0, 8))
            ],
          ),
          child: Stack(children: [
            Positioned(
              right: -18,
              bottom: -26,
              child: Icon(Icons.movie_creation_outlined,
                  size: 130, color: Colors.white.withValues(alpha: 0.10)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      _Pill('VOL.${movie.volume}'),
                      const SizedBox(width: 6),
                      if (movie.year > 0) _Pill('${movie.year}'),
                      const Spacer(),
                      Text('${movie.lessons.length}강',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800)),
                    ]),
                    StudyIllustration(screenMovieIllustration(movie.volume), height: 112),
                    const SizedBox(height: 14),
                    Text(movie.title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 23,
                            fontWeight: FontWeight.w900)),
                    if (movie.japaneseTitle.isNotEmpty)
                      Text(movie.japaneseTitle,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                    if (movie.description.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(movie.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 13,
                              height: 1.5)),
                    ],
                    const SizedBox(height: 14),
                    Row(children: [
                      Expanded(
                          child: SlimProgress(
                              ratio: ratio, color: Colors.white, height: 6)),
                      const SizedBox(width: 10),
                      Text('$done / ${movie.lessons.length}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                    ]),
                  ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20)),
        child: Text(text,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8)),
      );
}

/// 2026-10-06 한 영화의 강의 목록.
class ScreenLessonListPage extends StatefulWidget {
  const ScreenLessonListPage(
      {super.key,
      required this.movie,
      required this.progress,
      required this.speakJapanese,
      this.stop});
  final ScreenMovie movie;
  final ScreenProgress progress;
  final SpeakFn speakJapanese;
  final Future<void> Function()? stop;

  @override
  State<ScreenLessonListPage> createState() => _ScreenLessonListPageState();
}

class _ScreenLessonListPageState extends State<ScreenLessonListPage> {
  Future<void> _open(ScreenLesson lesson) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => ScreenLessonPage(
            movie: widget.movie,
            lesson: lesson,
            progress: widget.progress,
            speakJapanese: widget.speakJapanese,
            stop: widget.stop)));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final movie = widget.movie;
    final colors = screenMovieColors(movie.volume);
    final done = widget.progress.done;
    return Scaffold(
      appBar: washiAppBar(
          title: movie.title,
          subtitle: '${movie.japaneseTitle} · ${movie.lessons.length}강'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 28),
        children: [
          StudyIllustration(screenMovieIllustration(movie.volume), height: 160),
          const SizedBox(height: 12),
          HeroBanner(
            colors: colors,
            icon: Icons.local_movies_rounded,
            eyebrow: 'SCREEN JAPANESE ${movie.volume}',
            title: movie.title,
            subtitle:
                '${movie.lessons.where((l) => done.contains(l.id)).length} / ${movie.lessons.length}강 완료',
            progress: movie.lessons.isEmpty
                ? 0
                : movie.lessons.where((l) => done.contains(l.id)).length /
                    movie.lessons.length,
          ),
          const SizedBox(height: 18),
          for (final lesson in movie.lessons) ...[
            PaperCard(
              key: ValueKey('screen-lesson-${lesson.id}'),
              onTap: () => _open(lesson),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 90,
                    child: StudyIllustration(
                      screenChapterIllustration(movie, lesson), height: 65),
                  ),
                ),
                const SizedBox(width: 9),
                Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: done.contains(lesson.id)
                        ? colors.first
                        : colors.first.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: done.contains(lesson.id)
                      ? const Icon(Icons.check_rounded, color: Colors.white)
                      : Text(lesson.number.toString().padLeft(2, '0'),
                          style: TextStyle(
                              color: colors.last,
                              fontWeight: FontWeight.w900,
                              fontSize: 16)),
                ),
                const SizedBox(width: 14),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(lesson.title,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(
                          lesson.summary.isEmpty
                              ? '대사 ${lesson.lines.length}줄 · 퀴즈 ${lesson.quizzes.length}문제'
                              : lesson.summary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12.5, color: Washi.inkSoft)),
                    ])),
                const Icon(Icons.chevron_right_rounded, color: Washi.inkSoft),
              ]),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

/// 2026-10-06 강의 화면: 대본(대사별 🔊·해석) · 표현(키워드·오늘의 복습) · 퀴즈(정답 보기+듣기).
class ScreenLessonPage extends StatefulWidget {
  const ScreenLessonPage(
      {super.key,
      required this.movie,
      required this.lesson,
      required this.progress,
      required this.speakJapanese,
      this.stop});
  final ScreenMovie movie;
  final ScreenLesson lesson;
  final ScreenProgress progress;
  final SpeakFn speakJapanese;
  final Future<void> Function()? stop;

  @override
  State<ScreenLessonPage> createState() => _ScreenLessonPageState();
}

class _ScreenLessonPageState extends State<ScreenLessonPage> {
  bool _korean = true;
  bool _playingAll = false;
  int? _current; // 전체 듣기 중인 대사 번호
  String? _speaking; // 지금 읽는 문장
  final _revealed = <int>{};
  late bool _done = widget.progress.isDone(widget.lesson.id);

  ScreenLesson get lesson => widget.lesson;
  List<Color> get colors => screenMovieColors(widget.movie.volume);

  @override
  void initState() {
    super.initState();
    widget.progress.setLast(lesson.id);
  }

  @override
  void dispose() {
    _playingAll = false;
    widget.stop?.call();
    super.dispose();
  }

  Future<void> _speak(String text) async {
    if (text.trim().isEmpty) return;
    if (_playingAll) await _stopAll();
    setState(() => _speaking = text);
    try {
      await widget.speakJapanese(text);
    } finally {
      if (mounted && _speaking == text) setState(() => _speaking = null);
    }
  }

  Future<void> _playAll() async {
    if (_playingAll) return _stopAll();
    setState(() => _playingAll = true);
    for (var i = 0; i < lesson.lines.length; i++) {
      if (!mounted || !_playingAll) break;
      setState(() => _current = i);
      await widget.speakJapanese(lesson.lines[i].japanese);
    }
    if (mounted) {
      setState(() {
        _playingAll = false;
        _current = null;
      });
    }
  }

  Future<void> _stopAll() async {
    setState(() {
      _playingAll = false;
      _current = null;
    });
    await widget.stop?.call();
  }

  Future<void> _reveal(int i) async {
    setState(() => _revealed.add(i));
    await _speak(lesson.quizzes[i].japanese);
  }

  Future<void> _toggleDone() async {
    setState(() => _done = !_done);
    await widget.progress.setDone(lesson.id, _done);
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
            titleSpacing: 0,
            title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${lesson.label} ${lesson.title}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 19)),
                  Text(widget.movie.title,
                      style: const TextStyle(
                          fontSize: 12.5, color: Washi.inkSoft)),
                ]),
            actions: [
              IconButton(
                key: const ValueKey('screen-toggle-korean'),
                tooltip: _korean ? '해석 숨기기' : '해석 보기',
                onPressed: () => setState(() => _korean = !_korean),
                icon: Icon(_korean
                    ? Icons.translate_rounded
                    : Icons.g_translate_outlined),
              ),
              IconButton(
                key: const ValueKey('screen-done'),
                tooltip: _done ? '완료 취소' : '학습 완료',
                onPressed: _toggleDone,
                icon: Icon(
                    _done
                        ? Icons.check_circle_rounded
                        : Icons.check_circle_outline_rounded,
                    color: _done ? Washi.matcha : null),
              ),
            ],
            bottom: TabBar(
              labelColor: colors.last,
              indicatorColor: colors.first,
              unselectedLabelColor: Washi.inkSoft,
              labelStyle: const TextStyle(fontWeight: FontWeight.w800),
              tabs: [
                Tab(text: '대본 ${lesson.lines.length}'),
                const Tab(text: '표현'),
                Tab(key: const ValueKey('screen-tab-quiz'), text: '퀴즈 ${lesson.quizzes.length}'),
              ],
            ),
          ),
          body: TabBarView(children: [_script(), _expressions(), _quiz()]),
        ),
      );

  Widget _summaryCard() => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('今日のあらすじ · 오늘의 줄거리',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6)),
          const SizedBox(height: 8),
          Text(lesson.summary.isEmpty ? lesson.title : lesson.summary,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15.5,
                  height: 1.55,
                  fontWeight: FontWeight.w600)),
        ]),
      );

  Widget _script() => ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          StudyIllustration(screenChapterIllustration(widget.movie, lesson), height: 174),
          const SizedBox(height: 12),
          _summaryCard(),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                key: const ValueKey('screen-play-all'),
                style: FilledButton.styleFrom(backgroundColor: colors.last),
                onPressed: lesson.lines.isEmpty ? null : _playAll,
                icon: Icon(_playingAll
                    ? Icons.stop_rounded
                    : Icons.play_arrow_rounded),
                label: Text(_playingAll ? '멈추기' : '대본 전체 듣기'),
              ),
            ),
          ]),
          const SizedBox(height: 14),
          for (var i = 0; i < lesson.lines.length; i++) ...[
            if (lesson.lines[i].image.isNotEmpty) _sceneBreak(lesson.lines[i].image),
            _lineTile(i),
          ],
        ],
      );

  /// 2026-10-10 대본 중간에 끼워 넣는 장면 그림(장면이 바뀌는 곳).
  Widget _sceneBreak(String scene) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 14),
        child: Stack(children: [
          StudyIllustration('$scene.webp', height: 150),
          Positioned(
            left: 10,
            top: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.movie_filter_rounded, size: 14, color: Colors.white),
                SizedBox(width: 4),
                Text('장면 전환',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        ]),
      );

  Widget _lineTile(int i) {
    final line = lesson.lines[i];
    final active = _current == i || _speaking == line.japanese;
    final prevSpeaker = i == 0 ? null : lesson.lines[i - 1].speaker;
    final showSpeaker = line.speaker.isNotEmpty && line.speaker != prevSpeaker;
    return Padding(
      padding: EdgeInsets.only(top: showSpeaker && i > 0 ? 10 : 4),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
        decoration: BoxDecoration(
          color: active ? colors.first.withValues(alpha: 0.10) : Washi.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: active ? colors.first.withValues(alpha: 0.6) : Washi.line),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (showSpeaker)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: SpeakerChip(name: line.speaker, color: colors.last),
            )
          else if (line.speaker.isEmpty && (i == 0 || prevSpeaker!.isNotEmpty))
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: SpeakerChip(name: '내레이션', color: Washi.inkSoft),
            ),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(line.japanese,
                          style: const TextStyle(
                              fontSize: 18.5,
                              height: 1.5,
                              fontWeight: FontWeight.w600,
                              color: Washi.ink)),
                      if (_korean && line.korean.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(line.korean,
                              style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.5,
                                  color: Washi.inkSoft)),
                        ),
                    ]),
              ),
            ),
            SpeakButton(
              key: ValueKey('screen-speak-line-$i'),
              speaking: active,
              color: colors.last,
              onPressed: () => _speak(line.japanese),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _expressions() => ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          StudyIllustration(screenChapterIllustration(widget.movie, lesson), height: 128),
          const SizedBox(height: 12),
          if (lesson.keywords.isNotEmpty) ...[
            SectionTitle(
                lesson.keywords.any((k) => k.plain.isNotEmpty)
                    ? 'チェックポイント · 체크포인트'
                    : '今日のキーワード · 오늘의 키워드',
                trailing: '${lesson.keywords.length}개'),
            const SizedBox(height: 10),
            PaperCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(children: [
                for (var i = 0; i < lesson.keywords.length; i++) ...[
                  if (i > 0) const Divider(height: 1, color: Washi.line),
                  _keywordRow(lesson.keywords[i]),
                ]
              ]),
            ),
            const SizedBox(height: 22),
          ],
          if (lesson.patterns.isNotEmpty) ...[
            SectionTitle('今日のおさらい · 오늘의 복습',
                trailing: '${lesson.patterns.length}개'),
            const SizedBox(height: 10),
            for (final p in lesson.patterns) ...[
              _patternCard(p),
              const SizedBox(height: 10),
            ],
          ],
          if (lesson.keywords.isEmpty && lesson.patterns.isEmpty)
            const Padding(
                padding: EdgeInsets.only(top: 60),
                child: Center(child: Text('이 강의에는 정리된 표현이 없어요.'))),
        ],
      );

  Widget _keywordRow(ScreenKeyword k) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 4, 6),
        child: Row(children: [
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      children: [
                        Text(k.japanese,
                            style: const TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w700)),
                        if (k.plain.isNotEmpty) ...[
                          const Icon(Icons.arrow_forward_rounded,
                              size: 16, color: Washi.inkSoft),
                          Text(k.plain,
                              style: TextStyle(
                                  fontSize: 15,
                                  color: colors.last,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ]),
                  if (k.korean.isNotEmpty)
                    Text(k.korean,
                        style: const TextStyle(
                            fontSize: 13.5, color: Washi.inkSoft)),
                ]),
          ),
          SpeakButton(
              speaking: _speaking == k.japanese,
              color: colors.last,
              onPressed: () => _speak(k.japanese)),
        ]),
      );

  Widget _patternCard(ScreenPattern p) => PaperCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: colors.first.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10)),
              child: Text(p.pattern,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: colors.last)),
            ),
            const SizedBox(width: 10),
            Expanded(
                child: Text(p.meaning,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600))),
          ]),
          if (p.japanese.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.japanese,
                          style: const TextStyle(
                              fontSize: 16.5, height: 1.5,
                              fontWeight: FontWeight.w600)),
                      if (p.korean.isNotEmpty)
                        Text(p.korean,
                            style: const TextStyle(
                                fontSize: 13.5, color: Washi.inkSoft)),
                    ]),
              ),
              SpeakButton(
                  speaking: _speaking == p.japanese,
                  color: colors.last,
                  onPressed: () => _speak(p.japanese)),
            ]),
          ],
        ]),
      );

  Widget _quiz() => ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          StudyIllustration(screenChapterIllustration(widget.movie, lesson), height: 128),
          const SizedBox(height: 12),
          PaperCard(
            color: colors.first.withValues(alpha: 0.08),
            borderColor: colors.first.withValues(alpha: 0.3),
            child: Row(children: [
              Icon(Icons.quiz_rounded, color: colors.last),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('다음 문장을 일본어로 말해 보세요.\n떠올린 뒤 「정답」을 누르면 일본어와 발음이 나와요.',
                    style: TextStyle(height: 1.5, fontSize: 13.5)),
              ),
            ]),
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < lesson.quizzes.length; i++) ...[
            _quizCard(i),
            const SizedBox(height: 10),
          ],
          if (lesson.quizzes.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _revealed.isEmpty
                      ? null
                      : () => setState(_revealed.clear),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('다시 풀기'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  key: const ValueKey('screen-finish'),
                  style: FilledButton.styleFrom(
                      backgroundColor: _done ? Washi.matcha : colors.last),
                  onPressed: _toggleDone,
                  icon: Icon(_done
                      ? Icons.check_circle_rounded
                      : Icons.flag_rounded),
                  label: Text(_done ? '완료함' : '학습 완료'),
                ),
              ),
            ]),
          ],
        ],
      );

  Widget _quizCard(int i) {
    final q = lesson.quizzes[i];
    final open = _revealed.contains(i);
    return PaperCard(
      key: ValueKey('screen-quiz-$i'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: colors.last, borderRadius: BorderRadius.circular(10)),
            child: Text('${i + 1}',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Text(q.korean,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700, height: 1.45))),
          const SizedBox(width: 8),
          FilledButton.tonal(
            key: ValueKey('screen-answer-$i'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: const Size(0, 38),
              backgroundColor: open
                  ? Washi.matcha.withValues(alpha: 0.15)
                  : colors.first.withValues(alpha: 0.15),
              foregroundColor: open ? Washi.matcha : colors.last,
            ),
            onPressed: () => _reveal(i),
            child: Text(open ? '다시 듣기' : '정답',
                style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        ]),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          child: open
              ? Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                  decoration: BoxDecoration(
                    color: Washi.matcha.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: Washi.matcha.withValues(alpha: 0.35)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.check_rounded,
                        color: Washi.matcha, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(q.japanese,
                          key: ValueKey('screen-answer-text-$i'),
                          style: const TextStyle(
                              fontSize: 18,
                              height: 1.5,
                              fontWeight: FontWeight.w700,
                              color: Washi.ink)),
                    ),
                    SpeakButton(
                        speaking: _speaking == q.japanese,
                        color: Washi.matcha,
                        onPressed: () => _speak(q.japanese)),
                  ]),
                )
              : const SizedBox(width: double.infinity),
        ),
      ]),
    );
  }
}
