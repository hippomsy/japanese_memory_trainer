import 'package:kioku_japanese/widgets/chapter_art.dart';
import 'package:flutter/material.dart';
import 'package:kioku_japanese/services/grammar_course.dart';
import 'package:kioku_japanese/widgets/study_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef GrammarSpeak = Future<void> Function(String text);

const _gMain = Color(0xFF3D5A98); // 남색(문법)
const _gDeep = Color(0xFF233A6E);
const _gSoft = Color(0xFFE6ECF8);

/// 2026-10-07 일본어 고급 문법 강의 목록.
class GrammarListPage extends StatefulWidget {
  const GrammarListPage(
      {super.key,
      required this.speakJapanese,
      this.stop,
      this.lessons,
      this.preferences});
  final GrammarSpeak speakJapanese;
  final Future<void> Function()? stop;
  final Future<List<GrammarLesson>>? lessons;
  final Future<SharedPreferences>? preferences;

  @override
  State<GrammarListPage> createState() => _GrammarListPageState();
}

class _GrammarListPageState extends State<GrammarListPage> {
  late final Future<(List<GrammarLesson>, GrammarProgress)> _data = () async {
    final lessons = await (widget.lessons ?? GrammarLesson.load());
    final prefs = await (widget.preferences ?? SharedPreferences.getInstance());
    return (lessons, GrammarProgress(prefs));
  }();

  Future<void> _open(GrammarLesson lesson, GrammarProgress progress) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => GrammarLessonPage(
            lesson: lesson,
            progress: progress,
            speakJapanese: widget.speakJapanese,
            stop: widget.stop)));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: washiAppBar(title: '일본어 고급 문법', subtitle: '표현 · 활용 · 예문 · 퀴즈'),
        body: FutureBuilder<(List<GrammarLesson>, GrammarProgress)>(
          future: _data,
          builder: (context, snap) {
            if (snap.hasError) {
              return const Center(child: Text('문법 자료를 불러오지 못했어요.'));
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final (lessons, progress) = snap.data!;
            final done = progress.done;
            final count = lessons.where((l) => done.contains(l.id)).length;
            GrammarLesson? last;
            for (final l in lessons) {
              if (l.id == progress.last) last = l;
            }
            final next = last;
            return ListView(
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 28),
              children: [
                const SceneArt('cat_grammar', height: 145),
                const SizedBox(height: 12),
                HeroBanner(
                  colors: const [Color(0xFF3D5A98), Color(0xFF1F2E57)],
                  icon: Icons.account_tree_rounded,
                  eyebrow: 'ADVANCED GRAMMAR',
                  title: '문장의 뼈대를\n탄탄하게',
                  subtitle: '${lessons.length}강 중 $count강 완료',
                  progress: lessons.isEmpty ? 0 : count / lessons.length,
                ),
                if (next != null) ...[
                  const SizedBox(height: 14),
                  PaperCard(
                    key: const ValueKey('grammar-continue'),
                    onTap: () => _open(next, progress),
                    child: Row(children: [
                      const IconBadge(
                          icon: Icons.play_arrow_rounded, color: _gMain),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            const Text('이어서 공부하기',
                                style: TextStyle(
                                    fontSize: 12, color: Washi.inkSoft)),
                            Text('${next.label} ${next.headline}',
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
                const SectionTitle('강의 목록', trailing: '강기석 선생님 강의 노트'),
                const SizedBox(height: 10),
                for (final l in lessons) ...[
                  _LessonTile(
                      lesson: l,
                      done: done.contains(l.id),
                      score: progress.score(l.id),
                      onTap: () => _open(l, progress)),
                  const SizedBox(height: 8),
                ],
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                      '강의 노트를 문자 인식으로 옮겨 정리했고, 노트에서 빈칸이던 정답을 채워 넣었어요. '
                      '🔊 버튼은 기기의 일본어 음성으로 읽어 줍니다.',
                      style: TextStyle(
                          fontSize: 12, color: Washi.inkSoft, height: 1.6)),
                ),
              ],
            );
          },
        ),
      );
}

class _LessonTile extends StatelessWidget {
  const _LessonTile(
      {required this.lesson,
      required this.done,
      required this.score,
      required this.onTap});
  final GrammarLesson lesson;
  final bool done;
  final int? score;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final total = lesson.choices.length + lesson.orders.length;
    return PaperCard(
      key: ValueKey('grammar-lesson-${lesson.number}'),
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(children: [
        ChapterArt('grammar', lesson.number, width: 70, height: 62),
        const SizedBox(width: 8),
        Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: done ? _gMain : _gSoft,
              borderRadius: BorderRadius.circular(14)),
          child: done
              ? const Icon(Icons.check_rounded, color: Colors.white)
              : Text(lesson.number.toString().padLeft(2, '0'),
                  style: const TextStyle(
                      color: _gDeep, fontWeight: FontWeight.w900, fontSize: 16)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(lesson.headline,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(
                '${lesson.title}${score == null || total == 0 ? '' : ' · 문제 $score/$total'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.5, color: Washi.inkSoft)),
          ]),
        ),
        const Icon(Icons.chevron_right_rounded, color: Washi.inkSoft),
      ]),
    );
  }
}

