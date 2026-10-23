import 'package:kioku_japanese/widgets/chapter_art.dart';
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:kioku_japanese/data/sentence_bank.dart';
import 'package:kioku_japanese/data/study_store.dart';
import 'package:kioku_japanese/models/playback_settings.dart';
import 'package:kioku_japanese/models/vocabulary.dart';
import 'package:kioku_japanese/models/word_catalog.dart';
import 'package:kioku_japanese/pages/grade_list_page.dart';
import 'package:kioku_japanese/pages/playback_settings_page.dart';
import 'package:kioku_japanese/pages/word_match_game.dart';
import 'package:kioku_japanese/services/study_quiz.dart';
import 'package:kioku_japanese/widgets/sentence_quiz.dart';
import 'package:kioku_japanese/widgets/study_widgets.dart';
import 'package:kioku_japanese/widgets/word_row.dart';

/// 2026-09-27 챕터 화면: [목록] 탭(단어 보기·즐겨찾기)과 [학습] 탭.
/// 2026-09-30 수동에 '문장 만들기'(챕터별 5문제)를 추가했다.
/// 2026-09-29 [학습] 탭은 수동(4지선다·글자 조합 문제 풀기)과 자동(카드를 넘기며 일본어→한국어로 읽어 줌)으로 나뉜다.
class ChapterPage extends StatefulWidget {
  const ChapterPage({
    super.key,
    required this.chapter,
    required this.catalog,
    required this.store,
    required this.speakJapanese,
    this.speakKorean,
    this.stopSpeaking,
    this.random,
    this.autoTiming = AutoTiming.normal,
    this.initialStudy = false,
    this.titleOverride,
    this.initialImportantOnly = false,
  });

  final Chapter chapter;
  final WordCatalog catalog;
  final StudyStore store;
  final Future<void> Function(String text) speakJapanese;
  final Future<void> Function(String text)? speakKorean;
  final Future<void> Function()? stopSpeaking;
  final Random? random;
  // 2026-10-19 중요 단어 전용 학습 화면에서 학습 탭으로 바로 진입한다.
  final bool initialStudy;
  final String? titleOverride;
  // 2026-10-19 챕터의 ★ 중요 단어만 골라 학습 탭으로 바로 시작한다.
  final bool initialImportantOnly;

  /// 2026-09-29 자동 모드에서 일본어/한국어 사이 쉬는 시간(테스트에서는 짧게 바꾼다).
  final AutoTiming autoTiming;

  @override
  State<ChapterPage> createState() => _ChapterPageState();
}

class _ChapterPageState extends State<ChapterPage> {
  late final StudyQuiz _quiz;
  late StudyMode _mode;

  int _tab = 0; // 0: 목록, 1: 학습
  bool _importantOnly = false;

  // 2026-10-19 중요 단어 선택 상태를 기존 즐겨찾기 저장소와 공유한다.
  List<Vocabulary> get _studyWords => _importantOnly
      ? widget.chapter.words.where((w) => widget.store.isFavorite(w.id)).toList()
      : widget.chapter.words;

  void _changeImportantOnly(bool enabled) {
    _stopAuto();
    setState(() {
      _importantOnly = enabled;
      _autoIndex = 0;
      _showBack = false;
      _autoDone = false;
      _startRound(_studyWords);
      if (_mode == StudyMode.sentence && enabled) _mode = StudyMode.choice;
    });
  }

  // 학습 진행 상태
  late List<Vocabulary> _order;
  int _index = 0;
  bool _answered = false;
  bool _lastCorrect = false;
  bool _finished = false;
  int _correctCount = 0;
  final List<Vocabulary> _wrongWords = <Vocabulary>[];
  List<String> _choices = const <String>[];
  List<String> _tiles = const <String>[];
  String _assembled = '';

  // 자동 모드 상태
  late bool _auto;
  // 2026-10-20 자동 재생 설정(단어/뜻, 반복 회수, 쉬는 초, 순서).
  late PlaybackSettings _playback;
  int _autoIndex = 0;
  bool _showBack = false;
  bool _playing = false;
  bool _autoDone = false;
  int _autoToken = 0;
  Timer? _autoTimer;
  Completer<void>? _autoWait;

  GradeColors get _colors => GradeColors.of(widget.chapter.grade);
  Vocabulary get _current => _order[_index];

