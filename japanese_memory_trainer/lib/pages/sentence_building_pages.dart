import 'dart:math';

import 'package:flutter/material.dart';
import 'package:kioku_japanese/data/sentence_building_bank.dart';
import 'package:kioku_japanese/data/sentence_building_vocab.dart';
import 'package:kioku_japanese/widgets/study_widgets.dart';
import 'package:kioku_japanese/widgets/tile_3d.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 2026-10-16 N4·N3 문장 만들기.
/// 단어별 선택(낱말 탭·조각 배열·듣고 배열)과 글자별 선택(글자 하나하나 탭) 메뉴를 함께 제공한다.
/// mode 0: 한국어 보고 낱말 탭으로 문장 조립 (전체 조각 + 오답 1개 섞음)
/// mode 1: 한국어 보고 조각 배열
/// mode 2: 듣고 배열
/// mode 3: 글자 하나하나 순서대로 탭 (심화)
const Color sbColor = Color(0xFF2F7D7A);
const Color _sbSoft = Color(0xFFE2F1EF);
const Color _sbHard = Color(0xFF3B5BDB); // 2026-10-17 글자별 모드 색: 보라 → 맑은 남청색

typedef SbSpeak = Future<void> Function(String text);

/// 단어별 학습 / 글자별 학습 모드 구분
enum SbStudyMode {
  word, // 1단계: 단어별 선택 (낱말 조립, 조각 배열, 듣고 배열)
  char, // 2단계: 글자별 선택 (글자 하나하나 순서대로 탭)
}

/// 학습 기록(최고 점수, 틀린 문장).
class SbProgress {
  SbProgress(this.prefs);
  final SharedPreferences prefs;

  /// 단어별 모드 최고 점수 (레슨당 문장수 * 3)
  int bestWord(String lessonId) =>
      prefs.getInt('sb.best.word.$lessonId') ?? prefs.getInt('sb.best.$lessonId') ?? -1;
  Future<void> saveBestWord(String lessonId, int score) async {
    if (score > bestWord(lessonId)) await prefs.setInt('sb.best.word.$lessonId', score);
  }

  /// 글자별 모드 최고 점수 (레슨당 문장수 * 1)
  int bestChar(String lessonId) => prefs.getInt('sb.best.char.$lessonId') ?? -1;
  Future<void> saveBestChar(String lessonId, int score) async {
    if (score > bestChar(lessonId)) await prefs.setInt('sb.best.char.$lessonId', score);
  }

  /// 기존 호환용 best 메서드
  int best(String lessonId) => bestWord(lessonId);
  Future<void> saveBest(String lessonId, int score) => saveBestWord(lessonId, score);

  List<String> get wrong => prefs.getStringList('sb.wrong') ?? const [];
  Future<void> markWrong(String key) async {
    final w = [...wrong];
    if (!w.contains(key)) w.add(key);
    await prefs.setStringList('sb.wrong', w);
  }

  Future<void> clearWrong(String key) async {
    final w = [...wrong]..remove(key);
    await prefs.setStringList('sb.wrong', w);
  }
}

String sbKey(SbLesson l, int i) => '${l.id}|$i';

(SbLesson, int)? sbFromKey(String key) {
  final p = key.split('|');
  if (p.length != 2) return null;
  final i = int.tryParse(p[1]);
  for (final l in sbLessons) {
    if (l.id == p[0] && i != null && i >= 0 && i < l.items.length) return (l, i);
  }
  return null;
}

/// 일본어 문장을 낱자(글자) 단위로 분해한다.
/// 히라가나·가타카나·한자·구두점 등 모든 글자를 한 자씩 쪼갠다.
List<String> splitToChars(String text) {
  return text.runes.map(String.fromCharCode).toList();
}

/// 0: 한국어 보고 낱말 탭 조립, 1: 한국어 보고 배열, 2: 듣고 배열, 3: 글자 하나하나 탭.
class SbStep {
  const SbStep(this.lesson, this.index, this.mode);
  final SbLesson lesson;
  final int index;
  final int mode;
  SbItem get item => lesson.items[index];
}

// ───────────────────────────── 첫 화면 ─────────────────────────────

class SentenceBuildingHomePage extends StatefulWidget {
  const SentenceBuildingHomePage({super.key, required this.speak, this.preferences});
  final SbSpeak speak;
  final SharedPreferences? preferences;

  @override
  State<SentenceBuildingHomePage> createState() => _SentenceBuildingHomePageState();
}

class _SentenceBuildingHomePageState extends State<SentenceBuildingHomePage> {
  SbProgress? _p;
  String _level = 'N4';
  SbStudyMode _studyMode = SbStudyMode.word; // 기본값: 단어별 선택 먼저 공부
  final _rnd = Random();

