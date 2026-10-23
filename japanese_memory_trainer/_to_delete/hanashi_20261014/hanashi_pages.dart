import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kioku_japanese/services/hanashi_store.dart';
import 'package:kioku_japanese/widgets/study_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

/// 2026-10-12 「하나시 니홍고」 메뉴 색(藍).
const Color hanashiColor = Color(0xFF3A4FA0);
const Color _soft = Color(0xFFE8EBF7);
const Color _hl = Color(0xFFFFF1BD);

typedef HanashiVoice = Future<void> Function(String text, double rate);

/// YouTube 앱(없으면 브라우저)으로 해당 시간부터 연다.
Future<void> openHanashiVideo(BuildContext context, int episode, [int seconds = 0]) async {
  final url = hanashiUrl(hanashiEpisode(episode).videoId, seconds);
  var ok = false;
  try {
    ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (_) {
    ok = false;
  }
  if (!ok && context.mounted) {
    await Clipboard.setData(ClipboardData(text: url));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('영상을 열지 못해 주소를 복사했어요. 브라우저에 붙여 넣어 주세요.')));
    }
  }
}

// ───────────────────────────── 첫 화면 ─────────────────────────────

class HanashiHomePage extends StatefulWidget {
  const HanashiHomePage(
      {super.key,
      required this.speak,
      required this.stop,
      this.preferences,
      this.clock});
  final HanashiVoice speak;
  final Future<void> Function() stop;
  final SharedPreferences? preferences;
  final DateTime Function()? clock;

  @override
  State<HanashiHomePage> createState() => _HanashiHomePageState();
}

class _HanashiHomePageState extends State<HanashiHomePage> {
  HanashiStore? _store;
  int _tab = 0;

  DateTime get _now => (widget.clock ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    HanashiStore.open(widget.preferences).then((s) {
      if (mounted) setState(() => _store = s);
    });
  }

  @override
  void dispose() {
    widget.stop();
    super.dispose();
  }

  Future<void> _openEpisode(int no) async {
    await _store!.setLast(no);
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => HanashiEpisodePage(
            store: _store!, no: no, speak: widget.speak, stop: widget.stop)));
    widget.stop();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final s = _store;
    return Scaffold(
      backgroundColor: Washi.paper,
      appBar: washiAppBar(title: '하나시 니홍고', subtitle: '일본어로 듣는 따뜻한 이야기'),
      body: s == null
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
                child: Row(children: [
                  for (final (i, label) in [
                    (0, '에피소드'),
                    (1, '단어장 ${s.words.length}'),
                    (2, '복습 ${s.due(_now).length}')
                  ]) ...[
                    ChoiceChip(
                      key: ValueKey('hanashi-tab-$i'),
                      label: Text(label),
                      selected: _tab == i,
                      onSelected: (_) {
                        widget.stop();
                        setState(() => _tab = i);
                      },
                      selectedColor: Washi.ink,
                      labelStyle: TextStyle(
                          color: _tab == i ? Colors.white : Washi.inkSoft,
                          fontWeight: FontWeight.w700),
                      showCheckmark: false,
                    ),
                    const SizedBox(width: 6),
                  ]
                ]),
              ),
              Expanded(
                  child: switch (_tab) {
                1 => HanashiWordList(
                    store: s, speak: widget.speak, onChanged: () => setState(() {})),
                2 => HanashiReview(
                    store: s,
                    speak: widget.speak,
                    now: _now,
                    onChanged: () => setState(() {})),
                _ => _episodes(s),
              }),
            ]),
    );
  }

  Widget _episodes(HanashiStore s) {
    final any = s.lines.values.any((l) => l.isNotEmpty);
    return ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 28), children: [
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: hanashiColor, borderRadius: BorderRadius.circular(22)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('話 日本語',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2)),
          const SizedBox(height: 4),
          const Text('우마이 일본어 · 시즌 1 (1~13화) · 시즌 2 (14~25화)',
              style: TextStyle(color: Colors.white70, fontSize: 12.5)),
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _pill(Icons.play_circle_rounded,
                '이어서 보기 · ${s.lastEpisode.toString().padLeft(2, '0')}화',
                () => _openEpisode(s.lastEpisode)),
            _pill(Icons.style_rounded, '오늘 복습 ${s.due(_now).length}개',
                () => setState(() => _tab = 2)),
          ]),
        ]),
      ),
      if (!any) ...[
        const SizedBox(height: 14),
        PaperCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
            Text('시작하는 방법',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            SizedBox(height: 6),
            Text(
                '대본은 앱에 들어 있지 않아요. 아무 화나 열고 「대본 붙여넣기」를 눌러 '
                'YouTube 스크립트를 붙여 넣으면 이 기기에 저장돼요. 대본이 없어도 '
                '화마다 「핵심 표현」 노트와 표현 퀴즈로 바로 공부할 수 있어요.',
                style: TextStyle(fontSize: 13, color: Washi.inkSoft, height: 1.5)),
          ]),
        ),
      ],
      const SizedBox(height: 16),
      for (final season in [2, 1]) ...[
        SectionTitle(season == 2 ? '시즌 2 · 이야기로 배우는 일본어' : '시즌 1 · 일본어로 듣는 따뜻한 이야기',
            trailing: season == 2 ? '14~25화' : '1~13화'),
        const SizedBox(height: 10),
        for (final e in hanashiEpisodes.reversed.where((e) => e.season == season)) ...[
          _episodeTile(s, e),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 12),
      ],
    ]);
  }

  Widget _pill(IconData icon, String label, VoidCallback onTap) => Material(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, color: Colors.white, size: 17),
              const SizedBox(width: 5),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      );

  Widget _episodeTile(HanashiStore s, HanashiEpisode e) {
    final count = s.lines[e.no]!.length;
    final minutes = e.minutes;
    final done = s.done.contains(e.no);
    final notes = s.noteCount(e.no);
    return PaperCard(
      key: ValueKey('hanashi-ep-${e.no}'),
      onTap: () => _openEpisode(e.no),
      padding: const EdgeInsets.fromLTRB(12, 11, 8, 11),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: done ? Washi.matcha : _soft,
              borderRadius: BorderRadius.circular(12)),
          child: done
              ? const Icon(Icons.check_rounded, color: Colors.white)
              : Text(e.no.toString().padLeft(2, '0'),
                  style: const TextStyle(
                      color: hanashiColor, fontWeight: FontWeight.w900)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(e.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(
                [
                  e.ko,
                  '$minutes분',
                  count == 0 ? '대본 없음' : '$count문장',
                  if (count > 0 && notes > 0) '메모 $notes',
                ].join(' · '),
                style: const TextStyle(fontSize: 12, color: Washi.inkSoft)),
          ]),
        ),
        const Icon(Icons.chevron_right_rounded, color: Washi.inkSoft),
      ]),
    );
  }
}

