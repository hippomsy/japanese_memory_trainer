import 'dart:math';

import 'package:flutter/material.dart';
import 'package:kioku_japanese/data/kanji_parts.dart';
import 'package:kioku_japanese/services/radical_course.dart';
import 'package:kioku_japanese/widgets/kanji_parts_view.dart';
import 'package:kioku_japanese/widgets/study_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 2026-10-11 기본 부수 메뉴 색(벵갈라 · 弁柄).
const Color radicalColor = Color(0xFFA34A32);
const Color _rSoft = Color(0xFFF7E9E3);

typedef RadicalSpeak = Future<void> Function(String text);

/// 2026-10-11 헷갈리는 부수 짝과 구별법.
const List<(String, String, String)> radicalPairs = [
  ('礻', '衤', '礻(보일 시)는 점 하나 → 신·제사·복.  衤(옷 의)는 점 둘 → 옷.  「옷은 단추가 하나 더!」'),
  ('冫', '氵', '冫(얼음)은 점 둘, 氵(물)은 점 셋.  「얼음은 물보다 한 방울 적다」'),
  ('宀', '冖', '宀은 지붕 위에 점(굴뚝)이 있는 집.  冖은 점 없는 덮개'),
  ('⻖', '⻏', '똑같이 생긴 阝도 왼쪽이면 언덕(阜), 오른쪽이면 고을(邑).  「왼쪽 언덕, 오른쪽 마을」'),
  ('广', '厂', '广은 점 있는 큰 집(店·庭).  厂은 점 없는 절벽(原·厚)'),
  ('⻌', '廴', '⻌(책받침)은 점이 있는 「길 가다」(道·近).  廴(민책받침)은 점 없는 「길게 끌다」(建·延)'),
  ('彳', '亻', '彳은 삐침이 둘 → 네거리(行)의 절반 = 길.  亻은 하나 → 사람'),
  ('攵', '殳', '攵은 막대 든 손(教·数).  殳는 몽둥이 든 손, 위에 几(投·段)'),
  ('戸', '尸', '戸는 맨 위에 가로획 하나 더 → 문(所·房).  尸는 엉덩이 내민 사람 → 몸·집(屋·居)'),
  ('心', '忄', '같은 마음. 아래에 오면 心(思·感), 왼쪽에 서면 忄(情·忙)'),
  ('火', '灬', '같은 불. 왼쪽·위에선 火(焼·炎), 아래로 가면 점 넷 灬(点·熱)'),
  ('刀', '刂', '같은 칼. 오른쪽에 세로로 서면 刂(別·前)'),
  ('日', '目', '日은 가운데 가로획 하나(해), 目은 둘(눈)'),
  ('隹', '鳥', '둘 다 새. 隹는 꼬리 짧은 작은 새(集), 鳥는 꼬리 긴 새(鳴)'),
];

/// 2026-10-11 기본 부수 첫 화면.
class RadicalHomePage extends StatefulWidget {
  const RadicalHomePage(
      {super.key, this.speakJapanese, this.course, this.bank, this.clock});
  final RadicalSpeak? speakJapanese;
  final RadicalCourse? course;
  final KanjiPartsBank? bank;
  final DateTime Function()? clock;

  @override
  State<RadicalHomePage> createState() => _RadicalHomePageState();
}

class _RadicalHomePageState extends State<RadicalHomePage> {
  RadicalCourse? _course;
  KanjiPartsBank? _bank;
  RadicalProgress? _progress;
  String? _error;

