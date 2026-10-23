import 'dart:convert';
import 'dart:ui' show Offset, Path;

import 'package:flutter/services.dart' show rootBundle;
import 'package:kioku_japanese/data/kanji_dictionary.dart';

/// 2026-10-11 한자 한 글자를 부품(부수·구성 요소)으로 쪼갠 정보.
/// 획 데이터는 KanjiVG(© Ulrich Apel, CC BY-SA 3.0, kanjivg.tagaini.net)를
/// 가공한 것이다.
class KanjiParts {
  const KanjiParts({
    required this.kanji,
    required this.parts,
    required this.strokes,
    required this.strokeParts,
    this.phonetic = -1,
    this.story = '',
  });

  final String kanji;

  /// 부품 글자. ''는 이름 없는 획 묶음.
  final List<String> parts;

  /// SVG 경로(109×109 좌표). 쓰는 순서(획순)대로.
  final List<String> strokes;

  /// 각 획이 몇 번째 부품에 속하는지.
  final List<int> strokeParts;

  /// 소리(음)를 나타내는 부품의 위치. 없으면 -1.
  final int phonetic;

  /// 손으로 쓴 기억 이야기(없으면 '').
  final String story;

  int get strokeCount => strokes.length;

  /// 이름 있는 부품 수.
  int get namedPartCount => parts.where((p) => p.isNotEmpty).length;

  /// 형성자: 뜻 부품 + 소리 부품.
  bool get isPhonoSemantic => phonetic >= 0 && namedPartCount >= 2;

  /// 더 쪼개지지 않는 기본 글자(상형·지사).
  bool get isBasic => namedPartCount == 0;

  String? get phoneticPart =>
      phonetic >= 0 && phonetic < parts.length ? parts[phonetic] : null;

  factory KanjiParts.fromJson(String kanji, Map<String, dynamic> j) =>
      KanjiParts(
        kanji: kanji,
        parts: (j['c'] as List<dynamic>).cast<String>(),
        strokes: (j['s'] as List<dynamic>).cast<String>(),
        strokeParts: (j['i'] as List<dynamic>).cast<int>(),
        phonetic: j['p'] as int? ?? -1,
        story: j['m'] as String? ?? '',
      );
}

/// 2026-10-11 앱 전체의 한자 부품 사전. 처음 쓸 때 한 번 읽는다.
class KanjiPartsBank {
  KanjiPartsBank(this._entries,
      {Map<String, String> names = const {},
      Map<String, String> families = const {}})
      : _names = names,
        _families = families;

  static const String assetPath = 'assets/kanji/kanji_parts.json';

  static KanjiPartsBank? _instance;
  static Future<KanjiPartsBank>? _loading;

  /// 이미 읽어 둔 사전(없으면 null).
  static KanjiPartsBank? get cached => _instance;

  /// 테스트용으로 직접 넣을 수 있다.
  static set instance(KanjiPartsBank bank) {
    _instance = bank;
    _loading = Future.value(bank);
  }

  static Future<KanjiPartsBank> load() => _loading ??= () async {
        try {
          final raw = await rootBundle.loadString(assetPath);
          return _instance = KanjiPartsBank.parse(raw);
        } catch (_) {
          return _instance = KanjiPartsBank(const {});
        }
      }();

