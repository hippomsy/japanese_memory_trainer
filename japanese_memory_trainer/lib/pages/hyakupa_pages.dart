import 'dart:math';

import 'package:flutter/material.dart';
import 'package:kioku_japanese/services/hyakupa_course.dart';
import 'package:kioku_japanese/services/lesson_audio.dart';
import 'package:kioku_japanese/widgets/study_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 2026-10-11 백퍼 일본어 회화 메뉴 색(柿色).
const Color hyakupaColor = Color(0xFFD9692B);
const Color _hSoft = Color(0xFFFBEDE3);

/// 원어민 음성 구간 재생기. 도중에 다른 재생이 오면 기다리던 쪽은 false.
class HyakupaPlayer {
  HyakupaPlayer(this.audio);
  final LessonAudio audio;
  double speed = 1.0;
  int _gen = 0;

  Future<bool> clip(String asset, double start, double end, {bool wait = false}) async {
    final g = ++_gen;
    try {
      await audio.setSpeed(speed);
      await audio.playClip(asset, Duration(milliseconds: (max(0, start - 0.08) * 1000).round()),
          Duration(milliseconds: ((end + 0.15) * 1000).round()));
    } catch (_) {
      return false;
    }
    if (!wait) return g == _gen;
    await Future<void>.delayed(
        Duration(milliseconds: ((end - start + 0.25) * 1000 / speed).round()));
    return g == _gen;
  }

  Future<bool> pauseFor(Duration d) async {
    final g = _gen;
    await Future<void>.delayed(d);
    return g == _gen;
  }

  Future<void> stop() async {
    _gen++;
    try {
      await audio.pause();
    } catch (_) {}
  }

  Future<void> dispose() async {
    _gen++;
    await audio.dispose();
  }
}

// ───────────────────────────── 첫 화면 ─────────────────────────────

/// 2026-10-11 「백퍼 일본어 회화」 첫 화면.
class HyakupaHomePage extends StatefulWidget {
  const HyakupaHomePage(
      {super.key, this.audioFactory, this.book, this.preferences, this.clock});
  final LessonAudio Function()? audioFactory;
  final HyakupaBook? book;
  final Future<SharedPreferences>? preferences;
  final DateTime Function()? clock;

  @override
  State<HyakupaHomePage> createState() => _HyakupaHomePageState();
}

class _HyakupaHomePageState extends State<HyakupaHomePage> {
  HyakupaBook? _book;
  HyakupaProgress? _progress;
  String? _error;
  final _search = TextEditingController();
  String _query = '';

