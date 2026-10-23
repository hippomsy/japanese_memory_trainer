import 'package:kioku_japanese/widgets/chapter_art.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kioku_japanese/data/kanji_dictionary.dart';
import 'package:kioku_japanese/services/news_service.dart';
import 'package:kioku_japanese/services/tts_service.dart';
import 'package:kioku_japanese/services/jlpt_listening.dart';
import 'package:kioku_japanese/services/lesson_audio.dart';
import 'package:kioku_japanese/widgets/ruby_text.dart';
import 'package:kioku_japanese/widgets/study_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _jlptColor = Color(0xFFCF7A93); // N5 벚꽃색
const _numbers = ['①', '②', '③', '④'];

/// 2026-10-08 JLPT N5 청해 목록: 회차(第1回·第2回·模擬テスト1·2) × 문제 유형(問題1~4).
class JlptListeningHomePage extends StatefulWidget {
  const JlptListeningHomePage(
      {super.key, this.audioFactory, this.book, this.preferences});

  /// 테스트에서 오디오·데이터·저장소를 바꿔 끼울 수 있다.
  final LessonAudio Function()? audioFactory;
  final Future<JlptListeningBook>? book;
  final Future<SharedPreferences>? preferences;

  @override
  State<JlptListeningHomePage> createState() => _JlptListeningHomePageState();
}

class _JlptListeningHomePageState extends State<JlptListeningHomePage> {
  late final Future<(JlptListeningBook, JlptListeningProgress)> _data =
      () async {
    final book = await (widget.book ?? JlptListeningBook.load());
    final prefs = await (widget.preferences ?? SharedPreferences.getInstance());
    return (book, JlptListeningProgress(prefs));
  }();

  Future<void> _open(JlptListeningBook book, JlptListeningProgress progress,
      List<JlptQuestion> questions, String title,
      {int? start}) async {
    final first =
        start ?? questions.indexWhere((q) => progress.choice(q.id) == null);
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => JlptQuestionPage(
            book: book,
            progress: progress,
            questions: questions,
            title: title,
            initialIndex: first < 0 ? 0 : first,
            audioFactory: widget.audioFactory)));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Washi.paper,
        appBar: washiAppBar(
            title: 'JLPT N5 청해', subtitle: '원어민 음성 · 문제 풀이 · 채점 · 스크립트'),
        body: FutureBuilder<(JlptListeningBook, JlptListeningProgress)>(
          future: _data,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(child: Text('청해 문제를 불러오지 못했어요.'));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final (book, progress) = snapshot.data!;
            final all = book.questions;
            final solved = progress.solved(all), right = progress.right(all);
            final wrong = progress.wrong(all);
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
              children: [
                const SceneArt('cat_listen', height: 152),
                const SizedBox(height: 12),
                HeroBanner(
                  colors: const [Color(0xFF8E3B5B), Color(0xFFCF7A93)],
                  icon: Icons.headphones_rounded,
                  eyebrow: 'JLPT N5 · 聴解',
                  title: '듣고, 고르고,\n스크립트로 확인해요',
                  subtitle: '${book.tests.length}회분 ${all.length}문제 · '
                      '푼 문제 $solved개 · 맞힌 문제 $right개',
                  progress: all.isEmpty ? 0 : solved / all.length,
                  action: wrong.isEmpty
                      ? null
                      : FilledButton.tonalIcon(
                          key: const ValueKey('jlpt-retry-wrong'),
                          onPressed: () => _open(
                              book, progress, wrong, '틀린 문제 다시 풀기',
                              start: 0),
                          icon: const Icon(Icons.replay_rounded),
                          label: Text('틀린 문제 ${wrong.length}개 다시 풀기')),
                ),
                const SizedBox(height: 22),
                for (final test in book.tests) ...[
                  SectionTitle('${test.title} · ${test.korean}',
                      trailing:
                          '${progress.right(book.ofTest(test.id))}/${book.ofTest(test.id).length} 정답'),
                  const SizedBox(height: 10),
                  PaperCard(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(children: [
                      for (final m in book.mondai)
                        if (book.section(test.id, m.id).isNotEmpty)
                          _sectionTile(book, progress, test, m),
                    ]),
                  ),
                  const SizedBox(height: 22),
                ],
                const Text(
                    '※ 음성: 「JLPT 완전정복 한 권으로 N5」 MP3. 스크립트는 음성 인식 후 다듬은 것이라 드물게 다를 수 있어요.\n'
                    '※ 問題1·2의 그림 보기는 문제지 그림 대신 대화에 맞춰 새로 만든 그림문자 카드예요.',
                    style: TextStyle(
                        fontSize: 12, color: Washi.inkSoft, height: 1.6)),
              ],
            );
          },
        ),
      );

  Widget _sectionTile(JlptListeningBook book, JlptListeningProgress progress,
      JlptTest test, JlptMondai m) {
    final qs = book.section(test.id, m.id);
    final solved = progress.solved(qs), right = progress.right(qs);
    final done = solved == qs.length;
    return ListTile(
      key: ValueKey('jlpt-section-${test.id}-${m.id}'),
      onTap: () => _open(book, progress, qs, '${test.title} 問題${m.id}'),
      leading: HankoBadge(
          text: '${m.id}', color: _jlptColor, size: 40, filled: done),
      title: Text('問題${m.id}  ${m.japanese}',
          style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text('${m.korean} · ${qs.length}문제'
          '${solved > 0 ? ' · $solved문제 풂' : ''}'),
      trailing: solved == 0
          ? const Icon(Icons.chevron_right_rounded)
          : Text('$right/${qs.length}',
              style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: right == qs.length ? Washi.matcha : Washi.shu)),
    );
  }
}

