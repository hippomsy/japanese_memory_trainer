import 'package:flutter/material.dart';
import 'package:kioku_japanese/data/listening_bank.dart';
import 'package:kioku_japanese/services/listening_store.dart';
import 'package:kioku_japanese/widgets/study_widgets.dart';
import 'package:kioku_japanese/pages/theme_listening_page.dart';

typedef ListeningVoice = Future<void> Function(String text, double rate);

/// 2026-10-15 화자별 목소리 높이까지 받는 듣기 음성.
typedef ListeningPitchVoice = Future<void> Function(String text, double rate, double pitch);

/// 대화 속 n번째로 등장한 화자의 목소리 높이(1번째 높게, 2번째 낮게).
const List<double> listeningSpeakerPitches = [1.15, 0.82, 1.0, 1.3];

class ListeningPage extends StatefulWidget {
  const ListeningPage(
      {super.key,
      required this.store,
      required this.speak,
      required this.stop,
      this.speakAs});
  final ListeningStore store;
  final ListeningVoice speak;
  final ListeningPitchVoice? speakAs;
  final Future<void> Function() stop;
  @override
  State<ListeningPage> createState() => _ListeningPageState();
}

class _ListeningPageState extends State<ListeningPage> {
  Future<void> _open(ListeningLesson lesson) async {
    await widget.store.start(lesson.id);
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => ListeningExercisePage(
            lesson: lesson,
            store: widget.store,
            speak: widget.speak,
            speakAs: widget.speakAs,
            stop: widget.stop)));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: washiAppBar(title: 'N4 청해', subtitle: '듣고 → 답하고 → 따라 읽기'),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          PaperCard(
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                    builder: (_) => ThemeListeningPage(
                        speak: widget.speak, stop: widget.stop))),
            child: const ListTile(
                leading: Icon(Icons.category_outlined),
                title: Text('테마별 기초 청취 · 25강'),
                subtitle: Text('단어 뜻·발음 · 전체 스크립트 듣기'),
                trailing: Icon(Icons.chevron_right)),
          ),
          const SizedBox(height: 16),
          Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                  color: Washi.ink, borderRadius: BorderRadius.circular(28)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.headphones_rounded,
                        color: Color(0xFFFFCC94), size: 36),
                    const SizedBox(height: 12),
                    const Text('귀로 익히는\n생활 일본어',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 12),
                    Text(
                        '${n4ListeningLessons.length}개 연습 · 정답 ${widget.store.correctCount}개 · 복습 ${widget.store.dueCount}개',
                        style: const TextStyle(color: Colors.white70)),
                    const SizedBox(height: 16),
                    FilledButton(
                        onPressed: () => _open(widget.store.nextLesson),
                        child: const Text('이어서 듣기')),
                  ])),
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Text('앱에서 만든 N4 수준 연습입니다. 공식 기출문제가 아니며 기기 일본어 음성으로 재생합니다.',
                  style: TextStyle(color: Washi.inkSoft, height: 1.6))),
          for (var i = 0; i < n4ListeningLessons.length; i++) ...[
            PaperCard(
                onTap: () => _open(n4ListeningLessons[i]),
                child: Row(children: [
                  Text((i + 1).toString().padLeft(2, '0'),
                      style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Washi.shu)),
                  const SizedBox(width: 16),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(n4ListeningLessons[i].title,
                            style: const TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(n4ListeningLessons[i].focus,
                            style: const TextStyle(color: Washi.inkSoft))
                      ])),
                  Icon(
                      widget.store.completed(n4ListeningLessons[i].id)
                          ? Icons.check_circle_rounded
                          : widget.store.due(n4ListeningLessons[i].id)
                              ? Icons.history_rounded
                              : Icons.chevron_right_rounded,
                      color: widget.store.completed(n4ListeningLessons[i].id)
                          ? Washi.matcha
                          : Washi.inkSoft),
                ])),
            const SizedBox(height: 10),
          ],
        ]),
      );
}

class ListeningExercisePage extends StatefulWidget {
  const ListeningExercisePage(
      {super.key,
      required this.lesson,
      required this.store,
      required this.speak,
      required this.stop,
      this.speakAs});
  final ListeningLesson lesson;
  final ListeningStore store;
  final ListeningVoice speak;
  final ListeningPitchVoice? speakAs;
  final Future<void> Function() stop;
  @override
  State<ListeningExercisePage> createState() => _ListeningExercisePageState();
}