// ───────────────────────────── 화 학습 ─────────────────────────────

class HanashiEpisodePage extends StatefulWidget {
  const HanashiEpisodePage(
      {super.key,
      required this.store,
      required this.no,
      required this.speak,
      required this.stop});
  final HanashiStore store;
  final int no;
  final HanashiVoice speak;
  final Future<void> Function() stop;

  @override
  State<HanashiEpisodePage> createState() => _HanashiEpisodePageState();
}

class _HanashiEpisodePageState extends State<HanashiEpisodePage> {
  static const double _normal = 0.45;
  double _rate = _normal;
  bool _shadow = false;
  bool _showNote = true;
  bool _playing = false;
  int _current = -1;
  int _gen = 0;
  bool _voiceWarned = false;
  final Map<int, GlobalKey> _keys = {};
  bool _original = true; // 연속 재생 때 시간이 있는 문장은 영상 원본 음성으로
  late final YoutubePlayerController _yt = YoutubePlayerController.fromVideoId(
      videoId: _ep.videoId,
      autoPlay: false,
      params: const YoutubePlayerParams(
          showFullscreenButton: false, strictRelatedVideos: true, playsInline: true));
  Timer? _clipTimer;

  HanashiEpisode get _ep => hanashiEpisodes[widget.no - 1];
  List<HanashiLine> get _lines => widget.store.lines[widget.no]!;

  @override
  void dispose() {
    _gen++;
    _clipTimer?.cancel();
    _yt.close();
    widget.stop();
    super.dispose();
  }

  /// 영상의 그 장면으로 가서 재생한다.
  Future<void> _seek(int seconds) async {
    _clipTimer?.cancel();
    try {
      await _yt.seekTo(seconds: seconds.toDouble(), allowSeekAhead: true);
      await _yt.playVideo();
    } catch (_) {}
  }

  /// 문장 [i]의 원본 음성 구간(다음 문장 시작까지, 최대 15초)을 재생하고 끝나면 멈춘다.
  Future<void> _clip(int i) async {
    final t = _lines[i].t;
    if (t == null) return;
    int? next;
    for (final l in _lines) {
      if (l.t != null && l.t! > t) {
        next = next == null ? l.t : min(next, l.t!);
      }
    }
    final len = next == null ? 6 : (next - t).clamp(2, 15).toInt();
    await widget.stop();
    await _seek(t);
    final done = Completer<void>();
    _clipTimer = Timer(Duration(milliseconds: len * 1000 + 400), () {
      _yt.pauseVideo().catchError((_) {});
      if (!done.isCompleted) done.complete();
    });
    await done.future.timeout(Duration(seconds: len + 3), onTimeout: () {});
  }

