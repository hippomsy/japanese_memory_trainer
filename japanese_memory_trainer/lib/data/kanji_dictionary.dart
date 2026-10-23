import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:kioku_japanese/models/vocabulary.dart';

/// 2026-09-29 한자 한 글자의 풀이. 한국식 훈음(예: 배울 학)과 일본어 음독·훈독,
/// 획수, JLPT 급수를 함께 담는다.
class KanjiInfo {
  const KanjiInfo({
    required this.kanji,
    required this.hun,
    required this.eum,
    this.koreanForm = '',
    this.note = '',
    this.onReadings = const <String>[],
    this.kunReadings = const <String>[],
    this.strokes,
    this.jlpt,
  });

  final String kanji;

  /// 훈(뜻). 예: 배울
  final String hun;

  /// 음(소리). 예: 학
  final String eum;

  /// 한국에서 쓰는 정자가 일본 신자체와 다르면 그 글자(예: 学 → 學).
  final String koreanForm;

  /// 다른 훈음이나 일본에서만 쓰는 뜻 등 보충 설명.
  final String note;

  /// 음독(가타카나).
  final List<String> onReadings;

  /// 훈독(히라가나, 괄호 안은 오쿠리가나).
  final List<String> kunReadings;
  final int? strokes;
  final int? jlpt;

  /// 예: "배울 학"
  String get hunEum => eum.isEmpty ? hun : '$hun $eum';

  factory KanjiInfo.fromJson(String kanji, Map<String, dynamic> json) {
    List<String> list(Object? v) =>
        (v as List<dynamic>? ?? const <dynamic>[]).cast<String>();
    return KanjiInfo(
      kanji: kanji,
      hun: json['h'] as String? ?? '',
      eum: json['e'] as String? ?? '',
      koreanForm: json['kr'] as String? ?? '',
      note: json['n'] as String? ?? '',
      onReadings: list(json['on']),
      kunReadings: list(json['kun']),
      strokes: json['s'] as int?,
      jlpt: json['j'] as int?,
    );
  }
}

/// 2026-09-29 앱 전체에서 쓰는 한자 사전. main()에서 한 번 [load]하고,
/// 단어 목록을 [attachWords]로 넘겨 "이 한자가 들어간 다른 단어"를 찾는다.
/// 테스트에서는 [KanjiDictionary.instance]에 직접 만든 사전을 넣을 수 있다.
class KanjiDictionary {
  KanjiDictionary(this._entries);

  static const String assetPath = 'assets/kanji/kanji_info.json';

  static KanjiDictionary instance =
      KanjiDictionary(const <String, KanjiInfo>{});

  final Map<String, KanjiInfo> _entries;
  final Map<String, List<Vocabulary>> _wordsByKanji =
      <String, List<Vocabulary>>{};

  int get length => _entries.length;

  static bool isKanji(String ch) {
    if (ch.isEmpty) return false;
    final c = ch.codeUnitAt(0);
    return (c >= 0x4E00 && c <= 0x9FFF) || (c >= 0x3400 && c <= 0x4DBF);
  }

  static Future<KanjiDictionary> load() async {
    final raw = await rootBundle.loadString(assetPath);
    final map = jsonDecode(raw) as Map<String, dynamic>;
    final pdfRaw =
        await rootBundle.loadString('assets/kanji/elementary_pdf_kanji.json');
    final pdf = jsonDecode(pdfRaw) as Map<String, dynamic>;
    for (final entry in pdf.entries) {
      final original = Map<String, dynamic>.from(map[entry.key] as Map? ?? {});
      original.addAll(Map<String, dynamic>.from(entry.value as Map));
      map[entry.key] = original;
    }
    return KanjiDictionary(<String, KanjiInfo>{
      for (final e in map.entries)
        e.key: KanjiInfo.fromJson(e.key, e.value as Map<String, dynamic>),
    });
  }

  KanjiInfo? lookup(String kanji) => _entries[kanji];

  /// 단어에 들어 있는 한자를 순서대로(중복 없이) 풀이한다.
  List<KanjiInfo> breakdown(String japanese) {
    final seen = <String>{};
    final result = <KanjiInfo>[];
    for (final ch in japanese.split('')) {
      if (!isKanji(ch) || !seen.add(ch)) continue;
      final info = _entries[ch];
      if (info != null) result.add(info);
    }
    return result;
  }

  /// 단어 아래에 한 줄로 보여줄 요약. 예: "배울 학 · 날 생"
  String summary(String japanese) =>
      breakdown(japanese).map((k) => k.hunEum).join(' · ');

  void attachWords(List<Vocabulary> words) {
    _wordsByKanji.clear();
    for (final w in words) {
      final seen = <String>{};
      for (final ch in w.japanese.split('')) {
        if (isKanji(ch) && seen.add(ch)) {
          (_wordsByKanji[ch] ??= <Vocabulary>[]).add(w);
        }
      }
    }
    for (final list in _wordsByKanji.values) {
      list.sort((a, b) {
        final byLevel = b.jlptLevel.compareTo(a.jlptLevel); // N5 먼저(쉬운 단어)
        if (byLevel != 0) return byLevel;
        return a.japanese.length.compareTo(b.japanese.length);
      });
    }
  }

  /// [kanji]가 들어간 다른 단어(현재 단어 제외) 최대 [limit]개.
  /// 같은 표기의 단어(자기 자신, 중복 등록)는 빼고 표기별로 한 번만 보여준다.
  List<Vocabulary> relatedWords(String kanji,
      {String? excludeId, String? excludeJapanese, int limit = 3}) {
    final list = _wordsByKanji[kanji] ?? const <Vocabulary>[];
    final seen = <String>{if (excludeJapanese != null) excludeJapanese};
    return list
        .where((w) => w.id != excludeId && seen.add(w.japanese))
        .take(limit)
        .toList();
  }
}
