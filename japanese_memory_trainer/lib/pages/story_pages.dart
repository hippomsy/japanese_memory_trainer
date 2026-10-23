import 'dart:math';

import 'package:flutter/material.dart';
import 'package:kioku_japanese/pages/listening_page.dart' show ListeningVoice;
import 'package:kioku_japanese/services/news_service.dart';
import 'package:kioku_japanese/services/story_course.dart';
import 'package:kioku_japanese/widgets/chapter_art.dart';
import 'package:kioku_japanese/widgets/ruby_text.dart';
import 'package:kioku_japanese/widgets/study_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 2026-10-14 「N4 이야기 극장」 메뉴 색(朱鷺·とき色 계열).
const Color storyColor = Color(0xFFC0504D);
const Color _hl = Color(0xFFFFF0D6);

/// TTS 속도: 보통 / 천천히.
const double _normalRate = 0.5;
const double _slowRate = 0.32;

const String _ttsError =
    '일본어 음성을 재생하지 못했어요. 기기 설정 > 텍스트 음성 변환에서 일본어 음성을 설치해 주세요.';

/// 2026-10-14 이야기 목록.
class StoryListPage extends StatefulWidget {
  const StoryListPage(
      {super.key,
      required this.speak,
      required this.stop,
      this.stories,
      this.preferences});
  final ListeningVoice speak;
  final Future<void> Function() stop;

  /// 테스트에서 데이터·저장소를 바꿔 끼울 수 있다.
  final Future<List<Story>>? stories;
  final Future<SharedPreferences>? preferences;

  @override
  State<StoryListPage> createState() => _StoryListPageState();
}

class _StoryListPageState extends State<StoryListPage> {
  late final Future<(List<Story>, StoryProgress)> _data = () async {
    final stories = await (widget.stories ?? Story.load());
    final prefs = await (widget.preferences ?? SharedPreferences.getInstance());
    return (stories, StoryProgress(prefs));
  }();

  Future<void> _open(Story story, StoryProgress progress) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => StoryPage(
            story: story,
            progress: progress,
            speak: widget.speak,
            stop: widget.stop)));
    await widget.stop();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Washi.paper,
        appBar: washiAppBar(
            title: 'N4 이야기 극장', subtitle: '재미있게 읽고 · 듣고 · 외우기'),
        body: FutureBuilder<(List<Story>, StoryProgress)>(
          future: _data,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(child: Text('이야기를 불러오지 못했어요.'));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final (stories, progress) = snapshot.data!;
            final read = stories.where((s) => progress.read(s.id)).length;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                      color: storyColor,
                      borderRadius: BorderRadius.circular(26)),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.theater_comedy_rounded,
                            color: Colors.white, size: 34),
                        const SizedBox(height: 10),
                        const Text('반전이 있는\n짧은 일본어 이야기',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 10),
                        Text('${stories.length}편 중 $read편 완료',
                            style: const TextStyle(color: Colors.white70)),
                        const SizedBox(height: 10),
                        SlimProgress(
                            ratio: stories.isEmpty ? 0 : read / stories.length,
                            color: Colors.white),
                      ]),
                ),
                const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Text(
                        '① 전체 듣기로 먼저 귀로 들어 보고 ② 문장마다 다시 듣고 해석을 확인한 뒤 '
                        '③ 단어 카드와 문법, 내용 문제로 마무리해요. 음성은 기기의 일본어 TTS로 읽어 줘요.',
                        style: TextStyle(color: Washi.inkSoft, height: 1.6))),
                for (final story in stories) ...[
                  _StoryCard(
                      story: story,
                      read: progress.read(story.id),
                      score: progress.score(story.id),
                      known: progress.known(story.id).length,
                      onTap: () => _open(story, progress)),
                  const SizedBox(height: 10),
                ],
              ],
            );
          },
        ),
      );
}