  factory KanjiPartsBank.parse(String raw) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    final k = j['k'] as Map<String, dynamic>;
    return KanjiPartsBank(
      {
        for (final e in k.entries)
          e.key: KanjiParts.fromJson(e.key, e.value as Map<String, dynamic>)
      },
      names: (j['names'] as Map<String, dynamic>? ?? const {})
          .map((key, v) => MapEntry(key, v as String)),
      families: (j['fam'] as Map<String, dynamic>? ?? const {})
          .map((key, v) => MapEntry(key, v as String)),
    );
  }

  final Map<String, KanjiParts> _entries;
  final Map<String, String> _names;
  final Map<String, String> _families;

  int get length => _entries.length;

  KanjiParts? operator [](String kanji) => _entries[kanji];

  bool has(String kanji) => _entries.containsKey(kanji);

  /// 부품 이름. 예: 亻 → "사람 인 (인변)", 木 → "나무 목".
  String nameOf(String part) {
    if (part.isEmpty) return '획';
    final own = _names[part];
    if (own != null && own.isNotEmpty) return own;
    final info = KanjiDictionary.instance.lookup(part);
    if (info != null && info.hunEum.isNotEmpty) return info.hunEum;
    return '';
  }

  /// 이름의 첫 뜻만. 예: "사람 인 (인변)" → "사람", "나무 목" → "나무".
  String shortMeaning(String part) {
    var n = nameOf(part).split('(').first.split('/').first.trim();
    final words = n.split(' ');
    if (words.length >= 2) n = words.sublist(0, words.length - 1).join(' ');
    return n;
  }

  /// 같은 소리 부품을 가진 다른 한자들.
  List<String> soundFamily(String kanji) {
    final p = _entries[kanji]?.phoneticPart;
    if (p == null) return const [];
    final f = _families[p] ?? '';
    return [
      for (final ch in f.split(''))
        if (ch != kanji) ch
    ];
  }

  /// 기억 이야기. 손으로 쓴 것이 없으면 부품 뜻으로 만든다.
  String storyOf(String kanji) {
    final p = _entries[kanji];
    if (p == null) return '';
    if (p.story.isNotEmpty) return p.story;
    if (p.isBasic) return '더 쪼개지지 않는 기본 글자예요. 모양을 그림처럼 기억하세요.';
    final named = [
      for (final part in p.parts)
        if (part.isNotEmpty) part
    ];
    final self = KanjiDictionary.instance.lookup(kanji)?.hunEum ?? '';
    if (p.isPhonoSemantic) {
      final sound = p.phoneticPart!;
      final meaning = [
        for (final part in named)
          if (part != sound) '$part(${shortMeaning(part)})'
      ].join(' + ');
      final on = KanjiDictionary.instance.lookup(kanji)?.onReadings ?? const [];
      final reading = on.isEmpty ? '' : ' → 음은 ${on.first}';
      return '뜻은 $meaning 쪽, 소리는 $sound에서$reading${self.isEmpty ? '' : ' · $self'}';
    }
    final joined =
        named.map((part) => '$part(${shortMeaning(part)})').join(' + ');
    return self.isEmpty ? joined : '$joined → $self';
  }
}

/// 2026-10-11 KanjiVG 경로(d)를 Flutter Path로 바꾼다. M m C c S s L l 지원.
Path parseSvgPath(String d) {
  final path = Path();
  final tokens = RegExp(r'[MmCcSsLlZz]|-?(?:\d+\.?\d*|\.\d+)(?:e-?\d+)?')
      .allMatches(d)
      .map((m) => m.group(0)!)
      .toList();
  var i = 0;
  var cmd = 'M';
  var cur = Offset.zero;
  var start = Offset.zero;
  Offset? lastCtrl;
  double num() => double.parse(tokens[i++]);
  bool isCmd(String t) => RegExp(r'^[A-Za-z]$').hasMatch(t);
  while (i < tokens.length) {
    if (isCmd(tokens[i])) cmd = tokens[i++];
    switch (cmd) {
      case 'M':
      case 'm':
        final p = Offset(num(), num());
        cur = cmd == 'm' ? cur + p : p;
        start = cur;
        path.moveTo(cur.dx, cur.dy);
        cmd = cmd == 'm' ? 'l' : 'L';
        lastCtrl = null;
        break;
      case 'L':
      case 'l':
        final p = Offset(num(), num());
        cur = cmd == 'l' ? cur + p : p;
        path.lineTo(cur.dx, cur.dy);
        lastCtrl = null;
        break;
      case 'C':
      case 'c':
        var c1 = Offset(num(), num());
        var c2 = Offset(num(), num());
        var e = Offset(num(), num());
        if (cmd == 'c') {
          c1 += cur;
          c2 += cur;
          e += cur;
        }
        path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, e.dx, e.dy);
        lastCtrl = c2;
        cur = e;
        break;
      case 'S':
      case 's':
        final c1 = lastCtrl == null ? cur : cur * 2 - lastCtrl;
        var c2 = Offset(num(), num());
        var e = Offset(num(), num());
        if (cmd == 's') {
          c2 += cur;
          e += cur;
        }
        path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, e.dx, e.dy);
        lastCtrl = c2;
        cur = e;
        break;
      case 'Z':
      case 'z':
        path.close();
        cur = start;
        lastCtrl = null;
        break;
      default:
        i++;
    }
  }
  return path;
}