  @override
  void initState() {
    super.initState();
    _quiz = StudyQuiz(
      pool: widget.catalog.wordsOfGrade(widget.chapter.grade),
      random: widget.random,
    );
    _mode = widget.store.mode == StudyMode.sentence &&
            (widget.titleOverride != null || SentenceBank.instance.forChapter(widget.chapter).isEmpty)
        ? StudyMode.choice
        : widget.store.mode;
    _auto = widget.store.autoMode;
    _playback = widget.store.playback;
    _tab = widget.initialStudy || widget.initialImportantOnly ? 1 : 0;
    _importantOnly = widget.initialImportantOnly &&
        widget.chapter.words.any((w) => widget.store.isFavorite(w.id));
    if (_importantOnly && _mode == StudyMode.sentence) _mode = StudyMode.choice;
    _startRound(_studyWords);
  }

  @override
  void dispose() {
    _stopAuto(updateState: false);
    super.dispose();
  }

  void _startRound(List<Vocabulary> words) {
    _order = List<Vocabulary>.of(words);
    _index = 0;
    _finished = _order.isEmpty;
    _correctCount = 0;
    _wrongWords.clear();
    if (!_finished) _prepareQuestion();
  }

  void _prepareQuestion() {
    _answered = false;
    _lastCorrect = false;
    _assembled = '';
    _choices = _quiz.choicesFor(_current);
    _tiles = _quiz.tilesFor(_current);
  }