class _StoryCard extends StatelessWidget {
  const _StoryCard(
      {required this.story,
      required this.read,
      required this.score,
      required this.known,
      required this.onTap});
  final Story story;
  final bool read;
  final int? score;
  final int known;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => PaperCard(
        key: ValueKey('story-card-${story.number}'),
        onTap: onTap,
        padding: const EdgeInsets.all(12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Stack(children: [
            SceneArt(story.scene, height: 78, width: 78, radius: 14),
            Positioned(
              left: 4,
              top: 4,
              child: CircleAvatar(
                radius: 13,
                backgroundColor: read ? Washi.matcha : storyColor,
                child: read
                    ? const Icon(Icons.check, color: Colors.white, size: 16)
                    : Text('${story.number}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800)),
              ),
            ),
          ]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(story.title,
                      style: const TextStyle(
                          fontSize: 19, fontWeight: FontWeight.w800)),
                  Text(story.titleKorean,
                      style: const TextStyle(
                          fontSize: 14,
                          color: storyColor,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(story.summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, color: Washi.inkSoft, height: 1.4)),
                  const SizedBox(height: 4),
                  Text(
                      '${story.sentences.length}문장 · 단어 $known/${story.words.length}'
                      '${score == null ? '' : ' · 문제 $score/${story.questions.length}'}',
                      style: const TextStyle(
                          fontSize: 12, color: Washi.inkSoft)),
                ]),
          ),
        ]),
      );
}

/// 2026-10-14 이야기 화면.
/// 전체 듣기(읽는 문장 강조·자동 스크롤·섀도잉 틈·반복) · 문장별 듣기/천천히 ·
/// 후리가나/해석/빈칸 · 전체 해석 · 핵심 단어(단어 카드·퀴즈) · 문법 · 내용 확인 문제.
class StoryPage extends StatefulWidget {
  const StoryPage(
      {super.key,
      required this.story,
      required this.progress,
      required this.speak,
      required this.stop});
  final Story story;
  final StoryProgress progress;
  final ListeningVoice speak;
  final Future<void> Function() stop;

  @override
  State<StoryPage> createState() => _StoryPageState();
}

class _StoryPageState extends State<StoryPage> {
  final _keys = <GlobalKey>[];
  bool _ruby = true, _korean = true, _blank = false;
  bool _slow = false, _shadow = false, _loop = false, _follow = true;

  /// 재생 차례 번호. 새 재생을 시작하거나 멈추면 올려서 이전 재생을 끊는다.
  int _run = 0;
  bool _playingAll = false;

  /// 지금 읽는 문장(-1이면 없음)과 단독 재생 중인 항목 id.
  int _current = -1;
  String? _single;
  String? _error;

  final _revealed = <int>{};
  final _answers = <int, int>{};

  Story get story => widget.story;
  double get _rate => _slow ? _slowRate : _normalRate;

  @override
  void initState() {
    super.initState();
    _keys.addAll(List.generate(story.sentences.length, (_) => GlobalKey()));
  }

  @override
  void dispose() {
    _run++;
    widget.stop();
    super.dispose();
  }

  Future<bool> _say(String text, double rate) async {
    final run = _run;
    try {
      await widget.speak(text, rate);
      return true;
    } catch (_) {
      // 사용자가 멈춰서 끊긴 경우(_run 이 바뀜)는 오류로 보지 않는다.
      if (mounted && run == _run) setState(() => _error = _ttsError);
      return false;
    }
  }