/// 빈칸 문장. [revealed]이면 정답을 색으로 보여 주고, 아니면 빈 상자를 그린다.
class GapText extends StatelessWidget {
  const GapText(this.text,
      {super.key,
      required this.revealed,
      this.fontSize = 17,
      this.color = _gMain});
  final String text;
  final bool revealed;
  final double fontSize;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
        fontSize: fontSize,
        height: 1.6,
        fontWeight: FontWeight.w600,
        color: Washi.ink);
    return Text.rich(TextSpan(style: base, children: [
      for (final p in splitGaps(text))
        if (!p.blank)
          TextSpan(text: p.text)
        else if (revealed)
          TextSpan(
              text: p.text,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  backgroundColor: color.withValues(alpha: 0.10)))
        else
          TextSpan(
              text: '　' * (p.text.length.clamp(2, 6)),
              style: TextStyle(
                  decoration: TextDecoration.underline,
                  decorationColor: color,
                  decorationThickness: 2,
                  backgroundColor: color.withValues(alpha: 0.08))),
    ]));
  }
}

/// 2026-10-07 문법 강의 화면: 문법 · 연습 · 퀴즈 · 단어.
class GrammarLessonPage extends StatefulWidget {
  const GrammarLessonPage(
      {super.key,
      required this.lesson,
      required this.progress,
      required this.speakJapanese,
      this.stop});
  final GrammarLesson lesson;
  final GrammarProgress progress;
  final GrammarSpeak speakJapanese;
  final Future<void> Function()? stop;

  @override
  State<GrammarLessonPage> createState() => _GrammarLessonPageState();
}

class _GrammarLessonPageState extends State<GrammarLessonPage> {
  final _shown = <String>{}; // 정답을 연 빈칸 문장
  bool _showAll = false;
  bool _korean = true;
  String? _speaking;
  final _picked = <int, int>{}; // 고르기: 문제 → 고른 보기
  final _orders = <int, List<int>>{}; // 순서: 문제 → 고른 조각 번호
  final _checked = <int>{};
  late final _shuffles = <int, List<int>>{
    for (var i = 0; i < lesson.orders.length; i++)
      i: _shuffle(lesson.orders[i].chunks.length, i)
  };
  late bool _done = widget.progress.isDone(lesson.id);

  GrammarLesson get lesson => widget.lesson;

  /// 정답 순서와 다르게 섞는다(항상 같은 결과).
  static List<int> _shuffle(int n, int seed) {
    final list = List<int>.generate(n, (i) => i);
    if (n < 2) return list;
    final shift = 1 + seed % (n - 1);
    return [...list.sublist(shift), ...list.sublist(0, shift)];
  }

  @override
  void initState() {
    super.initState();
    widget.progress.setLast(lesson.id);
  }

  @override
  void dispose() {
    widget.stop?.call();
    super.dispose();
  }

  Future<void> _speak(String text) async {
    if (text.trim().isEmpty) return;
    setState(() => _speaking = text);
    try {
      await widget.speakJapanese(text);
    } finally {
      if (mounted && _speaking == text) setState(() => _speaking = null);
    }
  }

  bool _isShown(String key) => _showAll || _shown.contains(key);

  Future<void> _reveal(String key, String sentence) async {
    setState(() => _shown.add(key));
    await _speak(sentence);
  }

  int get _total => lesson.choices.length + lesson.orders.length;
  int get _correct =>
      _picked.entries.where((e) => lesson.choices[e.key].answer == e.value).length +
      _checked.where(_orderRight).length;

  bool _orderRight(int i) {
    final got = _orders[i] ?? const <int>[];
    final want = lesson.orders[i].chunks;
    if (got.length != want.length) return false;
    for (var k = 0; k < got.length; k++) {
      if (want[got[k]] != want[k]) return false;
    }
    return true;
  }

  Future<void> _saveScore() async {
    if (_picked.length + _checked.length == _total && _total > 0) {
      await widget.progress.setScore(lesson.id, _correct);
    }
  }