  DateTime get _now => (widget.clock ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    () async {
      try {
        final b = widget.book ?? await HyakupaBook.load();
        final prefs = await (widget.preferences ?? SharedPreferences.getInstance());
        if (mounted) {
          setState(() {
            _book = b;
            _progress = HyakupaProgress(prefs);
          });
        }
      } catch (e) {
        if (mounted) setState(() => _error = '$e');
      }
    }();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _push(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
    if (mounted) setState(() {});
  }

  void _openTracks(List<HyakupaTrack> tracks, int index, String title) => _push(HyakupaTrackPage(
      tracks: tracks,
      initialIndex: index,
      title: title,
      progress: _progress!,
      audioFactory: widget.audioFactory,
      clock: widget.clock));

  void _openUnit(HyakupaUnit u) => _push(HyakupaUnitPage(
      unit: u, book: _book!, progress: _progress!, audioFactory: widget.audioFactory, clock: widget.clock));

  void _quiz(String title, List<HyakupaTrack> targets) => _push(HyakupaQuizPage(
      title: title,
      targets: targets,
      book: _book!,
      progress: _progress!,
      audioFactory: widget.audioFactory,
      clock: widget.clock));

  void _today() {
    final b = _book!, p = _progress!;
    final due = p.due(b.tracks, _now);
    if (due.isNotEmpty) {
      _quiz('오늘의 복습', due.take(20).toList());
      return;
    }
    final next = p.nextNew(b);
    if (next != null) {
      final i = b.tracks.indexOf(next);
      final list = b.tracks.sublist(i, min(i + 5, b.tracks.length));
      _openTracks(list, 0, '오늘의 새 표현 ${list.length}개');
      return;
    }
    _quiz('전체 다시 보기', ([...b.tracks]..shuffle()).take(20).toList());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Washi.paper,
        appBar: washiAppBar(title: '백퍼 일본어 회화', subtitle: '애니·드라마 속 진짜 회화체 456'),
        body: _error != null
            ? Center(child: Text('자료를 읽지 못했어요.\n$_error', textAlign: TextAlign.center))
            : _book == null
                ? const Center(child: CircularProgressIndicator())
                : _body(_book!, _progress!),
      );

  Widget _body(HyakupaBook b, HyakupaProgress p) {
    final total = b.tracks.length;
    final learned = p.learnedCount(b.tracks);
    final mastered = p.masteredCount(b.tracks);
    final due = p.due(b.tracks, _now).length;
    final favs = p.favorites;
    final results = b.search(_query);
    return ListView(
      key: const ValueKey('hyakupa-home'),
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 32),
      children: [
        HeroBanner(
          colors: const [Color(0xFFE07A35), Color(0xFF9C3F1C)],
          icon: Icons.record_voice_over_rounded,
          eyebrow: '100% 会話体 · NATIVE AUDIO',
          title: '듣고, 따라 하고,\n진짜 회화체로',
          subtitle: '배운 표현 $learned / $total  ·  외운 표현 $mastered\n'
              '${due > 0 ? '지금 복습할 표현 $due개' : '복습할 표현이 없어요'}',
          progress: total == 0 ? 0 : learned / total,
          action: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const ValueKey('hyakupa-today'),
              style: FilledButton.styleFrom(
                  backgroundColor: Colors.white, foregroundColor: hyakupaColor),
              onPressed: _today,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(due > 0 ? '오늘의 학습 · 복습 $due개' : '오늘의 학습 · 새 표현 5개'),
            ),
          ),
        ),
        const SizedBox(height: 12),
        PaperCard(
          color: _hSoft,
          borderColor: hyakupaColor.withValues(alpha: 0.2),
          padding: const EdgeInsets.all(14),
          child: const Text(
            '① 표현 듣기 → ② 대화 듣기(문장 누르면 그 문장만) → ③ 따라 말하기(쉐도잉)\n'
            '→ ④ 일본어 가리고 듣기 → ⑤ 퀴즈 · 간격 복습(10분 → 1일 → 3일 → 7일 …)',
            style: TextStyle(fontSize: 13, height: 1.6, color: Washi.ink),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('hyakupa-search'),
          controller: _search,
          onChanged: (v) => setState(() => _query = v),
          decoration: InputDecoration(
            hintText: '표현 · 뜻 · 대사 · 번호로 찾기 (예: ノリ, 짜증, 101)',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => setState(() {
                          _search.clear();
                          _query = '';
                        })),
            filled: true,
            fillColor: Washi.card,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Washi.line)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Washi.line)),
          ),
        ),
        if (_query.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('검색 결과 ${results.length}개',
              style: const TextStyle(color: Washi.inkSoft, fontSize: 12.5)),
          const SizedBox(height: 6),
          for (var i = 0; i < min(results.length, 60); i++)
            HyakupaTrackTile(
                track: results[i],
                progress: p,
                onTap: () => _openTracks(results, i, '검색: $_query')),
        ] else ...[
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: _tool(const ValueKey('hyakupa-favorites'), Icons.star_rounded,
                  '즐겨찾기 ${favs.length}', favs.isEmpty
                      ? null
                      : () {
                          final list = b.tracks.where((t) => favs.contains(t.number)).toList();
                          _openTracks(list, 0, '즐겨찾기');
                        }),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _tool(const ValueKey('hyakupa-random-quiz'), Icons.quiz_rounded, '배운 것 퀴즈',
                  learned == 0
                      ? null
                      : () => _quiz('배운 표현 퀴즈',
                          ([...b.tracks.where((t) => !p.isNew(t.number))]..shuffle()).take(15).toList())),
            ),
          ]),
          const SizedBox(height: 20),
          SectionTitle('${b.units.length}단원', trailing: '표현 $total개'),
          const SizedBox(height: 10),
          for (final u in b.units)
            Padding(padding: const EdgeInsets.only(bottom: 10), child: _unitCard(u, p)),
        ],
      ],
    );
  }

  Widget _tool(Key key, IconData icon, String label, VoidCallback? onTap) => PaperCard(
        key: key,
        onTap: onTap,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: onTap == null ? Washi.line : hyakupaColor, size: 20),
          const SizedBox(width: 6),
          Flexible(
              child: Text(label,
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: onTap == null ? Washi.inkSoft : Washi.ink))),
        ]),
      );

  Widget _unitCard(HyakupaUnit u, HyakupaProgress p) {
    final ratio = p.unitRatio(u);
    final learned = u.tracks.where((t) => !p.isNew(t.number)).length;
    return PaperCard(
      key: ValueKey('hyakupa-unit-${u.number}'),
      onTap: () => _openUnit(u),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          HankoBadge(text: '${u.number}', color: hyakupaColor, size: 30, filled: ratio >= 1),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${u.number}단원 · ${u.range}',
                  style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
              Text(u.tracks.take(4).map((t) => t.title).join('  ·  '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, color: Washi.inkSoft)),
            ]),
          ),
          Text('$learned/${u.tracks.length}',
              style: const TextStyle(fontSize: 12.5, color: Washi.inkSoft)),
        ]),
        const SizedBox(height: 8),
        SlimProgress(ratio: ratio, color: hyakupaColor),
      ]),
    );
  }
}