  DateTime get _now => (widget.clock ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final course = widget.course ?? await RadicalCourse.load();
      final bank = widget.bank ?? await KanjiPartsBank.load();
      if (!mounted) return;
      setState(() {
        _course = course;
        _bank = bank;
        _progress = RadicalProgress(prefs);
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _push(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
    if (mounted) setState(() {});
  }

  void _openLesson(RadicalLesson l) => _push(RadicalLessonPage(
      lesson: l,
      course: _course!,
      bank: _bank!,
      progress: _progress!,
      speakJapanese: widget.speakJapanese,
      clock: widget.clock));

  void _openQuiz(String title, List<Radical> targets) => _push(RadicalQuizPage(
      title: title,
      targets: targets,
      course: _course!,
      bank: _bank!,
      progress: _progress!,
      speakJapanese: widget.speakJapanese,
      clock: widget.clock));

  void _today() {
    final c = _course!, p = _progress!;
    final due = p.due(c.radicals, _now);
    if (due.isNotEmpty) {
      _openQuiz('오늘의 복습', due.take(20).toList());
      return;
    }
    final next = p.nextLesson(c);
    if (next != null) {
      _openLesson(next);
      return;
    }
    final all = [...c.radicals]..shuffle();
    _openQuiz('전체 다시 보기', all.take(12).toList());
  }

  @override
  Widget build(BuildContext context) {
    final c = _course, p = _progress, bank = _bank;
    return Scaffold(
      backgroundColor: Washi.paper,
      appBar: washiAppBar(title: '기본 부수', subtitle: '부수를 알면 한자가 쪼개져요'),
      body: _error != null
          ? Center(child: Text('부수 자료를 읽지 못했어요.\n$_error', textAlign: TextAlign.center))
          : (c == null || p == null || bank == null)
              ? const Center(child: CircularProgressIndicator())
              : _body(c, p, bank),
    );
  }

  Widget _body(RadicalCourse c, RadicalProgress p, KanjiPartsBank bank) {
    final total = c.radicals.length;
    final mastered = p.masteredCount(c.radicals);
    final learned = p.learnedCount(c.radicals);
    final due = p.due(c.radicals, _now).length;
    final next = p.nextLesson(c);
    final todayLabel = due > 0
        ? '복습 $due개 하기'
        : next != null
            ? '${next.label} 배우기'
            : '전체 다시 보기';
    return ListView(
      key: const ValueKey('radical-home'),
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 32),
      children: [
        HeroBanner(
          colors: const [Color(0xFFA34A32), Color(0xFF6E2E22)],
          icon: Icons.extension_rounded,
          eyebrow: 'RADICALS · 部首',
          title: '부수를 알면\n한자가 보여요',
          subtitle: '외운 부수 $mastered / $total  ·  배운 부수 $learned\n'
              '${due > 0 ? '지금 복습할 부수 $due개' : '복습할 부수가 없어요'}',
          progress: total == 0 ? 0 : mastered / total,
          action: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const ValueKey('radical-today'),
              style: FilledButton.styleFrom(
                  backgroundColor: Colors.white, foregroundColor: radicalColor),
              onPressed: _today,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text('오늘의 학습 · $todayLabel'),
            ),
          ),
        ),
        const SizedBox(height: 14),
        PaperCard(
          color: _rSoft,
          borderColor: radicalColor.withValues(alpha: 0.2),
          padding: const EdgeInsets.all(14),
          child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('확실하게 외우는 3단계',
                style: TextStyle(fontWeight: FontWeight.w900, color: radicalColor)),
            SizedBox(height: 6),
            Text('① 카드로 배우기 — 획순 · 자리 · 이야기 · 예시 한자\n'
                '② 확인 퀴즈 — 틀린 부수는 맞힐 때까지 다시 나와요\n'
                '③ 간격 복습 — 10분 → 1일 → 3일 → 7일 → 14일 → 30일',
                style: TextStyle(fontSize: 13, height: 1.6, color: Washi.ink)),
          ]),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: _toolButton(
                const ValueKey('radical-table'),
                Icons.grid_view_rounded,
                '부수 전체표',
                () => _push(RadicalTablePage(
                    course: c, bank: bank, progress: p, speakJapanese: widget.speakJapanese))),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _toolButton(
                const ValueKey('radical-pairs'),
                Icons.compare_arrows_rounded,
                '헷갈리는 부수',
                () => _push(RadicalPairsPage(course: c, bank: bank))),
          ),
        ]),
        const SizedBox(height: 22),
        SectionTitle('${c.lessons.length}과', trailing: '부수 $total개'),
        const SizedBox(height: 10),
        for (final l in c.lessons)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _lessonCard(l, p, bank),
          ),
      ],
    );
  }

  Widget _toolButton(Key key, IconData icon, String label, VoidCallback onTap) =>
      PaperCard(
        key: key,
        onTap: onTap,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: radicalColor, size: 20),
          const SizedBox(width: 6),
          Flexible(
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.w800, color: Washi.ink)),
          ),
        ]),
      );

  Widget _lessonCard(RadicalLesson l, RadicalProgress p, KanjiPartsBank bank) {
    final ratio = p.lessonRatio(l);
    final newCount = l.radicals.where((r) => p.isNew(r.form)).length;
    final status = newCount == l.radicals.length
        ? '아직 안 배움'
        : newCount > 0
            ? '$newCount개 남음'
            : ratio >= 1
                ? '다 외웠어요'
                : '복습 중';
    return PaperCard(
      key: ValueKey('radical-lesson-${l.number}'),
      onTap: () => _openLesson(l),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          HankoBadge(text: '${l.number}', color: radicalColor, size: 30, filled: ratio >= 1),
          const SizedBox(width: 10),
          Expanded(
            child: Text('${l.label} · ${l.title}',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800, color: Washi.ink)),
          ),
          Text(status, style: const TextStyle(fontSize: 12, color: Washi.inkSoft)),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 4, runSpacing: 4, children: [
          for (final r in l.radicals) _miniGlyph(r, p, bank),
        ]),
        const SizedBox(height: 8),
        SlimProgress(ratio: ratio, color: radicalColor),
      ]),
    );
  }

  Widget _miniGlyph(Radical r, RadicalProgress p, KanjiPartsBank bank) {
    final s = p.stage(r.form);
    final parts = bank[r.form];
    return Container(
      width: 34,
      height: 34,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: s == 0
            ? Washi.card
            : radicalColor.withValues(alpha: 0.06 + 0.04 * min(s, 5)),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: s >= RadicalProgress.masteredStage ? radicalColor : Washi.line),
      ),
      child: parts == null
          ? Center(child: Text(r.form))
          : KanjiGlyph(parts: parts, size: 28, colored: false),
    );
  }
}

