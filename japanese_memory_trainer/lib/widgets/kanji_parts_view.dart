import 'package:flutter/material.dart';
import 'package:kioku_japanese/data/kanji_dictionary.dart';
import 'package:kioku_japanese/data/kanji_parts.dart';
import 'package:kioku_japanese/widgets/study_widgets.dart';

/// 2026-10-11 부품마다 다른 색(획 묶음은 회색).
const List<Color> kanjiPartColors = [
  Color(0xFFE2553F), // 주홍
  Color(0xFF4A7BE0), // 하늘
  Color(0xFF3FA88B), // 대나무
  Color(0xFFE9A23B), // 황매화
  Color(0xFF8B6CD9), // 등나무
  Color(0xFFE56B8F), // 벚꽃
];

Color kanjiPartColor(KanjiParts p, int index) {
  if (index < 0 || index >= p.parts.length || p.parts[index].isEmpty) {
    return const Color(0xFF9AA0B4);
  }
  var n = 0;
  for (var i = 0; i < index; i++) {
    if (p.parts[i].isNotEmpty) n++;
  }
  return kanjiPartColors[n % kanjiPartColors.length];
}

/// 2026-10-11 한자 글자를 획 단위로 그린다. 부품별 색, 강조, 획순 진행률.
class KanjiGlyph extends StatelessWidget {
  const KanjiGlyph({
    super.key,
    required this.parts,
    this.size = 150,
    this.colored = true,
    this.highlight = -1,
    this.progress,
    this.showNumbers = false,
    this.highlightStrokes,
    this.highlightColor = Washi.shu,
  });

  final KanjiParts parts;
  final double size;
  final bool colored;

  /// 강조할 부품 위치(-1 = 전체).
  final int highlight;

  /// 획순 진행(0 ~ 획수). null이면 전부 그린다.
  final double? progress;
  final bool showNumbers;

  /// 2026-10-11 이 획들만 [highlightColor]로 칠하고 나머지는 옅게(부수 강조).
  final Set<int>? highlightStrokes;
  final Color highlightColor;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _GlyphPainter(parts, colored, highlight, progress, showNumbers,
              highlightStrokes, highlightColor),
        ),
      );
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.parts, this.colored, this.highlight, this.progress,
      this.showNumbers, this.highlightStrokes, this.highlightColor);
  final Set<int>? highlightStrokes;
  final Color highlightColor;
  final KanjiParts parts;
  final bool colored;
  final int highlight;
  final double? progress;
  final bool showNumbers;

  static final Map<String, Path> _cache = {};

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 109;
    // 연습장 칸(십자 점선 대신 옅은 선)
    final guide = Paint()
      ..color = const Color(0x14000000)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(size.width / 2, 4), Offset(size.width / 2, size.height - 4), guide);
    canvas.drawLine(Offset(4, size.height / 2), Offset(size.width - 4, size.height / 2), guide);
    canvas.save();
    canvas.scale(s);
    final total = parts.strokes.length;
    final shown = progress ?? total.toDouble();
    for (var i = 0; i < total; i++) {
      final path = _cache.putIfAbsent(parts.strokes[i], () => parseSvgPath(parts.strokes[i]));
      final part = i < parts.strokeParts.length ? parts.strokeParts[i] : -1;
      var color = colored ? kanjiPartColor(parts, part) : Washi.ink;
      if (highlight >= 0 && part != highlight) color = color.withValues(alpha: 0.16);
      final hs = highlightStrokes;
      if (hs != null) {
        color = hs.contains(i) ? highlightColor : Washi.ink.withValues(alpha: 0.22);
      }
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 3.6
        ..color = color;
      if (progress != null) {
        // 아직 안 쓴 획은 옅게 미리 보여 준다.
        if (i >= shown) {
          canvas.drawPath(path, Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = 3.6
            ..color = const Color(0x12000000));
          if (i >= shown.ceil()) continue;
        }
        final frac = (shown - i).clamp(0.0, 1.0);
        if (frac < 1) {
          for (final m in path.computeMetrics()) {
            canvas.drawPath(m.extractPath(0, m.length * frac), paint);
          }
          continue;
        }
      }
      canvas.drawPath(path, paint);
    }
    canvas.restore();
    if (showNumbers) {
      for (var i = 0; i < total && i < shown.floor(); i++) {
        final path = _cache[parts.strokes[i]]!;
        final metrics = path.computeMetrics().toList();
        if (metrics.isEmpty) continue;
        final t = metrics.first.getTangentForOffset(0);
        if (t == null) continue;
        final tp = TextPainter(
          text: TextSpan(
              text: '${i + 1}',
              style: TextStyle(
                  fontSize: size.width / 13,
                  fontWeight: FontWeight.w800,
                  color: Washi.inkSoft)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, t.position * s - Offset(tp.width + 2, tp.height / 2 + 2));
      }
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter old) =>
      old.parts != parts ||
      old.highlight != highlight ||
      old.progress != progress ||
      old.colored != colored ||
      old.showNumbers != showNumbers ||
      old.highlightStrokes != highlightStrokes;
}