  void _scrollTo(int i) {
    if (!_follow) return;
    final ctx = _keys[i].currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx,
          alignment: 0.3, duration: const Duration(milliseconds: 350));
    }
  }

  /// 섀도잉: 문장 길이에 맞춰 따라 말할 틈을 준다.
  Duration _gap(String text) => _shadow
      ? Duration(
          milliseconds:
              (900 + text.runes.length * (_slow ? 190 : 140)).clamp(1500, 9000).toInt())
      : const Duration(milliseconds: 350);

  Future<void> _playAll({int from = 0}) async {
    final run = ++_run;
    await widget.stop();
    if (!mounted || run != _run) return;
    setState(() {
      _playingAll = true;
      _single = null;
      _error = null;
    });
    var start = from;
    do {
      for (var i = start; i < story.sentences.length; i++) {
        if (!mounted || run != _run) return;
        setState(() => _current = i);
        _scrollTo(i);
        final text = story.sentences[i].japanese;
        if (!await _say(text, _rate) || run != _run) {
          if (mounted && run == _run) _finish();
          return;
        }
        await Future<void>.delayed(_gap(text));
      }
      start = 0;
    } while (_loop && mounted && run == _run);
    if (!mounted || run != _run) return;
    _finish();
    await widget.progress.markRead(story.id);
    if (mounted) setState(() {});
  }

  void _finish() => setState(() {
        _playingAll = false;
        _current = -1;
      });

  Future<void> _stopAll() async {
    _run++;
    await widget.stop();
    if (mounted) {
      setState(() {
        _playingAll = false;
        _current = -1;
        _single = null;
      });
    }
  }

  /// 문장·예문·문제 하나만 읽는다. 같은 버튼을 다시 누르면 멈춘다.
  Future<void> _playOne(String id, String text,
      {double? rate, int sentence = -1}) async {
    if (_single == id) {
      await _stopAll();
      return;
    }
    final run = ++_run;
    await widget.stop();
    if (!mounted || run != _run) return;
    setState(() {
      _playingAll = false;
      _single = id;
      _current = sentence;
      _error = null;
    });
    await _say(text, rate ?? _rate);
    if (mounted && run == _run) {
      setState(() {
        _single = null;
        _current = -1;
      });
    }
  }

  void _showWord(NewsToken token) {
    final word = token.word ?? token.text;
    final reading = token.reading.isNotEmpty
        ? token.reading
        : token.parts.map((p) => p.$2.isEmpty ? p.$1 : p.$2).join();
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
                      Row(children: [
                        Expanded(
                          child: Text(word,
                              style: const TextStyle(
                                  fontSize: 30, fontWeight: FontWeight.bold)),
                        ),
                        IconButton(
                            tooltip: '발음 듣기',
                            onPressed: () => _say(reading, _normalRate),
                            icon: const Icon(Icons.volume_up_rounded,
                                color: storyColor, size: 30)),
                      ]),
                      if (reading != word)
                        Text(reading, style: const TextStyle(fontSize: 20)),
                      const SizedBox(height: 6),
                      if (token.meaning.isNotEmpty)
                        Text(token.meaning,
                            style: const TextStyle(fontSize: 22)),
                      if (token.level != null) Text('JLPT N${token.level}'),
                    ]))));
  }

  /// 빈칸 모드: 급수 단어를 밑줄 칸으로 가린다.
  List<NewsToken> _display(int index, List<NewsToken> tokens) {
    if (!_blank || _revealed.contains(index)) return tokens;
    return [
      for (final t in tokens)
        if (t.level != null)
          NewsToken(
              parts: [('＿' * t.text.runes.length.clamp(2, 6).toInt(), '')])
        else
          t
    ];
  }

  Widget _player() => PaperCard(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Icon(Icons.headphones_rounded, color: Washi.ink),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                  _playingAll && _current >= 0
                      ? '${_current + 1} / ${story.sentences.length} 문장'
                      : '전체 듣기 · ${story.sentences.length}문장',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800)),
            ),
          ]),
          const SizedBox(height: 8),
          if (_playingAll)
            SlimProgress(
                ratio: (_current + 1) / story.sentences.length,
                color: storyColor),
          const SizedBox(height: 10),
          FilledButton.icon(
            key: const ValueKey('story-play-all'),
            style: FilledButton.styleFrom(
                backgroundColor: storyColor,
                padding: const EdgeInsets.symmetric(vertical: 12)),
            onPressed: _playingAll ? _stopAll : () => _playAll(),
            icon: Icon(_playingAll ? Icons.stop_rounded : Icons.play_arrow),
            label: Text(_playingAll ? '멈추기' : '처음부터 전체 듣기',
                style: const TextStyle(fontSize: 16)),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 4, children: [
            FilterChip(
                key: const ValueKey('story-slow'),
                avatar: const Icon(Icons.slow_motion_video, size: 18),
                label: const Text('천천히'),
                selected: _slow,
                onSelected: (v) => setState(() => _slow = v)),
            FilterChip(
                key: const ValueKey('story-shadow'),
                avatar: const Icon(Icons.record_voice_over, size: 18),
                label: const Text('섀도잉 틈'),
                selected: _shadow,
                onSelected: (v) => setState(() => _shadow = v)),
            FilterChip(
                avatar: const Icon(Icons.repeat, size: 18),
                label: const Text('반복'),
                selected: _loop,
                onSelected: (v) => setState(() => _loop = v)),
            FilterChip(
                avatar: const Icon(Icons.my_location, size: 18),
                label: const Text('따라가기'),
                selected: _follow,
                onSelected: (v) => setState(() => _follow = v)),
          ]),
          if (_shadow)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('문장이 끝나면 따라 말할 시간을 줘요.',
                  style: TextStyle(fontSize: 12, color: Washi.inkSoft)),
            ),
        ]),
      );

  Widget _sentence(int i) {
    final s = story.sentences[i];
    final current = i == _current;
    final hidden = _blank && !_revealed.contains(i);
    return Padding(
      key: _keys[i],
      padding: EdgeInsets.only(top: s.paragraphStart && i > 0 ? 18 : 6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.fromLTRB(12, 8, 2, 8),
        decoration: BoxDecoration(
          color: current ? _hl : Washi.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: current ? storyColor : Washi.line),
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
                key: ValueKey('story-sentence-$i'),
                tokens: _display(i, s.tokens),
                fontSize: 20,
                showRuby: _ruby,
                onWordTap: hidden ? null : _showWord,
              ),
            ),
            Column(children: [
              IconButton(
                key: ValueKey('story-speak-$i'),
                tooltip: '문장 듣기',
                visualDensity: VisualDensity.compact,
                onPressed: () =>
                    _playOne('s$i', s.japanese, rate: _normalRate, sentence: i),
                icon: Icon(
                    _single == 's$i'
                        ? Icons.stop_circle_outlined
                        : Icons.volume_up_rounded,
                    color: storyColor,
                    size: 26),
              ),
              IconButton(
                key: ValueKey('story-slow-$i'),
                tooltip: '천천히 듣기',
                visualDensity: VisualDensity.compact,
                onPressed: () => _playOne('slow$i', s.japanese,
                    rate: _slowRate, sentence: i),
                icon: Icon(
                    _single == 'slow$i'
                        ? Icons.stop_circle_outlined
                        : Icons.slow_motion_video,
                    color: Washi.inkSoft,
                    size: 22),
              ),
              if (hidden)
                IconButton(
                    tooltip: '빈칸 정답 보기',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(() => _revealed.add(i)),
                    icon: const Icon(Icons.visibility_outlined,
                        color: Washi.inkSoft)),
            ]),
          ]),
          if (_korean)
            Padding(
              padding: const EdgeInsets.only(left: 18, right: 8, top: 2),
              child: Text(s.korean,
                  key: ValueKey('story-korean-$i'),
                  style: const TextStyle(
                      fontSize: 15, color: Washi.inkSoft, height: 1.5)),
            ),
          if (!_playingAll)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                  style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: Washi.inkSoft),
                  onPressed: () => _playAll(from: i),
                  icon: const Icon(Icons.playlist_play, size: 18),
                  label: const Text('여기부터', style: TextStyle(fontSize: 12))),
            ),
        ]),
      ),
    );
  }

  Widget _grammar(int i) {
    final g = story.grammar[i];
    return PaperCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: storyColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10)),
            child: Text(g.pattern,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: storyColor)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(g.meaning,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 8),
        Text(g.note, style: const TextStyle(height: 1.5)),
        const Divider(height: 20),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(g.japanese, style: const TextStyle(fontSize: 18)),
                  Text(g.korean,
                      style: const TextStyle(color: Washi.inkSoft)),
                ]),
          ),
          IconButton(
              tooltip: '예문 듣기',
              onPressed: () => _playOne('g$i', g.japanese),
              icon: Icon(
                  _single == 'g$i'
                      ? Icons.stop_circle_outlined
                      : Icons.volume_up_rounded,
                  color: storyColor)),
        ]),
      ]),
    );
  }

  Widget _question(int i) {
    final q = story.questions[i];
    final chosen = _answers[i];
    return PaperCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Text('問${i + 1}. ${q.japanese}',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ),
          IconButton(
              tooltip: '문제 듣기',
              onPressed: () => _playOne('q$i', q.japanese),
              icon: Icon(
                  _single == 'q$i'
                      ? Icons.stop_circle_outlined
                      : Icons.volume_up_rounded,
                  color: storyColor)),
        ]),
        if (_korean || chosen != null)
          Text(q.korean, style: const TextStyle(color: Washi.inkSoft)),
        for (var o = 0; o < q.options.length; o++)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton(
              key: ValueKey('story-q$i-option-$o'),
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
              key: ValueKey('story-q$i-feedback'),
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
    if (_answers.length == story.questions.length) {
      final score = [
        for (final e in _answers.entries)
          if (story.questions[e.key].answer == e.value) 1
      ].length;
      await widget.progress.saveScore(story.id, score);
      if (mounted) setState(() {});
    }
  }

  Future<void> _openWords({int mode = 0}) async {
    await _stopAll();
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => StoryWordPage(
            story: story,
            progress: widget.progress,
            speak: widget.speak,
            stop: widget.stop,
            initialMode: mode)));
    if (mounted) setState(() {});
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
            key: ValueKey('story-toggle-$label'),
            label: Text(label),
            selected: value,
            onSelected: onChanged),
      );

  Widget _heading(String text, {Widget? trailing}) => Padding(
        padding: const EdgeInsets.only(top: 26, bottom: 8),
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
    final read = widget.progress.read(story.id);
    final known = widget.progress.known(story.id);
    return Scaffold(
      backgroundColor: Washi.paper,
      appBar: washiAppBar(
          title: '이야기 ${story.number}', subtitle: story.titleKorean),
      body: Stack(children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
          children: [
            SceneArt(story.scene, height: 170),
            const SizedBox(height: 12),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: RubyText(
                    key: const ValueKey('story-title'),
                    tokens: story.titleTokens,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    showRuby: _ruby,
                    showUnderline: false,
                    onWordTap: _showWord),
              ),
              IconButton(
                  tooltip: '제목 듣기',
                  onPressed: () => _playOne('title', story.title),
                  icon: const Icon(Icons.volume_up_rounded,
                      color: storyColor, size: 28)),
            ]),
            Text(story.titleKorean,
                style: const TextStyle(fontSize: 16, color: Washi.inkSoft)),
            const SizedBox(height: 6),
            Text(story.summary,
                style: const TextStyle(fontSize: 14, height: 1.5)),
            const SizedBox(height: 12),
            _player(),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: const TextStyle(color: Washi.shu)),
              ),
            _heading('본문'),
            const Text('밑줄 단어를 누르면 뜻을, 🔊는 보통 속도, 🐢 아이콘은 천천히 읽어 줘요.',
                style: TextStyle(fontSize: 13, color: Washi.inkSoft)),
            for (var i = 0; i < story.sentences.length; i++) _sentence(i),
            _heading('전체 해석'),
            PaperCard(
              child: Text(story.koreanFull,
                  key: const ValueKey('story-korean-full'),
                  style: const TextStyle(fontSize: 16, height: 1.8)),
            ),
            _heading('단어 공부',
                trailing: Text('외움 ${known.length}/${story.words.length}',
                    style: const TextStyle(color: Washi.inkSoft))),
            Row(children: [
              Expanded(
                child: FilledButton.tonalIcon(
                    key: const ValueKey('story-word-cards'),
                    onPressed: () => _openWords(),
                    icon: const Icon(Icons.style_rounded),
                    label: const Text('단어 카드')),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.tonalIcon(
                    key: const ValueKey('story-word-quiz'),
                    onPressed: () => _openWords(mode: 1),
                    icon: const Icon(Icons.quiz_rounded),
                    label: const Text('단어 퀴즈')),
              ),
            ]),
            const SizedBox(height: 8),
            PaperCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(children: [
                for (final w in story.words)
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
                    title: Text(
                        w.kanaOnly ? w.word : '${w.word}  ${w.reading}',
                        style: const TextStyle(fontSize: 17)),
                    subtitle: Text(w.meaning),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (known.contains(w.word))
                        const Icon(Icons.check_circle,
                            color: Washi.matcha, size: 20),
                      IconButton(
                          tooltip: '발음 듣기',
                          onPressed: () =>
                              _playOne('w${w.word}', w.reading),
                          icon: const Icon(Icons.volume_up_rounded,
                              color: storyColor)),
                    ]),
                  ),
              ]),
            ),
            if (story.grammar.isNotEmpty) ...[
              _heading('문법 포인트'),
              for (var i = 0; i < story.grammar.length; i++) ...[
                _grammar(i),
                const SizedBox(height: 10),
              ],
            ],
            if (story.questions.isNotEmpty) ...[
              _heading('내용 확인 문제',
                  trailing: Text(
                      '${_answers.length}/${story.questions.length}',
                      style: const TextStyle(color: Washi.inkSoft))),
              for (var i = 0; i < story.questions.length; i++) ...[
                _question(i),
                const SizedBox(height: 10),
              ],
            ],
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              key: const ValueKey('story-mark-read'),
              onPressed: read
                  ? null
                  : () async {
                      await widget.progress.markRead(story.id);
                      if (mounted) setState(() {});
                    },
              icon: Icon(read ? Icons.check_circle : Icons.check),
              label: Text(read ? '이야기 완료' : '다 읽었어요'),
            ),
          ],
        ),
        Positioned(
            left: 0, right: 0, bottom: 18, child: Center(child: _toggles())),
      ]),
    );
  }
}

