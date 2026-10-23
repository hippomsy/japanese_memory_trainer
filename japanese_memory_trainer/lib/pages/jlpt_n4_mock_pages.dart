import 'package:kioku_japanese/widgets/chapter_art.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kioku_japanese/data/kanji_dictionary.dart';
import 'package:kioku_japanese/services/jlpt_n4_mock.dart';
import 'package:kioku_japanese/services/news_service.dart';
import 'package:kioku_japanese/services/tts_service.dart';
import 'package:kioku_japanese/widgets/ruby_text.dart';
import 'package:kioku_japanese/widgets/study_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _mockColor = Color(0xFF6B5BAF); // N4 모의고사 보라
const _numbers = ['①', '②', '③', '④'];

/// 2026-10-10 JLPT N4 모의고사 목록: 회차 × (문자·어휘 / 문법·독해).
class JlptN4MockHomePage extends StatefulWidget {
  const JlptN4MockHomePage({super.key, this.mock, this.preferences});

  /// 테스트에서 데이터·저장소를 바꿔 끼울 수 있다.
  final Future<JlptN4Mock>? mock;
  final Future<SharedPreferences>? preferences;

  @override
  State<JlptN4MockHomePage> createState() => _JlptN4MockHomePageState();
}

class _JlptN4MockHomePageState extends State<JlptN4MockHomePage> {
  late final Future<(JlptN4Mock, JlptN4MockProgress)> _data = () async {
    final mock = await (widget.mock ?? JlptN4Mock.load());
    final prefs = await (widget.preferences ?? SharedPreferences.getInstance());
    return (mock, JlptN4MockProgress(prefs));
  }();