  /// 지금 영상 위치를 주요 문장으로 저장한다.
  Future<void> _saveScene() async {
    var sec = 0;
    try {
      sec = (await _yt.currentTime).floor();
      await _yt.pauseVideo();
    } catch (_) {}
    if (!mounted) return;
    final ja = TextEditingController();
    final ko = TextEditingController();
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: Text('${hanashiClock(sec)} 장면 저장'),
              content: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(
                      controller: ja,
                      autofocus: true,
                      maxLines: 3,
                      minLines: 1,
                      decoration: const InputDecoration(labelText: '들은 일본어 문장')),
                  TextField(
                      controller: ko,
                      maxLines: 3,
                      minLines: 1,
                      decoration: const InputDecoration(labelText: '뜻 · 메모 (선택)')),
                  const SizedBox(height: 8),
                  const Text('문장을 정확히 몰라도 괜찮아요. 들리는 대로 적고, 원본 음성을 다시 들으며 고쳐 가세요.',
                      style: TextStyle(fontSize: 12, color: Washi.inkSoft)),
                ]),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
                FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('저장')),
              ],
            ));
    if (ok != true || ja.text.trim().isEmpty) return;
    _lines.add(HanashiLine(t: sec, ja: ja.text.trim(), note: ko.text.trim()));
    _lines.sort((a, b) => (a.t ?? 1 << 30).compareTo(b.t ?? 1 << 30));
    await widget.store.saveEpisode(widget.no);
    if (mounted) {
      setState(() => _keys.clear());
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('주요 문장에 저장했어요.')));
    }
  }

  Future<bool> _say(String text, double rate) async {
    try {
      await widget.speak(text.replaceAll(RegExp(r'[「」『』]'), ' '), rate);
      return true;
    } catch (_) {
      if (!_voiceWarned && mounted) {
        _voiceWarned = true;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('일본어 음성을 재생하지 못했어요. 기기 설정 › 텍스트 음성 변환에서 일본어 음성을 설치해 주세요.')));
      }
      return false;
    }
  }

  void _focus(int i) {
    setState(() => _current = i);
    final ctx = _keys[i]?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx,
          alignment: 0.35, duration: const Duration(milliseconds: 250));
    }
  }

  Future<void> _stopPlay() async {
    _gen++;
    _clipTimer?.cancel();
    _yt.pauseVideo().catchError((_) {});
    await widget.stop();
    if (mounted) setState(() => _playing = false);
  }

  Future<void> _playOne(int i, {bool slow = false}) async {
    _gen++;
    final g = _gen;
    setState(() {
      _playing = false;
      _current = i;
    });
    await _say(_lines[i].ja, slow ? max(0.2, _rate * 0.65) : _rate);
    if (mounted && g == _gen) setState(() => _current = -1);
  }

  Future<void> _playFrom(int start) async {
    _gen++;
    final g = _gen;
    setState(() => _playing = true);
    for (var i = start; i < _lines.length; i++) {
      if (!mounted || g != _gen) return;
      _focus(i);
      if (_original && _lines[i].t != null) {
        await _clip(i);
      } else {
        final ok = await _say(_lines[i].ja, _rate);
        if (!ok) break;
      }
      if (!mounted || g != _gen) return;
      final chars = _lines[i].ja.replaceAll(RegExp(r'[、。「」！？\s]'), '').length;
      final pause = _shadow
          ? min(9000, 900 + (chars * 190 * _normal / _rate).round())
          : 350;
      await Future<void>.delayed(Duration(milliseconds: pause));
    }
    if (mounted && g == _gen) {
      setState(() {
        _playing = false;
        _current = -1;
      });
    }
  }

  Future<void> _import() async {
    await _stopPlay();
    if (!mounted) return;
    final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => HanashiImportPage(store: widget.store, no: widget.no)));
    if (changed == true && mounted) setState(() => _keys.clear());
  }

  Future<void> _editNote(int i) async {
    final c = TextEditingController(text: _lines[i].note);
    final r = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('번역 · 메모'),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(_lines[i].ja, style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 10),
                TextField(
                    controller: c,
                    autofocus: true,
                    maxLines: 4,
                    minLines: 2,
                    decoration: const InputDecoration(
                        hintText: '뜻, 들은 대로의 해석, 문법 메모', border: OutlineInputBorder())),
              ]),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
                FilledButton(
                    onPressed: () => Navigator.pop(ctx, c.text.trim()),
                    child: const Text('저장')),
              ],
            ));
    if (r == null) return;
    _lines[i].note = r;
    await widget.store.saveEpisode(widget.no);
    if (mounted) setState(() {});
  }

  Future<void> _editLine(int i) async {
    final c = TextEditingController(text: _lines[i].ja);
    final r = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('문장 고치기'),
              content: TextField(controller: c, autofocus: true, maxLines: 3),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
                FilledButton(
                    onPressed: () => Navigator.pop(ctx, c.text.trim()),
                    child: const Text('저장')),
              ],
            ));
    if (r == null || r.isEmpty) return;
    _lines[i].ja = r;
    await widget.store.saveEpisode(widget.no);
    if (mounted) setState(() {});
  }

  Future<void> _addWord(int i, [String selected = '']) async {
    final l = _lines[i];
    final w = await showHanashiWordDialog(context,
        word: selected, example: l.ja, exampleKo: l.note, ep: widget.no, t: l.t);
    if (w == null) return;
    await widget.store.addWord(w);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('단어장에 담았어요: ${w.word}')));
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final done = widget.store.done.contains(widget.no);
    return Scaffold(
      backgroundColor: Washi.paper,
      appBar: washiAppBar(
          title: 'EPISODE ${widget.no.toString().padLeft(2, '0')}',
          subtitle: '하나시 니홍고 · 시즌 ${_ep.season}',
          actions: [
            IconButton(
                tooltip: '대본 붙여넣기',
                onPressed: _import,
                icon: const Icon(Icons.content_paste_rounded)),
          ]),
      body: Column(children: [
        YoutubePlayer(controller: _yt, aspectRatio: 16 / 9),
        Container(
          color: Washi.card,
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
          child: Row(children: [
            FilledButton.icon(
                key: const ValueKey('hanashi-save-scene'),
                style: FilledButton.styleFrom(backgroundColor: hanashiColor),
                onPressed: _saveScene,
                icon: const Icon(Icons.bookmark_add_rounded),
                label: const Text('이 장면 저장')),
            const Spacer(),
            TextButton.icon(
                onPressed: () => openHanashiVideo(context, widget.no),
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: const Text('YouTube 앱')),
          ]),
        ),
        Expanded(child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 40),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(_ep.title,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, height: 1.3)),
          const SizedBox(height: 2),
          Text(
              '${_ep.ko} · 약 ${_ep.minutes}분',
              style: const TextStyle(fontSize: 12.5, color: Washi.inkSoft)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(
                onPressed: () async {
                  await widget.store.setDone(widget.no, !done);
                  if (mounted) setState(() {});
                },
                icon: Icon(done ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                    color: done ? Washi.matcha : null),
                label: Text(done ? '학습 완료' : '완료 표시')),
          ]),
          const SizedBox(height: 14),
          _phraseCard(),
          const SizedBox(height: 14),
          _steps(),
          const SizedBox(height: 14),
          SectionTitle('주요 문장', trailing: _lines.isEmpty ? null : '${_lines.length}개'),
          const SizedBox(height: 8),
          if (_lines.isEmpty) _empty() else ...[_toolbar(), const SizedBox(height: 6), ..._lineWidgets()],
        ]),
      )),
      ]),
    );
  }

  /// 제목 표현을 풀어 쓴 자체 학습 노트(예문은 직접 만든 문장).
  Widget _phraseCard() {
    final e = _ep;
    Future<void> add() async {
      if (widget.store.hasWord(e.title, e.reading)) return;
      final now = DateTime.now();
      await widget.store.addWord(HanashiWord(
          word: e.title,
          reading: e.reading,
          meaning: e.ko,
          example: e.examples.first.$1,
          exampleKo: e.examples.first.$2,
          ep: e.no,
          due: now,
          added: now));
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('단어장에 담았어요: ${e.title}')));
        setState(() {});
      }
    }

    final saved = widget.store.hasWord(e.title, e.reading);
    return PaperCard(
      key: const ValueKey('hanashi-phrase'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('핵심 표현',
              style: TextStyle(
                  fontSize: 12, color: hanashiColor, fontWeight: FontWeight.w800)),
          const Spacer(),
          TextButton.icon(
              onPressed: saved ? null : add,
              icon: Icon(saved ? Icons.check_rounded : Icons.bookmark_add_rounded, size: 18),
              label: Text(saved ? '담음' : '단어장에 담기')),
        ]),
        InkWell(
          onTap: () => _say(e.title, _rate),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(e.reading, style: const TextStyle(fontSize: 13, color: Washi.inkSoft)),
                Text(e.title,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
              ]),
            ),
            const Icon(Icons.volume_up_rounded, color: hanashiColor),
          ]),
        ),
        const SizedBox(height: 6),
        Text(e.point, style: const TextStyle(fontSize: 13.5, height: 1.5)),
        const SizedBox(height: 8),
        for (final (ja, ko) in e.examples)
          InkWell(
            onTap: () => _say(ja, _rate),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Padding(
                  padding: EdgeInsets.only(top: 3),
                  child: Icon(Icons.play_circle_outline_rounded, size: 18, color: Washi.inkSoft),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(ja, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    Text(ko, style: const TextStyle(fontSize: 12.5, color: Washi.inkSoft)),
                  ]),
                ),
              ]),
            ),
          ),
        const Text('예문은 학습용으로 따로 만든 문장이에요. 영상 속에서 이 표현이 나오는 장면을 찾아 보세요.',
            style: TextStyle(fontSize: 11.5, color: Washi.inkSoft)),
      ]),
    );
  }

  Widget _steps() {
    const steps = [
      ('자막 없이 영상 보기', '줄거리만 잡기'),
      ('중요한 장면 저장', '들은 문장 적기'),
      ('원본 듣고 따라 말하기', '섀도잉 켜고 반복'),
      ('단어 담고 복습', '복습 탭 카드'),
      ('다시 영상 보기', '귀로만 이해되는지'),
    ];
    return LayoutBuilder(builder: (context, c) {
      final w = (c.maxWidth - 8) / 2;
      return Wrap(spacing: 8, runSpacing: 8, children: [
        for (var i = 0; i < steps.length; i++)
          Container(
            width: i == steps.length - 1 ? c.maxWidth : w,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(color: _soft, borderRadius: BorderRadius.circular(12)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${i + 1}',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w900, color: hanashiColor)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(steps[i].$1,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                  Text(steps[i].$2,
                      style: const TextStyle(fontSize: 11.5, color: Washi.inkSoft)),
                ]),
              ),
            ]),
          ),
      ]);
    });
  }

  Widget _empty() => PaperCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('아직 저장한 문장이 없어요',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 6),
          const Text(
              '위 영상을 보다가 중요한 문장이 나오면 「이 장면 저장」을 눌러 들은 문장을 적어 두세요.\n'
              '저장한 문장마다 원본 음성 다시 듣기, 발음 듣기, 섀도잉, 단어 담기, 복습을 할 수 있어요.\n'
              'PC에서 복사한 YouTube 스크립트를 한꺼번에 붙여 넣어도 돼요.',
              style: TextStyle(fontSize: 13, height: 1.6, color: Washi.inkSoft)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
              key: const ValueKey('hanashi-import'),
              onPressed: _import,
              icon: const Icon(Icons.content_paste_rounded),
              label: const Text('스크립트 붙여넣기')),
        ]),
      );

  Widget _toolbar() => PaperCard(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: Column(children: [
          Row(children: [
            FilledButton.icon(
                key: const ValueKey('hanashi-playall'),
                style: FilledButton.styleFrom(backgroundColor: hanashiColor),
                onPressed: _playing ? _stopPlay : () => _playFrom(max(0, _current)),
                icon: Icon(_playing ? Icons.stop_rounded : Icons.play_arrow_rounded),
                label: Text(_playing ? '정지' : '전체 듣기')),
            const Spacer(),
            const Text('원본', style: TextStyle(fontSize: 13)),
            Switch(
                value: _original,
                activeColor: hanashiColor,
                onChanged: (v) => setState(() => _original = v)),
            const Text('섀도잉', style: TextStyle(fontSize: 13)),
            Switch(
                value: _shadow,
                activeColor: hanashiColor,
                onChanged: (v) => setState(() => _shadow = v)),
          ]),
          Row(children: [
            const Icon(Icons.speed_rounded, size: 18, color: Washi.inkSoft),
            Expanded(
              child: Slider(
                  value: _rate,
                  min: 0.2,
                  max: 0.7,
                  divisions: 10,
                  activeColor: hanashiColor,
                  label: '${(_rate / _normal).toStringAsFixed(1)}배',
                  onChanged: (v) => setState(() => _rate = v)),
            ),
            TextButton(
                onPressed: () => setState(() => _showNote = !_showNote),
                child: Text(_showNote ? '메모 가리기' : '메모 보기')),
          ]),
        ]),
      );

  List<Widget> _lineWidgets() => [
        for (var i = 0; i < _lines.length; i++) _line(i),
      ];

  Widget _line(int i) {
    final l = _lines[i];
    final key = _keys.putIfAbsent(i, () => GlobalKey());
    final on = _current == i;
    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 4),
      decoration: BoxDecoration(
          color: on ? _hl : Washi.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Washi.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          InkWell(
            onTap: l.t == null ? null : () => _seek(l.t!),
            child: Text(l.t == null ? '${i + 1}'.padLeft(2, '0') : hanashiClock(l.t!),
                style: TextStyle(
                    fontSize: 12,
                    color: l.t == null ? Washi.inkSoft : hanashiColor,
                    fontWeight: FontWeight.w700,
                    decoration: l.t == null ? null : TextDecoration.underline)),
          ),
        ]),
        const SizedBox(height: 2),
        SelectableText(
          l.ja,
          onTap: () => _playOne(i),
          style: const TextStyle(fontSize: 20, height: 1.6, fontWeight: FontWeight.w500),
          contextMenuBuilder: (ctx, state) {
            final v = state.textEditingValue;
            final sel = v.selection.isValid ? v.selection.textInside(v.text).trim() : '';
            return AdaptiveTextSelectionToolbar.buttonItems(
              anchors: state.contextMenuAnchors,
              buttonItems: [
                if (sel.isNotEmpty)
                  ContextMenuButtonItem(
                      label: '단어장에 담기',
                      onPressed: () {
                        state.hideToolbar();
                        _addWord(i, sel);
                      }),
                ...state.contextMenuButtonItems,
              ],
            );
          },
        ),
        if (l.note.isNotEmpty)
          GestureDetector(
            onTap: () => setState(() => _showNote = true),
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(_showNote ? l.note : '메모 가림 · 눌러서 보기',
                  style: TextStyle(
                      fontSize: 14,
                      color: _showNote ? Washi.ink : Washi.inkSoft,
                      height: 1.4)),
            ),
          ),
        Wrap(children: [
          if (l.t != null)
            _act(Icons.graphic_eq_rounded, '원본', () async {
              _gen++;
              setState(() => _current = i);
              await _clip(i);
            }),
          _act(Icons.play_arrow_rounded, '발음', () => _playOne(i)),
          _act(Icons.slow_motion_video_rounded, '천천히', () => _playOne(i, slow: true)),
          _act(Icons.repeat_rounded, '여기부터', () => _playFrom(i)),
          _act(Icons.edit_note_rounded, '메모', () => _editNote(i)),
          _act(Icons.bookmark_add_rounded, '단어', () => _addWord(i)),
          PopupMenuButton<int>(
            icon: const Icon(Icons.more_horiz_rounded, size: 20, color: Washi.inkSoft),
            onSelected: (v) {
              if (v == 0 && l.t != null) _seek(l.t!);
              if (v == 1) _editLine(i);
            },
            itemBuilder: (_) => [
              if (l.t != null) const PopupMenuItem(value: 0, child: Text('원본 장면 보기')),
              const PopupMenuItem(value: 1, child: Text('문장 고치기')),
            ],
          ),
        ]),
      ]),
    );
  }

  Widget _act(IconData icon, String label, VoidCallback onTap) => TextButton.icon(
        style: TextButton.styleFrom(
            foregroundColor: Washi.inkSoft,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: const Size(0, 36),
            visualDensity: VisualDensity.compact),
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontSize: 12.5)),
      );
}