/// 2026-10-11 한 줄 부품 식: 亻사람 + 木나무 = 休
class KanjiPartsInline extends StatelessWidget {
  const KanjiPartsInline(this.kanji, {super.key, this.fontSize = 13});
  final String kanji;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final bank = KanjiPartsBank.cached;
    if (bank != null) return _line(bank);
    return FutureBuilder<KanjiPartsBank>(
      future: KanjiPartsBank.load(),
      builder: (_, snap) =>
          snap.hasData ? _line(snap.data!) : const SizedBox.shrink(),
    );
  }

  Widget _line(KanjiPartsBank bank) {
    final p = bank[kanji];
    if (p == null || p.namedPartCount < 2) return const SizedBox.shrink();
    final spans = <InlineSpan>[];
    for (var i = 0; i < p.parts.length; i++) {
      final part = p.parts[i];
      if (part.isEmpty) continue;
      if (spans.isNotEmpty) spans.add(const TextSpan(text: ' + '));
      spans.add(TextSpan(
          text: part,
          style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: fontSize + 2,
              color: kanjiPartColor(p, i))));
      final m = bank.shortMeaning(part);
      if (m.isNotEmpty) spans.add(TextSpan(text: m));
      if (i == p.phonetic) {
        spans.add(TextSpan(
            text: '(소리)',
            style: TextStyle(fontSize: fontSize - 2, color: Washi.inkSoft)));
      }
    }
    spans.add(TextSpan(text: ' = $kanji'));
    return Text.rich(
      TextSpan(children: spans),
      key: ValueKey('kanji-parts-inline-$kanji'),
      style: TextStyle(fontSize: fontSize, color: Washi.ink),
    );
  }
}

/// 2026-10-11 단어(또는 한자)를 아래에서 올라오는 시트로 쪼개 보여 준다.
/// 한자가 여러 개면 위쪽 탭으로 한 글자씩 넘긴다.
Future<void> showKanjiPartsSheet(BuildContext context, String text,
    {Color accent = Washi.shu}) async {
  final chars = <String>[];
  for (final ch in text.split('')) {
    if (KanjiDictionary.isKanji(ch) && !chars.contains(ch)) chars.add(ch);
  }
  if (chars.isEmpty) return;
  final bank = await KanjiPartsBank.load();
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Washi.paper,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.88,
      child: DefaultTabController(
        length: chars.length,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Row(children: [
              HankoBadge(text: '分', color: accent, size: 24, filled: true),
              const SizedBox(width: 8),
              Expanded(
                child: Text('$text 쪼개 보기',
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w800, color: Washi.ink)),
              ),
            ]),
          ),
          if (chars.length > 1)
            TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: accent,
              indicatorColor: accent,
              labelStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              tabs: [for (final c in chars) Tab(text: c)],
            ),
          Expanded(
            child: TabBarView(children: [
              for (final c in chars)
                KanjiPartsSection(kanji: c, bank: bank, accent: accent),
            ]),
          ),
        ]),
      ),
    ),
  );
}