  Future<void> _open(Widget page) async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => page));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Washi.paper,
        appBar: washiAppBar(
            title: 'JLPT N4 모의고사', subtitle: '언어지식(문자·어휘·문법) · 독해 · 2회분'),
        body: FutureBuilder<(JlptN4Mock, JlptN4MockProgress)>(
          future: _data,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(child: Text('모의고사를 불러오지 못했어요.'));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final (mock, progress) = snapshot.data!;
            var total = 0, done = 0;
            for (final s in mock.sets) {
              for (final sec in s.sections) {
                total++;
                if (progress.best(JlptN4MockProgress.sectionKey(s, sec)) !=
                    null) {
                  done++;
                }
              }
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
              children: [
                const SceneArt('school', height: 150),
                const SizedBox(height: 12),
                HeroBanner(
                  colors: const [Color(0xFF3F3474), _mockColor],
                  icon: Icons.assignment_rounded,
                  eyebrow: 'JLPT N4 · 模擬試験',
                  title: '5문제씩 연습하고\n실전처럼 풀어 봐요',
                  subtitle: '${mock.sets.length}회분 · 섹션 $total개 중 $done개 응시',
                  progress: total == 0 ? 0 : done / total,
                ),
                const SizedBox(height: 22),
                for (final set in mock.sets) ...[
                  SectionTitle('${set.title} · ${set.korean}'),
                  const SizedBox(height: 10),
                  PaperCard(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(children: [
                      for (final sec in set.sections) ...[
                        _sectionTile(set, sec, progress),
                        _practiceRow(set, sec, progress),
                      ],
                    ]),
                  ),
                  const SizedBox(height: 22),
                ],
                const Text(
                    '※ 먼저 「연습」(5문제씩, 고르면 바로 정답·해석·해설)으로 익힌 뒤 「실전」으로 시간을 재고 풀어 보세요.\n'
                    '※ 실제 JLPT N4 출제 형식(문제 유형·문항 수·시간)에 맞춰 새로 만든 문제예요.\n'
                    '※ 실제 시험은 척도 점수(언어지식·독해 0~120점, 기준점 38점)로 계산하므로, 여기 정답 수는 실력 확인용 참고 점수예요.',
                    style: TextStyle(
                        fontSize: 12, color: Washi.inkSoft, height: 1.6)),
              ],
            );
          },
        ),
      );

  Widget _sectionTile(
      MockSet set, MockSection sec, JlptN4MockProgress progress) {
    final k = JlptN4MockProgress.sectionKey(set, sec);
    final n = sec.questions.length;
    final best = progress.best(k);
    final draft = !progress.graded(k) && progress.answers(k).isNotEmpty;
    return ListTile(
      key: ValueKey('mock-set-${set.no}-${sec.id}'),
      onTap: () =>
          _open(MockExamPage(set: set, section: sec, progress: progress)),
      leading: HankoBadge(
          text: sec.id == 'vocab' ? '語' : '文',
          color: _mockColor,
          size: 40,
          filled: best != null),
      title: Text(sec.title,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
      subtitle: Text('실전 · ${sec.korean} · $n문제 · ${sec.minutes}분'
          '${draft ? ' · 푸는 중' : ''}'),
      trailing: best == null
          ? const Icon(Icons.chevron_right_rounded)
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                  Text('$best/$n',
                      style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: best * 10 >= n * 6
                              ? Washi.matcha
                              : Washi.shu)),
                  const Text('최고',
                      style: TextStyle(fontSize: 11, color: Washi.inkSoft)),
                ]),
    );
  }

  /// 5문제 연습 묶음 버튼(연습1~6). 푼 묶음은 최고 정답 수를 보여 준다.
  Widget _practiceRow(
      MockSet set, MockSection sec, JlptN4MockProgress progress) {
    final k = JlptN4MockProgress.sectionKey(set, sec);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 6),
          child: Text('✏️ 5문제 연습 · 고르면 바로 정답·해석',
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: _mockColor)),
        ),
        Wrap(spacing: 6, runSpacing: 6, children: [
        for (var i = 0; i < sec.practiceCount; i++)
          Builder(builder: (context) {
            final best = progress.practiceBest(k, i);
            final size = sec.practice(i).length;
            return ActionChip(
              key: ValueKey('mock-practice-${set.no}-${sec.id}-$i'),
              avatar: Icon(
                  best == null
                      ? Icons.edit_note_rounded
                      : Icons.check_circle_rounded,
                  size: 18,
                  color: best == null
                      ? _mockColor
                      : (best == size ? Washi.matcha : Washi.yamabuki)),
              label: Text(
                  '연습${i + 1}${best == null ? '' : ' $best/$size'}',
                  style: const TextStyle(fontSize: 12.5)),
              onPressed: () => _open(MockPracticePage(
                  set: set, section: sec, index: i, progress: progress)),
            );
          }),
      ]),
      ]),
    );
  }
}

/// 2026-10-10 모의고사 한 섹션: 모든 문제를 問題별로 보여 주고, 시간을 재고, 한 번에 채점한다.
class MockExamPage extends StatefulWidget {
  const MockExamPage(
      {super.key,
      required this.set,
      required this.section,
      required this.progress});
  final MockSet set;
  final MockSection section;
  final JlptN4MockProgress progress;

  @override
  State<MockExamPage> createState() => _MockExamPageState();
}

class _MockExamPageState extends State<MockExamPage> {
  late final String _key =
      JlptN4MockProgress.sectionKey(widget.set, widget.section);
  late final Map<int, int> _answers = widget.progress.answers(_key);
  late bool _graded = widget.progress.graded(_key);
  late int _elapsed = widget.progress.elapsed(_key);
  bool _onlyWrong = false, _showKorean = false;
  Timer? _timer;
  final _scroll = ScrollController();

  int get _total => widget.section.questions.length;
  int get _right => widget.section.questions
      .where((q) => _answers[q.no] == q.answer)
      .length;

  @override
  void initState() {
    super.initState();
    if (!_graded) _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsed++);
      if (_elapsed % 15 == 0) {
        widget.progress.saveDraft(_key, _answers, _elapsed);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (!_graded) widget.progress.saveDraft(_key, _answers, _elapsed);
    _scroll.dispose();
    super.dispose();
  }