// ───────────────────────────── 위치 그림 ─────────────────────────────

/// 2026-10-11 부수가 놓이는 자리를 네모 칸에 칠해서 보여 준다.
class RadicalPositionBox extends StatelessWidget {
  const RadicalPositionBox(this.position, {super.key, this.size = 44, this.color = radicalColor});
  final RadicalPosition position;
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) => SizedBox(
      width: size, height: size, child: CustomPaint(painter: _PosPainter(position, color)));
}

class _PosPainter extends CustomPainter {
  _PosPainter(this.pos, this.color);
  final RadicalPosition pos;
  final Color color;
  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    final fill = Paint()..color = color.withValues(alpha: 0.75);
    final line = Paint()
      ..color = Washi.inkSoft
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final r = RRect.fromRectAndRadius(Offset.zero & s, const Radius.circular(6));
    canvas.save();
    canvas.clipRRect(r);
    final t = w * 0.36;
    switch (pos) {
      case RadicalPosition.hen:
        canvas.drawRect(Rect.fromLTWH(0, 0, t, h), fill);
      case RadicalPosition.tsukuri:
        canvas.drawRect(Rect.fromLTWH(w - t, 0, t, h), fill);
      case RadicalPosition.kanmuri:
        canvas.drawRect(Rect.fromLTWH(0, 0, w, t), fill);
      case RadicalPosition.ashi:
        canvas.drawRect(Rect.fromLTWH(0, h - t, w, t), fill);
      case RadicalPosition.tare:
        canvas.drawRect(Rect.fromLTWH(0, 0, w, t * 0.75), fill);
        canvas.drawRect(Rect.fromLTWH(0, 0, t * 0.75, h), fill);
      case RadicalPosition.nyou:
        canvas.drawRect(Rect.fromLTWH(0, h - t * 0.75, w, t * 0.75), fill);
        canvas.drawRect(Rect.fromLTWH(0, 0, t * 0.75, h), fill);
      case RadicalPosition.kamae:
        canvas.drawRect(Offset.zero & s, fill);
        canvas.drawRect(Rect.fromLTWH(w * 0.25, h * 0.25, w * 0.5, h * 0.75),
            Paint()..color = Washi.card);
      case RadicalPosition.free:
        canvas.drawCircle(Offset(w / 2, h / 2), w * 0.22, fill);
    }
    canvas.restore();
    canvas.drawRRect(r, line);
  }

  @override
  bool shouldRepaint(_PosPainter old) => old.pos != pos || old.color != color;
}

// ───────────────────────────── 부수 카드 ─────────────────────────────

/// 2026-10-11 부수 한 개를 배우는 카드: 큰 글자(획순), 이름, 자리, 이야기, 예시 한자.
class RadicalCard extends StatefulWidget {
  const RadicalCard(
      {super.key, required this.radical, required this.bank, this.speakJapanese});
  final Radical radical;
  final KanjiPartsBank bank;
  final RadicalSpeak? speakJapanese;

  @override
  State<RadicalCard> createState() => _RadicalCardState();
}