/// 2026-10-08 한 구역(예: 第1回 問題1)의 문제를 한 장씩 넘기며 푼다.
class JlptQuestionPage extends StatefulWidget {
  const JlptQuestionPage({
    super.key,
    required this.book,
    required this.progress,
    required this.questions,
    required this.title,
    this.initialIndex = 0,
    this.audioFactory,
  });
  final JlptListeningBook book;
  final JlptListeningProgress progress;
  final List<JlptQuestion> questions;
  final String title;
  final int initialIndex;
  final LessonAudio Function()? audioFactory;

  @override
  State<JlptQuestionPage> createState() => _JlptQuestionPageState();
}

class _JlptQuestionPageState extends State<JlptQuestionPage> {
  late int _index =
      widget.initialIndex.clamp(0, widget.questions.length - 1).toInt();

  void _go(int delta) {
    final next = _index + delta;
    if (next < 0 || next >= widget.questions.length) return;
    setState(() => _index = next);
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.questions[_index];
    final total = widget.questions.length;
    final right = widget.progress.right(widget.questions);
    return Scaffold(
      backgroundColor: Washi.paper,
      appBar: washiAppBar(
          title: widget.title,
          subtitle: '${_index + 1} / $total문제 · 맞힌 문제 $right개'),
      body: JlptQuestionView(
          key: ValueKey('jlpt-q-${q.id}'),
          question: q,
          book: widget.book,
          progress: widget.progress,
          audioFactory: widget.audioFactory,
          onAnswered: () => setState(() {})),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
          child: Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                  key: const ValueKey('jlpt-prev'),
                  onPressed: _index > 0 ? () => _go(-1) : null,
                  icon: const Icon(Icons.chevron_left_rounded),
                  label: const Text('이전 문제')),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                  key: const ValueKey('jlpt-next'),
                  onPressed: _index < total - 1
                      ? () => _go(1)
                      : () => Navigator.of(context).maybePop(),
                  icon: Icon(_index < total - 1
                      ? Icons.chevron_right_rounded
                      : Icons.check_rounded),
                  label: Text(_index < total - 1 ? '다음 문제' : '마치기')),
            ),
          ]),
        ),
      ),
    );
  }
}