/// 2026-10-14 이야기 핵심 단어 공부: 카드(뒤집기·알아요/몰라요) / 뜻 퀴즈 / 듣기 퀴즈.
class StoryWordPage extends StatefulWidget {
  const StoryWordPage(
      {super.key,
      required this.story,
      required this.progress,
      required this.speak,
      required this.stop,
      this.initialMode = 0,
      this.random});
  final Story story;
  final StoryProgress progress;
  final ListeningVoice speak;
  final Future<void> Function() stop;

  /// 0 카드, 1 뜻 퀴즈, 2 듣기 퀴즈.
  final int initialMode;
  final Random? random;

  @override
  State<StoryWordPage> createState() => _StoryWordPageState();
}

class _StoryWordPageState extends State<StoryWordPage> {
  late int _mode = widget.initialMode;
  late final Random _rng = widget.random ?? Random();

  // 카드
  bool _onlyUnknown = false, _flipped = false;
  int _cardIndex = 0;

  // 퀴즈
  List<StoryWord> _quizOrder = const [];
  List<StoryWord> _options = const [];
  int _quizIndex = 0, _correct = 0;
  StoryWord? _picked;
  String? _error;

  List<StoryWord> get _words => widget.story.words;

  List<StoryWord> get _deck {
    if (!_onlyUnknown) return _words;
    final known = widget.progress.known(widget.story.id);
    return [
      for (final w in _words)
        if (!known.contains(w.word)) w
    ];
  }