class _RadicalCardState extends State<RadicalCard> with SingleTickerProviderStateMixin {
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    final n = widget.bank[widget.radical.form]?.strokeCount ?? 1;
    _anim = AnimationController(vsync: this, duration: Duration(milliseconds: 600 * max(n, 1)));
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.radical;
    final parts = widget.bank[r.form];
    final variants = r.forms.split('').where((f) => f != r.form).toList();
    return ListView(
      key: ValueKey('radical-card-${r.form}'),
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
      children: [
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          GestureDetector(
            onTap: () => _anim.forward(from: 0),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Washi.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: radicalColor.withValues(alpha: 0.35), width: 1.4),
              ),
              child: parts == null
                  ? SizedBox(
                      width: 140,
                      height: 140,
                      child: Center(child: Text(r.form, style: const TextStyle(fontSize: 90))))
                  : AnimatedBuilder(
                      animation: _anim,
                      builder: (_, __) => KanjiGlyph(
                        parts: parts,
                        size: 140,
                        colored: false,
                        progress: _anim.isAnimating ? _anim.value * parts.strokeCount : null,
                        showNumbers: _anim.isAnimating,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.korean,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w900, color: radicalColor)),
              if (r.nickname.isNotEmpty && r.nickname != r.korean)
                Text(r.nickname,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800, color: Washi.ink)),
              const SizedBox(height: 4),
              InkWell(
                onTap: widget.speakJapanese == null
                    ? null
                    : () => widget.speakJapanese!(r.japaneseName.split('/').first.trim()),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Flexible(
                    child: Text(r.japaneseName,
                        style: const TextStyle(fontSize: 14, color: Washi.inkSoft)),
                  ),
                  if (widget.speakJapanese != null) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.volume_up_rounded, size: 17, color: radicalColor),
                  ],
                ]),
              ),
              const SizedBox(height: 8),
              Row(children: [
                RadicalPositionBox(r.position, size: 30),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(r.position.label,
                      style: const TextStyle(fontSize: 12.5, color: Washi.ink)),
                ),
              ]),
              const SizedBox(height: 6),
              TextButton.icon(
                key: ValueKey('radical-stroke-${r.form}'),
                style: TextButton.styleFrom(
                    foregroundColor: radicalColor, padding: EdgeInsets.zero),
                onPressed: () => _anim.forward(from: 0),
                icon: const Icon(Icons.gesture_rounded, size: 18),
                label: Text('획순 보기 · ${parts?.strokeCount ?? '-'}획'),
              ),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        _label(Icons.label_rounded, '뜻'),
        Text(r.meaning,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Washi.ink)),
        if (variants.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('같은 부수의 다른 모양: ${variants.join(' · ')}',
              style: const TextStyle(fontSize: 13, color: Washi.inkSoft)),
        ],
        const SizedBox(height: 14),
        _label(Icons.lightbulb_rounded, '기억 이야기'),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _rSoft,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: radicalColor.withValues(alpha: 0.2)),
          ),
          child: Text(r.story,
              style: const TextStyle(fontSize: 15, height: 1.55, color: Washi.ink)),
        ),
        const SizedBox(height: 16),
        _label(Icons.grid_on_rounded,
            '이 부수가 들어간 한자${r.count > 0 ? ' (앱 안에 ${r.count}자)' : ''}'),
        const SizedBox(height: 4),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final e in r.examples) _example(e),
        ]),
        const SizedBox(height: 6),
        const Text('예시 한자를 누르면 부품으로 쪼개 볼 수 있어요.',
            style: TextStyle(fontSize: 11.5, color: Washi.inkSoft)),
      ],
    );
  }

  Widget _label(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          Icon(icon, size: 16, color: radicalColor),
          const SizedBox(width: 5),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.w800, color: Washi.inkSoft)),
          ),
        ]),
      );

  Widget _example(RadicalExample e) {
    final parts = widget.bank[e.kanji];
    return InkWell(
      key: ValueKey('radical-example-${e.kanji}'),
      borderRadius: BorderRadius.circular(12),
      onTap: () => showKanjiPartsSheet(context, e.kanji, accent: radicalColor),
      child: Container(
        width: 96,
        padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
        decoration: BoxDecoration(
          color: Washi.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Washi.line),
        ),
        child: Column(children: [
          parts == null
              ? Text(e.kanji, style: const TextStyle(fontSize: 44))
              : KanjiGlyph(
                  parts: parts,
                  size: 64,
                  highlightStrokes: e.strokes.toSet(),
                  highlightColor: radicalColor),
          const SizedBox(height: 4),
          Text(e.hunEum,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Washi.ink)),
        ]),
      ),
    );
  }
}