/// 표현 한 줄(목록용).
class HyakupaTrackTile extends StatelessWidget {
  const HyakupaTrackTile({super.key, required this.track, required this.progress, this.onTap});
  final HyakupaTrack track;
  final HyakupaProgress progress;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = progress.stage(track.number);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: PaperCard(
        key: ValueKey('hyakupa-track-${track.number}'),
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(children: [
          Container(
            width: 42,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
                color: s == 0 ? Washi.paper : hyakupaColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8)),
            child: Text(track.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w800, color: s == 0 ? Washi.inkSoft : hyakupaColor)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(track.title,
                  style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: Washi.ink)),
              Text(track.meaning,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, color: Washi.inkSoft)),
            ]),
          ),
          if (progress.isFavorite(track.number))
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Icon(Icons.star_rounded, size: 18, color: Color(0xFFE9A23B)),
            ),
          _StageDots(stage: s),
        ]),
      ),
    );
  }
}

class _StageDots extends StatelessWidget {
  const _StageDots({required this.stage});
  final int stage;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 1; i <= HyakupaProgress.masteredStage; i++)
          Container(
            width: 5,
            height: 5,
            margin: const EdgeInsets.only(left: 2),
            decoration: BoxDecoration(
                shape: BoxShape.circle, color: i <= stage ? hyakupaColor : Washi.line),
          ),
      ]);
}

// ───────────────────────────── 단원 ─────────────────────────────

class HyakupaUnitPage extends StatefulWidget {
  const HyakupaUnitPage(
      {super.key,
      required this.unit,
      required this.book,
      required this.progress,
      this.audioFactory,
      this.clock});
  final HyakupaUnit unit;
  final HyakupaBook book;
  final HyakupaProgress progress;
  final LessonAudio Function()? audioFactory;
  final DateTime Function()? clock;

  @override
  State<HyakupaUnitPage> createState() => _HyakupaUnitPageState();
}