  @override
  void initState() {
    super.initState();
    if (_mode > 0) _startQuiz();
  }

  @override
  void dispose() {
    widget.stop();
    super.dispose();
  }

  Future<void> _say(String text) async {
    try {
      await widget.speak(text, _normalRate);
    } catch (_) {
      if (mounted) setState(() => _error = _ttsError);
    }
  }

  void _setMode(int mode) {
    widget.stop();
    setState(() {
      _mode = mode;
      _error = null;
      _flipped = false;
      if (mode > 0) _startQuiz();
    });
  }

  void _startQuiz() {
    _quizOrder = [..._words]..shuffle(_rng);
    _quizIndex = 0;
    _correct = 0;
    _nextOptions();
  }

  void _nextOptions() {
    _picked = null;
    if (_quizIndex >= _quizOrder.length) return;
    final answer = _quizOrder[_quizIndex];
    final others = [
      for (final w in _words)
        if (w.word != answer.word) w
    ]..shuffle(_rng);
    _options = [answer, ...others.take(3)]..shuffle(_rng);
    if (_mode == 2) _say(answer.reading);
  }

  Future<void> _mark(bool known) async {
    final deck = _deck;
    if (deck.isEmpty) return;
    final word = deck[_cardIndex.clamp(0, deck.length - 1).toInt()];
    await widget.progress.setKnown(widget.story.id, word.word, known);
    setState(() {
      _flipped = false;
      final next = _deck;
      if (next.isEmpty) {
        _cardIndex = 0;
      } else if (_onlyUnknown && known) {
        // 외운 단어가 빠졌으므로 같은 자리에 다음 단어가 온다.
        _cardIndex = _cardIndex % next.length;
      } else {
        _cardIndex = (_cardIndex + 1) % next.length;
      }
    });
  }