// ───────────────────────────── 과 학습 ─────────────────────────────

/// 2026-10-11 한 과의 부수 카드를 넘겨 보고, 끝에서 확인 퀴즈로 간다.
class RadicalLessonPage extends StatefulWidget {
  const RadicalLessonPage({
    super.key,
    required this.lesson,
    required this.course,
    required this.bank,
    required this.progress,
    this.speakJapanese,
    this.clock,
  });
  final RadicalLesson lesson;
  final RadicalCourse course;
  final KanjiPartsBank bank;
  final RadicalProgress progress;
  final RadicalSpeak? speakJapanese;
  final DateTime Function()? clock;

  @override
  State<RadicalLessonPage> createState() => _RadicalLessonPageState();
}

class _RadicalLessonPageState extends State<RadicalLessonPage> {
  final _pager = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  int get _count => widget.lesson.radicals.length;

  Future<void> _startQuiz() async {
    final now = (widget.clock ?? DateTime.now)();
    for (final r in widget.lesson.radicals) {
      await widget.progress.markLearned(r.form, now);
    }
    if (!mounted) return;
    final nav = Navigator.of(context);
    await nav.push(MaterialPageRoute<void>(
        builder: (_) => RadicalQuizPage(
              title: '${widget.lesson.label} 확인 퀴즈',
              targets: widget.lesson.radicals,
              course: widget.course,
              bank: widget.bank,
              progress: widget.progress,
              speakJapanese: widget.speakJapanese,
              clock: widget.clock,
            )));
    // 퀴즈를 마치면 과 화면도 닫고 첫 화면(진행률 갱신)으로 돌아간다.
    if (mounted) nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.lesson;
    final last = _page >= _count;
    return Scaffold(
      backgroundColor: Washi.paper,
      appBar: washiAppBar(
          title: '${l.label} ${l.title}',
          subtitle: last ? '확인 퀴즈' : '${_page + 1} / $_count'),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 6),
          child: SlimProgress(ratio: min(_page + 1, _count) / _count, color: radicalColor),
        ),
        Expanded(
          child: PageView(
            controller: _pager,
            onPageChanged: (i) => setState(() => _page = i),
            children: [
              for (final r in l.radicals)
                RadicalCard(radical: r, bank: widget.bank, speakJapanese: widget.speakJapanese),
              _quizIntro(),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 12),
            child: Row(children: [
              IconButton.filledTonal(
                key: const ValueKey('radical-prev'),
                onPressed: _page > 0
                    ? () => _pager.previousPage(
                        duration: const Duration(milliseconds: 250), curve: Curves.easeOut)
                    : null,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  key: const ValueKey('radical-next'),
                  style: FilledButton.styleFrom(
                      backgroundColor: radicalColor, minimumSize: const Size.fromHeight(50)),
                  onPressed: last
                      ? _startQuiz
                      : () => _pager.nextPage(
                          duration: const Duration(milliseconds: 250), curve: Curves.easeOut),
                  child: Text(last ? '확인 퀴즈 시작' : (_page == _count - 1 ? '다 봤어요' : '다음 부수')),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _quizIntro() => ListView(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
        children: [
          const Icon(Icons.task_alt_rounded, size: 56, color: radicalColor),
          const SizedBox(height: 10),
          const Text('이제 확인해 볼까요?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text('모양 → 이름, 이름 → 모양, 한자 속 부수 찾기, 자리 맞히기.\n'
              '틀린 부수는 다른 문제로 바뀌어 맞힐 때까지 다시 나와요.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 1.6, color: Washi.inkSoft)),
          const SizedBox(height: 18),
          Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
            for (final r in widget.lesson.radicals)
              Chip(
                label: Text('${r.form} ${r.korean}'),
                backgroundColor: _rSoft,
                side: BorderSide.none,
              ),
          ]),
        ],
      );
}

// ───────────────────────────── 퀴즈 ─────────────────────────────

/// 2026-10-11 부수 퀴즈. 틀린 부수는 다른 종류의 문제로 맞힐 때까지 다시 낸다.
/// 처음 답한 결과로 간격 복습 단계를 올리거나 내린다.
class RadicalQuizPage extends StatefulWidget {
  const RadicalQuizPage({
    super.key,
    required this.title,
    required this.targets,
    required this.course,
    required this.bank,
    required this.progress,
    this.speakJapanese,
    this.clock,
    this.random,
  });
  final String title;
  final List<Radical> targets;
  final RadicalCourse course;
  final KanjiPartsBank bank;
  final RadicalProgress progress;
  final RadicalSpeak? speakJapanese;
  final DateTime Function()? clock;
  final Random? random;

  @override
  State<RadicalQuizPage> createState() => _RadicalQuizPageState();
}

class _RadicalQuizPageState extends State<RadicalQuizPage> {
  late final RadicalQuizBuilder _builder;
  late final List<RadicalQuestion> _queue;
  final Map<String, bool> _first = {};
  int _index = 0;
  int? _chosen;

  @override
  void initState() {
    super.initState();
    _builder = RadicalQuizBuilder(widget.course.radicals, random: widget.random);
    _queue = _builder.build(widget.targets);
  }

  DateTime get _now => (widget.clock ?? DateTime.now)();
  bool get _done => _index >= _queue.length;

  Future<void> _answer(int i) async {
    if (_chosen != null) return;
    final q = _queue[_index];
    final ok = i == q.answer;
    setState(() => _chosen = i);
    if (!_first.containsKey(q.radical.form)) {
      _first[q.radical.form] = ok;
      await widget.progress.record(q.radical.form, ok, _now);
    }
    if (!ok) {
      // 다른 종류로 다시 낸다.
      final kinds = RadicalQuizKind.values.where((k) => k != q.kind).toList();
      _queue.add(_builder.question(q.radical, kinds[_queue.length % kinds.length]));
    } else if (widget.speakJapanese != null) {
      widget.speakJapanese!(q.radical.japaneseName.split('/').first.trim());
    }
  }

  void _next() => setState(() {
        _index++;
        _chosen = null;
      });

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Washi.paper,
        appBar: washiAppBar(
            title: widget.title,
            subtitle: _done ? '결과' : '${min(_index + 1, _queue.length)} / ${_queue.length}'),
        body: _done ? _result() : _question(_queue[_index]),
      );

  Widget _glyph(String form, double size, {Set<int>? hl, bool colored = false}) {
    final p = widget.bank[form];
    if (p == null) {
      return SizedBox(
          width: size,
          height: size,
          child: Center(child: Text(form, style: TextStyle(fontSize: size * 0.7))));
    }
    return KanjiGlyph(
        parts: p, size: size, colored: colored, highlightStrokes: hl, highlightColor: radicalColor);
  }

  Widget _question(RadicalQuestion q) {
    final answered = _chosen != null;
    final correct = _chosen == q.answer;
    final showHl = answered && q.kanji != null;
    return ListView(
      key: ValueKey('radical-quiz-$_index'),
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 28),
      children: [
        SlimProgress(ratio: _index / _queue.length, color: radicalColor),
        const SizedBox(height: 16),
        Text(q.prompt,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: Washi.ink)),
        const SizedBox(height: 14),
        if (q.kind != RadicalQuizKind.form)
          Center(
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: Washi.card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Washi.line)),
              child: q.kanji != null
                  ? _glyph(q.kanji!.kanji, 130, hl: showHl ? q.kanji!.strokes.toSet() : null)
                  : _glyph(q.radical.form, 130),
            ),
          )
        else
          Center(
            child: Text(q.radical.title,
                style: const TextStyle(
                    fontSize: 24, fontWeight: FontWeight.w900, color: radicalColor)),
          ),
        if (q.kind == RadicalQuizKind.form)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('뜻: ${q.radical.meaning}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Washi.inkSoft)),
          ),
        const SizedBox(height: 18),
        if (q.optionsAreForms)
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: [
              for (var i = 0; i < q.options.length; i++)
                _formOption(q, i),
            ],
          )
        else
          for (var i = 0; i < q.options.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _textOption(q, i),
            ),
        if (answered) ...[
          const SizedBox(height: 10),
          _feedback(q, correct),
          const SizedBox(height: 12),
          FilledButton(
            key: const ValueKey('radical-quiz-next'),
            style: FilledButton.styleFrom(
                backgroundColor: radicalColor, minimumSize: const Size.fromHeight(50)),
            onPressed: _next,
            child: Text(_index + 1 >= _queue.length ? '결과 보기' : '다음 문제'),
          ),
        ],
      ],
    );
  }

  Color? _optionColor(RadicalQuestion q, int i) {
    if (_chosen == null) return null;
    if (i == q.answer) return Washi.matcha;
    if (i == _chosen) return Washi.shu;
    return null;
  }

  Widget _formOption(RadicalQuestion q, int i) {
    final c = _optionColor(q, i);
    return InkWell(
      key: ValueKey('radical-option-$i'),
      borderRadius: BorderRadius.circular(14),
      onTap: () => _answer(i),
      child: Container(
        decoration: BoxDecoration(
          color: c?.withValues(alpha: 0.12) ?? Washi.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c ?? Washi.line, width: c == null ? 1 : 2),
        ),
        padding: const EdgeInsets.all(4),
        child: Center(child: _glyph(q.options[i], 60)),
      ),
    );
  }

  Widget _textOption(RadicalQuestion q, int i) {
    final c = _optionColor(q, i);
    return InkWell(
      key: ValueKey('radical-option-$i'),
      borderRadius: BorderRadius.circular(14),
      onTap: () => _answer(i),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: c?.withValues(alpha: 0.12) ?? Washi.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c ?? Washi.line, width: c == null ? 1 : 2),
        ),
        child: Row(children: [
          if (q.kind == RadicalQuizKind.position) ...[
            RadicalPositionBox(
                RadicalPosition.values.firstWhere((p) => p.label == q.options[i],
                    orElse: () => RadicalPosition.free),
                size: 26,
                color: c ?? Washi.inkSoft),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(q.options[i],
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Washi.ink)),
          ),
          if (c != null)
            Icon(i == q.answer ? Icons.check_circle_rounded : Icons.cancel_rounded, color: c),
        ]),
      ),
    );
  }

  Widget _feedback(RadicalQuestion q, bool correct) {
    final r = q.radical;
    return Container(
      key: const ValueKey('radical-feedback'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: (correct ? Washi.matcha : Washi.shu).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: (correct ? Washi.matcha : Washi.shu).withValues(alpha: 0.35)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _glyph(r.form, 54),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(correct ? '정답이에요!' : '다시 기억해요 — 조금 뒤에 또 나와요',
                style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: correct ? Washi.matcha : Washi.shu)),
            const SizedBox(height: 2),
            Text('${r.title} · ${r.japaneseName}',
                style: const TextStyle(fontWeight: FontWeight.w800, color: Washi.ink)),
            Text('${r.position.label} · ${r.meaning}',
                style: const TextStyle(fontSize: 12.5, color: Washi.inkSoft)),
            const SizedBox(height: 4),
            Text(r.story, style: const TextStyle(fontSize: 13.5, height: 1.45, color: Washi.ink)),
          ]),
        ),
      ]),
    );
  }

  Widget _result() {
    final total = _first.length;
    final right = _first.values.where((v) => v).length;
    final wrong = [
      for (final e in _first.entries)
        if (!e.value) widget.course.byForm(e.key)
    ].whereType<Radical>().toList();
    return ListView(
      key: const ValueKey('radical-result'),
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 28),
      children: [
        Center(
          child: ProgressRing(
            ratio: total == 0 ? 0 : right / total,
            color: radicalColor,
            size: 120,
            stroke: 10,
            child: Text('$right/$total',
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
          ),
        ),
        const SizedBox(height: 14),
        Text(
            wrong.isEmpty ? '한 번에 다 맞혔어요! 👏' : '틀렸던 부수도 끝까지 맞혔어요. 복습 때 다시 나와요.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        const Text('맞힌 부수는 다음 복습이 점점 멀어지고(1일 → 3일 → 7일…),\n틀린 부수는 10분 뒤 다시 복습해요.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, height: 1.5, color: Washi.inkSoft)),
        if (wrong.isNotEmpty) ...[
          const SizedBox(height: 18),
          const SectionTitle('다시 볼 부수'),
          const SizedBox(height: 8),
          for (final r in wrong)
            PaperCard(
              padding: const EdgeInsets.all(10),
              onTap: () => showRadicalSheet(context, r, widget.bank, widget.speakJapanese),
              child: Row(children: [
                _glyph(r.form, 44),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('${r.title}\n${r.meaning}',
                      style: const TextStyle(fontSize: 13.5, height: 1.4)),
                ),
                const Icon(Icons.chevron_right_rounded),
              ]),
            ),
        ],
        const SizedBox(height: 20),
        FilledButton(
          key: const ValueKey('radical-quiz-done'),
          style: FilledButton.styleFrom(
              backgroundColor: radicalColor, minimumSize: const Size.fromHeight(50)),
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Text('마치기'),
        ),
      ],
    );
  }
}