  @override
  void initState() {
    super.initState();
    () async {
      final prefs = widget.preferences ?? await SharedPreferences.getInstance();
      if (mounted) setState(() => _p = SbProgress(prefs));
    }();
  }

  Future<void> _start(String title, List<SbStep> steps,
      {SbLesson? lesson, bool isCharMode = false}) async {
    if (steps.isEmpty) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => SbPracticePage(
            title: title,
            steps: steps,
            progress: _p!,
            speak: widget.speak,
            lesson: lesson,
            isCharMode: isCharMode)));
    if (mounted) setState(() {});
  }

  /// 단어별 학습 스텝 (mode 0, 1, 2)
  List<SbStep> _lessonWordSteps(SbLesson l) {
    final order = List.generate(l.items.length, (i) => i);
    return [
      for (final i in order) SbStep(l, i, 0),
      for (final i in [...order]..shuffle(_rnd)) SbStep(l, i, 1),
      for (final i in [...order]..shuffle(_rnd)) SbStep(l, i, 2),
    ];
  }

  /// 글자별 학습 스텝 (mode 3 - 글자 하나하나 탭)
  List<SbStep> _lessonCharSteps(SbLesson l) {
    final order = List.generate(l.items.length, (i) => i);
    return [
      for (final i in order) SbStep(l, i, 3),
    ];
  }

  /// 단어별 랜덤 10문제 (mode 0·1·2 섞음)
  List<SbStep> _randomWordSteps() {
    final all = [
      for (final l in sbLessons.where((l) => l.level == _level))
        for (var i = 0; i < l.items.length; i++) (l, i)
    ]..shuffle(_rnd);
    return [
      for (var k = 0; k < min(10, all.length); k++) SbStep(all[k].$1, all[k].$2, k % 3),
    ];
  }

  /// 글자별 랜덤 5문제 (mode 3)
  List<SbStep> _randomCharSteps() {
    final all = [
      for (final l in sbLessons.where((l) => l.level == _level))
        for (var i = 0; i < l.items.length; i++) (l, i)
    ]..shuffle(_rnd);
    return [
      for (var k = 0; k < min(5, all.length); k++) SbStep(all[k].$1, all[k].$2, 3),
    ];
  }

  List<SbStep> _wrongSteps({bool charMode = false}) {
    final list = _p!.wrong.map(sbFromKey).whereType<(SbLesson, int)>().toList()..shuffle(_rnd);
    return [for (final (l, i) in list) SbStep(l, i, charMode ? 3 : 0)];
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    final lessons = sbLessons.where((l) => l.level == _level).toList();
    final isChar = _studyMode == SbStudyMode.char;
    final activeColor = isChar ? _sbHard : sbColor;

    return Scaffold(
      backgroundColor: Washi.paper,
      appBar: washiAppBar(
        title: '문장 만들기',
        subtitle: isChar ? '2단계 · 글자 하나하나 탭' : '1단계 · 단어별로 선택 조립',
      ),
      body: p == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 30), children: [
              // ── 상단 인트로 배너 ──
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: activeColor,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(
                    isChar ? Icons.spellcheck_rounded : Icons.extension_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isChar ? '글자를 하나하나 탭해\n정확하게 완성해요' : '단어 조각을 맞춰\n일본어 문장을 만들어요',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        height: 1.3),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isChar
                        ? '2단계 심화 학습: 한 자씩 순서대로 탭하여 철자와 한자를 마스터해요'
                        : '1단계 기초 학습: 단어 조각을 탭하여 문장의 뼈대와 어순을 먼저 익혀요',
                    style: const TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.5),
                  ),
                ]),
              ),
              const SizedBox(height: 14),

              // ── 핵심: 단어별 선택 & 글자별 선택 통합 메뉴 ──
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Washi.line),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(4),
                child: Row(children: [
                  Expanded(
                    child: _modeTabButton(
                      key: const ValueKey('sb-mode-word'),
                      title: '단어별 선택',
                      stepBadge: '1단계 먼저',
                      subtitle: '낱말·조각 조립',
                      icon: Icons.dashboard_customize_rounded,
                      isSelected: !isChar,
                      color: sbColor,
                      onTap: () => setState(() => _studyMode = SbStudyMode.word),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _modeTabButton(
                      key: const ValueKey('sb-mode-char'),
                      title: '글자별 선택',
                      stepBadge: '2단계 다음',
                      subtitle: '글자 하나하나 탭',
                      icon: Icons.psychology_rounded,
                      isSelected: isChar,
                      color: _sbHard,
                      onTap: () => setState(() => _studyMode = SbStudyMode.char),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 14),

              // ── 레벨 선택 (N4 / N3) ──
              Row(children: [
                const Text('레벨: ',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Washi.inkSoft)),
                const SizedBox(width: 4),
                for (final lv in ['N4', 'N3']) ...[
                  ChoiceChip(
                    key: ValueKey('sb-level-$lv'),
                    label: Text(lv),
                    selected: _level == lv,
                    showCheckmark: false,
                    selectedColor: isChar ? _sbHard.withValues(alpha: 0.15) : _sbSoft,
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _level == lv ? activeColor : null,
                    ),
                    onSelected: (_) => setState(() => _level = lv),
                  ),
                  const SizedBox(width: 6),
                ],
              ]),
              const SizedBox(height: 10),

              // ── 퀵 실행 버튼 (랜덤 퀴즈 / 틀린 문장 복습) ──
              Row(children: [
                Expanded(
                  child: FilledButton.icon(
                    key: const ValueKey('sb-random'),
                    style: FilledButton.styleFrom(
                      backgroundColor: activeColor,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: () => isChar
                        ? _start('$_level 글자 도전 5문제', _randomCharSteps(), isCharMode: true)
                        : _start('$_level 단어 랜덤 10문제', _randomWordSteps(), isCharMode: false),
                    icon: Icon(isChar ? Icons.psychology_rounded : Icons.shuffle_rounded),
                    label: Text(isChar ? '$_level 글자 랜덤 5문제' : '$_level 단어 랜덤 10문제'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const ValueKey('sb-wrong'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      side: BorderSide(color: activeColor),
                      foregroundColor: activeColor,
                    ),
                    onPressed: p.wrong.isEmpty
                        ? null
                        : () => _start(
                              isChar ? '틀린 문장 글자 복습' : '틀린 문장 복습',
                              _wrongSteps(charMode: isChar),
                              isCharMode: isChar,
                            ),
                    icon: const Icon(Icons.replay_rounded),
                    label: Text('틀린 문장 ${p.wrong.length}'),
                  ),
                ),
              ]),
              const SizedBox(height: 18),

              // ── 문법 레슨 목록 ──
              SectionTitle(
                isChar ? '$_level 문법 (글자별 탭)' : '$_level 문법 (단어별 조립)',
                trailing: '${lessons.length}강',
              ),
              const SizedBox(height: 10),
              for (var k = 0; k < lessons.length; k++) ...[
                _lessonTile(lessons[k], k + 1, p, isChar: isChar),
                const SizedBox(height: 8),
              ],
            ]),
    );
  }

  /// 단어별/글자별 상단 모드 메뉴 탭 버튼
  Widget _modeTabButton({
    required Key key,
    required String title,
    required String stepBadge,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 18, color: isSelected ? Colors.white : color),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? Colors.white : Colors.black87,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.22)
                    : color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                stepBadge,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? Colors.white : color,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11.5,
              color: isSelected ? Colors.white70 : Washi.inkSoft,
            ),
          ),
        ]),
      ),
    );
  }

  Widget _lessonTile(SbLesson l, int no, SbProgress p, {required bool isChar}) {
    final best = isChar ? p.bestChar(l.id) : p.bestWord(l.id);
    final total = isChar ? l.items.length : l.items.length * 3;
    final mainColor = isChar ? _sbHard : sbColor;
    final softColor = isChar ? _sbHard.withValues(alpha: 0.12) : _sbSoft;

    return PaperCard(
      key: ValueKey('sb-lesson-${l.id}'),
      onTap: () => _start(
        '${l.pattern} (${isChar ? '글자별' : '단어별'})',
        isChar ? _lessonCharSteps(l) : _lessonWordSteps(l),
        lesson: l,
        isCharMode: isChar,
      ),
      padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
      child: Row(children: [
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: best == total && total > 0 ? mainColor : softColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: best == total && total > 0
              ? const Icon(Icons.check_rounded, color: Colors.white)
              : Text('$no',
                  style: TextStyle(color: mainColor, fontWeight: FontWeight.w900)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(l.pattern,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: softColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isChar ? '글자별' : '단어별',
                  style: TextStyle(
                      fontSize: 10.5, fontWeight: FontWeight.w700, color: mainColor),
                ),
              ),
            ]),
            const SizedBox(height: 2),
            Text(l.meaning, style: const TextStyle(fontSize: 12.5, color: Washi.inkSoft)),
          ]),
        ),
        const SizedBox(width: 8),
        Text(best < 0 ? '시작 전' : '최고 $best/$total',
            style: TextStyle(
                fontSize: 12,
                color: best == total && total > 0 ? mainColor : Washi.inkSoft,
                fontWeight: FontWeight.w700)),
        const Icon(Icons.chevron_right_rounded, color: Washi.inkSoft),
      ]),
    );
  }
}

