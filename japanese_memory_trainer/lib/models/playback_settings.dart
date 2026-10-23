import 'dart:convert';

/// 2026-10-20 자동(듣기 카드) 재생 설정이다.
/// 단어(일본어)·뜻(한국어) 각각 켜기/끄기, 반복 횟수(회), 읽은 뒤 쉬는 시간(초), 재생 순서를 정한다.
class PlaybackSettings {
  const PlaybackSettings({
    this.wordOn = true,
    this.meaningOn = true,
    this.wordRepeat = 1,
    this.meaningRepeat = 1,
    this.wordPause = defaultPause,
    this.meaningPause = defaultPause,
    this.meaningFirst = false,
  });

  static const int minRepeat = 1;
  static const int maxRepeat = 9;
  static const int minPause = 1;
  static const int maxPause = 10;

  /// 2026-10-20 기본 쉬는 시간(초). 이 값이면 기존 자동 모드의 쉬는 시간을 그대로 쓴다.
  static const int defaultPause = 1;

  final bool wordOn;
  final bool meaningOn;
  final int wordRepeat;
  final int meaningRepeat;
  final int wordPause;
  final int meaningPause;
  final bool meaningFirst;

  static const PlaybackSettings standard = PlaybackSettings();

  bool get isStandard =>
      wordOn &&
      meaningOn &&
      wordRepeat == 1 &&
      meaningRepeat == 1 &&
      wordPause == defaultPause &&
      meaningPause == defaultPause &&
      !meaningFirst;

  /// 2026-10-20 화면 아래 안내문용 요약(예: "단어 2회 → 뜻 1회").
  String get summary {
    final parts = <String>[
      for (final item in order)
        item == PlaybackItem.word
            ? '단어 $wordRepeat회·$wordPause초'
            : '뜻 $meaningRepeat회·$meaningPause초',
    ];
    return parts.join(' → ');
  }

  /// 2026-10-20 실제로 재생할 항목 순서(꺼진 항목은 빠진다).
  List<PlaybackItem> get order => [
        for (final item in meaningFirst
            ? const [PlaybackItem.meaning, PlaybackItem.word]
            : const [PlaybackItem.word, PlaybackItem.meaning])
          if (isOn(item)) item,
      ];

  bool isOn(PlaybackItem item) =>
      item == PlaybackItem.word ? wordOn : meaningOn;
  int repeatOf(PlaybackItem item) =>
      item == PlaybackItem.word ? wordRepeat : meaningRepeat;
  int pauseOf(PlaybackItem item) =>
      item == PlaybackItem.word ? wordPause : meaningPause;

  PlaybackSettings copyWith({
    bool? wordOn,
    bool? meaningOn,
    int? wordRepeat,
    int? meaningRepeat,
    int? wordPause,
    int? meaningPause,
    bool? meaningFirst,
  }) =>
      PlaybackSettings(
        wordOn: wordOn ?? this.wordOn,
        meaningOn: meaningOn ?? this.meaningOn,
        wordRepeat: (wordRepeat ?? this.wordRepeat).clamp(minRepeat, maxRepeat).toInt(),
        meaningRepeat:
            (meaningRepeat ?? this.meaningRepeat).clamp(minRepeat, maxRepeat).toInt(),
        wordPause: (wordPause ?? this.wordPause).clamp(minPause, maxPause).toInt(),
        meaningPause:
            (meaningPause ?? this.meaningPause).clamp(minPause, maxPause).toInt(),
        meaningFirst: meaningFirst ?? this.meaningFirst,
      );

  /// 2026-10-20 항목 하나만 바꾸는 도우미다.
  PlaybackSettings withItem(PlaybackItem item,
          {bool? on, int? repeat, int? pause}) =>
      item == PlaybackItem.word
          ? copyWith(wordOn: on, wordRepeat: repeat, wordPause: pause)
          : copyWith(meaningOn: on, meaningRepeat: repeat, meaningPause: pause);

  String toJson() => jsonEncode({
        'wordOn': wordOn,
        'meaningOn': meaningOn,
        'wordRepeat': wordRepeat,
        'meaningRepeat': meaningRepeat,
        'wordPause': wordPause,
        'meaningPause': meaningPause,
        'meaningFirst': meaningFirst,
      });

  /// 2026-10-20 저장된 값이 깨졌거나 없으면 기본값을 돌려준다.
  static PlaybackSettings fromJson(String? raw) {
    if (raw == null || raw.isEmpty) return standard;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final settings = const PlaybackSettings().copyWith(
        wordOn: map['wordOn'] as bool?,
        meaningOn: map['meaningOn'] as bool?,
        wordRepeat: (map['wordRepeat'] as num?)?.toInt(),
        meaningRepeat: (map['meaningRepeat'] as num?)?.toInt(),
        wordPause: (map['wordPause'] as num?)?.toInt(),
        meaningPause: (map['meaningPause'] as num?)?.toInt(),
        meaningFirst: map['meaningFirst'] as bool?,
      );
      // 둘 다 꺼진 값은 재생할 것이 없으므로 기본으로 되돌린다.
      if (!settings.wordOn && !settings.meaningOn) return standard;
      return settings;
    } catch (_) {
      return standard;
    }
  }
}

enum PlaybackItem { word, meaning }

extension PlaybackItemLabel on PlaybackItem {
  String get label => this == PlaybackItem.word ? '단어' : '뜻';
}