/// 부수 카드를 아래에서 올라오는 시트로 보여 준다.
Future<void> showRadicalSheet(
    BuildContext context, Radical r, KanjiPartsBank bank, RadicalSpeak? speak) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Washi.paper,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.85,
      child: RadicalCard(radical: r, bank: bank, speakJapanese: speak),
    ),
  );
}

// ───────────────────────────── 전체표 ─────────────────────────────

/// 2026-10-11 부수 전체표: 외운 정도를 색으로 보여 준다.
class RadicalTablePage extends StatelessWidget {
  const RadicalTablePage(
      {super.key, required this.course, required this.bank, required this.progress, this.speakJapanese});
  final RadicalCourse course;
  final KanjiPartsBank bank;
  final RadicalProgress progress;
  final RadicalSpeak? speakJapanese;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Washi.paper,
        appBar: washiAppBar(
            title: '부수 전체표',
            subtitle: '외움 ${progress.masteredCount(course.radicals)} / ${course.radicals.length}'),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
          children: [
            Row(children: [
              _legend(Washi.card, '안 배움'),
              _legend(radicalColor.withValues(alpha: 0.15), '배우는 중'),
              _legend(radicalColor.withValues(alpha: 0.45), '외움'),
            ]),
            const SizedBox(height: 10),
            for (final l in course.lessons) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(2, 10, 0, 6),
                child: Text('${l.label} · ${l.title}',
                    style: const TextStyle(fontWeight: FontWeight.w800, color: Washi.inkSoft)),
              ),
              LayoutBuilder(builder: (context, c) {
                final w = (c.maxWidth - 8 * 3) / 4;
                return Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final r in l.radicals) SizedBox(width: w, child: _tile(context, r)),
                ]);
              }),
            ],
          ],
        ),
      );

  Widget _legend(Color c, String t) => Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Row(children: [
          Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                  color: c,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Washi.line))),
          const SizedBox(width: 4),
          Text(t, style: const TextStyle(fontSize: 12, color: Washi.inkSoft)),
        ]),
      );

  Widget _tile(BuildContext context, Radical r) {
    final s = progress.stage(r.form);
    final bg = s == 0
        ? Washi.card
        : s >= RadicalProgress.masteredStage
            ? radicalColor.withValues(alpha: 0.45)
            : radicalColor.withValues(alpha: 0.15);
    final p = bank[r.form];
    return InkWell(
      key: ValueKey('radical-tile-${r.form}'),
      borderRadius: BorderRadius.circular(12),
      onTap: () => showRadicalSheet(context, r, bank, speakJapanese),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Washi.line)),
        child: Column(children: [
          p == null
              ? Text(r.form, style: const TextStyle(fontSize: 30))
              : KanjiGlyph(parts: p, size: 44, colored: false),
          Text(r.korean.split('/').first.trim(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}

// ───────────────────────────── 헷갈리는 부수 ─────────────────────────────

class RadicalPairsPage extends StatelessWidget {
  const RadicalPairsPage({super.key, required this.course, required this.bank});
  final RadicalCourse course;
  final KanjiPartsBank bank;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Washi.paper,
        appBar: washiAppBar(title: '헷갈리는 부수', subtitle: '닮은 짝을 나란히 비교해요'),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
          children: [
            for (final (a, b, tip) in radicalPairs)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: PaperCard(
                  key: ValueKey('radical-pair-$a$b'),
                  padding: const EdgeInsets.all(12),
                  child: Column(children: [
                    Row(children: [
                      Expanded(child: _side(a)),
                      const Text('vs',
                          style: TextStyle(color: Washi.inkSoft, fontWeight: FontWeight.w800)),
                      Expanded(child: _side(b)),
                    ]),
                    const SizedBox(height: 8),
                    Text(tip, style: const TextStyle(fontSize: 13.5, height: 1.5, color: Washi.ink)),
                  ]),
                ),
              ),
          ],
        ),
      );

  Widget _side(String form) {
    final r = course.byForm(form);
    final p = bank[form];
    return Column(children: [
      p == null
          ? Text(form, style: const TextStyle(fontSize: 48))
          : KanjiGlyph(parts: p, size: 72, colored: false),
      Text(r?.title ?? form,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
      if (r != null && r.examples.isNotEmpty)
        Text(r.examples.take(3).map((e) => e.kanji).join(' '),
            style: const TextStyle(fontSize: 16, color: radicalColor)),
    ]);
  }
}