/// 2026-10-11 한 글자 쪼개기 화면: 색칠된 글자, 부품 식, 기억 이야기, 소리 가족, 획순.
class KanjiPartsSection extends StatefulWidget {
  const KanjiPartsSection(
      {super.key, required this.kanji, required this.bank, this.accent = Washi.shu});
  final String kanji;
  final KanjiPartsBank bank;
  final Color accent;

  @override
  State<KanjiPartsSection> createState() => _KanjiPartsSectionState();
}

class _KanjiPartsSectionState extends State<KanjiPartsSection>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  int _highlight = -1;

  KanjiParts? get _p => widget.bank[widget.kanji];

  @override
  void initState() {
    super.initState();
    final n = _p?.strokeCount ?? 1;
    _anim = AnimationController(
        vsync: this, duration: Duration(milliseconds: 550 * (n < 1 ? 1 : n)));
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _playStrokes() {
    setState(() => _highlight = -1);
    _anim.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    final info = KanjiDictionary.instance.lookup(widget.kanji);
    if (p == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('「${widget.kanji}」은 아직 부품 정보가 없어요.',
              style: const TextStyle(color: Washi.inkSoft)),
        ),
      );
    }
    final family = widget.bank.soundFamily(widget.kanji);
    return ListView(
      key: ValueKey('kanji-parts-${widget.kanji}'),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        // ── 큰 글자 + 훈음
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Container(
            decoration: BoxDecoration(
              color: Washi.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Washi.line),
            ),
            padding: const EdgeInsets.all(8),
            child: AnimatedBuilder(
              animation: _anim,
              builder: (_, __) => KanjiGlyph(
                parts: p,
                size: 140,
                highlight: _highlight,
                progress: _anim.isAnimating || _anim.value > 0 && _anim.value < 1
                    ? _anim.value * p.strokeCount
                    : null,
                showNumbers: _anim.isAnimating,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(info?.hunEum ?? widget.bank.nameOf(widget.kanji),
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w900, color: widget.accent)),
              const SizedBox(height: 4),
              if (info != null && info.onReadings.isNotEmpty)
                Text('음독 ${info.onReadings.join(' · ')}',
                    style: const TextStyle(fontSize: 13.5, color: Washi.ink)),
              if (info != null && info.kunReadings.isNotEmpty)
                Text('훈독 ${info.kunReadings.join(' · ')}',
                    style: const TextStyle(fontSize: 13.5, color: Washi.ink)),
              const SizedBox(height: 4),
              Text('${p.strokeCount}획 · ${_typeLabel(p)}',
                  style: const TextStyle(fontSize: 12.5, color: Washi.inkSoft)),
              const SizedBox(height: 8),
              FilledButton.tonalIcon(
                key: const ValueKey('kanji-stroke-play'),
                onPressed: _playStrokes,
                icon: const Icon(Icons.gesture_rounded, size: 18),
                label: const Text('획순 보기'),
              ),
            ]),
          ),
        ]),
        const SizedBox(height: 18),
        // ── 부품 식
        _sectionTitle(Icons.extension_rounded, '부품으로 쪼개기'),
        const SizedBox(height: 8),
        if (p.isBasic)
          _note('더 쪼개지지 않는 기본 글자예요. 이 글자가 다른 한자의 부품이 됩니다.')
        else
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 8,
            children: [
              for (var i = 0; i < p.parts.length; i++)
                if (p.parts[i].isNotEmpty) ...[
                  if (_firstNamed(p) != i)
                    const Text('+',
                        style: TextStyle(fontSize: 20, color: Washi.inkSoft)),
                  _partChip(p, i),
                ],
              const Text('=', style: TextStyle(fontSize: 20, color: Washi.inkSoft)),
              Text(widget.kanji,
                  style: const TextStyle(
                      fontSize: 28, fontWeight: FontWeight.w900, color: Washi.ink)),
            ],
          ),
        if (!p.isBasic)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text('부품을 누르면 글자에서 그 부분이 강조되고, 한 번 더 누르면 그 부품을 또 쪼개 봐요.',
                style: TextStyle(fontSize: 11.5, color: Washi.inkSoft)),
          ),
        const SizedBox(height: 18),
        // ── 기억 이야기
        _sectionTitle(Icons.lightbulb_rounded, '기억 이야기'),
        const SizedBox(height: 8),
        Container(
          key: ValueKey('kanji-story-${widget.kanji}'),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: widget.accent.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: widget.accent.withValues(alpha: 0.25)),
          ),
          child: Text(widget.bank.storyOf(widget.kanji),
              style: const TextStyle(fontSize: 15, height: 1.5, color: Washi.ink)),
        ),
        // ── 소리 가족
        if (family.isNotEmpty) ...[
          const SizedBox(height: 18),
          _sectionTitle(Icons.graphic_eq_rounded,
              '같은 소리 부품 「${p.phoneticPart}」 가족'),
          const SizedBox(height: 4),
          const Text('소리 부품이 같으면 음독이 같거나 비슷한 경우가 많아요.',
              style: TextStyle(fontSize: 11.5, color: Washi.inkSoft)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final f in family.take(12)) _familyChip(f),
          ]),
        ],
        const SizedBox(height: 20),
        const Text('획 데이터: KanjiVG (CC BY-SA 3.0)',
            style: TextStyle(fontSize: 10, color: Washi.inkSoft)),
      ],
    );
  }

  static int _firstNamed(KanjiParts p) =>
      p.parts.indexWhere((x) => x.isNotEmpty);

  String _typeLabel(KanjiParts p) {
    if (p.isBasic) return '기본 글자';
    if (p.isPhonoSemantic) return '뜻 + 소리 (형성자)';
    return '뜻 + 뜻 (회의자)';
  }

  Widget _sectionTitle(IconData icon, String text) => Row(children: [
        Icon(icon, size: 18, color: widget.accent),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800, color: Washi.ink)),
        ),
      ]);

  Widget _note(String text) => Text(text,
      style: const TextStyle(fontSize: 13.5, color: Washi.inkSoft, height: 1.4));

  Widget _partChip(KanjiParts p, int i) {
    final part = p.parts[i];
    final color = kanjiPartColor(p, i);
    final selected = _highlight == i;
    final canDrill = widget.bank.has(part) && part != widget.kanji;
    return InkWell(
      key: ValueKey('kanji-part-${widget.kanji}-$i'),
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        if (selected && canDrill) {
          showKanjiPartsSheet(context, part, accent: widget.accent);
        } else {
          _anim.value = 0;
          _anim.stop();
          setState(() => _highlight = selected ? -1 : i);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.16) : Washi.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color, width: selected ? 2 : 1.2),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(part,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(width: 6),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.bank.nameOf(part).isEmpty ? '부품' : widget.bank.nameOf(part),
                style: const TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w700, color: Washi.ink)),
            Text(
                [
                  if (i == p.phonetic) '소리 담당',
                  if (i != p.phonetic && p.isPhonoSemantic) '뜻 담당',
                  if (selected && canDrill) '한 번 더 → 쪼개기',
                ].join(' · '),
                style: const TextStyle(fontSize: 10.5, color: Washi.inkSoft)),
          ]),
        ]),
      ),
    );
  }

  Widget _familyChip(String k) {
    final info = KanjiDictionary.instance.lookup(k);
    final on = info?.onReadings.isNotEmpty == true ? info!.onReadings.first : '';
    return ActionChip(
      key: ValueKey('kanji-family-$k'),
      backgroundColor: Washi.card,
      side: const BorderSide(color: Washi.line),
      label: Text.rich(TextSpan(children: [
        TextSpan(
            text: k,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w900, color: Washi.ink)),
        if (on.isNotEmpty)
          TextSpan(
              text: ' $on',
              style: TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w700, color: widget.accent)),
        if (info != null)
          TextSpan(
              text: ' ${info.hunEum}',
              style: const TextStyle(fontSize: 11.5, color: Washi.inkSoft)),
      ])),
      onPressed: () => showKanjiPartsSheet(context, k, accent: widget.accent),
    );
  }
}