  void _choose(MockQuestion q, int i) {
    if (_graded) return;
    setState(() => _answers[q.no] = i);
    widget.progress.saveDraft(_key, _answers, _elapsed);
  }

  Future<void> _submit() async {
    final left = _total - _answers.length;
    if (left > 0) {
      final ok = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
                title: const Text('채점할까요?'),
                content: Text('아직 고르지 않은 문제가 $left개 있어요. 고르지 않은 문제는 틀린 것으로 채점돼요.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('계속 풀기')),
                  FilledButton(
                      key: const ValueKey('mock-submit-confirm'),
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('채점하기')),
                ],
              ));
      if (ok != true) return;
    }
    _timer?.cancel();
    await widget.progress
        .submit(_key, widget.section, Map.of(_answers), _elapsed);
    if (!mounted) return;
    setState(() => _graded = true);
    if (_scroll.hasClients) {
      _scroll.animateTo(0,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  Future<void> _restart() async {
    await widget.progress.restart(_key);
    setState(() {
      _answers.clear();
      _graded = false;
      _onlyWrong = false;
      _elapsed = 0;
    });
    _startTimer();
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  String _clock(int sec) {
    final s = sec.abs();
    return '${sec < 0 ? '+' : ''}${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final limit = widget.section.minutes * 60;
    final remain = limit - _elapsed;
    return Scaffold(
      backgroundColor: Washi.paper,
      appBar: washiAppBar(
        title: '${widget.set.no}회 ${widget.section.korean}',
        subtitle: '${widget.section.minutes}분 · $_total문제',
        actions: [
          IconButton(
              tooltip: '한국어 지시문',
              onPressed: () => setState(() => _showKorean = !_showKorean),
              icon: Icon(Icons.translate_rounded,
                  color: _showKorean ? _mockColor : Washi.inkSoft)),
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Center(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.timer_outlined,
                    size: 18,
                    color: remain < 0 ? Washi.shu : Washi.inkSoft),
                const SizedBox(width: 3),
                Text(
                    _graded ? _clock(_elapsed) : _clock(remain),
                    key: const ValueKey('mock-timer'),
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: remain < 0 && !_graded
                            ? Washi.shu
                            : Washi.ink)),
              ]),
            ),
          ),
        ],
      ),
      body: ListView(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          ChapterArt('mock', widget.set.no, height: 145),
          const SizedBox(height: 10),
          if (_graded) _resultCard() else _guideCard(limit),
          const SizedBox(height: 14),
          for (final m in widget.section.mondai) ..._mondai(m),
        ],
      ),
      bottomNavigationBar: _bottomBar(),
    );
  }

  Widget _guideCard(int limit) => PaperCard(
        padding: const EdgeInsets.all(14),
        child: Column(children: [
          Row(children: [
            const IconBadge(icon: Icons.edit_note_rounded, color: _mockColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                  '제한 시간 ${widget.section.minutes}분 · $_total문제. 보기를 누르면 답이 저장돼요. '
                  '중간에 나가도 이어서 풀 수 있고, 다 풀면 아래 「채점하기」를 눌러요.',
                  style: const TextStyle(fontSize: 13, height: 1.5)),
            ),
          ]),
          const SizedBox(height: 10),
          _practiceButton(),
        ]),
      );

  /// 2026-10-10 실전 화면에서 바로 5문제 연습으로 가는 버튼.
  Widget _practiceButton() => SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
            key: const ValueKey('mock-to-practice'),
            style: OutlinedButton.styleFrom(
                foregroundColor: _mockColor,
                side: const BorderSide(color: _mockColor)),
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                    builder: (_) => MockPracticePage(
                        set: widget.set,
                        section: widget.section,
                        index: 0,
                        progress: widget.progress))),
            icon: const Icon(Icons.school_rounded),
            label: const Text('5문제씩 연습하기 (정답·해석 바로 보기)')),
      );

  Widget _resultCard() {
    final right = _right;
    final pct = _total == 0 ? 0 : (right * 100 / _total).round();
    final best = widget.progress.best(_key);
    return PaperCard(
      key: const ValueKey('mock-score'),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          ProgressRing(
            ratio: _total == 0 ? 0 : right / _total,
            color: pct >= 60 ? Washi.matcha : Washi.shu,
            size: 72,
            child: Text('$pct%',
                style: const TextStyle(
                    fontWeight: FontWeight.w900, fontSize: 16)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$right / $_total 정답',
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 22)),
              const SizedBox(height: 2),
              Text(
                  '걸린 시간 ${_clock(_elapsed)} / ${widget.section.minutes}분'
                  '${best != null ? ' · 최고 $best' : ''}',
                  style: const TextStyle(color: Washi.inkSoft, fontSize: 13)),
              const SizedBox(height: 2),
              Text(pct >= 60 ? '합격권이에요! 틀린 문제 해설을 확인해 보세요.' : '60%가 목표예요. 해설을 보고 다시 도전해요.',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: pct >= 60 ? Washi.matcha : Washi.shu)),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        for (final m in widget.section.mondai)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              SizedBox(
                  width: 58,
                  child: Text('問題${m.no}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 13))),
              Expanded(
                child: SlimProgress(
                    ratio: m.questions.isEmpty
                        ? 0
                        : _rightOf(m) / m.questions.length,
                    color: _mockColor),
              ),
              const SizedBox(width: 10),
              Text('${_rightOf(m)}/${m.questions.length}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 13)),
            ]),
          ),
        const SizedBox(height: 8),
        FilterChip(
          key: const ValueKey('mock-only-wrong'),
          label: Text('틀린 문제만 보기 (${_total - right})'),
          selected: _onlyWrong,
          onSelected: (v) => setState(() => _onlyWrong = v),
        ),
        const SizedBox(height: 8),
        _practiceButton(),
      ]),
    );
  }

  int _rightOf(MockMondai m) =>
      m.questions.where((q) => _answers[q.no] == q.answer).length;

  bool _visible(MockQuestion q) =>
      !(_graded && _onlyWrong && _answers[q.no] == q.answer);

  List<Widget> _mondai(MockMondai m) => mockMondaiWidgets(
        m,
        m.questions.where(_visible).toList(),
        showKorean: _showKorean,
        helps: _graded,
        card: (q) => MockQuestionCard(
          key: ValueKey('mock-card-${q.no}'),
          question: q,
          chosen: _answers[q.no],
          revealed: _graded,
          onChoose: _graded ? null : (i) => _choose(q, i),
        ),
      );

  Widget _bottomBar() => SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: const BoxDecoration(
              color: Washi.card,
              border: Border(top: BorderSide(color: Washi.line))),
          child: Row(children: [
            Expanded(
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        _graded
                            ? '$_right / $_total 정답'
                            : '${_answers.length} / $_total 문제 선택',
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 5),
                    SlimProgress(
                        ratio: _total == 0
                            ? 0
                            : (_graded ? _right : _answers.length) / _total,
                        color: _graded ? Washi.matcha : _mockColor),
                  ]),
            ),
            const SizedBox(width: 14),
            _graded
                ? FilledButton.tonalIcon(
                    key: const ValueKey('mock-retry'),
                    onPressed: _restart,
                    icon: const Icon(Icons.replay_rounded),
                    label: const Text('다시 풀기'))
                : FilledButton.icon(
                    key: const ValueKey('mock-submit'),
                    style:
                        FilledButton.styleFrom(backgroundColor: _mockColor),
                    onPressed: _submit,
                    icon: const Icon(Icons.fact_check_rounded),
                    label: const Text('채점하기')),
          ]),
        ),
      );
}