// ───────────────────────────── 대본 붙여넣기 ─────────────────────────────

class HanashiImportPage extends StatefulWidget {
  const HanashiImportPage({super.key, required this.store, required this.no});
  final HanashiStore store;
  final int no;
  @override
  State<HanashiImportPage> createState() => _HanashiImportPageState();
}

class _HanashiImportPageState extends State<HanashiImportPage> {
  final _text = TextEditingController();
  bool _merge = true;
  List<HanashiLine>? _preview;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final d = await Clipboard.getData(Clipboard.kTextPlain);
    if (d?.text != null) {
      _text.text = d!.text!;
      _check();
    }
  }

  void _check() {
    final lines = parseHanashiTranscript(_text.text, merge: _merge);
    setState(() {
      if (lines.isEmpty) {
        _preview = null;
        _error = '일본어 문장을 찾지 못했어요. 일본어 스크립트를 복사했는지 확인해 주세요.';
      } else {
        _error = null;
        _preview = lines;
      }
    });
  }

  Future<void> _apply() async {
    final p = _preview;
    if (p == null) return;
    final n = await widget.store.importLines(widget.no, p);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('${widget.no}화에 $n문장을 넣었어요.')));
    Navigator.pop(context, true);
  }

  Future<void> _clear() async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              content: Text('${widget.no}화 대본과 메모를 지울까요? 단어장은 남아요.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
                FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('지우기')),
              ],
            ));
    if (ok != true) return;
    await widget.store.clearEpisode(widget.no);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final p = _preview;
    final hasOld = widget.store.lines[widget.no]!.isNotEmpty;
    final timed = p?.where((l) => l.t != null).length ?? 0;
    return Scaffold(
      backgroundColor: Washi.paper,
      appBar: washiAppBar(title: '대본 붙여넣기', subtitle: 'YouTube 스크립트 · .srt · .vtt'),
      body: ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 30), children: [
        Text(
            '${widget.no}화 「${hanashiEpisode(widget.no).title}」 영상의 일본어 스크립트를 붙여 넣으세요. '
            '시간이 붙어 있으면 문장마다 그 장면으로 바로 갈 수 있어요. 대본은 이 기기에만 저장됩니다.',
            style: const TextStyle(fontSize: 13, color: Washi.inkSoft, height: 1.5)),
        const SizedBox(height: 10),
        TextField(
          key: const ValueKey('hanashi-import-text'),
          controller: _text,
          minLines: 8,
          maxLines: 14,
          onChanged: (_) => setState(() => _preview = null),
          decoration: const InputDecoration(
              filled: true,
              fillColor: Colors.white,
              hintText: '0:24\n文章…\n0:29\n…',
              border: OutlineInputBorder()),
        ),
        const SizedBox(height: 8),
        Row(children: [
          OutlinedButton.icon(
              onPressed: _paste,
              icon: const Icon(Icons.content_paste_go_rounded),
              label: const Text('클립보드에서')),
          const SizedBox(width: 8),
          FilledButton(
              key: const ValueKey('hanashi-import-check'),
              style: FilledButton.styleFrom(backgroundColor: hanashiColor),
              onPressed: _check,
              child: const Text('미리 보기')),
        ]),
        SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _merge,
            activeColor: hanashiColor,
            title: const Text('끊긴 자막을 문장 단위로 합치기', style: TextStyle(fontSize: 13.5)),
            onChanged: (v) => setState(() {
                  _merge = v;
                  _preview = null;
                })),
        if (_error != null)
          Text(_error!, style: const TextStyle(color: Washi.shu, fontSize: 13)),
        if (p != null) ...[
          const SizedBox(height: 6),
          PaperCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${p.length}문장을 찾았어요 · 시간 표시 $timed개',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              for (final l in p.take(3))
                Text('${l.t == null ? '' : '${hanashiClock(l.t!)}  '}${l.ja}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: Washi.inkSoft)),
              if (hasOld)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text('이미 넣은 대본과 메모가 새 대본으로 바뀌어요.',
                      style: TextStyle(color: Washi.shu, fontSize: 12.5)),
                ),
              const SizedBox(height: 10),
              FilledButton(
                  key: const ValueKey('hanashi-import-apply'),
                  style: FilledButton.styleFrom(backgroundColor: hanashiColor),
                  onPressed: _apply,
                  child: const Text('적용하기')),
            ]),
          ),
        ],
        if (widget.store.lines[widget.no]!.isNotEmpty) ...[
          const SizedBox(height: 24),
          TextButton.icon(
              onPressed: _clear,
              icon: const Icon(Icons.delete_outline_rounded, color: Washi.shu),
              label: Text('${widget.no}화 대본 지우기',
                  style: const TextStyle(color: Washi.shu))),
        ],
      ]),
    );
  }
}

