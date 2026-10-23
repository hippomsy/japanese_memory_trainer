import 'package:kioku_japanese/widgets/chapter_art.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kioku_japanese/models/vocabulary.dart';
import 'package:kioku_japanese/pages/listening_page.dart';
import 'package:kioku_japanese/pages/word_match_game.dart';
import 'package:kioku_japanese/services/lesson_audio.dart';
import 'package:kioku_japanese/widgets/study_widgets.dart';

class ThemeListeningPage extends StatefulWidget {
  const ThemeListeningPage(
      {super.key, required this.speak, required this.stop, this.audioFactory});
  final ListeningVoice speak;
  final Future<void> Function() stop;

  /// 2026-10-05 원어민 녹음 재생기 생성 함수(테스트에서 교체).
  final LessonAudio Function()? audioFactory;
  @override
  State<ThemeListeningPage> createState() => _ThemeListeningPageState();
}

class _ThemeListeningPageState extends State<ThemeListeningPage> {
  late final _lessons = rootBundle
      .loadString('assets/data/basicjl_lessons.json')
      .then((raw) => (jsonDecode(raw) as List).cast<Map<String, dynamic>>());
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: washiAppBar(title: '테마별 기초 청취', subtitle: '주제별 단어 · 원어민 대화 듣기'),
        body: FutureBuilder<List<Map<String, dynamic>>>(
            future: _lessons,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(child: Text('강의노트를 불러오지 못했어요.'));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final lessons = snapshot.data!;
              final categories =
                  lessons.map((l) => l['category'] as String).toSet();
              return ListView(padding: const EdgeInsets.all(20), children: [
                const SceneArt('cafe', height: 150),
                const SizedBox(height: 12),
                for (final category in categories)
                  Card(
                      child: ExpansionTile(title: Text(category), children: [
                    for (final lesson
                        in lessons.where((l) => l['category'] == category))
                      ListTile(
                        leading: ChapterArt('listening', int.tryParse('${lesson['number']}') ?? 1, width: 80, height: 56),
                        title:
                            Text('${lesson['number']}강 · ${lesson['title']}'),
                        subtitle: Text(
                            '단어 ${(lesson['words'] as List).length}개 · 원어민 녹음'),
                        trailing: const Icon(Icons.headphones),
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                                builder: (_) => ThemeListeningLessonPage(
                                    lesson: lesson,
                                    speak: widget.speak,
                                    stop: widget.stop,
                                    audioFactory: widget.audioFactory))),
                      ),
                  ])),
              ]);
            }),
      );
}

class ThemeListeningLessonPage extends StatefulWidget {
  const ThemeListeningLessonPage(
      {super.key,
      required this.lesson,
      required this.speak,
      required this.stop,
      this.audioFactory});
  final Map<String, dynamic> lesson;
  final ListeningVoice speak;
  final Future<void> Function() stop;
  final LessonAudio Function()? audioFactory;
  @override
  State<ThemeListeningLessonPage> createState() =>
      _ThemeListeningLessonPageState();
}

/// 2026-10-05 전체 대화는 압축파일의 원어민 녹음(Track N → N강)으로,
/// 단어·문장 단위 듣기는 기존 일본어 TTS로 재생한다.
class _ThemeListeningLessonPageState extends State<ThemeListeningLessonPage> {
  bool _speaking = false, _translation = true;
  double _rate = .45;
  int _generation = 0;
  String? _error;

  late final LessonAudio _audio =
      (widget.audioFactory ?? JustLessonAudio.new)();
  final _subs = <StreamSubscription<Object?>>[];
  bool _audioReady = false, _audioPlaying = false, _loop = false;
  Duration _position = Duration.zero, _duration = Duration.zero;

  double get _audioSpeed => _rate == .45 ? 1.0 : .75;

  @override
  void initState() {
    super.initState();
    _subs.add(_audio.playingStream.listen((v) {
      if (mounted) setState(() => _audioPlaying = v);
    }));
    _subs.add(_audio.positionStream.listen((v) {
      if (mounted) setState(() => _position = v);
    }));
    _subs.add(_audio.durationStream.listen((v) {
      if (mounted && v != null) setState(() => _duration = v);
    }));
    _subs.add(_audio.completedStream.listen((done) {
      if (done && !_loop) {
        _audio.pause();
        _audio.seek(Duration.zero);
      }
    }));
    _loadAudio();
  }