/// 2026-10-10 問題 머리글 + (지문) + 문제 카드들. 실전·연습 화면이 함께 쓴다.
List<Widget> mockMondaiWidgets(MockMondai m, List<MockQuestion> shown,
    {required bool showKorean,
    required bool helps,
    required Widget Function(MockQuestion) card}) {
  if (shown.isEmpty) return const [];
  final widgets = <Widget>[
    Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
              color: Washi.ink, borderRadius: BorderRadius.circular(6)),
          child: Text('問題${m.no}',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 13)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(m.japanese,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700, height: 1.5)),
            if (showKorean)
              Text(m.korean,
                  style: const TextStyle(
                      fontSize: 12.5, color: Washi.inkSoft, height: 1.4)),
          ]),
        ),
      ]),
    ),
  ];
  int? lastPassage;
  for (final q in shown) {
    if (q.passage != null && q.passage != lastPassage) {
      widgets.add(MockPassageCard(
          key: ValueKey('mock-passage-${m.no}-${q.passage}'),
          passage: m.passages[q.passage!],
          helps: helps));
      widgets.add(const SizedBox(height: 10));
    }
    lastPassage = q.passage;
    widgets.add(card(q));
    widgets.add(const SizedBox(height: 10));
  }
  widgets.add(const SizedBox(height: 14));
  return widgets;
}