class _HyakupaUnitPageState extends State<HyakupaUnitPage> {
  Future<void> _push(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.unit;
    return Scaffold(
      backgroundColor: Washi.paper,
      appBar: washiAppBar(title: '${u.number}단원 · ${u.range}', subtitle: u.title),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                key: const ValueKey('hyakupa-unit-listen'),
                style: FilledButton.styleFrom(backgroundColor: hyakupaColor),
                onPressed: () => _push(HyakupaTrackPage(
                    tracks: u.tracks,
                    initialIndex: 0,
                    title: '${u.number}단원 연속 듣기',
                    progress: widget.progress,
                    audioFactory: widget.audioFactory,
                    clock: widget.clock,
                    autoPlayAll: true)),
                icon: const Icon(Icons.headphones_rounded),
                label: const Text('연속 듣기'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.tonalIcon(
                key: const ValueKey('hyakupa-unit-quiz'),
                onPressed: () => _push(HyakupaQuizPage(
                    title: '${u.number}단원 퀴즈',
                    targets: u.tracks,
                    book: widget.book,
                    progress: widget.progress,
                    audioFactory: widget.audioFactory,
                    clock: widget.clock)),
                icon: const Icon(Icons.quiz_rounded),
                label: const Text('단원 퀴즈'),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          for (var i = 0; i < u.tracks.length; i++)
            HyakupaTrackTile(
              track: u.tracks[i],
              progress: widget.progress,
              onTap: () => _push(HyakupaTrackPage(
                  tracks: u.tracks,
                  initialIndex: i,
                  title: '${u.number}단원',
                  progress: widget.progress,
                  audioFactory: widget.audioFactory,
                  clock: widget.clock)),
            ),
        ],
      ),
    );
  }
}

// ───────────────────────────── 표현 학습 ─────────────────────────────

enum _Hide { none, japanese, korean }

/// 2026-10-11 표현 한 개: 표현 듣기, 대화(문장별 재생), 쉐도잉, 가리기, 즐겨찾기, 배웠어요.
class HyakupaTrackPage extends StatefulWidget {
  const HyakupaTrackPage({
    super.key,
    required this.tracks,
    required this.initialIndex,
    required this.title,
    required this.progress,
    this.audioFactory,
    this.clock,
    this.autoPlayAll = false,
  });
  final List<HyakupaTrack> tracks;
  final int initialIndex;
  final String title;
  final HyakupaProgress progress;
  final LessonAudio Function()? audioFactory;
  final DateTime Function()? clock;

  /// 단원 연속 듣기: 대화를 끝까지 들으면 다음 표현으로 넘어간다.
  final bool autoPlayAll;

  @override
  State<HyakupaTrackPage> createState() => _HyakupaTrackPageState();
}

class _HyakupaTrackPageState extends State<HyakupaTrackPage> {
  late final HyakupaPlayer _player =
      HyakupaPlayer((widget.audioFactory ?? JustLessonAudio.new)());
  late int _index = widget.initialIndex;
  int _playing = -1; // 재생 중인 대사 번호(-2 = 표현)
  bool _shadowing = false;
  bool _running = false;
  bool _shadowPrompt = false;
  _Hide _hide = _Hide.none;
  final Set<int> _revealed = {};

