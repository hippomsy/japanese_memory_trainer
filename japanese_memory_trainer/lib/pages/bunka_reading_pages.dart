import 'package:kioku_japanese/widgets/chapter_art.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kioku_japanese/services/bunka_reading.dart';
import 'package:kioku_japanese/services/lesson_audio.dart';
import 'package:kioku_japanese/services/news_service.dart';
import 'package:kioku_japanese/widgets/ruby_text.dart';
import 'package:kioku_japanese/widgets/study_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 2026-10-05 문화 독해 목록: 기초(1~20강)·심화(21~40강).
class BunkaReadingListPage extends StatefulWidget {
  const BunkaReadingListPage(
      {super.key, this.audioFactory, this.lessons, this.preferences});

  /// 테스트에서 오디오·데이터·저장소를 바꿔 끼울 수 있다.
  final LessonAudio Function()? audioFactory;
  final Future<List<BunkaLesson>>? lessons;
  final Future<SharedPreferences>? preferences;

  @override
  State<BunkaReadingListPage> createState() => _BunkaReadingListPageState();
}

class _BunkaReadingListPageState extends State<BunkaReadingListPage> {
  late final Future<(List<BunkaLesson>, BunkaProgress)> _data = () async {
    final lessons = await (widget.lessons ?? BunkaLesson.load());
    final prefs =
        await (widget.preferences ?? SharedPreferences.getInstance());
    return (lessons, BunkaProgress(prefs));
  }();

  Future<void> _open(BunkaLesson lesson, BunkaProgress progress) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => BunkaLessonPage(
            lesson: lesson,
            progress: progress,
            audioFactory: widget.audioFactory)));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Washi.paper,
        appBar: washiAppBar(title: '문화 독해', subtitle: '원어민 낭독 · 문장별 듣기 · 전체 해석'),
        body: FutureBuilder<(List<BunkaLesson>, BunkaProgress)>(
          future: _data,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(child: Text('독해 자료를 불러오지 못했어요.'));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final (lessons, progress) = snapshot.data!;
            final read = lessons.where((l) => progress.read(l.id)).length;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                const SceneArt('library', height: 150),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                      color: Washi.ink,
                      borderRadius: BorderRadius.circular(26)),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.menu_book_rounded,
                            color: Color(0xFFFFCC94), size: 34),
                        const SizedBox(height: 10),
                        const Text('읽고 듣는\n일본 문화',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 10),
                        Text('${lessons.length}강 중 $read강 읽음',
                            style: const TextStyle(color: Colors.white70)),
                        const SizedBox(height: 10),
                        SlimProgress(
                            ratio: lessons.isEmpty ? 0 : read / lessons.length,
                            color: const Color(0xFFFFCC94)),
                      ]),
                ),
                const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Text(
                        '원어민 낭독을 들으며 본문을 읽고, 문장마다 다시 듣고, 내용 확인 문제를 풀어요. '
                        '스크립트는 녹음을 음성 인식으로 받아 적어 다듬은 것이라 드물게 원문과 다를 수 있어요.',
                        style: TextStyle(color: Washi.inkSoft, height: 1.6))),
                for (final part in [1, 2]) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 8),
                    child: Text(part == 1 ? 'PART 1 · 기초' : 'PART 2 · 심화',
                        style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                            color: Washi.ink)),
                  ),
                  for (final lesson in lessons.where((l) => l.part == part)) ...[
                    _LessonCard(
                        lesson: lesson,
                        read: progress.read(lesson.id),
                        score: progress.score(lesson.id),
                        onTap: () => _open(lesson, progress)),
                    const SizedBox(height: 8),
                  ],
                ],
              ],
            );
          },
        ),
      );
}