TtsService? _wordTts;

/// 2026-10-10 단어를 누르면 읽기·뜻·한자 훈음·발음을 보여 준다.
Future<void> showMockWordSheet(BuildContext context, NewsToken token) {
  final word = token.word ?? token.text;
  final kanji = word.runes
      .map(String.fromCharCode)
      .where(KanjiDictionary.isKanji)
      .toSet();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Washi.paper,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
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
                  tooltip: '발음 듣기',
                  onPressed: () => (_wordTts ??= TtsService()).speakJapanese(
                      token.reading.isEmpty ? word : token.reading),
                  icon: const Icon(Icons.volume_up_rounded,
                      color: _mockColor)),
              IconButton(
                  tooltip: '닫기',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close)),
            ]),
            if (token.reading.isNotEmpty)
              Text('읽기: ${token.reading}',
                  style: const TextStyle(fontSize: 18)),
            Text(
                token.meaning.isEmpty
                    ? '단어장에 없는 말이에요. 문장 해석을 참고하세요.'
                    : '뜻: ${token.meaning}',
                style: TextStyle(
                    fontSize: token.meaning.isEmpty ? 15 : 21,
                    color: token.meaning.isEmpty ? Washi.inkSoft : Washi.ink)),
            if (token.level != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('JLPT N${token.level}',
                    style: const TextStyle(
                        color: Washi.inkSoft, fontWeight: FontWeight.w700)),
              ),
            if (kanji.isNotEmpty) ...[
              const Divider(height: 24),
              const Text('한자 풀이',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              for (final ch in kanji)
                Text(
                    '$ch · ${KanjiDictionary.instance.lookup(ch)?.hunEum ?? '한자 풀이가 아직 없어요.'}',
                    style: const TextStyle(fontSize: 16, height: 1.6)),
            ],
          ],
        ),
      ),
    ),
  );
}

/// 2026-10-10 지문 카드. helps 가 켜지면(연습·채점 후) 후리가나·해석 버튼과 단어 뜻 보기가 생긴다.
class MockPassageCard extends StatefulWidget {
  const MockPassageCard(
      {super.key, required this.passage, required this.helps});
  final MockPassage passage;
  final bool helps;

  @override
  State<MockPassageCard> createState() => _MockPassageCardState();
}