// ───────────────────────────── 연습 ─────────────────────────────

class SbPracticePage extends StatefulWidget {
  const SbPracticePage(
      {super.key,
      required this.title,
      required this.steps,
      required this.progress,
      required this.speak,
      this.lesson,
      this.isCharMode = false});
  final String title;
  final List<SbStep> steps;
  final SbProgress progress;
  final SbSpeak speak;
  final SbLesson? lesson;
  final bool isCharMode;

  @override
  State<SbPracticePage> createState() => _SbPracticePageState();
}

class _SbPracticePageState extends State<SbPracticePage> {
  final _rnd = Random();
  int _at = 0;
  int _right = 0;
  final List<SbStep> _missed = [];
  bool _done = false;

  // mode 0·1·2 공통: 낱말 배열용
  List<int> _pool = []; // 남은 조각 번호(tiles 기준)
  List<int> _answer = []; // 고른 조각 번호
  List<String> _tiles = [];
  bool? _ok; // null: 아직, true/false: 채점됨
  bool _showAnswer = false; // 정답 미리 보기

  // mode 3 전용: 글자 하나하나 탭
  List<String> _charPool = []; // 남은 글자 목록 (셔플됨)
  List<int> _charPoolIdx = []; // charPool 원본 인덱스 (중복 글자 구분용)
  List<String> _charAnswer = []; // 순서대로 고른 글자
  List<int> _charAnswerIdx = []; // charAnswer 원본 인덱스
  List<String> _targetChars = []; // 정답 글자 목록 (순서 있음)