// ───────────────────────────── 단어 ─────────────────────────────

Future<HanashiWord?> showHanashiWordDialog(BuildContext context,
    {String word = '', String example = '', String exampleKo = '', int ep = 0, int? t}) {
  final w = TextEditingController(text: word);
  final r = TextEditingController();
  final m = TextEditingController();
  return showDialog<HanashiWord>(
      context: context,
      builder: (ctx) => AlertDialog(
            title: const Text('단어장에 담기'),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                    controller: w,
                    autofocus: word.isEmpty,
                    decoration: const InputDecoration(labelText: '단어 (사전형)')),
                TextField(
                    controller: r,
                    autofocus: word.isNotEmpty,
                    decoration: const InputDecoration(labelText: '읽기 (히라가나)')),
                TextField(controller: m, decoration: const InputDecoration(labelText: '뜻')),
                if (example.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text('예문: $example',
                      style: const TextStyle(fontSize: 12.5, color: Washi.inkSoft)),
                ],
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
              FilledButton(
                  onPressed: () {
                    if (w.text.trim().isEmpty || m.text.trim().isEmpty) return;
                    final now = DateTime.now();
                    Navigator.pop(
                        ctx,
                        HanashiWord(
                            word: w.text.trim(),
                            reading: r.text.trim(),
                            meaning: m.text.trim(),
                            example: example,
                            exampleKo: exampleKo,
                            ep: ep,
                            t: t,
                            due: now,
                            added: now));
                  },
                  child: const Text('담기')),
            ],
          ));
}