class _ListeningExercisePageState extends State<ListeningExercisePage> {
  bool _playing = false, _heard = false, _transcript = false, _saving = false;
  double _rate = 0.45;
  int _playGeneration = 0;
  int? _answer;
  String? _error;
  bool _showKorean = true;

  void _showTranslation() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.7,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                const Expanded(
                    child: Text('대화 해석',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w800))),
                IconButton(
                    tooltip: '해석 닫기',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close)),
              ]),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text('어려운 문장을 확인한 뒤 닫고 다시 들어 보세요.'),
            ),
            Expanded(
                child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                for (final line in widget.lesson.lines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(line.speaker,
                              style: const TextStyle(color: Washi.inkSoft)),
                          Text(line.japanese,
                              style:
                                  const TextStyle(fontSize: 20, height: 1.7)),
                          Text(line.korean,
                              style: const TextStyle(height: 1.7)),
                        ]),
                  ),
              ],
            )),
          ]),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _playGeneration++;
    widget.stop();
    super.dispose();
  }

  Future<void> _play(List<ListeningLine> lines) async {
    if (_playing) return;
    final generation = ++_playGeneration;
    setState(() {
      _playing = true;
      _error = null;
    });
    try {
      for (final line in lines) {
        if (!mounted || generation != _playGeneration) return;
        final speakers = <String>[];
        for (final l in widget.lesson.lines) {
          if (!speakers.contains(l.speaker)) speakers.add(l.speaker);
        }
        final idx = speakers.indexOf(line.speaker);
        final speakAs = widget.speakAs;
        if (speakAs != null && speakers.length > 1 && idx >= 0) {
          await speakAs(line.japanese, _rate,
              listeningSpeakerPitches[idx % listeningSpeakerPitches.length]);
        } else {
          await widget.speak(line.japanese, _rate);
        }
      }
      if (mounted &&
          generation == _playGeneration &&
          lines.length == widget.lesson.lines.length) {
        setState(() => _heard = true);
      }
    } catch (_) {
      if (mounted && generation == _playGeneration) {
        setState(() =>
            _error = '음성을 재생하지 못했어요. 기기의 일본어 음성 설정과 음량을 확인하고 다시 시도해 주세요.');
      }
    } finally {
      if (mounted && generation == _playGeneration) {
        setState(() => _playing = false);
      }
    }
  }

  Future<void> _stop() async {
    _playGeneration++;
    await widget.stop();
    if (mounted) setState(() => _playing = false);
  }

  Future<void> _choose(int index) async {
    if (!_heard || _answer != null || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.store
          .record(widget.lesson.id, index == widget.lesson.answer);
      if (mounted) {
        setState(() {
          _answer = index;
          _transcript = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = '기록을 저장하지 못했어요. 다시 답을 선택해 주세요.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lesson = widget.lesson;
    return Scaffold(
      appBar: washiAppBar(
          title: lesson.title,
          subtitle: 'N4 · ${lesson.focus}',
          actions: [
            TextButton.icon(
                key: const ValueKey('listening-translation-header'),
                onPressed: _showTranslation,
                icon: const Icon(Icons.translate_rounded),
                label: const Text('해석')),
          ]),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        const Text('01  먼저 들어요',
            style: TextStyle(color: Washi.shu, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        PaperCard(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              const Icon(Icons.graphic_eq_rounded, size: 72, color: Washi.ink),
              Text(_heard ? '다시 들으며 핵심을 확인하세요' : '대본을 보지 않고 들어 보세요',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(lesson.question,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Washi.inkSoft, height: 1.6)),
              const SizedBox(height: 16),
              Wrap(alignment: WrapAlignment.center, spacing: 8, children: [
                ChoiceChip(
                    label: const Text('천천히'),
                    selected: _rate == 0.32,
                    onSelected:
                        _playing ? null : (_) => setState(() => _rate = 0.32)),
                ChoiceChip(
                    label: const Text('보통'),
                    selected: _rate == 0.45,
                    onSelected:
                        _playing ? null : (_) => setState(() => _rate = 0.45))
              ]),
              const SizedBox(height: 12),
              FilledButton.icon(
                  key: const ValueKey('play-listening'),
                  onPressed: _playing ? _stop : () => _play(lesson.lines),
                  icon: Icon(
                      _playing ? Icons.stop_rounded : Icons.play_arrow_rounded),
                  label: Text(_playing
                      ? '재생 멈추기'
                      : _heard
                          ? '다시 듣기'
                          : '대화 듣기')),
              TextButton.icon(
                  key: const ValueKey('listening-translation'),
                  onPressed: _showTranslation,
                  icon: const Icon(Icons.translate_rounded),
                  label: const Text('해석 보기')),
            ])),
        if (_error != null)
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(_error!, style: const TextStyle(color: Washi.shu))),
        const SizedBox(height: 24),
        const Text('02  답을 골라요',
            style: TextStyle(color: Washi.shu, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Text(lesson.question,
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
        if (!_heard)
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('대화를 끝까지 들으면 답을 고를 수 있어요.',
                  style: TextStyle(color: Washi.inkSoft))),
        for (var i = 0; i < lesson.options.length; i++)
          Padding(
              padding: const EdgeInsets.only(top: 10),
              child: OutlinedButton(
                  key: ValueKey('listening-answer-$i'),
                  style: OutlinedButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.all(18),
                      disabledForegroundColor: Washi.ink,
                      backgroundColor: _answer != null && i == lesson.answer
                          ? Washi.matcha.withValues(alpha: 0.15)
                          : _answer == i
                              ? Washi.shu.withValues(alpha: 0.12)
                              : Washi.card),
                  onPressed: !_heard || _answer != null || _saving
                      ? null
                      : () => _choose(i),
                  child: Text('${i + 1}. ${lesson.options[i]}',
                      style: const TextStyle(fontSize: 16)))),
        if (_answer != null) ...[
          const SizedBox(height: 16),
          PaperCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(_answer == lesson.answer ? '잘 들었어요!' : '다음에 한 번 더 들어요',
                    key: const ValueKey('listening-feedback'),
                    style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        color: _answer == lesson.answer
                            ? Washi.matcha
                            : Washi.shu)),
                const SizedBox(height: 8),
                Text('정답: ${lesson.options[lesson.answer]}'),
                const SizedBox(height: 8),
                Text(lesson.explanation, style: const TextStyle(height: 1.7)),
                if (_answer != lesson.answer)
                  const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('틀린 문제는 내일 복습 목록에 다시 나와요.')),
              ])),
          const SizedBox(height: 24),
          Row(children: [
            const Expanded(
                child: Text('03  확인하고 따라 읽어요',
                    style: TextStyle(
                        color: Washi.shu, fontWeight: FontWeight.w800))),
            IconButton(
                tooltip: _transcript ? '대본 숨기기' : '대본 보기',
                onPressed: () => setState(() => _transcript = !_transcript),
                icon: Icon(_transcript
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined))
          ]),
          if (_transcript) ...[
            SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('한국어 해석 표시'),
                subtitle: const Text('끄면 일본어만 보며 따라 읽을 수 있어요.'),
                value: _showKorean,
                onChanged: (value) => setState(() => _showKorean = value)),
            for (final line in lesson.lines)
              Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: PaperCard(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Row(children: [
                          Expanded(
                              child: Text(line.speaker,
                                  style:
                                      const TextStyle(color: Washi.inkSoft))),
                          IconButton(
                              tooltip: '문장 반복 듣기',
                              onPressed: _playing ? null : () => _play([line]),
                              icon: const Icon(Icons.volume_up_rounded))
                        ]),
                        Text(line.japanese,
                            style: const TextStyle(
                                fontSize: 21, height: 1.7, color: Washi.ink)),
                        const SizedBox(height: 8),
                        if (_showKorean)
                          Text(line.korean,
                              style: const TextStyle(
                                  height: 1.6, color: Washi.inkSoft)),
                      ]))),
            const SizedBox(height: 16),
            Text('기억할 표현\n${lesson.expression}',
                style: const TextStyle(
                    fontSize: 17, height: 1.7, fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 24),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('학습 마치기')),
        ],
        const SizedBox(height: 24),
      ]),
    );
  }
}