  SbStep get _step => widget.steps[_at];

  /// 2026-10-17 문제 화면에서 「글자별 선택」으로 바꿔 풀 수 있게 하는 덮어쓰기 모드.
  int? _modeOverride;
  int get _mode => _modeOverride ?? _step.mode;

  /// 채점 전이면 지금 문제를 낱말 조립 ↔ 글자별 선택으로 바꾼다.
  void _switchMode(int mode) {
    if (_ok != null || mode == _mode) return;
    setState(() {
      _modeOverride = mode == _step.mode ? null : mode;
      _prepare();
    });
  }

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _say(String t) async {
    try {
      await widget.speak(t);
    } catch (_) {}
  }

  void _prepare() {
    final s = _step;
    _ok = null;
    _showAnswer = false;
    if (_mode == 3) {
      // 글자 하나하나 탭 모드: 문장의 모든 글자를 낱자로 분해
      _targetChars = splitToChars(s.item.japanese);
      final indexed = List.generate(_targetChars.length, (i) => i)..shuffle(_rnd);
      _charPoolIdx = indexed;
      _charPool = [for (final i in indexed) _targetChars[i]];
      _charAnswer = [];
      _charAnswerIdx = [];
      _tiles = [];
      _pool = [];
      _answer = [];
    } else {
      // mode 0·1·2: 전체 조각 + 오답 1개 섞음
      _tiles = [...s.item.chunks, s.item.wrongs.first];
      _pool = List.generate(_tiles.length, (i) => i)..shuffle(_rnd);
      _answer = [];
      _charPool = [];
      _charAnswer = [];
      _charPoolIdx = [];
      _charAnswerIdx = [];
      _targetChars = [];
      if (_mode == 2) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _say(s.item.japanese));
      }
    }
  }

  Future<void> _grade(bool ok) async {
    final s = _step;
    setState(() => _ok = ok);
    if (ok) {
      _right++;
      await widget.progress.clearWrong(sbKey(s.lesson, s.index));
    } else {
      _missed.add(s);
      await widget.progress.markWrong(sbKey(s.lesson, s.index));
    }
    _say(s.item.japanese);
  }

  Future<void> _accept() async {
    // 다른 순서로도 맞는 문장일 때 스스로 인정.
    final s = _step;
    _missed.remove(s);
    _right++;
    await widget.progress.clearWrong(sbKey(s.lesson, s.index));
    if (mounted) setState(() => _ok = true);
  }

  Future<void> _next() async {
    if (_at >= widget.steps.length - 1) {
      final l = widget.lesson;
      if (l != null) {
        if (widget.isCharMode) {
          await widget.progress.saveBestChar(l.id, _right);
        } else {
          await widget.progress.saveBestWord(l.id, _right);
        }
      }
      setState(() => _done = true);
      return;
    }
    setState(() {
      _at++;
      _modeOverride = null;
      _prepare();
    });
  }

  void _restart() {
    setState(() {
      _at = 0;
      _right = 0;
      _missed.clear();
      _done = false;
      _modeOverride = null;
      _prepare();
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Washi.paper,
        appBar: washiAppBar(
            title: widget.title,
            subtitle: widget.isCharMode ? '2단계 · 글자별 탭' : '1단계 · 단어별 조립'),
        body: _done ? _result() : _question(),
      );

  Widget _question() {
    final s = _step;
    const modeName = ['낱말 조립', '조각 배열', '듣고 배열', '글자 탭'];
    final modeColor = [sbColor, sbColor, sbColor, _sbHard];
    final mc = modeColor[_mode.clamp(0, 3)];
    return ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 30), children: [
      Row(children: [
        Text('${_at + 1} / ${widget.steps.length}',
            style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(width: 10),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
                minHeight: 7,
                value: (_at + 1) / widget.steps.length,
                backgroundColor: _sbSoft,
                color: mc),
          ),
        ),
      ]),
      const SizedBox(height: 12),
      Wrap(spacing: 6, children: [
        // 2026-10-17 낱말 조립(또는 원래 방식) 옆에 「글자별 선택」 버튼.
        for (final (m, label) in [
          (_step.mode == 3 ? 0 : _step.mode, modeName[_step.mode == 3 ? 0 : _step.mode]),
          (3, '글자별 선택'),
        ])
          ChoiceChip(
            key: ValueKey('sb-mode-$m'),
            visualDensity: VisualDensity.compact,
            showCheckmark: false,
            selected: _mode == m,
            selectedColor: m == 3 ? _sbHard.withValues(alpha: 0.15) : _sbSoft,
            label: Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: m == 3 ? _sbHard : sbColor,
                    fontWeight: _mode == m ? FontWeight.w800 : FontWeight.normal)),
            onSelected: _ok != null ? null : (_) => _switchMode(m),
          ),
        Chip(
            visualDensity: VisualDensity.compact,
            label: Text('${s.lesson.level} · ${s.lesson.pattern}',
                style: const TextStyle(fontSize: 12))),
      ]),
      const SizedBox(height: 8),
      ...(_mode == 3 ? _charMode(s) : _arrange(s)),
      if (_ok != null) ...[const SizedBox(height: 12), _feedback(s)],
    ]);
  }

  // ───── 글자 하나하나 탭 모드 (mode 3) ─────
  List<Widget> _charMode(SbStep s) {
    final it = s.item;
    final targetLen = _targetChars.length;
    final filledCount = _charAnswer.length;

    return [
      PaperCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(it.ko,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, height: 1.4)),
            ),
            IconButton(
              onPressed: () => _say(it.japanese),
              style: IconButton.styleFrom(
                  backgroundColor: _ok != null ? _sbHard : _sbSoft,
                  foregroundColor: _ok != null ? Colors.white : _sbHard),
              icon: const Icon(Icons.volume_up_rounded, size: 22),
              tooltip: '음성 듣기',
            ),
          ]),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _sbHard.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.psychology_rounded, size: 13, color: _sbHard),
              const SizedBox(width: 4),
              Text('글자 $filledCount / $targetLen',
                  style: TextStyle(
                      fontSize: 11, color: _sbHard, fontWeight: FontWeight.w700)),
            ]),
          ),
          const SizedBox(height: 12),
          // ── 답 조립 영역 ──
          Container(
            key: const ValueKey('sb-char-answer'),
            constraints: const BoxConstraints(minHeight: 72),
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: _ok == null
                    ? _sbHard.withValues(alpha: 0.06)
                    : _ok!
                        ? Washi.matcha.withValues(alpha: 0.12)
                        : Washi.shu.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: _ok == null
                        ? _sbHard.withValues(alpha: 0.3)
                        : _ok!
                            ? Washi.matcha.withValues(alpha: 0.5)
                            : Washi.shu.withValues(alpha: 0.5),
                    width: 1.5)),
            child: _charAnswer.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('아래 글자를 순서대로 탭하세요',
                        style: TextStyle(color: Washi.inkSoft, fontSize: 13)))
                : Wrap(spacing: 4, runSpacing: 4, children: [
                    for (var k = 0; k < _charAnswer.length; k++)
                      _charTile(
                        _charAnswer[k],
                        filled: true,
                        // 2026-10-17 채점 후에도 맞는 자리 초록·틀린 자리 빨강으로 남긴다.
                        isCorrectPos: k < _targetChars.length &&
                            _charAnswer[k] == _targetChars[k],
                        onTap: _ok != null
                            ? null
                            : () => setState(() {
                                  final removedIdx = _charAnswerIdx[k];
                                  _charPool.add(_charAnswer[k]);
                                  _charPoolIdx.add(removedIdx);
                                  _charAnswer.removeAt(k);
                                  _charAnswerIdx.removeAt(k);
                                }),
                      ),
                  ]),
          ),
          // ── 정답 보기 (채점 전) ──
          if (_ok == null) ...[
            const SizedBox(height: 8),
            Row(children: [
              GestureDetector(
                onTap: () => setState(() => _showAnswer = !_showAnswer),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(_showAnswer ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                      size: 16, color: Washi.inkSoft),
                  const SizedBox(width: 4),
                  Text(_showAnswer ? '정답 숨기기' : '정답 보기',
                      style: const TextStyle(fontSize: 12, color: Washi.inkSoft)),
                ]),
              ),
            ]),
            if (_showAnswer) ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.5))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(it.japanese,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF7B5800))),
                  const SizedBox(height: 2),
                  Text(it.reading,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF9E7000))),
                ]),
              ),
            ],
          ],
        ]),
      ),
      const SizedBox(height: 12),
      const Text('글자를 정확한 순서로 하나씩 탭하세요',
          style: TextStyle(fontSize: 12, color: Washi.inkSoft)),
      const SizedBox(height: 8),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (var k = 0; k < _charPool.length; k++)
          _charTile(
            _charPool[k],
            onTap: _ok != null
                ? null
                : () => setState(() {
                      _charAnswer.add(_charPool[k]);
                      _charAnswerIdx.add(_charPoolIdx[k]);
                      _charPool.removeAt(k);
                      _charPoolIdx.removeAt(k);
                    }),
          ),
      ]),
      if (_ok == null) ...[
        const SizedBox(height: 12),
        Row(children: [
          TextButton(
              onPressed: _charAnswer.isEmpty
                  ? null
                  : () => setState(() {
                        _charPool.addAll(_charAnswer);
                        _charPoolIdx.addAll(_charAnswerIdx);
                        _charAnswer = [];
                        _charAnswerIdx = [];
                      }),
              child: const Text('다시 놓기')),
          const Spacer(),
          FilledButton(
              key: const ValueKey('sb-char-check'),
              style: FilledButton.styleFrom(backgroundColor: _sbHard),
              onPressed: _charAnswer.length != _targetChars.length
                  ? null
                  : () => _grade(_charAnswer.join() == it.japanese),
              child: const Text('확인')),
        ]),
      ],
      const SizedBox(height: 14),
      _wordList(it),
    ];
  }

  /// 2026-10-17 글자별 선택: 이 문장의 주요 단어와 뜻(누르면 발음).
  Widget _wordList(SbItem it) {
    final words = sbWordsFor(it.japanese);
    if (words.isEmpty) return const SizedBox.shrink();
    return PaperCard(
      key: const ValueKey('sb-char-words'),
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('주요 단어 ${words.length}개',
            style: const TextStyle(
                fontWeight: FontWeight.w800, color: _sbHard, fontSize: 13.5)),
        const SizedBox(height: 4),
        for (final w in words)
          InkWell(
            onTap: () => _say(w.word),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                SizedBox(
                  width: 110,
                  child: Text(w.word,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                ),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(w.reading,
                        style: const TextStyle(fontSize: 12, color: Washi.inkSoft)),
                    Text(w.meaning, style: const TextStyle(fontSize: 13.5)),
                  ]),
                ),
                const Icon(Icons.volume_up_rounded, size: 18, color: _sbHard),
              ]),
            ),
          ),
      ]),
    );
  }

  // ───── 낱말 탭 조립 / 조각 배열 / 듣고 배열 (mode 0·1·2 통합) ─────
  List<Widget> _arrange(SbStep s) {
    final it = s.item;
    final listen = _mode == 2;
    return [
      PaperCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── 문제 헤더 ──
          if (listen) ...[
            Row(children: [
              const Expanded(
                  child: Text('잘 듣고 들린 순서대로 낱말을 누르세요',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
              IconButton.filled(
                  style: IconButton.styleFrom(backgroundColor: sbColor),
                  onPressed: () => _say(it.japanese),
                  icon: const Icon(Icons.volume_up_rounded)),
            ]),
            if (_ok != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(it.ko, style: const TextStyle(fontSize: 14, color: Washi.inkSoft)),
              ),
          ] else ...[
            // mode 0·1: 한국어 보여주고 + 음성 버튼
            Row(children: [
              Expanded(
                child: Text(it.ko,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, height: 1.4)),
              ),
              // 음성 버튼 - 채점 전에는 흐리게, 채점 후엔 활성화
              IconButton(
                onPressed: () => _say(it.japanese),
                style: IconButton.styleFrom(
                    backgroundColor: _ok != null ? sbColor : _sbSoft,
                    foregroundColor: _ok != null ? Colors.white : sbColor),
                icon: const Icon(Icons.volume_up_rounded, size: 22),
                tooltip: '음성 듣기',
              ),
            ]),
          ],
          const SizedBox(height: 12),
          // ── 답 조립 영역 ──
          Container(
            key: const ValueKey('sb-answer'),
            constraints: const BoxConstraints(minHeight: 64),
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: _ok == null
                    ? _sbSoft
                    : _ok!
                        ? Washi.matcha.withValues(alpha: 0.12)
                        : Washi.shu.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12)),
            child: _answer.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(10),
                    child: Text('아래 낱말을 순서대로 누르세요',
                        style: TextStyle(color: Washi.inkSoft, fontSize: 13)))
                : Wrap(spacing: 6, runSpacing: 6, children: [
                    for (final (pos, i) in _answer.indexed)
                      _tile(_tiles[i], filled: true,
                          // 2026-10-17 확인 후: 제자리 초록, 틀린 자리·함정 빨강.
                          isCorrectPos: _ok == null
                              ? null
                              : pos < _step.item.chunks.length &&
                                  _tiles[i] == _step.item.chunks[pos],
                          onTap: _ok != null
                              ? null
                              : () => setState(() {
                                    _answer.remove(i);
                                    _pool.add(i);
                                  })),
                  ]),
          ),
          // ── 정답 보기 (채점 전) ──
          if (_ok == null) ...[
            const SizedBox(height: 8),
            Row(children: [
              GestureDetector(
                onTap: () => setState(() => _showAnswer = !_showAnswer),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(_showAnswer ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                      size: 16, color: Washi.inkSoft),
                  const SizedBox(width: 4),
                  Text(_showAnswer ? '정답 숨기기' : '정답 보기',
                      style: const TextStyle(fontSize: 12, color: Washi.inkSoft)),
                ]),
              ),
            ]),
            if (_showAnswer) ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.5))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(it.japanese,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF7B5800))),
                  const SizedBox(height: 2),
                  Text(it.reading,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF9E7000))),
                ]),
              ),
            ],
          ],
        ]),
      ),
      const SizedBox(height: 12),
      // ── 낱말 풀 (선택 안 된 조각들) ──
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final i in _pool)
          _tile(_tiles[i],
              onTap: _ok != null
                  ? null
                  : () => setState(() {
                        _pool.remove(i);
                        _answer.add(i);
                      })),
      ]),
      const SizedBox(height: 6),
      const Text('낱말 하나는 함정이에요. 필요 없는 낱말은 남겨 두세요.',
          style: TextStyle(fontSize: 12, color: Washi.inkSoft)),
      if (_ok == null) ...[
        const SizedBox(height: 12),
        Row(children: [
          TextButton(
              onPressed: _answer.isEmpty
                  ? null
                  : () => setState(() {
                        _pool.addAll(_answer);
                        _answer = [];
                      }),
              child: const Text('다시 놓기')),
          const Spacer(),
          FilledButton(
              key: const ValueKey('sb-check'),
              style: FilledButton.styleFrom(backgroundColor: sbColor),
              onPressed: _answer.length != it.chunks.length
                  ? null
                  : () => _grade(_answer.map((i) => _tiles[i]).join() == it.japanese),
              child: const Text('확인')),
        ]),
      ],
    ];
  }

  // 2026-10-17 낱말 조각을 3D 블록으로(누르면 눌리고, 놓이면 튀어나옴).
  Widget _tile(String text,
          {bool filled = false, bool? isCorrectPos, VoidCallback? onTap}) =>
      Tile3D(
        key: ValueKey('sb-tile-$text'),
        label: text,
        onTap: onTap,
        face: isCorrectPos == null
            ? (filled ? const Color(0xFFDDF1EE) : Colors.white)
            : isCorrectPos
                ? const Color(0xFFE3F4EA)
                : const Color(0xFFFBE4E0),
        edge: isCorrectPos == null
            ? (filled ? const Color(0xFF1F5C59) : const Color(0xFFB9C4C3))
            : isCorrectPos
                ? const Color(0xFF2E7A50)
                : const Color(0xFFB2412F),
        border: isCorrectPos == null
            ? (filled ? sbColor : null)
            : isCorrectPos
                ? Washi.matcha
                : Washi.shu,
        textColor: isCorrectPos == null
            ? (filled ? const Color(0xFF14403E) : Washi.ink)
            : isCorrectPos
                ? const Color(0xFF1E5A3A)
                : const Color(0xFF9A2E20),
      );

  /// 글자별 탭 모드 전용 타일.
  /// [isCorrectPos]: null=미채점, true/false=실시간 위치 힌트(입력 중).
  Widget _charTile(String char,
      {bool filled = false, bool? isCorrectPos, VoidCallback? onTap}) {
    final Color borderColor;
    final Color bgColor;

    if (filled && isCorrectPos != null) {
      borderColor = isCorrectPos ? Washi.matcha : Washi.shu.withValues(alpha: 0.7);
      bgColor = isCorrectPos
          ? Washi.matcha.withValues(alpha: 0.08)
          : Washi.shu.withValues(alpha: 0.05);
    } else if (filled) {
      borderColor = _sbHard;
      bgColor = _sbHard.withValues(alpha: 0.06);
    } else {
      borderColor = _sbHard.withValues(alpha: 0.4);
      bgColor = Colors.white;
    }

    // 2026-10-17 글자 조각도 3D 블록(정답 위치 초록·틀린 위치 빨강 옆면).
    final Color edge = filled && isCorrectPos != null
        ? (isCorrectPos ? const Color(0xFF2E7A50) : const Color(0xFFB2412F))
        : filled
            ? const Color(0xFF243B8F)
            : const Color(0xFFB8C4E8);
    return Tile3D(
      label: char,
      onTap: onTap,
      face: filled ? Color.lerp(bgColor, Colors.white, 0.4)! : Colors.white,
      edge: edge,
      border: borderColor,
      textColor: filled ? _sbHard : Colors.black87,
      fontSize: 20,
      depth: 4,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    );
  }

  Widget _feedback(SbStep s) {
    final it = s.item;
    final ok = _ok!;
    return PaperCard(
      key: const ValueKey('sb-feedback'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
              color: ok ? Washi.matcha : Washi.shu),
          const SizedBox(width: 6),
          Text(ok ? '정답이에요!' : '아쉬워요. 정답을 확인하세요',
              style: TextStyle(
                  fontWeight: FontWeight.w800, color: ok ? Washi.matcha : Washi.shu)),
        ]),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _say(it.japanese),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(it.japanese,
                    style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
                Text(it.reading, style: const TextStyle(fontSize: 12.5, color: Washi.inkSoft)),
                Text(it.ko, style: const TextStyle(fontSize: 13.5)),
              ]),
            ),
            const Icon(Icons.volume_up_rounded, color: sbColor),
          ]),
        ),
        const Divider(height: 20),
        Text('${s.lesson.pattern}  ${s.lesson.meaning}',
            style: const TextStyle(fontWeight: FontWeight.w800, color: sbColor, fontSize: 13)),
        const SizedBox(height: 2),
        Text(s.lesson.point, style: const TextStyle(fontSize: 13, height: 1.5)),
        const SizedBox(height: 12),
        Row(children: [
          if (!ok && _mode != 0 && _mode != 3)
            TextButton(onPressed: _accept, child: const Text('다른 순서지만 맞아요')),
          const Spacer(),
          FilledButton(
              key: const ValueKey('sb-next'),
              style: FilledButton.styleFrom(
                  backgroundColor: _mode == 3 ? _sbHard : sbColor),
              onPressed: _next,
              child: Text(_at >= widget.steps.length - 1 ? '결과 보기' : '다음')),
        ]),
      ]),
    );
  }

  Widget _result() {
    final total = widget.steps.length;
    final missed = <String, SbStep>{};
    for (final m in _missed) {
      missed[sbKey(m.lesson, m.index)] = m;
    }
    final primaryColor = widget.isCharMode ? _sbHard : sbColor;

    return ListView(padding: const EdgeInsets.fromLTRB(18, 10, 18, 30), children: [
      PaperCard(
        child: Column(children: [
          Text('$_right / $total',
              style: TextStyle(
                  fontSize: 40, fontWeight: FontWeight.w900, color: primaryColor)),
          Text(_right == total
              ? '모두 맞혔어요! 다음 문법으로 넘어가세요.'
              : '틀린 문장은 「틀린 문장 복습」에 모아 두었어요.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Washi.inkSoft)),
        ]),
      ),
      if (missed.isNotEmpty) ...[
        const SizedBox(height: 16),
        const SectionTitle('다시 볼 문장'),
        const SizedBox(height: 8),
        for (final m in missed.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: PaperCard(
              onTap: () => _say(m.item.japanese),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(m.item.japanese,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    Text(m.item.ko, style: const TextStyle(fontSize: 12.5, color: Washi.inkSoft)),
                  ]),
                ),
                Icon(Icons.volume_up_rounded, color: primaryColor),
              ]),
            ),
          ),
      ],
      const SizedBox(height: 16),
      Row(children: [
        Expanded(
            child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  side: BorderSide(color: primaryColor),
                  foregroundColor: primaryColor,
                ),
                onPressed: _restart,
                child: const Text('다시 하기'))),
        const SizedBox(width: 8),
        Expanded(
            child: FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: primaryColor, minimumSize: const Size.fromHeight(48)),
                onPressed: () => Navigator.pop(context),
                child: const Text('목록으로'))),
      ]),
    ]);
  }
}