/// 2026-10-08 문제 한 개: 음성 듣기(반복·속도) → 보기 고르기 → 채점·해설 → 스크립트(문장별 다시 듣기).
class JlptQuestionView extends StatefulWidget {
  const JlptQuestionView({
    super.key,
    required this.question,
    required this.book,
    required this.progress,
    this.audioFactory,
    this.onAnswered,
  });
  final JlptQuestion question;
  final JlptListeningBook book;
  final JlptListeningProgress progress;
  final LessonAudio Function()? audioFactory;
  final VoidCallback? onAnswered;

  @override
  State<JlptQuestionView> createState() => _JlptQuestionViewState();
}

class _JlptQuestionViewState extends State<JlptQuestionView> {
  TtsService? _wordTts;

  Future<void> _showWord(NewsToken token, JlptLine line) async {
    final word = token.word ?? token.text;
    final kanji = word.runes
        .map(String.fromCharCode)
        .where(KanjiDictionary.isKanji)
        .toSet();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Washi.paper,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                    child: Text(word,
                        style: const TextStyle(
                            fontSize: 30, fontWeight: FontWeight.bold))),
                IconButton(
                    tooltip: '닫기',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close)),
              ]),
              Text('발음: ${token.reading}',
                  style: const TextStyle(fontSize: 20)),
              Text('뜻: ${token.meaning}', style: const TextStyle(fontSize: 22)),
              if (token.level != null) Text('JLPT N${token.level}'),
              TextButton.icon(
                  onPressed: () async {
                    await _full.pause();
                    await _clip.pause();
                    if (!mounted) return;
                    await (_wordTts ??= TtsService()).speakJapanese(
                        token.reading.isEmpty ? word : token.reading);
                  },
                  icon: const Icon(Icons.volume_up),
                  label: const Text('발음 듣기')),
              const Divider(),
              const Text('한자 뜻', style: TextStyle(fontWeight: FontWeight.bold)),
              if (kanji.isEmpty) const Text('한자가 없는 단어예요.'),
              for (final ch in kanji)
                Text(
                    '$ch · ${KanjiDictionary.instance.lookup(ch)?.hunEum ?? '한자 풀이가 아직 없어요.'}'),
              const Divider(),
              Text(line.japanese, style: const TextStyle(height: 1.6)),
              Text('해석: ${line.korean}', style: const TextStyle(height: 1.6)),
            ],
          ),
        ),
      ),
    );
    await _wordTts?.stop();
  }

  JlptQuestion get q => widget.question;
  LessonAudio _create() => (widget.audioFactory ?? JustLessonAudio.new)();
  late final LessonAudio _full = _create(); // 문제 전체 듣기
  late final LessonAudio _clip = _create(); // 문장·보기 구간 듣기
  final _subs = <StreamSubscription<Object?>>[];

  bool _ready = false, _playing = false, _loop = false;
  bool _showScript = false, _showKorean = true, _showRuby = true;
  double _speed = 1.0;
  Duration _position = Duration.zero, _duration = Duration.zero;
  String? _error, _clipId;
  bool _clipActive = false;
  int? _chosen;
  late final bool? _lastResult = widget.progress.correct(q.id);

  @override
  void initState() {
    super.initState();
    _duration = q.duration;
    _subs
      ..add(_full.playingStream.listen((v) {
        if (mounted) setState(() => _playing = v);
      }))
      ..add(_full.positionStream.listen((v) {
        if (mounted) setState(() => _position = v);
      }))
      ..add(_full.durationStream.listen((v) {
        if (mounted && v != null && v > Duration.zero) {
          setState(() => _duration = v);
        }
      }))
      ..add(_full.completedStream.listen((done) {
        if (done && !_loop) {
          _full.pause();
          _full.seek(Duration.zero);
        }
      }))
      ..add(_clip.playingStream.listen((v) {
        if (mounted) {
          setState(() {
            _clipActive = v;
            if (!v) _clipId = null;
          });
        }
      }))
      ..add(_clip.completedStream.listen((done) {
        if (done && !_loop) _clip.pause();
      }));
    _load();
  }

  Future<void> _load() async {
    try {
      await _full.load(q.audio);
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      if (mounted) setState(() => _error = '음성 파일을 불러오지 못했어요.');
    }
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _full.dispose();
    _clip.dispose();
    _wordTts?.stop();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (!_ready) return;
    if (_playing) {
      await _full.pause();
      return;
    }
    await _clip.pause();
    await _full.setSpeed(_speed);
    await _full.play();
  }

  Future<void> _restart() async {
    if (!_ready) return;
    await _clip.pause();
    await _full.seek(Duration.zero);
    await _full.setSpeed(_speed);
    await _full.play();
  }

  Future<void> _seekBy(int seconds) async {
    var target = _position + Duration(seconds: seconds);
    if (target < Duration.zero) target = Duration.zero;
    if (target > _duration) target = _duration;
    await _full.seek(target);
  }

  Future<void> _setSpeed(double v) async {
    setState(() => _speed = v);
    await _full.setSpeed(v);
    await _clip.setSpeed(v);
  }

  Future<void> _toggleLoop() async {
    setState(() => _loop = !_loop);
    await _full.setLoop(_loop);
    await _clip.setLoop(_loop);
  }

  /// 스크립트 한 줄·보기 하나를 원음으로 다시 듣는다(다시 누르면 멈춤).
  Future<void> _playSpan(String id, JlptSpan span) async {
    if (_clipId == id && _clipActive) {
      await _clip.pause();
      return;
    }
    await _full.pause();
    try {
      await _clip.setSpeed(_speed);
      await _clip.playClip(q.audio, span.start, span.end);
      if (mounted) setState(() => _clipId = id);
    } catch (_) {
      if (mounted) setState(() => _error = '음성을 재생하지 못했어요.');
    }
  }

  Future<void> _choose(int i) async {
    if (_chosen != null) return;
    setState(() => _chosen = i);
    await widget.progress.answer(q.id, i, i == q.answer);
    widget.onAnswered?.call();
  }

  void _retry() => setState(() => _chosen = null);

  int get _activeLine {
    if (!_playing) return -1;
    return q.lines.indexWhere((l) => l.span.contains(_position));
  }

  String _fmt(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final m = widget.book.mondaiOf(q.mondai);
    final t = widget.book.testOf(q.test);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        Row(children: [
          SpeakerChip(
              name: '${t.title} · 問題${m.id} ${m.japanese}', color: _jlptColor),
          const SizedBox(width: 8),
          Text('${q.number}番',
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const Spacer(),
          if (_lastResult != null && _chosen == null)
            Text(_lastResult == true ? '지난번 ⭕' : '지난번 ❌',
                style: const TextStyle(fontSize: 12, color: Washi.inkSoft)),
        ]),
        const SizedBox(height: 4),
        Text(m.guide,
            style: const TextStyle(fontSize: 12.5, color: Washi.inkSoft)),
        const SizedBox(height: 12),
        _player(),
        if (_error != null)
          Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!, style: const TextStyle(color: Washi.shu))),
        const SizedBox(height: 14),
        _questionCard(),
        const SizedBox(height: 14),
        if (q.optionsSpoken) _spokenOptions() else _pictureOptions(),
        if (_chosen != null) ...[
          const SizedBox(height: 14),
          _result(),
        ],
        const SizedBox(height: 14),
        OutlinedButton.icon(
          key: const ValueKey('jlpt-script-toggle'),
          onPressed: () => setState(() => _showScript = !_showScript),
          icon: Icon(_showScript
              ? Icons.visibility_off_rounded
              : Icons.description_rounded),
          label: Text(_showScript ? '스크립트 숨기기' : '스크립트 보기'),
          style:
              OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        ),
        if (_showScript) ...[
          const SizedBox(height: 12),
          _script(),
        ],
      ],
    );
  }

  Widget _player() {
    final max = _duration.inMilliseconds.toDouble();
    final value =
        _position.inMilliseconds.clamp(0, max <= 0 ? 0 : max).toDouble();
    return PaperCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      child: Column(children: [
        Row(children: [
          const Icon(Icons.headphones_rounded, color: _jlptColor),
          const SizedBox(width: 8),
          const Expanded(
              child: Text('문제 음성',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
          for (final s in const [0.75, 1.0])
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: ChoiceChip(
                  key: ValueKey('jlpt-speed-$s'),
                  label: Text(s == 1.0 ? '보통' : '천천히'),
                  visualDensity: VisualDensity.compact,
                  selected: _speed == s,
                  onSelected: (_) => _setSpeed(s)),
            ),
        ]),
        Slider(
            value: value,
            max: max <= 0 ? 1 : max,
            activeColor: _jlptColor,
            onChanged: max <= 0 || !_ready
                ? null
                : (v) => _full.seek(Duration(milliseconds: v.round()))),
        Row(children: [
          Text(_fmt(_position), style: const TextStyle(fontSize: 12)),
          const Spacer(),
          Text(_fmt(_duration), style: const TextStyle(fontSize: 12)),
        ]),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(
              tooltip: '처음부터',
              onPressed: _ready ? _restart : null,
              icon: const Icon(Icons.skip_previous_rounded)),
          IconButton(
              tooltip: '5초 뒤로',
              onPressed: _ready ? () => _seekBy(-5) : null,
              icon: const Icon(Icons.replay_5_rounded)),
          const SizedBox(width: 4),
          FilledButton.icon(
              key: const ValueKey('jlpt-play'),
              style: FilledButton.styleFrom(backgroundColor: _jlptColor),
              onPressed: _ready ? _togglePlay : null,
              icon: Icon(
                  _playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
              label: Text(_playing ? '일시정지' : '듣기')),
          const SizedBox(width: 4),
          IconButton(
              tooltip: '5초 앞으로',
              onPressed: _ready ? () => _seekBy(5) : null,
              icon: const Icon(Icons.forward_5_rounded)),
          IconButton(
              key: const ValueKey('jlpt-loop'),
              tooltip: '반복 듣기',
              isSelected: _loop,
              color: _loop ? _jlptColor : null,
              onPressed: _ready ? _toggleLoop : null,
              icon: const Icon(Icons.repeat_rounded),
              selectedIcon: const Icon(Icons.repeat_one_rounded)),
        ]),
        if (_loop)
          const Text('반복 듣기 켜짐 · 전체/문장 듣기가 계속 반복돼요',
              style: TextStyle(fontSize: 11.5, color: _jlptColor)),
      ]),
    );
  }

  Widget _questionCard() {
    final scene = q.scene;
    return PaperCard(
      color: const Color(0xFFFFF7F9),
      borderColor: _jlptColor.withValues(alpha: 0.25),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (scene != null) ...[
          Center(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Washi.line)),
              child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  if (q.mondai == 3)
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Text('➡🙋', style: TextStyle(fontSize: 30)),
                    ),
                  Flexible(
                    child: Text(scene.emoji,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 46)),
                  ),
                ]),
                const SizedBox(height: 8),
                Text(scene.japanese,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(scene.korean,
                    textAlign: TextAlign.center,
                    style:
                        const TextStyle(fontSize: 12.5, color: Washi.inkSoft)),
              ]),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (q.ask != null) ...[
          const Text('質問 · 질문',
              style: TextStyle(
                  fontSize: 12,
                  color: _jlptColor,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          RubyText(tokens: q.askTokens, fontSize: 20, showUnderline: false),
          const SizedBox(height: 4),
          Text(q.askKorean ?? '',
              style: const TextStyle(color: Washi.inkSoft, fontSize: 13)),
        ] else if (q.mondai == 3)
          const Text('➡(화살표) 사람은 뭐라고 말할까요? 음성으로 나오는 1~3 중에서 고르세요.',
              style: TextStyle(fontWeight: FontWeight.w700, height: 1.5))
        else
          const Row(children: [
            Text('💬', style: TextStyle(fontSize: 34)),
            SizedBox(width: 10),
            Expanded(
                child: Text('그림이 없는 문제예요. 상대의 말을 듣고 알맞은 대답을 1~3 중에서 고르세요.',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, height: 1.5))),
          ]),
      ]),
    );
  }

  Color? _optionColor(int i) {
    if (_chosen == null) return null;
    if (i == q.answer) return Washi.matcha;
    if (i == _chosen) return Washi.shu;
    return null;
  }

  /// 問題1·2: 그림(그림문자) 보기 카드 2×2.
  Widget _pictureOptions() => LayoutBuilder(builder: (context, c) {
        final width = (c.maxWidth - 10) / 2;
        return Wrap(spacing: 10, runSpacing: 10, children: [
          for (var i = 0; i < q.options.length; i++)
            SizedBox(
              width: width,
              child: _pictureCard(i),
            ),
        ]);
      });

  Widget _pictureCard(int i) {
    final o = q.options[i];
    final color = _optionColor(i);
    return PaperCard(
      key: ValueKey('jlpt-option-$i'),
      onTap: _chosen == null ? () => _choose(i) : null,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
      borderColor: color ?? Washi.line,
      color: color == null ? Washi.card : color.withValues(alpha: 0.08),
      child: Column(children: [
        Row(children: [
          Text(_numbers[i],
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: color ?? Washi.ink)),
          const Spacer(),
          if (color != null)
            Icon(i == q.answer ? Icons.circle_outlined : Icons.close_rounded,
                color: color, size: 22),
        ]),
        SizedBox(
          height: 58,
          child: FittedBox(
              child: Text(o.emoji ?? '', style: const TextStyle(fontSize: 44))),
        ),
        const SizedBox(height: 6),
        Text(o.japanese,
            textAlign: TextAlign.center,
            style:
                const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
        if (_chosen != null)
          Text(o.korean,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11.5, color: Washi.inkSoft)),
      ]),
    );
  }

  /// 問題3·4: 보기는 음성으로만 나오므로 번호만 보여 주고, 답한 뒤에 내용을 연다.
  Widget _spokenOptions() => Column(children: [
        for (var i = 0; i < q.options.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _spokenCard(i),
          ),
      ]);

  Widget _spokenCard(int i) {
    final o = q.options[i];
    final color = _optionColor(i);
    final span = o.span;
    final id = 'o$i';
    return PaperCard(
      key: ValueKey('jlpt-option-$i'),
      onTap: _chosen == null ? () => _choose(i) : null,
      padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
      borderColor: color ?? Washi.line,
      color: color == null ? Washi.card : color.withValues(alpha: 0.08),
      child: Row(children: [
        Text('${i + 1}',
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: color ?? _jlptColor)),
        const SizedBox(width: 14),
        Expanded(
          child: _chosen == null
              ? const Text('🔊 음성으로 듣고 고르기',
                  style: TextStyle(color: Washi.inkSoft))
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(o.japanese.replaceFirst(RegExp(r'^\d\.\s*'), ''),
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                  Text(o.korean,
                      style: const TextStyle(
                          fontSize: 12.5, color: Washi.inkSoft)),
                ]),
        ),
        if (color != null)
          Icon(i == q.answer ? Icons.circle_outlined : Icons.close_rounded,
              color: color),
        if (span != null)
          SpeakButton(
              key: ValueKey('jlpt-option-play-$i'),
              tooltip: '${i + 1}번 보기 다시 듣기',
              color: _jlptColor,
              speaking: _clipId == id && _clipActive,
              onPressed: () => _playSpan(id, span)),
      ]),
    );
  }

  Widget _result() {
    final ok = _chosen == q.answer;
    final color = ok ? Washi.matcha : Washi.shu;
    final answer = q.options[q.answer];
    return PaperCard(
      key: const ValueKey('jlpt-result'),
      borderColor: color.withValues(alpha: 0.5),
      color: color.withValues(alpha: 0.06),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(ok ? '⭕' : '❌', style: const TextStyle(fontSize: 26)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(ok ? '정답이에요!' : '아쉬워요. 정답은 ${_numbers[q.answer]} 번',
                style: TextStyle(
                    fontSize: 19, fontWeight: FontWeight.w900, color: color)),
          ),
          TextButton.icon(
              key: const ValueKey('jlpt-retry'),
              onPressed: _retry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('다시 풀기')),
        ]),
        const SizedBox(height: 6),
        Text(
            '정답: ${answer.emoji ?? ''} ${answer.japanese.replaceFirst(RegExp(r'^\d\.\s*'), '')} (${answer.korean})',
            style: const TextStyle(fontWeight: FontWeight.w700, height: 1.5)),
        const SizedBox(height: 8),
        Text(q.explanation, style: const TextStyle(height: 1.6)),
        if (q.note != null) ...[
          const SizedBox(height: 6),
          Text('※ ${q.note}',
              style: const TextStyle(fontSize: 12, color: Washi.inkSoft)),
        ],
      ]),
    );
  }

  Color _speakerColor(String sp) => switch (sp) {
        'ナ' => Washi.inkSoft,
        '男' => Washi.sora,
        '女' => Washi.sakura,
        _ => Washi.fuji,
      };

  String _speakerName(String sp) => switch (sp) {
        'ナ' => '안내',
        '男' => '男 남자',
        '女' => '女 여자',
        '先生' => '先生 선생님',
        '店の人' => '店の人 점원',
        'A' => '말하는 사람',
        _ => sp,
      };

  Widget _script() {
    final active = _activeLine;
    return PaperCard(
      key: const ValueKey('jlpt-script'),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.description_rounded, color: _jlptColor, size: 20),
          const SizedBox(width: 6),
          const Expanded(
              child: Text('スクリプト · 스크립트',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
          FilterChip(
              key: const ValueKey('jlpt-ruby'),
              label: const Text('후리가나'),
              visualDensity: VisualDensity.compact,
              selected: _showRuby,
              onSelected: (v) => setState(() => _showRuby = v)),
          const SizedBox(width: 6),
          FilterChip(
              key: const ValueKey('jlpt-korean'),
              label: const Text('해석'),
              visualDensity: VisualDensity.compact,
              selected: _showKorean,
              onSelected: (v) => setState(() => _showKorean = v)),
        ]),
        const Padding(
          padding: EdgeInsets.only(top: 2, bottom: 6),
          child: Text(
              '밑줄 단어를 누르면 발음·뜻·한자 뜻·문장 해석을 볼 수 있어요.\n문장의 🔊를 누르면 그 부분만 원음으로 다시 들려줘요.',
              style: TextStyle(fontSize: 12, color: Washi.inkSoft)),
        ),
        for (var i = 0; i < q.lines.length; i++) _scriptLine(i, i == active),
        if (q.optionsSpoken)
          for (var i = 0; i < q.options.length; i++) _scriptOption(i),
      ]),
    );
  }

  Widget _scriptLine(int i, bool active) {
    final l = q.lines[i];
    final id = 'l$i';
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
      decoration: BoxDecoration(
        color: active || (_clipId == id && _clipActive)
            ? _jlptColor.withValues(alpha: 0.10)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SpeakerChip(
                name: _speakerName(l.speaker), color: _speakerColor(l.speaker)),
            const SizedBox(height: 4),
            RubyText(
                tokens: l.tokens,
                fontSize: l.isNarration ? 16 : 18,
                showRuby: _showRuby,
                showUnderline: true,
                onWordTap: (token) => _showWord(token, l),
                color: l.isNarration ? Washi.inkSoft : Washi.ink),
            if (_showKorean)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(l.korean,
                    style: const TextStyle(
                        fontSize: 13, color: Washi.inkSoft, height: 1.45)),
              ),
          ]),
        ),
        SpeakButton(
            key: ValueKey('jlpt-line-$i'),
            tooltip: '이 문장 다시 듣기',
            color: _jlptColor,
            speaking: _clipId == id && _clipActive,
            onPressed: () => _playSpan(id, l.span)),
      ]),
    );
  }

  Widget _scriptOption(int i) {
    final o = q.options[i];
    final answered = _chosen != null;
    final isAnswer = answered && i == q.answer;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: isAnswer ? Washi.matcha.withValues(alpha: 0.08) : Washi.paper,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(o.japanese,
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            if (_showKorean)
              Text(o.korean,
                  style: const TextStyle(fontSize: 13, color: Washi.inkSoft)),
          ]),
        ),
        if (isAnswer)
          const Text('정답',
              style:
                  TextStyle(color: Washi.matcha, fontWeight: FontWeight.w900)),
      ]),
    );
  }
}