  Widget _cards() {
    final deck = _deck;
    final known = widget.progress.known(widget.story.id);
    if (deck.isEmpty) {
      return Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.emoji_events_rounded, color: storyColor, size: 64),
        const SizedBox(height: 12),
        const Text('이 이야기의 단어를 모두 외웠어요!',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        OutlinedButton(
            onPressed: () => setState(() => _onlyUnknown = false),
            child: const Text('전체 단어 다시 보기')),
      ]);
    }
    final i = _cardIndex.clamp(0, deck.length - 1).toInt();
    final w = deck[i];
    return Column(children: [
      Row(children: [
        Text('${i + 1} / ${deck.length}',
            style: const TextStyle(color: Washi.inkSoft)),
        const Spacer(),
        FilterChip(
            label: Text('모르는 것만 (${_words.length - known.length})'),
            selected: _onlyUnknown,
            onSelected: (v) => setState(() {
                  _onlyUnknown = v;
                  _cardIndex = 0;
                  _flipped = false;
                })),
      ]),
      const SizedBox(height: 12),
      Expanded(
        child: GestureDetector(
          key: const ValueKey('story-card-flip'),
          onTap: () => setState(() => _flipped = !_flipped),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Container(
              key: ValueKey('${w.word}-$_flipped'),
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _flipped ? _hl : Washi.card,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: _flipped ? storyColor : Washi.line, width: 2),
              ),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (known.contains(w.word))
                      const Icon(Icons.check_circle, color: Washi.matcha),
                    Text(w.word,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 44, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 14),
                    if (_flipped) ...[
                      if (!w.kanaOnly)
                        Text(w.reading,
                            style: const TextStyle(
                                fontSize: 24, color: storyColor)),
                      const SizedBox(height: 8),
                      Text(w.meaning,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 26)),
                      const SizedBox(height: 6),
                      Text('JLPT N${w.level}',
                          style: const TextStyle(color: Washi.inkSoft)),
                    ] else
                      const Text('눌러서 뜻 보기',
                          style: TextStyle(color: Washi.inkSoft)),
                    const SizedBox(height: 14),
                    IconButton(
                        tooltip: '발음 듣기',
                        onPressed: () => _say(w.reading),
                        icon: const Icon(Icons.volume_up_rounded,
                            color: storyColor, size: 34)),
                  ]),
            ),
          ),
        ),
      ),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(
          child: OutlinedButton.icon(
              key: const ValueKey('story-card-unknown'),
              style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              onPressed: () => _mark(false),
              icon: const Icon(Icons.replay),
              label: const Text('몰라요')),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton.icon(
              key: const ValueKey('story-card-known'),
              style: FilledButton.styleFrom(
                  backgroundColor: Washi.matcha,
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              onPressed: () => _mark(true),
              icon: const Icon(Icons.check),
              label: const Text('알아요')),
        ),
      ]),
    ]);
  }

  Widget _quiz() {
    if (_quizIndex >= _quizOrder.length) {
      return Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.emoji_events_rounded, color: storyColor, size: 64),
        const SizedBox(height: 12),
        Text('$_correct / ${_quizOrder.length} 정답',
            key: const ValueKey('story-quiz-result'),
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
        const SizedBox(height: 16),
        FilledButton(
            style: FilledButton.styleFrom(backgroundColor: storyColor),
            onPressed: () => setState(_startQuiz),
            child: const Text('다시 풀기')),
      ]);
    }
    final answer = _quizOrder[_quizIndex];
    final listening = _mode == 2;
    return ListView(children: [
      Text('${_quizIndex + 1} / ${_quizOrder.length}   ·   맞힘 $_correct',
          style: const TextStyle(color: Washi.inkSoft)),
      const SizedBox(height: 10),
      PaperCard(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
        child: Column(children: [
          if (listening) ...[
            IconButton(
                key: const ValueKey('story-quiz-listen'),
                iconSize: 64,
                onPressed: () => _say(answer.reading),
                icon: const Icon(Icons.volume_up_rounded, color: storyColor)),
            const Text('듣고 알맞은 단어를 고르세요',
                style: TextStyle(color: Washi.inkSoft)),
            if (_picked != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('${answer.reading} · ${answer.meaning}',
                    style: const TextStyle(fontSize: 18)),
              ),
          ] else ...[
            Text(answer.word,
                style:
                    const TextStyle(fontSize: 40, fontWeight: FontWeight.w800)),
            if (_picked != null && !answer.kanaOnly)
              Text(answer.reading,
                  style: const TextStyle(fontSize: 20, color: storyColor)),
            const SizedBox(height: 6),
            const Text('알맞은 뜻을 고르세요',
                style: TextStyle(color: Washi.inkSoft)),
          ],
        ]),
      ),
      const SizedBox(height: 8),
      for (var o = 0; o < _options.length; o++)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: OutlinedButton(
            key: ValueKey('story-quiz-option-$o'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              disabledForegroundColor: Washi.ink,
              backgroundColor: _picked == null
                  ? null
                  : _options[o] == answer
                      ? Washi.matcha.withValues(alpha: 0.18)
                      : _options[o] == _picked
                          ? Washi.shu.withValues(alpha: 0.12)
                          : null,
            ),
            onPressed: _picked != null
                ? null
                : () {
                    setState(() {
                      _picked = _options[o];
                      if (_options[o] == answer) _correct++;
                    });
                    if (!listening) _say(answer.reading);
                  },
            child: Text(listening ? _options[o].word : _options[o].meaning,
                style: const TextStyle(fontSize: 18)),
          ),
        ),
      if (_picked != null)
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: FilledButton(
              key: const ValueKey('story-quiz-next'),
              style: FilledButton.styleFrom(
                  backgroundColor: storyColor,
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              onPressed: () => setState(() {
                _quizIndex++;
                _nextOptions();
              }),
              child: Text(_quizIndex + 1 >= _quizOrder.length ? '결과 보기' : '다음')),
        ),
    ]);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Washi.paper,
        appBar: washiAppBar(
            title: '단어 공부', subtitle: widget.story.title),
        body: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          child: Column(children: [
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(
                    value: 0,
                    label: Text('카드'),
                    icon: Icon(Icons.style_rounded)),
                ButtonSegment(
                    value: 1,
                    label: Text('뜻 퀴즈'),
                    icon: Icon(Icons.translate)),
                ButtonSegment(
                    value: 2,
                    label: Text('듣기 퀴즈'),
                    icon: Icon(Icons.hearing)),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => _setMode(s.first),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: const TextStyle(color: Washi.shu)),
              ),
            const SizedBox(height: 14),
            Expanded(
                child: Center(child: _mode == 0 ? _cards() : _quiz())),
          ]),
        ),
      );
}