  HyakupaTrack get _t => widget.tracks[_index];
  DateTime get _now => (widget.clock ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    if (widget.autoPlayAll) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _playAll());
    }
  }

  @override
  void dispose() {
    _running = false;
    _player.dispose();
    super.dispose();
  }

  Future<void> _stop() async {
    _running = false;
    await _player.stop();
    if (mounted) {
      setState(() {
        _playing = -1;
        _shadowPrompt = false;
      });
    }
  }

  Future<void> _playTitle() async {
    _running = false;
    setState(() => _playing = -2);
    final ok = await _player.clip(_t.audio, _t.titleStart, _t.titleEnd, wait: true);
    if (ok && mounted) setState(() => _playing = -1);
  }

  Future<void> _playLine(int i) async {
    _running = false;
    final l = _t.lines[i];
    setState(() => _playing = i);
    final ok = await _player.clip(_t.audio, l.start, l.end, wait: true);
    if (ok && mounted) setState(() => _playing = -1);
  }

  /// 표현 → 대사를 차례로. 쉐도잉이면 대사마다 따라 말할 시간을 준다.
  Future<void> _playAll({bool shadow = false}) async {
    await _player.stop();
    _running = true;
    setState(() => _shadowing = shadow);
    final track = _t;
    if (!await _player.clip(track.audio, track.titleStart, track.titleEnd, wait: true)) return;
    final lines = track.lines;
    for (var i = 0; i < lines.length; i++) {
      if (!_running || !mounted || _t != track) return;
      setState(() {
        _playing = i;
        _shadowPrompt = false;
      });
      if (!await _player.clip(track.audio, lines[i].start, lines[i].end, wait: true)) return;
      if (shadow) {
        if (!mounted) return;
        setState(() => _shadowPrompt = true);
        final pause = Duration(milliseconds: (lines[i].length * 1300 / _player.speed + 700).round());
        if (!await _player.pauseFor(pause)) return;
      }
    }
    if (!mounted || !_running) return;
    setState(() {
      _playing = -1;
      _shadowPrompt = false;
    });
    _running = false;
    if (widget.autoPlayAll && _index < widget.tracks.length - 1) {
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      _go(1, autoplay: true);
    }
  }

  void _go(int delta, {bool autoplay = false}) {
    final next = _index + delta;
    if (next < 0 || next >= widget.tracks.length) return;
    _player.stop();
    setState(() {
      _index = next;
      _playing = -1;
      _shadowPrompt = false;
      _revealed.clear();
    });
    if (autoplay) _playAll();
  }

  Future<void> _learned() async {
    await widget.progress.markLearned(_t.number, _now);
    if (!mounted) return;
    if (_index < widget.tracks.length - 1) {
      _go(1);
    } else {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이 목록을 다 배웠어요! 퀴즈로 확인해 보세요.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final fav = widget.progress.isFavorite(t.number);
    return Scaffold(
      backgroundColor: Washi.paper,
      appBar: washiAppBar(
        title: widget.title,
        subtitle: '${_index + 1} / ${widget.tracks.length}',
        actions: [
          IconButton(
            key: const ValueKey('hyakupa-fav'),
            tooltip: '즐겨찾기',
            onPressed: () async {
              await widget.progress.toggleFavorite(t.number);
              if (mounted) setState(() {});
            },
            icon: Icon(fav ? Icons.star_rounded : Icons.star_outline_rounded,
                color: fav ? const Color(0xFFE9A23B) : Washi.inkSoft),
          ),
        ],
      ),
      body: ListView(
        key: ValueKey('hyakupa-page-${t.number}'),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          _expressionCard(t),
          const SizedBox(height: 12),
          _controls(),
          const SizedBox(height: 10),
          for (var d = 0; d < t.dialogs.length; d++) ...[
            if (d > 0)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Row(children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('대화 2', style: TextStyle(fontSize: 12, color: Washi.inkSoft)),
                  ),
                  Expanded(child: Divider()),
                ]),
              ),
            for (final l in t.dialogs[d]) _bubble(t, t.lines.indexOf(l)),
          ],
          if (_shadowPrompt)
            Container(
              key: const ValueKey('hyakupa-shadow-prompt'),
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: hyakupaColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.mic_rounded, color: hyakupaColor),
                SizedBox(width: 6),
                Text('방금 문장을 소리 내어 따라 말해 보세요',
                    style: TextStyle(fontWeight: FontWeight.w800, color: hyakupaColor)),
              ]),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
          child: Row(children: [
            IconButton.filledTonal(
              key: const ValueKey('hyakupa-prev'),
              onPressed: _index > 0 ? () => _go(-1) : null,
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                key: const ValueKey('hyakupa-learned'),
                style: FilledButton.styleFrom(
                    backgroundColor: hyakupaColor, minimumSize: const Size.fromHeight(48)),
                onPressed: _learned,
                icon: Icon(widget.progress.isNew(t.number)
                    ? Icons.check_rounded
                    : Icons.check_circle_rounded),
                label: Text(widget.progress.isNew(t.number) ? '배웠어요 → 다음' : '다음 표현'),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              key: const ValueKey('hyakupa-next'),
              onPressed: _index < widget.tracks.length - 1 ? () => _go(1) : null,
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _expressionCard(HyakupaTrack t) => Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFFFFF4EC), Color(0xFFFBE3D3)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: hyakupaColor.withValues(alpha: 0.25)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                  color: hyakupaColor, borderRadius: BorderRadius.circular(8)),
              child: Text(t.label,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
            ),
            const Spacer(),
            _StageDots(stage: widget.progress.stage(t.number)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: Text(t.title,
                  key: const ValueKey('hyakupa-title'),
                  style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: Washi.ink)),
            ),
            IconButton.filled(
              key: const ValueKey('hyakupa-play-title'),
              style: IconButton.styleFrom(backgroundColor: hyakupaColor),
              tooltip: '표현 듣기',
              onPressed: _playTitle,
              icon: Icon(_playing == -2 ? Icons.graphic_eq_rounded : Icons.volume_up_rounded),
            ),
          ]),
          const SizedBox(height: 4),
          Text(t.meaning,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: hyakupaColor)),
          if (t.note.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(t.note, style: const TextStyle(fontSize: 13.5, height: 1.5, color: Washi.ink)),
          ],
        ]),
      );

  Widget _controls() => Column(children: [
        Row(children: [
          Expanded(
            child: FilledButton.icon(
              key: const ValueKey('hyakupa-play-all'),
              style: FilledButton.styleFrom(backgroundColor: Washi.ink),
              onPressed: _running && !_shadowing ? _stop : () => _playAll(),
              icon: Icon(_running && !_shadowing ? Icons.stop_rounded : Icons.play_arrow_rounded),
              label: Text(_running && !_shadowing ? '멈추기' : '대화 듣기'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton.tonalIcon(
              key: const ValueKey('hyakupa-shadow'),
              onPressed: _running && _shadowing ? _stop : () => _playAll(shadow: true),
              icon: Icon(_running && _shadowing ? Icons.stop_rounded : Icons.mic_rounded),
              label: Text(_running && _shadowing ? '멈추기' : '따라 말하기'),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: SegmentedButton<_Hide>(
              key: const ValueKey('hyakupa-hide'),
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: _Hide.none, label: Text('모두')),
                ButtonSegment(value: _Hide.japanese, label: Text('일본어 가림')),
                ButtonSegment(value: _Hide.korean, label: Text('한국어 가림')),
              ],
              selected: {_hide},
              onSelectionChanged: (s) => setState(() {
                _hide = s.first;
                _revealed.clear();
              }),
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
            ),
          ),
          const SizedBox(width: 6),
          ActionChip(
            key: const ValueKey('hyakupa-speed'),
            label: Text('${_player.speed == 1.0 ? '1.0' : _player.speed}x'),
            onPressed: () => setState(() => _player.speed = _player.speed == 1.0
                ? 0.8
                : _player.speed == 0.8
                    ? 0.6
                    : 1.0),
          ),
        ]),
      ]);

  Widget _bubble(HyakupaTrack t, int i) {
    final l = t.lines[i];
    final left = l.speaker != 'B';
    final active = _playing == i;
    final revealed = _revealed.contains(i);
    final hideJa = _hide == _Hide.japanese && !revealed;
    final hideKo = _hide == _Hide.korean && !revealed;
    final color = switch (l.speaker) {
      'B' => const Color(0xFF4A7BE0),
      'C' => const Color(0xFF3FA88B),
      _ => hyakupaColor,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: left ? MainAxisAlignment.start : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (left) _avatar(l.speaker, color),
          Flexible(
            child: InkWell(
              key: ValueKey('hyakupa-line-$i'),
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                if (_hide != _Hide.none) setState(() => _revealed.add(i));
                _playLine(i);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: EdgeInsets.only(left: left ? 6 : 40, right: left ? 40 : 6),
                padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
                decoration: BoxDecoration(
                  color: active ? color.withValues(alpha: 0.14) : Washi.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: active ? color : Washi.line, width: active ? 1.6 : 1),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  hideJa
                      ? Text('・・・ (눌러서 듣고 보기)',
                          style: TextStyle(fontSize: 15, color: Washi.inkSoft.withValues(alpha: 0.6)))
                      : Text(l.japanese,
                          style: const TextStyle(fontSize: 17, height: 1.45, color: Washi.ink)),
                  const SizedBox(height: 3),
                  hideKo
                      ? Text('뜻 가림', style: TextStyle(fontSize: 12.5, color: Washi.inkSoft.withValues(alpha: 0.5)))
                      : Text(l.korean,
                          style: const TextStyle(fontSize: 13, height: 1.4, color: Washi.inkSoft)),
                ]),
              ),
            ),
          ),
          if (!left) _avatar(l.speaker, color),
        ],
      ),
    );
  }

  Widget _avatar(String sp, Color c) => Container(
        width: 28,
        height: 28,
        margin: const EdgeInsets.only(top: 4),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        child: Text(sp, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
      );
}