class _MockPassageCardState extends State<MockPassageCard> {
  bool _ruby = false, _korean = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.passage;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD9CFBC)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (widget.helps)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Wrap(spacing: 6, children: [
              FilterChip(
                  key: const ValueKey('mock-passage-ruby'),
                  label: const Text('후리가나'),
                  selected: _ruby,
                  onSelected: (v) => setState(() => _ruby = v)),
              FilterChip(
                  key: const ValueKey('mock-passage-ko'),
                  label: const Text('지문 해석'),
                  selected: _korean,
                  onSelected: (v) => setState(() => _korean = v)),
            ]),
          ),
        for (final b in p.blocks)
          if (b.rows != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Table(
                  defaultColumnWidth: const IntrinsicColumnWidth(),
                  border: TableBorder.all(color: const Color(0xFFBFB39C)),
                  children: [
                    for (var r = 0; r < b.rows!.length; r++)
                      TableRow(
                        decoration: r == 0
                            ? const BoxDecoration(color: Color(0xFFF1EADB))
                            : null,
                        children: [
                          for (final c in b.rows![r])
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 6),
                              child: Text(c,
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: r == 0
                                          ? FontWeight.w800
                                          : FontWeight.w500)),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            )
          else if (widget.helps && b.tokens.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: RubyText(
                  tokens: b.tokens,
                  fontSize: 15,
                  showRuby: _ruby,
                  showUnderline: false,
                  onWordTap: (t) => showMockWordSheet(context, t)),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(b.text!,
                  style: const TextStyle(fontSize: 15, height: 1.75)),
            ),
        if (widget.helps && _korean)
          Container(
            key: const ValueKey('mock-passage-korean'),
            width: double.infinity,
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: _mockColor.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(10)),
            child: Text(p.korean.join('\n'),
                style: const TextStyle(fontSize: 13.5, height: 1.6)),
          ),
      ]),
    );
  }
}

/// 2026-10-10 문제 한 개 카드. revealed 이면 ○/×, 보기마다 뜻(후리가나), 정답 문장 해석, 해설을 보여 준다.
class MockQuestionCard extends StatelessWidget {
  const MockQuestionCard(
      {super.key,
      required this.question,
      required this.chosen,
      required this.revealed,
      this.onChoose,
      this.onReveal});
  final MockQuestion question;
  final int? chosen;
  final bool revealed;
  final void Function(int)? onChoose;

  /// 연습 모드: 고르지 않고 정답·해석만 보기.
  final VoidCallback? onReveal;