  Future<void> _loadAudio() async {
    try {
      await _audio.load(lessonAudioAsset(widget.lesson['number'] as int));
      if (mounted) setState(() => _audioReady = true);
    } catch (_) {
      if (mounted) setState(() => _error = '녹음 파일을 불러오지 못했어요.');
    }
  }

  Future<void> _toggleRecording() async {
    if (!_audioReady) return;
    if (_audioPlaying) {
      await _audio.pause();
      return;
    }
    await _stopSpeech();
    await _audio.setSpeed(_audioSpeed);
    await _audio.play();
  }

  Future<void> _seekBy(int seconds) async {
    var target = _position + Duration(seconds: seconds);
    if (target < Duration.zero) target = Duration.zero;
    if (_duration > Duration.zero && target > _duration) target = _duration;
    await _audio.seek(target);
  }

  Future<void> _setRate(double rate) async {
    setState(() => _rate = rate);
    if (_audioReady) await _audio.setSpeed(_audioSpeed);
  }

  Future<void> _stopSpeech() async {
    _generation++;
    await widget.stop();
    if (mounted) setState(() => _speaking = false);
  }

  Future<void> _speak(List<String> texts) async {
    if (_speaking) return;
    if (_audioPlaying) await _audio.pause();
    final generation = ++_generation;
    setState(() {
      _speaking = true;
      _error = null;
    });
    try {
      for (final text in texts) {
        if (!mounted || generation != _generation) return;
        await widget.speak(text, _rate);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = '音声を再生できませんでした。 일본어 음성 설정을 확인해 주세요.');
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _speaking = false);
      }
    }
  }

  @override
  void dispose() {
    _generation++;
    for (final s in _subs) {
      s.cancel();
    }
    _audio.dispose();
    widget.stop();
    super.dispose();
  }

  String _fmt(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  Widget _recordingCard() {
    final max = _duration.inMilliseconds.toDouble();
    final value = _position.inMilliseconds.clamp(0, max <= 0 ? 0 : max).toDouble();
    return Card(
        child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(children: [
              const Row(children: [
                Icon(Icons.headphones),
                SizedBox(width: 8),
                Text('원어민 녹음',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ]),
              Slider(
                  value: value,
                  max: max <= 0 ? 1 : max,
                  onChanged: max <= 0
                      ? null
                      : (v) =>
                          _audio.seek(Duration(milliseconds: v.round()))),
              Row(children: [
                Text(_fmt(_position)),
                const Spacer(),
                Text(_fmt(_duration)),
              ]),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                IconButton(
                    tooltip: '5초 뒤로',
                    onPressed: _audioReady ? () => _seekBy(-5) : null,
                    icon: const Icon(Icons.replay_5)),
                const SizedBox(width: 8),
                FilledButton.icon(
                    key: const ValueKey('theme-play-all'),
                    onPressed: _audioReady ? _toggleRecording : null,
                    icon: Icon(_audioPlaying ? Icons.pause : Icons.play_arrow),
                    label: Text(_audioPlaying ? '일시정지' : '전체 대화 듣기')),
                const SizedBox(width: 8),
                IconButton(
                    tooltip: '5초 앞으로',
                    onPressed: _audioReady ? () => _seekBy(5) : null,
                    icon: const Icon(Icons.forward_5)),
                IconButton(
                    tooltip: '반복 재생',
                    isSelected: _loop,
                    onPressed: _audioReady
                        ? () async {
                            setState(() => _loop = !_loop);
                            await _audio.setLoop(_loop);
                          }
                        : null,
                    icon: const Icon(Icons.repeat),
                    selectedIcon: const Icon(Icons.repeat_one)),
              ]),
            ])));
  }

  @override
  Widget build(BuildContext context) {
    final words = (widget.lesson['words'] as List).cast<Map<String, dynamic>>();
    final script = (widget.lesson['script'] as List).cast<String>();
    return Scaffold(
      appBar: washiAppBar(
          title: '${widget.lesson['number']}강 · ${widget.lesson['title']}'),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        ChapterArt('listening', int.tryParse('${widget.lesson['number']}') ?? 1, height: 166),
        const SizedBox(height: 12),
        const Text('전체 대화는 원어민 녹음, 단어·문장은 일본어 음성으로 들려줘요.',
            style: TextStyle(color: Washi.inkSoft)),
        Wrap(spacing: 8, children: [
          ChoiceChip(
              label: const Text('보통'),
              selected: _rate == .45,
              onSelected: _speaking ? null : (_) => _setRate(.45)),
          ChoiceChip(
              label: const Text('천천히'),
              selected: _rate == .32,
              onSelected: _speaking ? null : (_) => _setRate(.32)),
          TextButton(onPressed: () => _source(0), child: const Text('단어 원문')),
          TextButton(onPressed: () => _source(2), child: const Text('스크립트 원문')),
        ]),
        const SizedBox(height: 12),
        _recordingCard(),
        if (_error != null)
          Text(_error!, style: const TextStyle(color: Colors.red)),
        const SizedBox(height: 12),
        const Text('오늘의 단어',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        // 2026-10-18 이 강의 단어로 일본어·한국어 카드 짝맞추기 게임을 시작하는 버튼.
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: FilledButton.tonalIcon(
                key: const ValueKey('theme-word-game'),
                onPressed: words.length >= 2 ? () => _openWordGame(words) : null,
                icon: const Icon(Icons.extension_rounded),
                label: const Text('단어 게임 (카드 짝맞추기)'))),
        for (final word in words)
          Card(
              child: ListTile(
            title: Text('${word['japanese']}  ${word['reading']}'),
            subtitle: Text(word['korean'] as String),
            trailing: IconButton(
                tooltip: '단어 발음 듣기',
                onPressed:
                    _speaking ? null : () => _speak([word['reading'] as String]),
                icon: const Icon(Icons.volume_up)),
          )),
        const SizedBox(height: 24),
        const Text('전체 스크립트',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        if (_speaking)
          TextButton.icon(
              onPressed: _stopSpeech,
              icon: const Icon(Icons.stop),
              label: const Text('문장 듣기 멈추기')),
        for (final line in script)
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    Expanded(
                        child: Text(line,
                            style: const TextStyle(fontSize: 20, height: 1.7))),
                    IconButton(
                        tooltip: '문장 듣기',
                        onPressed: _speaking ? null : () => _speak([line]),
                        icon: const Icon(Icons.volume_up)),
                  ]))),
        SwitchListTile(
            title: const Text('한국어 해석 보기'),
            value: _translation,
            onChanged: (v) => setState(() => _translation = v)),
        if (_translation)
          Text(widget.lesson['koreanScript'] as String,
              style: const TextStyle(fontSize: 17, height: 1.8)),
      ]),
    );
  }

  /// 2026-10-18 강의 단어를 Vocabulary로 변환해 짝맞추기 게임 화면을 연다.
  /// 일본어 카드는 읽는 법으로 발음하고, 게임 중에는 녹음·문장 재생을 멈춘다.
  Future<void> _openWordGame(List<Map<String, dynamic>> words) async {
    await _stopSpeech();
    if (_audioPlaying) await _audio.pause();
    if (!mounted) return;
    final number = widget.lesson['number'];
    final vocab = [
      for (var i = 0; i < words.length; i++)
        Vocabulary(
            id: 'theme-$number-$i',
            japanese: words[i]['japanese'] as String,
            reading: words[i]['reading'] as String,
            korean: words[i]['korean'] as String,
            exampleJapanese: '',
            exampleKorean: '',
            jlptLevel: '',
            wordType: '',
            frequencyRank: i),
    ];
    await Navigator.push(
        context,
        MaterialPageRoute<void>(
            builder: (_) => Scaffold(
                appBar: washiAppBar(
                    title: '$number강 · 단어 게임',
                    subtitle: '같은 뜻의 일본어·한국어 카드를 맞춰요'),
                body: SafeArea(
                    child: WordMatchGame(
                        key: const ValueKey('theme-word-match'),
                        words: vocab,
                        speakJapanese: (t) => widget.speak(t, _rate))))));
    await widget.stop();
  }

  void _source(int page) {
    showDialog<void>(
        context: context,
        builder: (context) => Dialog(
                child: Column(children: [
              Row(children: [
                const Expanded(
                    child: Padding(
                        padding: EdgeInsets.all(12), child: Text('강의노트 원문'))),
                IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close))
              ]),
              Expanded(
                  child: InteractiveViewer(
                      maxScale: 6,
                      child: Image.asset(
                          'assets/basicjl/${(widget.lesson['number'] as int).toString().padLeft(2, '0')}_$page.png'))),
            ])));
  }
}