// ───────────────────────────── 퀴즈 ─────────────────────────────

class HyakupaQuizPage extends StatefulWidget {
  const HyakupaQuizPage({
    super.key,
    required this.title,
    required this.targets,
    required this.book,
    required this.progress,
    this.audioFactory,
    this.clock,
    this.random,
  });
  final String title;
  final List<HyakupaTrack> targets;
  final HyakupaBook book;
  final HyakupaProgress progress;
  final LessonAudio Function()? audioFactory;
  final DateTime Function()? clock;
  final Random? random;

  @override
  State<HyakupaQuizPage> createState() => _HyakupaQuizPageState();
}

class _HyakupaQuizPageState extends State<HyakupaQuizPage> {
  late final HyakupaPlayer _player =
      HyakupaPlayer((widget.audioFactory ?? JustLessonAudio.new)());
  late final HyakupaQuizBuilder _builder =
      HyakupaQuizBuilder(widget.book.tracks, random: widget.random);
  late final List<HyakupaQuestion> _queue = _builder.build(widget.targets);
  final Map<int, bool> _first = {};
  int _index = 0;
  int? _chosen;

  DateTime get _now => (widget.clock ?? DateTime.now)();
  bool get _done => _index >= _queue.length;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoListen());
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  void _autoListen() {
    if (_done) return;
    final q = _queue[_index];
    if (q.kind == HyakupaQuizKind.listen) {
      _player.clip(q.track.audio, q.track.titleStart, q.track.titleEnd);
    }
  }

  Future<void> _answer(int i) async {
    if (_chosen != null) return;
    final q = _queue[_index];
    final ok = i == q.answer;
    setState(() => _chosen = i);
    if (!_first.containsKey(q.track.number)) {
      _first[q.track.number] = ok;
      await widget.progress.record(q.track.number, ok, _now);
    }
    if (!ok) {
      final kinds = HyakupaQuizKind.values.where((k) => k != q.kind).toList();
      _queue.add(_builder.question(q.track, kinds[_queue.length % kinds.length]));
    }
    // 정답을 원어민 음성으로 들려준다(빈칸이면 그 대사, 아니면 표현).
    final l = q.line;
    if (l != null) {
      _player.clip(q.track.audio, l.start, l.end);
    } else {
      _player.clip(q.track.audio, q.track.titleStart, q.track.titleEnd);
    }
  }

  void _next() {
    _player.stop();
    setState(() {
      _index++;
      _chosen = null;
    });
    _autoListen();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Washi.paper,
        appBar: washiAppBar(
            title: widget.title,
            subtitle: _done ? '결과' : '${_index + 1} / ${_queue.length}'),
        body: _done ? _result() : _question(_queue[_index]),
      );

  Widget _question(HyakupaQuestion q) {
    final answered = _chosen != null;
    final correct = _chosen == q.answer;
    final t = q.track;
    return ListView(
      key: ValueKey('hyakupa-quiz-$_index'),
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 28),
      children: [
        SlimProgress(ratio: _index / _queue.length, color: hyakupaColor),
        const SizedBox(height: 16),
        Text(q.prompt,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 14),
        PaperCard(
          color: _hSoft,
          borderColor: hyakupaColor.withValues(alpha: 0.25),
          padding: const EdgeInsets.all(16),
          child: switch (q.kind) {
            HyakupaQuizKind.meaning => Text(t.title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
            HyakupaQuizKind.expression => Text(t.meaning,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800, color: hyakupaColor)),
            HyakupaQuizKind.listen => Center(
                child: FilledButton.icon(
                  key: const ValueKey('hyakupa-quiz-listen'),
                  style: FilledButton.styleFrom(backgroundColor: hyakupaColor),
                  onPressed: () => _player.clip(t.audio, t.titleStart, t.titleEnd),
                  icon: const Icon(Icons.volume_up_rounded),
                  label: Text(answered ? t.title : '다시 듣기'),
                ),
              ),
            HyakupaQuizKind.blank => Column(children: [
                Text(answered ? q.line!.japanese : q.blanked,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 19, height: 1.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(q.line!.korean,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13.5, color: Washi.inkSoft)),
              ]),
          },
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < q.options.length; i++)
          Padding(padding: const EdgeInsets.only(bottom: 8), child: _option(q, i)),
        if (answered) ...[
          const SizedBox(height: 6),
          Container(
            key: const ValueKey('hyakupa-feedback'),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: (correct ? Washi.matcha : Washi.shu).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: (correct ? Washi.matcha : Washi.shu).withValues(alpha: 0.35)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(correct ? '정답이에요!' : '다시 기억해요 — 조금 뒤에 또 나와요',
                  style: TextStyle(
                      fontWeight: FontWeight.w900, color: correct ? Washi.matcha : Washi.shu)),
              const SizedBox(height: 4),
              Text('${t.label}  ${t.title}  —  ${t.meaning}',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              if (t.note.isNotEmpty)
                Text(t.note, style: const TextStyle(fontSize: 13, height: 1.45)),
            ]),
          ),
          const SizedBox(height: 12),
          FilledButton(
            key: const ValueKey('hyakupa-quiz-next'),
            style: FilledButton.styleFrom(
                backgroundColor: hyakupaColor, minimumSize: const Size.fromHeight(50)),
            onPressed: _next,
            child: Text(_index + 1 >= _queue.length ? '결과 보기' : '다음 문제'),
          ),
        ],
      ],
    );
  }

  Widget _option(HyakupaQuestion q, int i) {
    Color? c;
    if (_chosen != null) {
      if (i == q.answer) {
        c = Washi.matcha;
      } else if (i == _chosen) {
        c = Washi.shu;
      }
    }
    return InkWell(
      key: ValueKey('hyakupa-option-$i'),
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
          Expanded(
            child: Text(q.options[i],
                style: TextStyle(
                    fontSize: q.optionsAreJapanese ? 18 : 15,
                    fontWeight: FontWeight.w700,
                    color: Washi.ink)),
          ),
          if (c != null)
            Icon(i == q.answer ? Icons.check_circle_rounded : Icons.cancel_rounded, color: c),
        ]),
      ),
    );
  }

  Widget _result() {
    final total = _first.length;
    final right = _first.values.where((v) => v).length;
    final wrong = [
      for (final e in _first.entries)
        if (!e.value) widget.book.byNumber(e.key)
    ].whereType<HyakupaTrack>().toList();
    return ListView(
      key: const ValueKey('hyakupa-result'),
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 28),
      children: [
        Center(
          child: ProgressRing(
            ratio: total == 0 ? 0 : right / total,
            color: hyakupaColor,
            size: 120,
            stroke: 10,
            child: Text('$right/$total',
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
          ),
        ),
        const SizedBox(height: 14),
        Text(wrong.isEmpty ? '한 번에 다 맞혔어요! 👏' : '틀린 표현도 끝까지 맞혔어요. 복습 때 다시 나와요.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        if (wrong.isNotEmpty) ...[
          const SizedBox(height: 16),
          const SectionTitle('다시 볼 표현'),
          const SizedBox(height: 8),
          for (var i = 0; i < wrong.length; i++)
            HyakupaTrackTile(
              track: wrong[i],
              progress: widget.progress,
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => HyakupaTrackPage(
                      tracks: wrong,
                      initialIndex: i,
                      title: '다시 볼 표현',
                      progress: widget.progress,
                      audioFactory: widget.audioFactory,
                      clock: widget.clock))),
            ),
        ],
        const SizedBox(height: 20),
        FilledButton(
          key: const ValueKey('hyakupa-quiz-done'),
          style: FilledButton.styleFrom(
              backgroundColor: hyakupaColor, minimumSize: const Size.fromHeight(50)),
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Text('마치기'),
        ),
      ],
    );
  }
}