  @override
  Widget build(BuildContext context) {
    final q = question;
    final right = chosen == q.answer;
    return PaperCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      borderColor: !revealed
          ? Washi.line
          : (right ? Washi.matcha : Washi.shu).withValues(alpha: 0.5),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 30,
            height: 26,
            alignment: Alignment.center,
            margin: const EdgeInsets.only(right: 8, top: 1),
            decoration: BoxDecoration(
              border: Border.all(color: Washi.ink, width: 1.3),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text('${q.no}',
                style: const TextStyle(
                    fontWeight: FontWeight.w900, fontSize: 13)),
          ),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                for (final p in stemParts(q.stem))
                  TextSpan(
                      text: p.text,
                      style: p.underline
                          ? const TextStyle(
                              decoration: TextDecoration.underline,
                              decorationThickness: 2,
                              fontWeight: FontWeight.w800)
                          : null),
              ]),
              style: const TextStyle(fontSize: 16, height: 1.6),
            ),
          ),
          if (revealed)
            Icon(
                chosen == null
                    ? Icons.visibility_rounded
                    : (right ? Icons.circle_outlined : Icons.close_rounded),
                color: chosen == null
                    ? Washi.inkSoft
                    : (right ? Washi.matcha : Washi.shu),
                size: 26),
        ]),
        const SizedBox(height: 8),
        for (var i = 0; i < q.options.length; i++) _option(context, i),
        if (!revealed && onReveal != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
                key: ValueKey('mock-reveal-${q.no}'),
                onPressed: onReveal,
                icon: const Icon(Icons.lightbulb_outline_rounded, size: 18),
                label: const Text('정답·해석 보기')),
          ),
        if (revealed) ...[
          const SizedBox(height: 8),
          _answerPanel(context),
        ],
      ]),
    );
  }

  Widget _answerPanel(BuildContext context) {
    final q = question;
    final isQuestion = q.answerSentence == q.stem;
    return Container(
      key: ValueKey('mock-answer-${q.no}'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: _mockColor.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('정답 ${_numbers[q.answer]}  ${q.options[q.answer]}',
            style: const TextStyle(
                fontWeight: FontWeight.w900, color: Washi.matcha)),
        if (q.answerTokens.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(isQuestion ? '질문 해석' : '문장 해석 (정답을 넣은 문장)',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Washi.inkSoft)),
          const SizedBox(height: 2),
          RubyText(
              tokens: q.answerTokens,
              fontSize: 17,
              onWordTap: (t) => showMockWordSheet(context, t)),
        ],
        if (q.korean.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(q.korean,
                style: const TextStyle(fontSize: 14, height: 1.5)),
          ),
        const SizedBox(height: 8),
        Text('해설  ${q.explanation}',
            style: const TextStyle(fontSize: 13, height: 1.55)),
        const SizedBox(height: 4),
        const Text('밑줄 단어를 누르면 뜻·한자·발음을 볼 수 있어요.',
            style: TextStyle(fontSize: 11, color: Washi.inkSoft)),
      ]),
    );
  }

  Widget _option(BuildContext context, int i) {
    final q = question;
    final picked = chosen == i;
    Color border = Washi.line, fill = Washi.card;
    if (revealed && i == q.answer) {
      border = Washi.matcha;
      fill = Washi.matcha.withValues(alpha: 0.10);
    } else if (revealed && picked) {
      border = Washi.shu;
      fill = Washi.shu.withValues(alpha: 0.08);
    } else if (picked) {
      border = _mockColor;
      fill = _mockColor.withValues(alpha: 0.10);
    }
    final ko = i < q.optionKorean.length ? q.optionKorean[i] : '';
    final tokens = i < q.optionTokens.length ? q.optionTokens[i] : const <NewsToken>[];
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Material(
        color: fill,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          key: ValueKey('mock-q${q.no}-opt$i'),
          borderRadius: BorderRadius.circular(10),
          onTap: revealed || onChoose == null ? null : () => onChoose!(i),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: border, width: picked ? 1.8 : 1.2)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_numbers[i],
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: picked ? _mockColor : Washi.inkSoft)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (revealed && tokens.isNotEmpty)
                        RubyText(
                            tokens: tokens,
                            fontSize: 15,
                            showUnderline: false,
                            onWordTap: (t) => showMockWordSheet(context, t))
                      else
                        Text(q.options[i],
                            style: const TextStyle(fontSize: 15, height: 1.45)),
                      if (revealed && ko.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(ko,
                              style: TextStyle(
                                  fontSize: 12.5,
                                  height: 1.4,
                                  color: i == q.answer
                                      ? Washi.matcha
                                      : Washi.inkSoft)),
                        ),
                    ]),
              ),
              if (revealed && i == q.answer)
                const Icon(Icons.check_rounded,
                    color: Washi.matcha, size: 20),
            ]),
          ),
        ),
      ),
    );
  }
}

/// 2026-10-10 5문제 연습: 실전과 같은 문제 형식, 고르면 바로 정답·해석·해설을 보여 준다.
class MockPracticePage extends StatefulWidget {
  const MockPracticePage(
      {super.key,
      required this.set,
      required this.section,
      required this.index,
      required this.progress});
  final MockSet set;
  final MockSection section;
  final int index;
  final JlptN4MockProgress progress;

  @override
  State<MockPracticePage> createState() => _MockPracticePageState();
}

class _MockPracticePageState extends State<MockPracticePage> {
  final Map<int, int> _answers = {};
  final Set<int> _revealed = {};
  bool _showKorean = true;
  late final List<MockQuestion> _qs =
      widget.section.practice(widget.index);
  late final String _key =
      JlptN4MockProgress.sectionKey(widget.set, widget.section);

  int get _right => _qs.where((q) => _answers[q.no] == q.answer).length;
  bool get _done => _qs.every((q) => _revealed.contains(q.no));