class HanashiWordList extends StatelessWidget {
  const HanashiWordList(
      {super.key, required this.store, required this.speak, required this.onChanged});
  final HanashiStore store;
  final HanashiVoice speak;
  final VoidCallback onChanged;

  Future<void> _say(String text) async {
    try {
      await speak(text, 0.45);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final items = store.words.values.toList()..sort((a, b) => b.added.compareTo(a.added));
    return Scaffold(
      backgroundColor: Washi.paper,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: hanashiColor,
        foregroundColor: Colors.white,
        onPressed: () async {
          final w = await showHanashiWordDialog(context);
          if (w != null) {
            await store.addWord(w);
            onChanged();
          }
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('직접 추가'),
      ),
      body: items.isEmpty
          ? const Center(
              child: Padding(
              padding: EdgeInsets.all(30),
              child: Text(
                  '아직 담은 단어가 없어요.\n대본 문장을 길게 눌러 단어를 고른 뒤 「단어장에 담기」를 누르거나, 문장 아래 「단어」 버튼을 눌러 보세요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Washi.inkSoft, height: 1.6)),
            ))
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 90),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final w = items[i];
                return PaperCard(
                  padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(w.word,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                        Text(
                            [if (w.reading.isNotEmpty) w.reading, w.meaning].join(' · '),
                            style: const TextStyle(fontSize: 13.5)),
                        if (w.example.isNotEmpty)
                          Text(w.example,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, color: Washi.inkSoft)),
                        const SizedBox(height: 4),
                        Row(children: [
                          for (var b = 1; b <= 5; b++)
                            Container(
                                width: 7,
                                height: 7,
                                margin: const EdgeInsets.only(right: 3),
                                decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: w.box >= b ? Washi.matcha : Washi.line)),
                          if (w.ep > 0)
                            Text('  ${w.ep.toString().padLeft(2, '0')}화',
                                style: const TextStyle(fontSize: 11.5, color: Washi.inkSoft)),
                        ]),
                      ]),
                    ),
                    IconButton(
                        onPressed: () => _say(w.reading.isNotEmpty ? w.reading : w.word),
                        icon: const Icon(Icons.volume_up_rounded, color: hanashiColor)),
                    IconButton(
                        onPressed: () async {
                          final ok = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                    content: Text('「${w.word}」를 단어장에서 뺄까요?'),
                                    actions: [
                                      TextButton(
                                          onPressed: () => Navigator.pop(ctx, false),
                                          child: const Text('취소')),
                                      FilledButton(
                                          onPressed: () => Navigator.pop(ctx, true),
                                          child: const Text('빼기')),
                                    ],
                                  ));
                          if (ok == true) {
                            await store.removeWord(w.id);
                            onChanged();
                          }
                        },
                        icon: const Icon(Icons.delete_outline_rounded, color: Washi.inkSoft)),
                  ]),
                );
              }),
    );
  }
}