  Future<void> _toggleDone() async {
    setState(() => _done = !_done);
    await widget.progress.setDone(lesson.id, _done);
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 4,
        child: Scaffold(
          appBar: AppBar(
            titleSpacing: 0,
            title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${lesson.label} ${lesson.headline}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 19)),
                  Text(lesson.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12.5, color: Washi.inkSoft)),
                ]),
            actions: [
              IconButton(
                key: const ValueKey('grammar-show-all'),
                tooltip: _showAll ? '빈칸 가리기' : '정답 모두 보기',
                onPressed: () => setState(() => _showAll = !_showAll),
                icon: Icon(_showAll
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined),
              ),
              IconButton(
                tooltip: _done ? '완료 취소' : '학습 완료',
                onPressed: _toggleDone,
                icon: Icon(
                    _done
                        ? Icons.check_circle_rounded
                        : Icons.check_circle_outline_rounded,
                    color: _done ? Washi.matcha : null),
              ),
            ],
            bottom: const TabBar(
              labelColor: _gDeep,
              indicatorColor: _gMain,
              unselectedLabelColor: Washi.inkSoft,
              labelStyle: TextStyle(fontWeight: FontWeight.w800),
              tabs: [
                Tab(text: '문법'),
                Tab(key: ValueKey('grammar-tab-practice'), text: '연습'),
                Tab(key: ValueKey('grammar-tab-quiz'), text: '퀴즈'),
                Tab(text: '단어'),
              ],
            ),
          ),
          body: TabBarView(
              children: [_grammar(), _practice(), _quiz(), _words()]),
        ),
      );

  // ───────────── 문법 ─────────────
  Widget _grammar() => ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          ChapterArt('grammar', lesson.number, height: 158),
          const SizedBox(height: 12),
          PaperCard(
            color: _gSoft,
            borderColor: _gMain.withValues(alpha: 0.25),
            child: Row(children: [
              const Icon(Icons.touch_app_rounded, color: _gMain),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                    '빈칸을 먼저 떠올려 보고, 줄을 누르면 정답이 나오며 읽어 줘요.'
                    '${_korean ? '' : '\n(해석 숨김 중)'}',
                    style: const TextStyle(fontSize: 13, height: 1.5)),
              ),
              TextButton(
                  onPressed: () => setState(() => _korean = !_korean),
                  child: Text(_korean ? '해석 숨기기' : '해석 보기')),
            ]),
          ),
          for (var pi = 0; pi < lesson.points.length; pi++) ...[
            const SizedBox(height: 18),
            _pointCard(lesson.points[pi]),
            if (lesson.points[pi].drills.isNotEmpty) ...[
              const SizedBox(height: 12),
              _subTitle('활용 연습'),
              for (var i = 0; i < lesson.points[pi].drills.length; i++)
                _gapRow('d$pi-$i', lesson.points[pi].drills[i], compact: true),
            ],
            if (lesson.points[pi].examples.isNotEmpty) ...[
              const SizedBox(height: 12),
              _subTitle('예문'),
              for (var i = 0; i < lesson.points[pi].examples.length; i++)
                _gapRow('e$pi-$i', lesson.points[pi].examples[i]),
            ],
          ],
        ],
      );

  Widget _subTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6, left: 2),
        child: Text(text,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: _gMain,
                letterSpacing: 0.5)),
      );

  Widget _pointCard(GrammarPoint p) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
              colors: [Color(0xFF3D5A98), Color(0xFF233A6E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(p.head,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w900)),
            ),
            SpeakButton(
                speaking: _speaking == p.head,
                color: Colors.white,
                onPressed: () => _speak(p.head)),
          ]),
          if (p.form.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10)),
              child: Text(p.form,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700)),
            ),
          ],
          if (p.meaning.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(p.meaning,
                style: const TextStyle(
                    color: Color(0xFFFFD29E),
                    fontSize: 16,
                    fontWeight: FontWeight.w800)),
          ],
          if (p.notes.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final n in p.notes)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text('★ $n',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 12.5, height: 1.3)),
                ),
            ]),
          ],
        ]),
      );

  Widget _gapRow(String key, GapItem item, {bool compact = false}) {
    final shown = _isShown(key);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: shown ? Colors.white : Washi.card,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          key: ValueKey('gap-$key'),
          borderRadius: BorderRadius.circular(16),
          onTap: () => _reveal(key, item.filled),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: _speaking == item.filled
                      ? _gMain.withValues(alpha: 0.6)
                      : Washi.line),
            ),
            child: Row(children: [
              if (item.base.isNotEmpty)
                Container(
                  constraints: const BoxConstraints(minWidth: 58),
                  margin: const EdgeInsets.only(right: 10),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: _gSoft, borderRadius: BorderRadius.circular(10)),
                  child: Text(item.base,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: _gDeep)),
                ),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GapText(item.japanese,
                          revealed: shown, fontSize: compact ? 16.5 : 17),
                      if (_korean && item.korean.isNotEmpty)
                        Text(item.korean,
                            style: const TextStyle(
                                fontSize: 13, color: Washi.inkSoft, height: 1.4)),
                    ]),
              ),
              SpeakButton(
                  speaking: _speaking == item.filled,
                  color: _gMain,
                  onPressed: () => _reveal(key, item.filled)),
            ]),
          ),
        ),
      ),
    );
  }

  // ───────────── 연습(활용표 + 고르기) ─────────────
  Widget _practice() => ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          if (lesson.table.isNotEmpty) ...[
            const SectionTitle('활용 정리', trailing: '빈칸을 눌러 확인'),
            const SizedBox(height: 10),
            for (var i = 0; i < lesson.table.length; i++)
              _gapRow('x$i', lesson.table[i], compact: true),
            const SizedBox(height: 14),
          ],
          if (lesson.choices.isNotEmpty) ...[
            SectionTitle('れんしゅうしましょ！',
                trailing: '${lesson.choices.length}문제'),
            const SizedBox(height: 10),
            for (var i = 0; i < lesson.choices.length; i++) _choiceCard(i),
          ],
          if (lesson.table.isEmpty && lesson.choices.isEmpty)
            const Padding(
                padding: EdgeInsets.only(top: 60),
                child: Center(child: Text('이 강의에는 연습 문제가 없어요.'))),
        ],
      );

  Widget _choiceCard(int i) {
    final q = lesson.choices[i];
    final picked = _picked[i];
    final answered = picked != null;
    final filled = fillGaps(q.japanese);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PaperCard(
        key: ValueKey('grammar-choice-$i'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _numBadge(i + 1),
            const SizedBox(width: 10),
            Expanded(child: GapText(q.japanese, revealed: answered)),
            if (answered)
              SpeakButton(
                  speaking: _speaking == filled,
                  color: _gMain,
                  onPressed: () => _speak(filled)),
          ]),
          if (_korean && q.korean.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 40, top: 2),
              child: Text(q.korean,
                  style: const TextStyle(fontSize: 13, color: Washi.inkSoft)),
            ),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (var o = 0; o < q.options.length; o++)
              _optionChip(
                  key: ValueKey('grammar-choice-$i-$o'),
                  label: '${'①②③④⑤'[o]} ${q.options[o]}',
                  state: !answered
                      ? 0
                      : o == q.answer
                          ? 1
                          : o == picked
                              ? 2
                              : 0,
                  onTap: answered
                      ? null
                      : () async {
                          setState(() => _picked[i] = o);
                          await _saveScore();
                          await _speak(filled);
                        }),
          ]),
        ]),
      ),
    );
  }

  Widget _numBadge(int n) => Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
            color: _gMain, borderRadius: BorderRadius.circular(10)),
        child: Text('$n',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w900)),
      );

  /// state: 0 기본, 1 정답, 2 오답.
  Widget _optionChip(
      {Key? key, required String label, required int state, VoidCallback? onTap}) {
    final color = switch (state) {
      1 => Washi.matcha,
      2 => Washi.shu,
      _ => _gMain,
    };
    return Material(
      key: key,
      color: state == 0 ? Colors.white : color.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
              color: state == 0 ? Washi.line : color.withValues(alpha: 0.6))),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (state == 1)
              const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Icon(Icons.check_rounded, size: 18, color: Washi.matcha)),
            if (state == 2)
              const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Icon(Icons.close_rounded, size: 18, color: Washi.shu)),
            Text(label,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: state == 0 ? Washi.ink : color)),
          ]),
        ),
      ),
    );
  }

  // ───────────── 퀴즈(순서 맞추기) ─────────────
  Widget _quiz() => ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          PaperCard(
            color: _gSoft,
            borderColor: _gMain.withValues(alpha: 0.25),
            child: const Row(children: [
              Icon(Icons.extension_rounded, color: _gMain),
              SizedBox(width: 10),
              Expanded(
                child: Text('즐거운 퀴즈 시간! 조각을 순서대로 눌러 문장을 완성하세요.',
                    style: TextStyle(fontSize: 13.5, height: 1.5)),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < lesson.orders.length; i++) _orderCard(i),
          if (lesson.orders.isEmpty)
            const Padding(
                padding: EdgeInsets.only(top: 60),
                child: Center(child: Text('이 강의에는 퀴즈가 없어요.'))),
          if (_total > 0) ...[
            const SizedBox(height: 8),
            PaperCard(
              child: Row(children: [
                const Icon(Icons.emoji_events_rounded, color: Washi.yamabuki),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                      '연습+퀴즈 $_total문제 중 ${_picked.length + _checked.length}문제 풀이 · 정답 $_correct개',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ]),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              key: const ValueKey('grammar-finish'),
              style: FilledButton.styleFrom(
                  backgroundColor: _done ? Washi.matcha : _gMain),
              onPressed: _toggleDone,
              icon: Icon(_done ? Icons.check_circle_rounded : Icons.flag_rounded),
              label: Text(_done ? '완료함' : '학습 완료'),
            ),
          ],
        ],
      );

  Widget _orderCard(int i) {
    final q = lesson.orders[i];
    final got = _orders[i] ?? <int>[];
    final checked = _checked.contains(i);
    final right = checked && _orderRight(i);
    final filled = fillGaps(q.japanese);
    // 정답 순서의 k번째 빈칸에 고른 조각을 넣은 미리보기
    var k = 0;
    final preview = q.japanese.replaceAllMapped(RegExp(r'\[(.+?)\]'), (m) {
      final idx = k++;
      if (checked) return '[${q.chunks[idx]}]';
      return idx < got.length ? '[${q.chunks[got[idx]]}]' : '[＿＿]';
    });
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PaperCard(
        key: ValueKey('grammar-order-$i'),
        borderColor: !checked
            ? Washi.line
            : right
                ? Washi.matcha
                : Washi.shu,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _numBadge(i + 1),
            const SizedBox(width: 10),
            Expanded(child: GapText(preview, revealed: true)),
            if (checked)
              SpeakButton(
                  speaking: _speaking == filled,
                  color: _gMain,
                  onPressed: () => _speak(filled)),
          ]),
          if (q.korean.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 40, top: 2),
              child: Text(q.korean,
                  style: const TextStyle(fontSize: 13, color: Washi.inkSoft)),
            ),
          const SizedBox(height: 10),
          if (!checked)
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final c in _shuffles[i]!)
                _optionChip(
                    key: ValueKey('grammar-order-$i-chunk-$c'),
                    label: q.chunks[c],
                    state: 0,
                    onTap: got.contains(c)
                        ? null
                        : () => setState(() => _orders[i] = [...got, c])),
            ]),
          if (checked)
            Text(right ? '정답이에요!' : '정답 순서로 고쳐 두었어요. 다시 읽어 보세요.',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: right ? Washi.matcha : Washi.shu)),
          const SizedBox(height: 8),
          Row(children: [
            TextButton.icon(
              onPressed: got.isEmpty && !checked
                  ? null
                  : () => setState(() {
                        _orders.remove(i);
                        _checked.remove(i);
                      }),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('다시'),
            ),
            const Spacer(),
            if (!checked)
              FilledButton(
                key: ValueKey('grammar-order-$i-check'),
                style: FilledButton.styleFrom(
                    backgroundColor: _gMain,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 18, vertical: 10)),
                onPressed: got.length == q.chunks.length
                    ? () async {
                        setState(() => _checked.add(i));
                        await _saveScore();
                        await _speak(filled);
                      }
                    : null,
                child: const Text('정답 확인'),
              ),
          ]),
        ]),
      ),
    );
  }

  // ───────────── 단어 ─────────────
  Widget _words() => ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          SectionTitle('たんごまとめ · 단어 정리',
              trailing: '${lesson.words.length}개'),
          const SizedBox(height: 10),
          PaperCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(children: [
              for (var i = 0; i < lesson.words.length; i++) ...[
                if (i > 0) const Divider(height: 1, color: Washi.line),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 6, 4, 6),
                  child: Row(children: [
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                                crossAxisAlignment: WrapCrossAlignment.end,
                                spacing: 8,
                                children: [
                                  Text(lesson.words[i].word,
                                      style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800)),
                                  if (lesson.words[i].reading.isNotEmpty &&
                                      lesson.words[i].reading !=
                                          lesson.words[i].word)
                                    Text(lesson.words[i].reading,
                                        style: const TextStyle(
                                            fontSize: 13, color: _gMain)),
                                ]),
                            Text(lesson.words[i].meaning,
                                style: const TextStyle(
                                    fontSize: 13.5, color: Washi.inkSoft)),
                          ]),
                    ),
                    SpeakButton(
                        speaking: _speaking == lesson.words[i].word,
                        color: _gMain,
                        onPressed: () => _speak(lesson.words[i].word)),
                  ]),
                ),
              ],
            ]),
          ),
        ],
      );
}