  void _after() {
    if (_done) {
      widget.progress.savePractice(_key, widget.index, _right);
    }
  }

  void _choose(MockQuestion q, int i) {
    if (_revealed.contains(q.no)) return;
    setState(() {
      _answers[q.no] = i;
      _revealed.add(q.no);
    });
    _after();
  }

  void _reveal(MockQuestion q) {
    setState(() => _revealed.add(q.no));
    _after();
  }

  void _go(Widget page) => Navigator.of(context)
      .pushReplacement(MaterialPageRoute<void>(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final sec = widget.section;
    final last = widget.index + 1 >= sec.practiceCount;
    return Scaffold(
      backgroundColor: Washi.paper,
      appBar: washiAppBar(
        title: '${widget.set.no}회 ${sec.korean} 연습${widget.index + 1}',
        subtitle:
            '${_qs.first.no}~${_qs.last.no}번 · ${widget.index + 1}/${sec.practiceCount}묶음',
        actions: [
          IconButton(
              tooltip: '한국어 지시문',
              onPressed: () => setState(() => _showKorean = !_showKorean),
              icon: Icon(Icons.translate_rounded,
                  color: _showKorean ? _mockColor : Washi.inkSoft)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          const PaperCard(
            padding: EdgeInsets.all(14),
            child: Row(children: [
              IconBadge(icon: Icons.school_rounded, color: _mockColor),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                    '실전과 같은 형식의 5문제예요. 보기를 고르면 바로 채점되고, 정답 문장의 후리가나·해석·보기 뜻·해설이 나와요. '
                    '모르면 「정답·해석 보기」를 누르고, 단어를 누르면 뜻을 볼 수 있어요.',
                    style: TextStyle(fontSize: 13, height: 1.5)),
              ),
            ]),
          ),
          const SizedBox(height: 14),
          for (final m in sec.mondai)
            ...mockMondaiWidgets(
              m,
              m.questions.where(_qs.contains).toList(),
              showKorean: _showKorean,
              helps: true,
              card: (q) => MockQuestionCard(
                key: ValueKey('mock-card-${q.no}'),
                question: q,
                chosen: _answers[q.no],
                revealed: _revealed.contains(q.no),
                onChoose: (i) => _choose(q, i),
                onReveal: () => _reveal(q),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: const BoxDecoration(
              color: Washi.card,
              border: Border(top: BorderSide(color: Washi.line))),
          child: Row(children: [
            Expanded(
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        _done
                            ? '$_right / ${_qs.length} 정답'
                            : '${_revealed.length} / ${_qs.length} 확인 · 맞힘 $_right',
                        key: const ValueKey('mock-practice-status'),
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 5),
                    SlimProgress(
                        ratio: _revealed.length / _qs.length,
                        color: _mockColor),
                  ]),
            ),
            const SizedBox(width: 10),
            IconButton(
                key: const ValueKey('mock-practice-again'),
                tooltip: '이 5문제 다시',
                onPressed: () => setState(() {
                      _answers.clear();
                      _revealed.clear();
                    }),
                icon: const Icon(Icons.replay_rounded)),
            last
                ? FilledButton.icon(
                    key: const ValueKey('mock-practice-exam'),
                    style:
                        FilledButton.styleFrom(backgroundColor: _mockColor),
                    onPressed: () => _go(MockExamPage(
                        set: widget.set,
                        section: sec,
                        progress: widget.progress)),
                    icon: const Icon(Icons.assignment_rounded),
                    label: const Text('실전 보기'))
                : FilledButton.icon(
                    key: const ValueKey('mock-practice-next'),
                    style:
                        FilledButton.styleFrom(backgroundColor: _mockColor),
                    onPressed: () => _go(MockPracticePage(
                        set: widget.set,
                        section: sec,
                        index: widget.index + 1,
                        progress: widget.progress)),
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: const Text('다음 5문제')),
          ]),
        ),
      ),
    );
  }
}