class _LessonCard extends StatelessWidget {
  const _LessonCard(
      {required this.lesson,
      required this.read,
      required this.score,
      required this.onTap});
  final BunkaLesson lesson;
  final bool read;
  final int? score;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => PaperCard(
        key: ValueKey('bunka-lesson-${lesson.number}'),
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          CircleAvatar(
            radius: 20,
            backgroundColor:
                read ? Washi.matcha : Washi.shu.withValues(alpha: 0.12),
            child: read
                ? const Icon(Icons.check, color: Colors.white)
                : Text('${lesson.chapter}',
                    style: const TextStyle(
                        color: Washi.shu, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 12),
          ChapterArt('reading', lesson.chapter, width: 72, height: 60),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(lesson.title,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                  Text(
                      '${lesson.partLabel} ${lesson.chapter}강 · ${lesson.titleKorean} · ${lesson.sentences.length}문장'
                      '${score == null ? '' : ' · 문제 $score/${lesson.questions.length}'}',
                      style: const TextStyle(
                          fontSize: 13, color: Washi.inkSoft)),
                ]),
          ),
          const Icon(Icons.chevron_right, color: Washi.inkSoft),
        ]),
      );
}

/// 2026-10-05 문화 독해 강의 화면.
/// 전체 낭독(진행 중인 문장 강조) · 문장별 원음 듣기 · 후리가나/해석/빈칸 모드 ·
/// 전체 해석 · 핵심 단어 · 내용 확인 문제.
class BunkaLessonPage extends StatefulWidget {
  const BunkaLessonPage(
      {super.key,
      required this.lesson,
      required this.progress,
      this.audioFactory});
  final BunkaLesson lesson;
  final BunkaProgress progress;
  final LessonAudio Function()? audioFactory;

  @override
  State<BunkaLessonPage> createState() => _BunkaLessonPageState();
}

class _BunkaLessonPageState extends State<BunkaLessonPage> {
  LessonAudio _create() => (widget.audioFactory ?? JustLessonAudio.new)();
  late final LessonAudio _full = _create(); // 전체 낭독
  late final LessonAudio _clip = _create(); // 문장·문제 구간 듣기
  final _subs = <StreamSubscription<Object?>>[];
  final _keys = <GlobalKey>[];

  bool _ready = false, _playing = false, _loop = false, _follow = true;
  bool _ruby = true, _korean = true, _blank = false;
  double _speed = 1.0;
  Duration _position = Duration.zero, _duration = Duration.zero;
  String? _error;

  /// 지금 재생 중인 구간 이름(예: 's3', 'q0', 'title').
  String? _clipPlaying;
  bool _clipActive = false;

  final _revealed = <int>{};
  final _answers = <int, int>{};

  BunkaLesson get lesson => widget.lesson;

  @override
  void initState() {
    super.initState();
    _keys.addAll(List.generate(lesson.sentences.length, (_) => GlobalKey()));
    _subs
      ..add(_full.playingStream.listen((v) {
        if (mounted) setState(() => _playing = v);
      }))
      ..add(_full.positionStream.listen(_onPosition))
      ..add(_full.durationStream.listen((v) {
        if (mounted && v != null) setState(() => _duration = v);
      }))
      ..add(_full.completedStream.listen((done) {
        if (done && !_loop) {
          _full.pause();
          _full.seek(Duration.zero);
          widget.progress.markRead(lesson.id);
        }
      }))
      ..add(_clip.playingStream.listen((v) {
        if (mounted) {
          setState(() {
            _clipActive = v;
            if (!v) _clipPlaying = null;
          });
        }
      }))
      ..add(_clip.completedStream.listen((done) {
        if (done) _clip.pause();
      }));
    _load();
  }

  Future<void> _load() async {
    try {
      await _full.load(lesson.audio);
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      if (mounted) setState(() => _error = '녹음 파일을 불러오지 못했어요.');
    }
  }