// ───────────────────────────── 복습 ─────────────────────────────

class HanashiReview extends StatefulWidget {
  const HanashiReview(
      {super.key,
      required this.store,
      required this.speak,
      required this.now,
      required this.onChanged});
  final HanashiStore store;
  final HanashiVoice speak;
  final DateTime now;
  final VoidCallback onChanged;
  @override
  State<HanashiReview> createState() => _HanashiReviewState();
}

class _HanashiReviewState extends State<HanashiReview> {
  int _mode = 0; // 0 단어→뜻, 1 뜻→단어, 2 듣고 맞히기, 3 문장(메모→일본어)
  late List<HanashiWord> _queue = widget.store.due(widget.now);
  bool _flip = false;
  bool _practice = false;
  final _rnd = Random();
  (int, int)? _sent;

  Future<void> _say(String text) async {
    try {
      await widget.speak(text, 0.45);
    } catch (_) {}
  }

  List<(int, int)> get _sentPool => [
        for (final e in hanashiEpisodes)
          for (var i = 0; i < widget.store.lines[e.no]!.length; i++)
            if (widget.store.lines[e.no]![i].note.trim().isNotEmpty) (e.no, i),
      ];

  void _setMode(int m) {
    setState(() {
      _mode = m;
      _flip = false;
      _sent = null;
    });
    if (m == 2 && _queue.isNotEmpty) _say(_queue.first.reading.isNotEmpty ? _queue.first.reading : _queue.first.word);
  }

  Future<void> _grade(int g) async {
    final w = _queue.removeAt(0);
    await widget.store.grade(w, g, DateTime.now());
    if (g == 0) _queue.insert(min(_queue.length, 3), w);
    setState(() => _flip = false);
    widget.onChanged();
    if (_mode == 2 && _queue.isNotEmpty) {
      _say(_queue.first.reading.isNotEmpty ? _queue.first.reading : _queue.first.word);
    }
  }