  Future<void> _submit(String answer) async {
    if (_answered || _finished) return;
    final word = _current;
    final correct = switch (_mode) {
      StudyMode.choice => answer == word.japanese,
      StudyMode.assemble => StudyQuiz.isCorrect(word, answer),
      StudyMode.sentence => false, // 문장 만들기는 SentenceQuiz가 따로 채점한다.
    };
    setState(() {
      _answered = true;
      _lastCorrect = correct;
      if (correct) {
        _correctCount++;
      } else {
        _wrongWords.add(word);
      }
    });
    FocusScope.of(context).unfocus();
    try {
      await widget.store.recordRecall(
          word.id, correct ? RecallRating.remembered : RecallRating.forgotten);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('학습 기록 저장에 실패했습니다. 다시 학습해 주세요.')));
      }
    }
  }

  void _next() {
    setState(() {
      if (_index >= _order.length - 1) {
        _finished = true;
      } else {
        _index++;
        _prepareQuestion();
      }
    });
  }

  Future<void> _setMode(StudyMode mode) async {
    if (mode == _mode) return;
    await widget.store.setMode(mode);
    if (!mounted) return;
    setState(() {
      _mode = mode;
      if (!_finished) _prepareQuestion();
    });
  }

  Future<void> _resetChapter() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Washi.card,
        title: const Text('초기화'),
        content: const Text('이 챕터의 학습 기록을 지우고 처음부터 다시 할까요?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('취소')),
          TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('초기화')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await widget.store
        .resetLearned(widget.chapter.words.map((word) => word.id));
    setState(() => _startRound(_studyWords));
  }

  @override
  Widget build(BuildContext context) {
    final compact = widget.store.compactList;
    return Scaffold(
      backgroundColor: Washi.paper,
      appBar: washiAppBar(
        // 2026-09-27 제목이 잘리지 않도록 "第1章"만 크게, 급수·품사는 아래 작은 글씨로 둔다.
        title: widget.titleOverride ?? '第${widget.chapter.number}章',
        subtitle:
            '${widget.chapter.grade} · ${WordCatalog.categoryLabel(widget.chapter.category)} · ${widget.chapter.words.length}단어',
        actions: [
          if (_tab == 0) ...[
            IconButton(
              key: const ValueKey('toggle-compact'),
              tooltip: compact ? '크게 보기' : '작게 보기',
              icon: Icon(
                  compact ? Icons.view_agenda_outlined : Icons.view_headline),
              onPressed: () async {
                await widget.store.setCompactList(!compact);
                if (mounted) setState(() {});
              },
            ),
            IconButton(
              key: const ValueKey('reset-chapter'),
              tooltip: '초기화',
              icon: const Icon(Icons.restart_alt),
              onPressed: _resetChapter,
            ),
          ],
          IconButton(
            tooltip: '도움말',
            icon: const Icon(Icons.help_outline),
            onPressed: () => showHelpDialog(context),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: _SegmentedTabs(
                color: _colors.main,
                selected: _tab,
                onSelect: (tab) {
                  // 학습 탭을 떠나면 자동 재생을 멈춘다.
                  if (tab != 1) _stopAuto();
                  setState(() => _tab = tab);
                },
              ),
            ),
            // 2026-10-17 [게임] 탭: 일본어↔한국어 카드 짝맞추기.
            Expanded(
                child: switch (_tab) {
              0 => _buildList(),
              2 => WordMatchGame(
                  key: const ValueKey('word-match-game'),
                  words: widget.chapter.words,
                  speakJapanese: widget.speakJapanese,
                  speakKorean: widget.speakKorean),
              _ => _buildStudy(),
            }),
          ],
        ),
      ),
    );
  }

  // ---------------- 단어 목록 탭 ----------------

  // 2026-10-19 단어 목록 위에 이 챕터의 ★ 중요 단어 수와 바로 학습 버튼을 둔다.
  Widget _importantBar(int count) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Material(
          color: const Color(0xFFFFF3D1),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: Color(0xFFF0D58A))),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
            child: Row(children: [
              const Icon(Icons.star_rounded, color: Color(0xFFE0A526)),
              const SizedBox(width: 6),
              Expanded(
                  child: Text('이 챕터 중요 단어 $count개',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, color: Washi.ink))),
              TextButton.icon(
                key: const ValueKey('chapter-important-study'),
                onPressed: () {
                  setState(() => _tab = 1);
                  _changeImportantOnly(true);
                },
                icon: const Icon(Icons.school_outlined, size: 18),
                label: const Text('★만 학습'),
              ),
            ]),
          ),
        ),
      );

  Widget _buildList() {
    final favorites = widget.store.favoriteIds;
    final learned = widget.store.learnedIds;
    final words = widget.chapter.words;
    final importantCount =
        words.where((w) => favorites.contains(w.id)).length;
    final header = importantCount > 0 && widget.titleOverride == null;
    return ListView.builder(
      padding: const EdgeInsets.only(top: 2, bottom: 12),
      itemCount: words.length + (header ? 1 : 0),
      itemBuilder: (context, rawIndex) {
        if (header && rawIndex == 0) return _importantBar(importantCount);
        final index = header ? rawIndex - 1 : rawIndex;
        final word = words[index];
        return WordRow(
          key: ValueKey('row-${word.id}'),
          number: index + 1,
          word: word,
          favorite: favorites.contains(word.id),
          learned: learned.contains(word.id),
          compact: widget.store.compactList,
          accent: _colors.main,
          store: widget.store,
          speakJapanese: widget.speakJapanese,
          onToggleFavorite: () async {
            await widget.store.toggleFavorite(word.id);
            if (mounted) setState(() {});
          },
        );
      },
    );
  }

  // ---------------- 학습 탭 ----------------

  /// 2026-09-27 학습 화면은 스크롤 없이 한 화면에 모두 들어가도록 남은 공간을 비율로 나눈다.
  Widget _buildStudy() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ManualAutoSwitch(
            auto: _auto,
            color: _colors.main,
            onChanged: _setAuto,
          ),
          const SizedBox(height: 8),
          // 2026-10-19 별표 표시 단어만 수동/자동 학습한다.
          Row(children: [
            Expanded(child: FilterChip(
              key: const ValueKey('important-only-filter'),
              label: Text('★ 중요 단어만 (${widget.chapter.words.where((w) => widget.store.isFavorite(w.id)).length})'),
              selected: _importantOnly,
              onSelected: _changeImportantOnly,
              selectedColor: const Color(0xFFFFE6A4),
            )),
          ]),
          const SizedBox(height: 8),
          Expanded(child: _studyWords.isEmpty
            ? Center(child: Text(_importantOnly
                ? '이 챕터에 별표 표시한 중요 단어가 없습니다.\n단어 목록에서 ☆를 눌러 추가해 주세요.'
                : '학습할 단어가 없습니다.', textAlign: TextAlign.center))
            : _auto ? _buildAuto() : _buildManual()),
        ],
      ),
    );
  }

  Widget _buildManual() {
    // 2026-09-30 문장 만들기는 챕터별 5문제를 SentenceQuiz가 따로 진행한다.
    if (_mode == StudyMode.sentence && !_importantOnly && widget.titleOverride == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ModeChips(mode: _mode, color: _colors.main, onSelect: _setMode),
          const SizedBox(height: 10),
          Expanded(
            child: SentenceQuiz(
              key: ValueKey(
                  'sentence-quiz-${SentenceBank.keyOf(widget.chapter)}'),
              items: SentenceBank.instance.forChapter(widget.chapter),
              speakJapanese: widget.speakJapanese,
              accent: _colors.main,
              random: widget.random,
            ),
          ),
        ],
      );
    }
    if (_finished) return _buildFinished();
    final word = _current;
    return Padding(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ModeChips(
            mode: _mode,
            color: _colors.main,
            onSelect: _setMode,
            allowSentence: !_importantOnly && widget.titleOverride == null &&
                SentenceBank.instance.forChapter(widget.chapter).isNotEmpty,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                '${_index + 1} / ${_order.length}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Washi.inkSoft,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SlimProgress(
                  ratio: (_index + 1) / _order.length,
                  color: _colors.main,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            flex: 3,
            child: PaperCard(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '뜻',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Washi.shu,
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width - 64,
                          ),
                          child: Text(
                            word.korean,
                            key: const ValueKey('study-prompt'),
                            textAlign: TextAlign.center,
                            maxLines: 3,
                            style: TextStyle(
                              fontSize: word.korean.length > 14 ? 28 : 38,
                              fontWeight: FontWeight.w900,
                              color: Washi.ink,
                              height: 1.25,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            flex: 7,
            child: _answered ? _buildFeedback(word) : _buildModeInput(),
          ),
        ],
      ),
    );
  }

  Widget _buildModeInput() {
    switch (_mode) {
      case StudyMode.choice:
        return Column(
          children: [
            for (var row = 0; row < 2; row++)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: row == 0 ? 10 : 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var col = 0; col < 2; col++) ...[
                        if (col == 1) const SizedBox(width: 10),
                        Expanded(
                          child: row * 2 + col < _choices.length
                              ? _WashiTile(
                                  key: ValueKey(
                                      'choice-${_choices[row * 2 + col]}'),
                                  text: _choices[row * 2 + col],
                                  fontSize: 30,
                                  onTap: () => _submit(_choices[row * 2 + col]),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        );
      case StudyMode.sentence:
        return const SizedBox.shrink();
      case StudyMode.assemble:
        const columns = 5;
        final rows = (_tiles.length / columns).ceil();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _InputRow(
              color: _colors.main,
              onDelete: () => setState(() {
                final chars = StudyQuiz.splitChars(_assembled);
                if (chars.isNotEmpty) {
                  _assembled = chars.sublist(0, chars.length - 1).join();
                }
              }),
              onSubmit: () => _submit(_assembled),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _assembled.isEmpty ? ' ' : _assembled,
                    key: const ValueKey('assembled-text'),
                    style: const TextStyle(fontSize: 30, color: Washi.ink),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Column(
                children: [
                  for (var row = 0; row < rows; row++)
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var col = 0; col < columns; col++)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(3),
                                child: row * columns + col < _tiles.length
                                    ? _WashiTile(
                                        key: ValueKey(
                                            'tile-${row * columns + col}'),
                                        text: _tiles[row * columns + col],
                                        fontSize: 30,
                                        radius: 12,
                                        onTap: () => setState(
                                          () => _assembled +=
                                              _tiles[row * columns + col],
                                        ),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
    }
  }

  Widget _buildFeedback(Vocabulary word) {
    final color = _lastCorrect ? Washi.shu : Washi.ink;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: PaperCard(
            borderColor: color.withValues(alpha: 0.5),
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                HankoBadge(
                  text: _lastCorrect ? '正' : '誤',
                  color: color,
                  size: 64,
                  filled: _lastCorrect,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width - 190,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _lastCorrect ? '정답입니다!' : '틀렸습니다',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: color,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            word.japanese,
                            key: const ValueKey('feedback-answer'),
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: Washi.ink,
                            ),
                          ),
                          Text(
                            '【${word.reading}】',
                            style: const TextStyle(
                                fontSize: 17, color: Washi.inkSoft),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            word.exampleJapanese,
                            style:
                                const TextStyle(fontSize: 15, color: Washi.ink),
                          ),
                          Text(
                            word.exampleKorean,
                            style: const TextStyle(
                                fontSize: 13, color: Washi.inkSoft),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '발음 듣기',
                  icon: const Icon(Icons.volume_up_rounded,
                      size: 30, color: Washi.ink),
                  onPressed: () => widget.speakJapanese(word.reading),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          key: const ValueKey('next-question'),
          style: FilledButton.styleFrom(
            backgroundColor: Washi.ink,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(54),
            shape: const StadiumBorder(),
          ),
          onPressed: _next,
          child: Text(
            _index >= _order.length - 1 ? '결과 보기' : '다음 문제',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }

  // ---------------- 자동 모드 ----------------

  Future<void> _setAuto(bool auto) async {
    if (auto == _auto) return;
    _stopAuto();
    await widget.store.setAutoMode(auto);
    if (!mounted) return;
    setState(() {
      _auto = auto;
      _showBack = false;
      _autoDone = false;
    });
    // 자동을 고르면 바로 재생을 시작한다.
    if (auto) _playAuto();
  }

  /// 2026-09-29 자동 재생을 멈춘다. 대기 중인 타이머와 음성도 함께 멈춘다.
  void _stopAuto({bool updateState = true}) {
    _autoToken++;
    _autoTimer?.cancel();
    _autoTimer = null;
    final wait = _autoWait;
    _autoWait = null;
    if (wait != null && !wait.isCompleted) wait.complete();
    if (_playing) widget.stopSpeaking?.call();
    _playing = false;
    if (updateState && mounted) setState(() {});
  }

  /// 2026-09-29 취소할 수 있는 대기(일시정지하면 바로 끝난다).
  Future<void> _wait(Duration duration) {
    final completer = Completer<void>();
    _autoWait = completer;
    _autoTimer = Timer(duration, () {
      if (!completer.isCompleted) completer.complete();
    });
    return completer.future;
  }

  bool _alive(int token) => mounted && token == _autoToken;

  /// 2026-09-29 자동 재생: 일본어 카드를 보여주고 읽어 준 뒤, 카드를 뒤집어 한국어 뜻을 읽어 주고
  /// 다음 단어로 넘어간다. 챕터 끝까지 가면 멈춘다.
  Future<void> _playAuto() async {
    final words = _studyWords;
    if (words.isEmpty) return;
    _stopAuto();
    final token = _autoToken;
    setState(() {
      if (_autoDone) {
        _autoIndex = 0;
        _autoDone = false;
      }
      _playing = true;
    });
    final timing = widget.autoTiming;
    final order = _playback.order;
    if (order.isEmpty) {
      setState(() => _playing = false);
      return;
    }
    while (_alive(token)) {
      final word = words[_autoIndex];
      // 2026-10-20 설정한 순서대로 단어(앞면)·뜻(뒷면)을 정한 횟수만큼 읽고 정한 초만큼 쉰다.
      for (final item in order) {
        final back = item == PlaybackItem.meaning;
        if (_showBack != back) {
          setState(() => _showBack = back);
          await _wait(timing.flip);
          if (!_alive(token)) return;
        }
        final repeat = _playback.repeatOf(item);
        for (var i = 0; i < repeat; i++) {
          if (back) {
            await (widget.speakKorean?.call(word.korean) ??
                Future<void>.value());
          } else {
            await widget.speakJapanese(word.reading);
          }
          if (!_alive(token)) return;
          await _wait(_pauseFor(item, timing));
          if (!_alive(token)) return;
        }
      }

      if (_autoIndex >= words.length - 1) {
        setState(() {
          _playing = false;
          _autoDone = true;
        });
        _autoToken++;
        return;
      }
      setState(() {
        _autoIndex++;
        // 2026-10-20 다음 단어는 첫 재생 항목의 면(뜻 먼저면 뒷면)으로 시작한다.
        _showBack = order.first == PlaybackItem.meaning;
      });
      await _wait(timing.flip);
    }
  }

  /// 2026-10-20 읽은 뒤 쉬는 시간. 기본값(1초)이면 기존 자동 모드의 쉬는 시간을 그대로 쓴다.
  Duration _pauseFor(PlaybackItem item, AutoTiming timing) {
    final seconds = _playback.pauseOf(item);
    if (seconds == PlaybackSettings.defaultPause) {
      return item == PlaybackItem.word
          ? timing.afterJapanese
          : timing.afterKorean;
    }
    return Duration(seconds: seconds);
  }

  /// 2026-10-20 재생 설정 화면을 열고, 돌아오면 바뀐 설정을 다시 읽는다.
  Future<void> _openPlaybackSettings() async {
    _stopAuto();
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) =>
          PlaybackSettingsPage(store: widget.store, accent: _colors.main),
    ));
    if (!mounted) return;
    setState(() => _playback = widget.store.playback);
  }

  void _autoMove(int delta) {
    final words = _studyWords;
    if (words.isEmpty) return;
    _stopAuto();
    setState(() {
      _autoIndex = (_autoIndex + delta).clamp(0, words.length - 1).toInt();
      _showBack = false;
      _autoDone = false;
    });
  }

  /// 2026-09-29 멈춘 상태에서 카드를 누르면 직접 뒤집고 그 면의 말을 읽어 준다.
  void _flipByHand() {
    if (_playing) return;
    final word = _studyWords[_autoIndex];
    setState(() => _showBack = !_showBack);
    if (_showBack) {
      widget.speakKorean?.call(word.korean);
    } else {
      widget.speakJapanese(word.reading);
    }
  }

  Widget _buildAuto() {
    final words = _studyWords;
    if (words.isEmpty) return const SizedBox.shrink();
    final word = words[_autoIndex];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              '${_autoIndex + 1} / ${words.length}',
              key: const ValueKey('auto-progress'),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Washi.inkSoft,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SlimProgress(
                ratio: (_autoIndex + 1) / words.length,
                color: _colors.main,
              ),
            ),
            // 2026-10-20 재생 항목·순서·반복 설정.
            IconButton(
              key: const ValueKey('auto-settings'),
              tooltip: '재생 설정',
              visualDensity: VisualDensity.compact,
              onPressed: _openPlaybackSettings,
              icon: const Icon(Icons.tune_rounded, color: Washi.inkSoft),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: _FlipCard(
            key: const ValueKey('auto-card'),
            showBack: _showBack,
            onTap: _flipByHand,
            front: _AutoFace(
              label: '日本語',
              color: _colors.main,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    word.japanese,
                    key: const ValueKey('auto-japanese'),
                    style: const TextStyle(
                      fontSize: 64,
                      fontWeight: FontWeight.w800,
                      color: Washi.ink,
                    ),
                  ),
                ),
                if (word.reading != word.japanese)
                  Text(
                    word.reading,
                    style: const TextStyle(fontSize: 22, color: Washi.inkSoft),
                  ),
              ],
            ),
            back: _AutoFace(
              label: '한국어',
              color: Washi.shu,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width - 80,
                    ),
                    child: Text(
                      word.korean,
                      key: const ValueKey('auto-korean'),
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        color: Washi.ink,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '${word.japanese}【${word.reading}】',
                  style: const TextStyle(fontSize: 18, color: Washi.inkSoft),
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    word.exampleJapanese,
                    style: const TextStyle(fontSize: 15, color: Washi.ink),
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    word.exampleKorean,
                    style: const TextStyle(fontSize: 13, color: Washi.inkSoft),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _playing
              ? '자동 재생 중 · ${_playback.summary}'
              : _autoDone
                  ? '끝까지 들었어요! ▶ 를 누르면 처음부터 다시 재생합니다.'
                  : '멈춤 · 카드를 누르면 뒤집어서 들을 수 있어요.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: Washi.inkSoft),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton.outlined(
              key: const ValueKey('auto-prev'),
              tooltip: '이전 단어',
              iconSize: 28,
              style: IconButton.styleFrom(
                  side: const BorderSide(color: Washi.line)),
              onPressed: _autoIndex > 0 ? () => _autoMove(-1) : null,
              icon: const Icon(Icons.skip_previous_rounded, color: Washi.ink),
            ),
            const SizedBox(width: 18),
            IconButton.filled(
              key: const ValueKey('auto-play'),
              tooltip: _playing ? '일시정지' : '재생',
              iconSize: 40,
              style: IconButton.styleFrom(
                backgroundColor: Washi.ink,
                minimumSize: const Size(72, 72),
              ),
              onPressed: _playing ? _stopAuto : _playAuto,
              icon: Icon(
                _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 18),
            IconButton.outlined(
              key: const ValueKey('auto-next'),
              tooltip: '다음 단어',
              iconSize: 28,
              style: IconButton.styleFrom(
                  side: const BorderSide(color: Washi.line)),
              onPressed:
                  _autoIndex < words.length - 1 ? () => _autoMove(1) : null,
              icon: const Icon(Icons.skip_next_rounded, color: Washi.ink),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFinished() {
    final wrong = List<Vocabulary>.of(_wrongWords);
    final perfect = _order.isNotEmpty && _correctCount == _order.length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      children: [
        Center(
          child: HankoBadge(
            text: perfect ? '満点' : '済',
            color: Washi.shu,
            size: 110,
            filled: true,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          '학습 완료',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 26, fontWeight: FontWeight.w900, color: Washi.ink),
        ),
        const SizedBox(height: 6),
        Text(
          '${_order.length}문제 중 $_correctCount개 정답',
          key: const ValueKey('finish-score'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, color: Washi.inkSoft),
        ),
        const SizedBox(height: 28),
        if (wrong.isNotEmpty) ...[
          FilledButton(
            key: const ValueKey('retry-wrong'),
            style: FilledButton.styleFrom(
              backgroundColor: Washi.ink,
              minimumSize: const Size.fromHeight(52),
              shape: const StadiumBorder(),
            ),
            onPressed: () => setState(() => _startRound(wrong)),
            child: Text('틀린 단어만 다시 (${wrong.length}개)'),
          ),
          const SizedBox(height: 10),
        ],
        OutlinedButton(
          key: const ValueKey('retry-all'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Washi.ink,
            side: const BorderSide(color: Washi.ink),
            minimumSize: const Size.fromHeight(52),
            shape: const StadiumBorder(),
          ),
          onPressed: () => setState(() => _startRound(_studyWords)),
          child: const Text('처음부터 다시'),
        ),
      ],
    );
  }
}

/// 2026-09-27 [단어 목록 | 학습] 둥근 알약 모양 전환 버튼이다.
class _SegmentedTabs extends StatelessWidget {
  const _SegmentedTabs(
      {required this.color, required this.selected, required this.onSelect});

  final Color color;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    Widget tab(int index, String label, IconData icon) {
      final active = selected == index;
      return Expanded(
        child: Material(
          color: active ? Washi.ink : Colors.transparent,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: ValueKey('tab-$index'),
            onTap: () => onSelect(index),
            child: SizedBox(
              height: 42,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon,
                      size: 18, color: active ? Colors.white : Washi.inkSoft),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      color: active ? Colors.white : Washi.inkSoft,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Washi.card,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Washi.line),
      ),
      child: Row(
        children: [
          tab(0, '단어 목록', Icons.menu_book_outlined),
          tab(1, '학습', Icons.edit_note),
          tab(2, '게임', Icons.style_outlined),
        ],
      ),
    );
  }
}

/// 2026-09-27 학습 방식(4지선다·글자 조합·직접 입력)을 바로 고르는 작은 칩 줄이다.
class _ModeChips extends StatelessWidget {
  const _ModeChips(
      {required this.mode,
      required this.color,
      required this.onSelect,
      this.allowSentence = true});

  final StudyMode mode;
  final Color color;
  final ValueChanged<StudyMode> onSelect;
  final bool allowSentence;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final item in StudyMode.values
            .where((item) => allowSentence || item != StudyMode.sentence)) ...[
          if (item != StudyMode.values.first) const SizedBox(width: 8),
          Expanded(
            child: Material(
              color: item == mode
                  ? color.withValues(alpha: 0.16)
                  : Colors.transparent,
              shape: StadiumBorder(
                side: BorderSide(color: item == mode ? color : Washi.line),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: ValueKey('mode-${item.name}'),
                onTap: () => onSelect(item),
                child: SizedBox(
                  height: 34,
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: item == mode ? Washi.ink : Washi.inkSoft,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// 2026-09-27 둥근 모서리 종이 타일(보기·글자판)이다.
class _WashiTile extends StatelessWidget {
  const _WashiTile({
    super.key,
    required this.text,
    required this.onTap,
    this.fontSize = 30,
    this.radius = 16,
  });

  final String text;
  final VoidCallback onTap;
  final double fontSize;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return PaperCard(
      radius: radius,
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: SizedBox.expand(
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                text,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w500,
                  color: Washi.ink,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 2026-09-27 [⌫ 삭제] 입력칸 [✓ 입력] 줄이다.
class _InputRow extends StatelessWidget {
  const _InputRow({
    required this.color,
    required this.onDelete,
    required this.onSubmit,
    required this.child,
  });

  final Color color;
  final VoidCallback onDelete;
  final VoidCallback onSubmit;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IconButton.outlined(
            key: const ValueKey('input-delete'),
            tooltip: '삭제',
            style: IconButton.styleFrom(
              side: const BorderSide(color: Washi.line),
              backgroundColor: Washi.card,
            ),
            onPressed: onDelete,
            icon: const Icon(Icons.backspace_outlined, color: Washi.inkSoft),
          ),
          const SizedBox(width: 8),
          Expanded(
            // 둥근 모서리에 색이 다른 테두리를 함께 쓰면 오류가 나므로, 잘라낸 뒤 아래 밑줄만 그린다.
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                decoration: BoxDecoration(
                  color: Washi.card,
                  border: Border(bottom: BorderSide(color: color, width: 3)),
                ),
                alignment: Alignment.center,
                child: child,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            key: const ValueKey('input-submit'),
            tooltip: '입력',
            style: IconButton.styleFrom(backgroundColor: Washi.ink),
            onPressed: onSubmit,
            icon: const Icon(Icons.check_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

/// 2026-09-29 자동 모드의 쉬는 시간 설정이다.
class AutoTiming {
  const AutoTiming({
    required this.afterJapanese,
    required this.afterKorean,
    required this.flip,
  });

  final Duration afterJapanese;
  final Duration afterKorean;
  final Duration flip;

  static const AutoTiming normal = AutoTiming(
    afterJapanese: Duration(milliseconds: 900),
    afterKorean: Duration(milliseconds: 1400),
    flip: Duration(milliseconds: 450),
  );
}

/// 2026-09-29 학습 탭 맨 위의 [✋ 수동 | ▶ 자동] 전환 버튼이다.
class _ManualAutoSwitch extends StatelessWidget {
  const _ManualAutoSwitch(
      {required this.auto, required this.color, required this.onChanged});

  final bool auto;
  final Color color;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget option(bool value, String label, IconData icon, Key key) {
      final active = auto == value;
      return Expanded(
        child: Material(
          color: active ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: key,
            onTap: () => onChanged(value),
            child: SizedBox(
              height: 34,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon,
                      size: 18, color: active ? Colors.white : Washi.inkSoft),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: active ? Colors.white : Washi.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Washi.card,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Washi.line),
      ),
      child: Row(
        children: [
          option(false, '수동 (문제 풀기)', Icons.touch_app_outlined,
              const ValueKey('study-manual')),
          option(true, '자동 (듣기 카드)', Icons.play_circle_outline,
              const ValueKey('study-auto')),
        ],
      ),
    );
  }
}

/// 2026-09-29 자동 모드 카드의 한 면(위에 작은 라벨, 가운데 내용)이다.
class _AutoFace extends StatelessWidget {
  const _AutoFace(
      {required this.label, required this.color, required this.children});

  final String label;
  final Color color;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return PaperCard(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w800, color: color),
          ),
          Expanded(
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: children,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 2026-09-29 앞면(일본어)과 뒷면(한국어)을 3D로 뒤집는 카드다.
class _FlipCard extends StatefulWidget {
  const _FlipCard({
    super.key,
    required this.showBack,
    required this.front,
    required this.back,
    required this.onTap,
  });

  final bool showBack;
  final Widget front;
  final Widget back;
  final VoidCallback onTap;

  @override
  State<_FlipCard> createState() => _FlipCardState();
}

class _FlipCardState extends State<_FlipCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
    value: widget.showBack ? 1 : 0,
  );

  @override
  void didUpdateWidget(covariant _FlipCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.showBack != widget.showBack) {
      widget.showBack ? _controller.forward() : _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final angle = _controller.value * pi;
          final showingBack = angle > pi / 2;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(angle),
            child: showingBack
                ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(pi),
                    child: widget.back,
                  )
                : widget.front,
          );
        },
      ),
    );
  }
}