  int _current = -1;
  void _onPosition(Duration p) {
    if (!mounted) return;
    var index = -1;
    if (_playing) {
      for (var i = 0; i < lesson.sentences.length; i++) {
        final s = lesson.sentences[i];
        if (p >= s.start && p < s.end + const Duration(milliseconds: 300)) {
          index = i;
          break;
        }
      }
    }
    final changed = index != _current && index >= 0;
    setState(() {
      _position = p;
      if (index >= 0 || !_playing) _current = index;
    });
    if (changed && _follow) {
      final ctx = _keys[index].currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx,
            alignment: 0.25, duration: const Duration(milliseconds: 350));
      }
    }
  }

  Future<void> _toggleFull() async {
    if (!_ready) return;
    if (_playing) {
      await _full.pause();
      return;
    }
    await _clip.pause();
    await _full.setSpeed(_speed);
    await _full.play();
  }

  Future<void> _playClip(String id, String asset, Duration? s, Duration? e) async {
    if (s == null || e == null) return;
    if (_clipPlaying == id && _clipActive) {
      await _clip.pause();
      return;
    }
    if (_playing) await _full.pause();
    try {
      await _clip.setSpeed(_speed);
      await _clip.playClip(asset, s, e);
      if (mounted) setState(() => _clipPlaying = id);
    } catch (_) {
      if (mounted) setState(() => _error = '음성을 재생하지 못했어요.');
    }
  }

  Future<void> _setSpeed(double v) async {
    setState(() => _speed = v);
    if (_ready) await _full.setSpeed(v);
    await _clip.setSpeed(v);
  }

  Future<void> _seekBy(int seconds) async {
    var t = _position + Duration(seconds: seconds);
    if (t < Duration.zero) t = Duration.zero;
    if (_duration > Duration.zero && t > _duration) t = _duration;
    await _full.seek(t);
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _full.dispose();
    _clip.dispose();
    super.dispose();
  }

  String _fmt(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  void _showWord(NewsToken token) {
    showModalBottomSheet<void>(
        context: context,
        backgroundColor: Washi.paper,
        builder: (context) => SafeArea(
            child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(token.word ?? token.text,
                          style: const TextStyle(
                              fontSize: 30, fontWeight: FontWeight.bold)),
                      Text(token.reading, style: const TextStyle(fontSize: 20)),
                      const SizedBox(height: 6),
                      Text(token.meaning, style: const TextStyle(fontSize: 22)),
                      if (token.level != null) Text('JLPT N${token.level}'),
                    ]))));
  }

  /// 빈칸 모드: 급수 단어를 밑줄 칸으로 가린다.
  List<NewsToken> _display(int index, List<NewsToken> tokens) {
    if (!_blank || _revealed.contains(index)) return tokens;
    return [
      for (final t in tokens)
        if (t.level != null)
          NewsToken(parts: [('＿' * t.text.runes.length.clamp(2, 6).toInt(), '')])
        else
          t
    ];
  }

  Widget _speakButton(String id, String asset, Duration? s, Duration? e,
      {String tooltip = '문장 듣기'}) {
    final active = _clipPlaying == id && _clipActive;
    return IconButton(
      key: ValueKey('bunka-speak-$id'),
      tooltip: tooltip,
      onPressed: s == null ? null : () => _playClip(id, asset, s, e),
      icon: Icon(active ? Icons.stop_circle_outlined : Icons.volume_up_rounded,
          color: Washi.shu, size: 28),
    );
  }

  Widget _player() {
    final max = _duration.inMilliseconds.toDouble();
    final value =
        _position.inMilliseconds.clamp(0, max <= 0 ? 0 : max).toDouble();
    return PaperCard(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      child: Column(children: [
        Row(children: [
          const Icon(Icons.headphones_rounded, color: Washi.ink),
          const SizedBox(width: 8),
          const Text('원어민 낭독',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const Spacer(),
          ChoiceChip(
              label: const Text('1.0×'),
              selected: _speed == 1.0,
              onSelected: (_) => _setSpeed(1.0)),
          const SizedBox(width: 6),
          ChoiceChip(
              label: const Text('0.8×'),
              selected: _speed == 0.8,
              onSelected: (_) => _setSpeed(0.8)),
        ]),
        Slider(
            value: value,
            max: max <= 0 ? 1 : max,
            onChanged: max <= 0
                ? null
                : (v) => _full.seek(Duration(milliseconds: v.round()))),
        Row(children: [
          Text(_fmt(_position), style: const TextStyle(color: Washi.inkSoft)),
          const Spacer(),
          Text(_fmt(_duration), style: const TextStyle(color: Washi.inkSoft)),
        ]),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(
              tooltip: '5초 뒤로',
              onPressed: _ready ? () => _seekBy(-5) : null,
              icon: const Icon(Icons.replay_5)),
          FilledButton.icon(
              key: const ValueKey('bunka-play-all'),
              onPressed: _ready ? _toggleFull : null,
              icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
              label: Text(_playing ? '일시정지' : '전체 듣기')),
          IconButton(
              tooltip: '5초 앞으로',
              onPressed: _ready ? () => _seekBy(5) : null,
              icon: const Icon(Icons.forward_5)),
          IconButton(
              tooltip: '반복 재생',
              isSelected: _loop,
              onPressed: _ready
                  ? () async {
                      setState(() => _loop = !_loop);
                      await _full.setLoop(_loop);
                    }
                  : null,
              icon: const Icon(Icons.repeat),
              selectedIcon: const Icon(Icons.repeat_one, color: Washi.shu)),
          IconButton(
              tooltip: '읽는 문장 따라가기',
              isSelected: _follow,
              onPressed: () => setState(() => _follow = !_follow),
              icon: const Icon(Icons.my_location_outlined),
              selectedIcon: const Icon(Icons.my_location, color: Washi.shu)),
        ]),
      ]),
    );
  }

  Widget _sentence(int i) {
    final s = lesson.sentences[i];
    final current = i == _current && _playing;
    return Padding(
      key: _keys[i],
      padding: EdgeInsets.only(top: s.paragraphStart && i > 0 ? 18 : 6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        decoration: BoxDecoration(
          color: current ? const Color(0xFFFFF0D6) : Washi.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: current ? Washi.shu : Washi.line),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.only(top: 4, right: 6),
              child: Text('${i + 1}',
                  style: const TextStyle(
                      fontSize: 12,
                      color: Washi.inkSoft,
                      fontWeight: FontWeight.w700)),
            ),
            Expanded(
              child: RubyText(
                key: ValueKey('bunka-sentence-$i'),
                tokens: _display(i, s.tokens),
                fontSize: 20,
                showRuby: _ruby,
                onWordTap: _blank && !_revealed.contains(i) ? null : _showWord,
              ),
            ),
            Column(children: [
              _speakButton('s$i', lesson.audio, s.start, s.end),
              if (_blank && !_revealed.contains(i))
                IconButton(
                    tooltip: '빈칸 정답 보기',
                    onPressed: () => setState(() => _revealed.add(i)),
                    icon: const Icon(Icons.visibility_outlined,
                        color: Washi.inkSoft)),
            ]),
          ]),
          if (_korean)
            Padding(
              padding: const EdgeInsets.only(left: 18, right: 8, top: 4),
              child: Text(s.korean,
                  key: ValueKey('bunka-korean-$i'),
                  style: const TextStyle(
                      fontSize: 15, color: Washi.inkSoft, height: 1.5)),
            ),
        ]),
      ),
    );
  }

  Widget _question(int i) {
    final q = lesson.questions[i];
    final chosen = _answers[i];
    return PaperCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Text('問${i + 1}. ${q.japanese}',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ),
          _speakButton('q$i', lesson.questionAudio, q.start, q.end,
              tooltip: '문제 듣기'),
        ]),
        if (_korean || chosen != null)
          Text(q.korean, style: const TextStyle(color: Washi.inkSoft)),
        for (var o = 0; o < q.options.length; o++)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton(
              key: ValueKey('bunka-q$i-option-$o'),
              style: OutlinedButton.styleFrom(
                alignment: Alignment.centerLeft,
                disabledForegroundColor: Washi.ink,
                backgroundColor: chosen == null
                    ? null
                    : o == q.answer
                        ? Washi.matcha.withValues(alpha: 0.15)
                        : o == chosen
                            ? Washi.shu.withValues(alpha: 0.12)
                            : null,
              ),
              onPressed: chosen != null ? null : () => _answer(i, o),
              child: Text('${o + 1}. ${q.options[o]}',
                  style: const TextStyle(fontSize: 16)),
            ),
          ),
        if (chosen != null) ...[
          const SizedBox(height: 10),
          Text(chosen == q.answer ? '정답이에요!' : '정답은 ${q.answer + 1}번이에요.',
              key: ValueKey('bunka-q$i-feedback'),
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: chosen == q.answer ? Washi.matcha : Washi.shu)),
          if (q.explanation.isNotEmpty)
            Text(q.explanation, style: const TextStyle(height: 1.5)),
        ],
      ]),
    );
  }

  Future<void> _answer(int question, int option) async {
    setState(() => _answers[question] = option);
    if (_answers.length == lesson.questions.length) {
      final score = [
        for (final e in _answers.entries)
          if (lesson.questions[e.key].answer == e.value) 1
      ].length;
      await widget.progress.saveScore(lesson.id, score);
    }
  }

  Widget _toggles() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
            color: Washi.card,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Washi.line),
            boxShadow: [
              BoxShadow(
                  color: Washi.ink.withValues(alpha: 0.12), blurRadius: 12)
            ]),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          _toggle('후리가나', _ruby, (v) => setState(() => _ruby = v)),
          _toggle('해석', _korean, (v) => setState(() => _korean = v)),
          _toggle('빈칸', _blank, (v) {
            setState(() {
              _blank = v;
              _revealed.clear();
            });
          }),
        ]),
      );

  Widget _toggle(String label, bool value, ValueChanged<bool> onChanged) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
        child: FilterChip(
            key: ValueKey('bunka-toggle-$label'),
            label: Text(label),
            selected: value,
            onSelected: onChanged),
      );

  Widget _heading(String text, {Widget? trailing}) => Padding(
        padding: const EdgeInsets.only(top: 26, bottom: 6),
        child: Row(children: [
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Washi.ink)),
          ),
          if (trailing != null) trailing,
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final read = widget.progress.read(lesson.id);
    return Scaffold(
      backgroundColor: Washi.paper,
      appBar: washiAppBar(
          title: '${lesson.partLabel} ${lesson.chapter}강',
          subtitle: lesson.titleKorean),
      body: Stack(children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
          children: [
            ChapterArt('reading', lesson.chapter, height: 170),
            const SizedBox(height: 12),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: RubyText(
                    key: const ValueKey('bunka-title'),
                    tokens: lesson.titleTokens,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    showRuby: _ruby,
                    showUnderline: false,
                    onWordTap: _showWord),
              ),
              _speakButton('title', lesson.audio, lesson.titleStart,
                  lesson.titleEnd,
                  tooltip: '제목 듣기'),
            ]),
            Text(lesson.titleKorean,
                style: const TextStyle(fontSize: 16, color: Washi.inkSoft)),
            const SizedBox(height: 12),
            _player(),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: const TextStyle(color: Washi.shu)),
              ),
            _heading('본문'),
            const Text('단어를 누르면 뜻을, 🔊를 누르면 그 문장을 원음으로 들려줘요.',
                style: TextStyle(fontSize: 13, color: Washi.inkSoft)),
            for (var i = 0; i < lesson.sentences.length; i++) _sentence(i),
            _heading('전체 해석'),
            PaperCard(
              child: Text(lesson.koreanFull,
                  key: const ValueKey('bunka-korean-full'),
                  style: const TextStyle(fontSize: 16, height: 1.8)),
            ),
            if (lesson.words.isNotEmpty) ...[
              _heading('핵심 단어'),
              PaperCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(children: [
                  for (final w in lesson.words)
                    ListTile(
                      dense: true,
                      leading: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: GradeColors.of('N${w.level}').main,
                            borderRadius: BorderRadius.circular(6)),
                        child: Text('N${w.level}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w800)),
                      ),
                      title: Text('${w.word}  ${w.reading}',
                          style: const TextStyle(fontSize: 17)),
                      subtitle: Text(w.meaning),
                    ),
                ]),
              ),
            ],
            if (lesson.questions.isNotEmpty) ...[
              _heading('내용 확인 문제',
                  trailing: Text(
                      '${_answers.length}/${lesson.questions.length}',
                      style: const TextStyle(color: Washi.inkSoft))),
              for (var i = 0; i < lesson.questions.length; i++) ...[
                _question(i),
                const SizedBox(height: 10),
              ],
            ],
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              key: const ValueKey('bunka-mark-read'),
              onPressed: read
                  ? null
                  : () async {
                      await widget.progress.markRead(lesson.id);
                      if (mounted) setState(() {});
                    },
              icon: Icon(read ? Icons.check_circle : Icons.check),
              label: Text(read ? '읽기 완료' : '다 읽었어요'),
            ),
          ],
        ),
        Positioned(
            left: 0, right: 0, bottom: 18, child: Center(child: _toggles())),
      ]),
    );
  }
}