  @override
  Widget build(BuildContext context) {
    const modes = ['단어 → 뜻', '뜻 → 단어', '듣고 맞히기', '문장 카드', '표현 퀴즈'];
    return ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 30), children: [
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (var i = 0; i < modes.length; i++)
          ChoiceChip(
              label: Text(modes[i]),
              selected: _mode == i,
              showCheckmark: false,
              selectedColor: _soft,
              onSelected: (_) => _setMode(i)),
      ]),
      const SizedBox(height: 14),
      if (_mode == 4) _phraseQuiz() else if (_mode == 3) _sentenceCard() else _wordCard(),
      const SizedBox(height: 14),
      const Text('「다시」는 몇 분 뒤, 「알아요」는 1·2·4·8·16일 간격으로 다시 나와요.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Washi.inkSoft)),
    ]);
  }

  Widget _box(List<Widget> children) => PaperCard(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 220),
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: children),
        ),
      );

  Widget _wordCard() {
    if (widget.store.words.isEmpty) {
      return _box(const [
        Text('복습할 단어가 아직 없어요', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        SizedBox(height: 6),
        Text('대본에서 단어를 담으면 잊어버릴 때쯤 다시 보여 줘요.',
            textAlign: TextAlign.center, style: TextStyle(color: Washi.inkSoft)),
      ]);
    }
    if (_queue.isEmpty) {
      return _box([
        Text(_practice ? '연습을 마쳤어요' : '오늘 복습은 끝났어요',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: 12),
        OutlinedButton(
            onPressed: () => setState(() {
                  _practice = true;
                  _queue = widget.store.words.values.toList()..shuffle(_rnd);
                }),
            child: const Text('그래도 전체 단어 연습하기')),
      ]);
    }
    final w = _queue.first;
    final sayWord = w.reading.isNotEmpty ? w.reading : w.word;
    final front = switch (_mode) {
      1 => [
          Text(w.meaning,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
        ],
      2 => [
          FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: hanashiColor),
              onPressed: () => _say(sayWord),
              icon: const Icon(Icons.volume_up_rounded),
              label: const Text('다시 듣기')),
        ],
      _ => [
          Text(w.word,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w900)),
        ],
    };
    return Column(children: [
      _box([
        Text('${_practice ? '전체 연습' : '복습'} · 남은 카드 ${_queue.length}',
            style: const TextStyle(fontSize: 12, color: Washi.inkSoft)),
        const SizedBox(height: 14),
        if (!_flip) ...[
          ...front,
          const SizedBox(height: 18),
          OutlinedButton(
              key: const ValueKey('hanashi-flip'),
              onPressed: () {
                setState(() => _flip = true);
                _say(sayWord);
              },
              child: const Text('정답 보기')),
        ] else ...[
          Text(w.word,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900)),
          if (w.reading.isNotEmpty)
            Text(w.reading, style: const TextStyle(color: Washi.inkSoft, fontSize: 15)),
          const SizedBox(height: 6),
          Text(w.meaning,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          if (w.example.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(w.example,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, color: Washi.inkSoft)),
          ],
          const SizedBox(height: 8),
          Wrap(spacing: 6, alignment: WrapAlignment.center, children: [
            TextButton.icon(
                onPressed: () => _say(sayWord),
                icon: const Icon(Icons.volume_up_rounded),
                label: const Text('단어')),
            if (w.example.isNotEmpty)
              TextButton.icon(
                  onPressed: () => _say(w.example),
                  icon: const Icon(Icons.volume_up_rounded),
                  label: const Text('예문')),
            if (w.t != null && w.ep > 0)
              TextButton.icon(
                  onPressed: () => openHanashiVideo(context, w.ep, w.t!),
                  icon: const Icon(Icons.smart_display_rounded),
                  label: const Text('원본 장면')),
          ]),
        ],
      ]),
      if (_flip) ...[
        const SizedBox(height: 10),
        Row(children: [
          for (final (g, label, color) in [
            (0, '다시', Washi.shu),
            (1, '애매해요', Washi.yamabuki),
            (2, '알아요', Washi.matcha)
          ]) ...[
            Expanded(
              child: OutlinedButton(
                  key: ValueKey('hanashi-grade-$g'),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: color,
                      minimumSize: const Size.fromHeight(48),
                      side: BorderSide(color: color.withValues(alpha: 0.5))),
                  onPressed: () => _grade(g),
                  child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800))),
            ),
            if (g < 2) const SizedBox(width: 8),
          ]
        ]),
      ],
    ]);
  }

  // 25화 제목 표현 4지선다(자체 학습 노트 기반).
  HanashiEpisode? _qEp;
  List<HanashiEpisode> _qChoices = [];
  HanashiEpisode? _qPicked;
  int _qRight = 0, _qTotal = 0;

  void _nextQuiz() {
    final pool = [...hanashiEpisodes]..shuffle(_rnd);
    _qEp = pool.first;
    _qChoices = (pool.take(4).toList()..shuffle(_rnd));
    _qPicked = null;
  }

  Widget _phraseQuiz() {
    if (_qEp == null) _nextQuiz();
    final e = _qEp!;
    return Column(children: [
      _box([
        Text('표현 퀴즈 · $_qRight / $_qTotal',
            style: const TextStyle(fontSize: 12, color: Washi.inkSoft)),
        const SizedBox(height: 12),
        Text(e.title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
        if (_qPicked != null)
          Text(e.reading, style: const TextStyle(color: Washi.inkSoft)),
        TextButton.icon(
            onPressed: () => _say(e.title),
            icon: const Icon(Icons.volume_up_rounded),
            label: const Text('듣기')),
        const SizedBox(height: 6),
        for (final c in _qChoices)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                key: ValueKey('hanashi-quiz-${c.no}'),
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                    backgroundColor: _qPicked == null
                        ? null
                        : c == e
                            ? Washi.matcha.withValues(alpha: 0.15)
                            : c == _qPicked
                                ? Washi.shu.withValues(alpha: 0.12)
                                : null),
                onPressed: _qPicked != null
                    ? null
                    : () => setState(() {
                          _qPicked = c;
                          _qTotal++;
                          if (c == e) _qRight++;
                        }),
                child: Text(c.ko, textAlign: TextAlign.center),
              ),
            ),
          ),
        if (_qPicked != null) ...[
          const SizedBox(height: 4),
          Text(e.point,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Washi.inkSoft, height: 1.5)),
          Text('${e.no}화 「${e.title}」',
              style: const TextStyle(fontSize: 12, color: hanashiColor)),
        ],
      ]),
      if (_qPicked != null) ...[
        const SizedBox(height: 10),
        FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: hanashiColor, minimumSize: const Size.fromHeight(48)),
            onPressed: () => setState(_nextQuiz),
            child: const Text('다음 문제')),
      ],
    ]);
  }

  Widget _sentenceCard() {
    final pool = _sentPool;
    if (pool.isEmpty) {
      return _box(const [
        Text('문장 카드가 아직 없어요', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        SizedBox(height: 6),
        Text('대본 문장에 「메모」로 뜻을 적으면, 그 뜻을 보고 일본어로 말해 보는 카드가 만들어져요.',
            textAlign: TextAlign.center, style: TextStyle(color: Washi.inkSoft, height: 1.5)),
      ]);
    }
    _sent ??= pool[_rnd.nextInt(pool.length)];
    final (ep, i) = _sent!;
    final l = widget.store.lines[ep]![i];
    return Column(children: [
      _box([
        Text('${ep.toString().padLeft(2, '0')}화 · 뜻을 보고 일본어로 말해 보세요',
            style: const TextStyle(fontSize: 12, color: Washi.inkSoft)),
        const SizedBox(height: 14),
        Text(l.note,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, height: 1.45)),
        const SizedBox(height: 16),
        if (!_flip)
          OutlinedButton(
              onPressed: () {
                setState(() => _flip = true);
                _say(l.ja);
              },
              child: const Text('정답 보기'))
        else ...[
          Text(l.ja,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, height: 1.6, color: hanashiColor)),
          Wrap(spacing: 6, alignment: WrapAlignment.center, children: [
            TextButton.icon(
                onPressed: () => _say(l.ja),
                icon: const Icon(Icons.volume_up_rounded),
                label: const Text('듣기')),
            if (l.t != null)
              TextButton.icon(
                  onPressed: () => openHanashiVideo(context, ep, l.t!),
                  icon: const Icon(Icons.smart_display_rounded),
                  label: const Text('원본 장면')),
          ]),
        ],
      ]),
      if (_flip) ...[
        const SizedBox(height: 10),
        FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: hanashiColor, minimumSize: const Size.fromHeight(48)),
            onPressed: () => setState(() {
                  _flip = false;
                  _sent = pool[_rnd.nextInt(pool.length)];
                }),
            child: const Text('다음 문장')),
      ],
    ]);
  }
}
