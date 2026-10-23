import 'package:flutter/material.dart';
import 'package:kioku_japanese/data/study_store.dart';
import 'package:kioku_japanese/models/playback_settings.dart';
import 'package:kioku_japanese/widgets/study_widgets.dart';

/// 2026-10-20 "재생 항목 및 순서, 반복 변경" 화면이다.
/// 항목마다 [켜기/끄기] [+ 숫자 −] [^ 회/초 v] 를 두고, 회는 반복 횟수, 초는 읽은 뒤 쉬는 시간이다.
/// 바꿀 때마다 바로 저장한다.
class PlaybackSettingsPage extends StatefulWidget {
  const PlaybackSettingsPage({
    super.key,
    required this.store,
    this.accent = Washi.wakatake,
  });

  final StudyStore store;
  final Color accent;

  @override
  State<PlaybackSettingsPage> createState() => _PlaybackSettingsPageState();
}

class _PlaybackSettingsPageState extends State<PlaybackSettingsPage> {
  late PlaybackSettings _settings;

  /// 2026-10-20 항목별로 지금 숫자 칸이 '초'를 편집 중인지(false면 '회').
  final Map<PlaybackItem, bool> _secondsUnit = {
    PlaybackItem.word: false,
    PlaybackItem.meaning: false,
  };

  @override
  void initState() {
    super.initState();
    _settings = widget.store.playback;
  }

  Future<void> _update(PlaybackSettings next) async {
    setState(() => _settings = next);
    await widget.store.setPlayback(next);
  }

  List<PlaybackItem> get _rows => _settings.meaningFirst
      ? const [PlaybackItem.meaning, PlaybackItem.word]
      : const [PlaybackItem.word, PlaybackItem.meaning];

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;
    return Scaffold(
      backgroundColor: Washi.paper,
      appBar: washiAppBar(
        title: '재생 항목 및 순서, 반복 변경',
        actions: [
          TextButton(
            key: const ValueKey('playback-swap-order'),
            onPressed: () =>
                _update(_settings.copyWith(meaningFirst: !_settings.meaningFirst)),
            child: Text('순서 변경',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800, color: accent)),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            for (final item in _rows) ...[
              _row(item, accent),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 6),
            PaperCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('재생 순서',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: accent)),
                  const SizedBox(height: 4),
                  Text(_settings.summary,
                      key: const ValueKey('playback-summary'),
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Washi.ink)),
                  const SizedBox(height: 8),
                  const Text(
                    '· 회: 같은 말을 몇 번 반복해서 읽을지 정합니다.\n'
                    '· 초: 한 번 읽은 뒤 몇 초 쉬었다가 다음으로 넘어갈지 정합니다.\n'
                    '· 오른쪽 ^ v 를 누르면 숫자 칸이 회 ↔ 초로 바뀝니다.\n'
                    '· 단어와 뜻을 모두 끌 수는 없습니다.',
                    style: TextStyle(
                        fontSize: 13, height: 1.5, color: Washi.inkSoft),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                key: const ValueKey('playback-reset'),
                onPressed: _settings.isStandard
                    ? null
                    : () => _update(PlaybackSettings.standard),
                icon: const Icon(Icons.restart_alt),
                label: const Text('기본값으로'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(PlaybackItem item, Color accent) {
    final on = _settings.isOn(item);
    final seconds = _secondsUnit[item]!;
    final value = seconds ? _settings.pauseOf(item) : _settings.repeatOf(item);
    final min = seconds ? PlaybackSettings.minPause : PlaybackSettings.minRepeat;
    final max = seconds ? PlaybackSettings.maxPause : PlaybackSettings.maxRepeat;
    // 다른 항목이 꺼져 있으면 이 항목은 끌 수 없다.
    final otherOn = _settings.isOn(item == PlaybackItem.word
        ? PlaybackItem.meaning
        : PlaybackItem.word);

    void setValue(int next) {
      _update(seconds
          ? _settings.withItem(item, pause: next)
          : _settings.withItem(item, repeat: next));
    }

    void toggleUnit() => setState(() => _secondsUnit[item] = !seconds);

    final key = item.name;
    return PaperCard(
      key: ValueKey('playback-row-$key'),
      padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
      child: Opacity(
        opacity: on ? 1 : 0.55,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.label,
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Washi.ink)),
                  const SizedBox(height: 2),
                  Text(
                    '${_settings.repeatOf(item)}회 · ${_settings.pauseOf(item)}초',
                    key: ValueKey('playback-info-$key'),
                    style: const TextStyle(fontSize: 12, color: Washi.inkSoft),
                  ),
                ],
              ),
            ),
            Switch(
              key: ValueKey('playback-switch-$key'),
              value: on,
              activeTrackColor: accent,
              onChanged: (!on || otherOn)
                  ? (v) => _update(_settings.withItem(item, on: v))
                  : null,
            ),
            const SizedBox(width: 8),
            _SpinBox(
              topIcon: Icons.add,
              bottomIcon: Icons.remove,
              topKey: ValueKey('playback-plus-$key'),
              bottomKey: ValueKey('playback-minus-$key'),
              valueKey: ValueKey('playback-value-$key'),
              text: '$value',
              color: accent,
              onTop: on && value < max ? () => setValue(value + 1) : null,
              onBottom: on && value > min ? () => setValue(value - 1) : null,
            ),
            const SizedBox(width: 8),
            _SpinBox(
              topIcon: Icons.keyboard_arrow_up,
              bottomIcon: Icons.keyboard_arrow_down,
              topKey: ValueKey('playback-unit-up-$key'),
              bottomKey: ValueKey('playback-unit-down-$key'),
              valueKey: ValueKey('playback-unit-$key'),
              text: seconds ? '초' : '회',
              color: accent,
              onTop: on ? toggleUnit : null,
              onBottom: on ? toggleUnit : null,
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 34,
              child: Text(seconds ? '쉬기' : '반복',
                  style: const TextStyle(fontSize: 15, color: Washi.ink)),
            ),
          ],
        ),
      ),
    );
  }
}

/// 2026-10-20 위·가운데·아래 3칸짜리 작은 조절 상자(+ 1 −, ^ 회 v).
class _SpinBox extends StatelessWidget {
  const _SpinBox({
    required this.topIcon,
    required this.bottomIcon,
    required this.topKey,
    required this.bottomKey,
    required this.valueKey,
    required this.text,
    required this.color,
    required this.onTop,
    required this.onBottom,
  });

  final IconData topIcon;
  final IconData bottomIcon;
  final Key topKey;
  final Key bottomKey;
  final Key valueKey;
  final String text;
  final Color color;
  final VoidCallback? onTop;
  final VoidCallback? onBottom;

  @override
  Widget build(BuildContext context) {
    Widget button(IconData icon, Key key, VoidCallback? onTap) => InkWell(
          key: key,
          onTap: onTap,
          child: SizedBox(
            height: 34,
            child: Icon(icon,
                size: 22,
                color: onTap == null ? Washi.line : Washi.inkSoft),
          ),
        );
    return Container(
      width: 52,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Washi.card,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Washi.line),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          button(topIcon, topKey, onTop),
          Container(
            height: 36,
            width: double.infinity,
            color: const Color(0xFFF0F0F0),
            alignment: Alignment.center,
            child: Text(text,
                key: valueKey,
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800, color: color)),
          ),
          button(bottomIcon, bottomKey, onBottom),
        ],
      ),
    );
  }
}
