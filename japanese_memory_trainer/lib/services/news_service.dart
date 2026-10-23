import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:kioku_japanese/models/vocabulary.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 2026-10-01 기사 속 한 조각(단어). [parts]는 (글자, 후리가나) 쌍이고 한자 부분에만 후리가나가 있다.
class NewsToken {
  const NewsToken(
      {required this.parts,
      this.level,
      this.word,
      this.base,
      this.meaning = '',
      this.reading = ''});
  final String meaning;
  final String reading;

  final List<(String, String)> parts;

  /// JLPT 급수(5~1). 단어장에 있는 내용어만 값이 있다.
  final int? level;

  /// 단어장 표제어(사전형).
  final String? word;

  /// 형태소 분석으로 얻은 사전형(앱이 단어장에서 급수를 찾을 때 쓴다).
  final String? base;

  NewsToken withLevel(int level, String word) => NewsToken(
      parts: parts,
      level: level,
      word: word,
      base: base,
      meaning: meaning,
      reading: reading);

  String get text => parts.map((p) => p.$1).join();

  factory NewsToken.fromJson(Map<String, dynamic> json) {
    final parts = <(String, String)>[
      for (final p in json['p'] as List<dynamic>)
        ((p as List<dynamic>)[0] as String, p.length > 1 ? p[1] as String : ''),
    ];
    return NewsToken(
      parts: parts,
      level: json['lv'] as int?,
      word: json['w'] as String?,
      base: json['b'] as String?,
      meaning: json['meaning'] as String? ?? '',
      reading: json['reading'] as String? ?? '',
    );
  }
}

class NewsParagraph {
  const NewsParagraph({required this.tokens, required this.korean});

  final List<NewsToken> tokens;
  final String korean;

  String get japanese => tokens.map((t) => t.text).join();
}

class NewsWord {
  const NewsWord(
      {required this.japanese,
      required this.reading,
      required this.korean,
      required this.level});

  final String japanese;
  final String reading;
  final String korean;
  final int level;

  factory NewsWord.fromJson(Map<String, dynamic> json) => NewsWord(
        japanese: json['jp'] as String,
        reading: json['reading'] as String? ?? '',
        korean: json['ko'] as String? ?? '',
        level: json['lv'] as int,
      );
}

class NewsQuestion {
  const NewsQuestion(
      {required this.prompt,
      required this.options,
      required this.answer,
      required this.explanation});
  final String prompt;
  final List<String> options;
  final int answer;
  final String explanation;
  factory NewsQuestion.fromJson(Map<String, dynamic> json) => NewsQuestion(
      prompt: json['prompt'] as String,
      options: (json['options'] as List).cast<String>(),
      answer: json['answer'] as int,
      explanation: json['explanation'] as String);
  Map<String, dynamic> toJson() => {
        'prompt': prompt,
        'options': options,
        'answer': answer,
        'explanation': explanation
      };
}

NewsQuestion? vocabularyQuestion(
    List<NewsWord> words, List<NewsParagraph> paragraphs) {
  final candidates = words.where((w) => w.korean.isNotEmpty).toList();
  if (candidates.isEmpty) return null;
  final word = candidates.first;
  final options = <String>[word.korean];
  for (final meaning in [
    ...candidates.skip(1).map((w) => w.korean),
    '약속을 취소하다',
    '물건을 수리하다',
    '아침에 운동하다',
    '주말에 여행하다'
  ]) {
    if (!options.contains(meaning)) options.add(meaning);
    if (options.length == 4) break;
  }
  final sentence = paragraphs
      .where((p) => p.tokens.any((t) => t.word == word.japanese))
      .firstOrNull;
  final position = word.japanese.runes.fold<int>(0, (a, b) => a + b) % 4;
  final correct = options.removeAt(0);
  options.insert(position, correct);
  return NewsQuestion(
      prompt: '글에서 「${word.japanese}」는 어떤 뜻인가요?',
      options: options,
      answer: position,
      explanation:
          '「${word.japanese}」(${word.reading})는 “${word.korean}”라는 뜻입니다.${sentence == null ? '' : '\n${sentence.japanese}\n${sentence.korean}'}');
}

/// 2026-10-01 쉬운 일본어 뉴스 기사 한 편.
class NewsArticle {
  const NewsArticle({
    required this.id,
    required this.date,
    required this.category,
    required this.title,
    required this.titleKorean,
    required this.paragraphs,
    required this.distribution,
    required this.words,
    this.source = '',
    this.question,
  });

  final String id;
  final String date;
  final String category;
  final List<NewsToken> title;
  final String titleKorean;
  final List<NewsParagraph> paragraphs;

  /// N5~N1 단어 수.
  final Map<String, int> distribution;
  final List<NewsWord> words;
  final String source;
  final NewsQuestion? question;

  Map<String, dynamic> toJson() {
    Map<String, dynamic> token(NewsToken t) => {
          'p': [
            for (final p in t.parts) [p.$1, p.$2]
          ],
          if (t.level != null) 'lv': t.level,
          if (t.word != null) 'w': t.word,
          if (t.base != null) 'b': t.base,
          'meaning': t.meaning,
          'reading': t.reading,
        };
    return {
      'id': id,
      'date': date,
      'category': category,
      'title': title.map(token).toList(),
      'titleKo': titleKorean,
      'paragraphs': [
        for (final p in paragraphs)
          {'t': p.tokens.map(token).toList(), 'ko': p.korean}
      ],
      'dist': distribution,
      'words': [
        for (final w in words)
          {
            'jp': w.japanese,
            'reading': w.reading,
            'ko': w.korean,
            'lv': w.level
          }
      ],
      'source': source,
      if (question != null) 'question': question!.toJson()
    };
  }

  String get titleText => title.map((t) => t.text).join();

  /// 2026-10-02 앱 단어장으로 급수 밑줄·단어 분포·핵심 단어를 채운다(이미 있는 값은 그대로).
  NewsArticle enrich(NewsLexicon lexicon) {
    final seen = <String, int>{};
    List<NewsToken> tag(List<NewsToken> tokens) => [
          for (final t in tokens)
            () {
              var token = t;
              if (token.level == null) {
                final hit = lexicon.find(token);
                if (hit != null) token = token.withLevel(hit.level, hit.word);
              }
              final entry =
                  lexicon.entry(token.word ?? token.base ?? token.text);
              final fallback =
                  words.where((w) => w.japanese == token.word).firstOrNull;
              if (entry != null || fallback != null) {
                token = NewsToken(
                    parts: token.parts,
                    level: token.level,
                    word: token.word,
                    base: token.base,
                    meaning: entry?.korean ?? fallback!.korean,
                    reading: entry?.reading ?? fallback!.reading);
              }
              if (token.level != null && token.word != null) {
                seen.putIfAbsent(token.word!, () => token.level!);
              }
              return token;
            }(),
        ];
    final newTitle = tag(title);
    final newParagraphs = [
      for (final p in paragraphs)
        NewsParagraph(tokens: tag(p.tokens), korean: p.korean)
    ];
    var dist = distribution;
    if (dist.isEmpty) {
      dist = {
        for (final l in const [5, 4, 3, 2, 1]) 'N$l': 0
      };
      for (final lv in seen.values) {
        dist['N$lv'] = (dist['N$lv'] ?? 0) + 1;
      }
    }
    var keyWords = words;
    if (keyWords.isEmpty) {
      final order = seen.keys.toList();
      final sorted = seen.entries.toList()
        ..sort((a, b) {
          final byLevel = a.value.compareTo(b.value); // N1(어려움) 먼저
          return byLevel != 0
              ? byLevel
              : order.indexOf(a.key).compareTo(order.indexOf(b.key));
        });
      keyWords = [
        for (final e in sorted.take(8))
          if (lexicon.entry(e.key) case final entry?)
            NewsWord(
                japanese: e.key,
                reading: entry.reading,
                korean: entry.korean,
                level: e.value),
      ];
    }
    return NewsArticle(
      id: id,
      date: date,
      category: category,
      title: newTitle,
      titleKorean: titleKorean,
      paragraphs: newParagraphs,
      distribution: dist,
      words: keyWords,
      source: source,
      question: question ?? vocabularyQuestion(keyWords, paragraphs),
    );
  }

  factory NewsArticle.fromJson(Map<String, dynamic> json) {
    List<NewsToken> tokens(Object? raw) => [
          for (final t in raw as List<dynamic>)
            NewsToken.fromJson(t as Map<String, dynamic>)
        ];
    final dist = (json['dist'] as Map<String, dynamic>? ?? const {})
        .map((k, v) => MapEntry(k, v as int));
    return NewsArticle(
      id: json['id'] as String,
      date: json['date'] as String? ?? '',
      category: json['category'] as String? ?? '',
      title: tokens(json['title']),
      titleKorean: json['titleKo'] as String? ?? '',
      paragraphs: [
        for (final p in json['paragraphs'] as List<dynamic>)
          NewsParagraph(
            tokens: tokens((p as Map<String, dynamic>)['t']),
            korean: p['ko'] as String? ?? '',
          ),
      ],
      distribution: dist,
      words: [
        for (final w in json['words'] as List<dynamic>? ?? const [])
          NewsWord.fromJson(w as Map<String, dynamic>)
      ],
      source: json['source'] as String? ?? '',
      question: json['question'] == null
          ? null
          : NewsQuestion.fromJson(json['question'] as Map<String, dynamic>),
    );
  }
}

class LexiconEntry {
  const LexiconEntry(this.word, this.level, this.reading, this.korean);
  final String word;
  final int level;
  final String reading;
  final String korean;
}

/// 2026-10-02 앱 단어장(급수·읽기·뜻) 사전. 같은 표기가 여러 급수에 있으면 쉬운 급수를 쓴다.
class NewsLexicon {
  NewsLexicon(this._entries);

  factory NewsLexicon.fromWords(Iterable<Vocabulary> words) {
    final map = <String, LexiconEntry>{};
    for (final w in words) {
      final level =
          int.tryParse(w.jlptLevel.trim().toUpperCase().replaceFirst('N', ''));
      if (level == null) continue;
      final current = map[w.japanese];
      if (current == null || level > current.level) {
        map[w.japanese] = LexiconEntry(w.japanese, level, w.reading, w.korean);
      }
    }
    return NewsLexicon(map);
  }

  static final NewsLexicon empty = NewsLexicon(const {});

  final Map<String, LexiconEntry> _entries;

  LexiconEntry? entry(String word) => _entries[word];

  /// 이미 확보한 문장을 사전의 가장 긴 표제어 우선으로 표시한다. 형태소 분석은 아니다.
  List<NewsToken> tokenize(String text) {
    final result = <NewsToken>[];
    var offset = 0;
    while (offset < text.length) {
      LexiconEntry? match;
      for (var length = 12.clamp(0, text.length - offset);
          length > 0;
          length--) {
        match = _entries[text.substring(offset, offset + length)];
        if (match != null) break;
      }
      if (match != null) {
        final kanji = RegExp(r'[一-龯]').hasMatch(match.word);
        result.add(NewsToken(
            parts: [(match.word, kanji ? match.reading : '')],
            base: match.word,
            word: match.word,
            level: match.level,
            meaning: match.korean,
            reading: match.reading));
        offset += match.word.length;
      } else {
        final char = text.substring(offset, offset + 1);
        if (result.isNotEmpty &&
            result.last.word == null &&
            result.last.parts.every((p) => p.$2.isEmpty)) {
          final last = result.removeLast();
          result.add(NewsToken(parts: [(last.text + char, '')]));
        } else {
          result.add(NewsToken(parts: [(char, '')]));
        }
        offset++;
      }
    }
    return result;
  }

  /// 조각의 사전형 → 표기 순으로 단어장을 찾는다. 사전형이 없는 조각(조사 등)은 찾지 않는다.
  LexiconEntry? find(NewsToken token) {
    final base = token.base;
    if (base == null) return null;
    return _entries[base] ?? _entries[token.text];
  }
}

/// 2026-10-02 CSV(따옴표·줄바꿈 포함 칸 지원)를 행 목록으로 나눈다.
List<List<String>> parseCsv(String raw) {
  final rows = <List<String>>[];
  var row = <String>[];
  final cell = StringBuffer();
  var quoted = false;
  for (var i = 0; i < raw.length; i++) {
    final c = raw[i];
    if (quoted) {
      if (c == '"') {
        if (i + 1 < raw.length && raw[i + 1] == '"') {
          cell.write('"');
          i++;
        } else {
          quoted = false;
        }
      } else {
        cell.write(c);
      }
    } else if (c == '"') {
      quoted = true;
    } else if (c == ',') {
      row.add(cell.toString());
      cell.clear();
    } else if (c == '\n' || c == '\r') {
      if (c == '\r' && i + 1 < raw.length && raw[i + 1] == '\n') i++;
      row.add(cell.toString());
      cell.clear();
      rows.add(row);
      row = <String>[];
    } else {
      cell.write(c);
    }
  }
  if (cell.isNotEmpty || row.isNotEmpty) {
    row.add(cell.toString());
    rows.add(row);
  }
  return rows;
}

/// 2026-10-01 기사 목록을 읽는다. JSON 피드({"articles":[…]}) 또는
/// 구글 시트 CSV(열: id, date, json — 첫 행은 제목)를 모두 받는다. 형식이 틀리면 예외.
List<NewsArticle> parseNewsFeed(String raw) {
  final text = raw.trimLeft();
  if (text.startsWith('{')) {
    final map = jsonDecode(text) as Map<String, dynamic>;
    return [
      for (final a in map['articles'] as List<dynamic>)
        NewsArticle.fromJson(a as Map<String, dynamic>),
    ];
  }
  final rows = parseCsv(text);
  if (rows.isEmpty) throw const FormatException('빈 피드');
  final header = rows.first.map((h) => h.trim().toLowerCase()).toList();
  final jsonCol = header.indexOf('json');
  if (jsonCol < 0) throw const FormatException('json 열이 없습니다');
  final articles = <NewsArticle>[];
  for (final row in rows.skip(1)) {
    if (row.length <= jsonCol || row[jsonCol].trim().isEmpty) continue;
    try {
      articles.add(NewsArticle.fromJson(
          jsonDecode(row[jsonCol]) as Map<String, dynamic>));
    } catch (_) {
      // 깨진 행 하나 때문에 전체를 버리지 않는다.
    }
  }
  return articles;
}

/// 2026-10-02 오늘 날짜 기사는 오전 7시부터 보여준다(미래 날짜 기사는 숨김).
bool isNewsVisible(NewsArticle article, DateTime now) {
  final date = DateTime.tryParse(article.date);
  if (date == null) return true;
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(date.year, date.month, date.day);
  if (day.isBefore(today)) return true;
  if (day.isAfter(today)) return false;
  return now.hour >= 7;
}

typedef NewsFetcher = Future<String> Function(Uri uri);

Future<String> _httpGet(Uri uri) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
  try {
    final request = await client.getUrl(uri);
    final response = await request.close().timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw HttpException('HTTP ${response.statusCode}', uri: uri);
    }
    return await response.transform(utf8.decoder).join();
  } finally {
    client.close(force: true);
  }
}

/// 2026-10-01 뉴스 기사 보관소. 앱에 든 기사 + 마지막으로 받아 둔 기사 + 새로 받은 기사를 합친다.
/// 인터넷이 없거나 피드 주소가 비어 있어도 앱에 든 기사와 저장된 기사는 항상 보여준다.
class NewsRepository {
  NewsRepository(
    this._preferences, {
    this.feedUrl = '',
    NewsFetcher? fetcher,
    this.bundled,
    NewsLexicon? lexicon,
    DateTime Function()? clock,
    this.dailyArticles,
    this.fetchDaily,
  })  : _fetch = fetcher ?? _httpGet,
        _lexicon = lexicon ?? NewsLexicon.empty,
        _clock = clock ?? DateTime.now;

  final NewsLexicon _lexicon;
  final DateTime Function() _clock;

  static const String cacheKey = 'news_feed_cache_v1';
  static const String assetPath = 'assets/news/news.json';

  final SharedPreferences _preferences;
  final String feedUrl;
  final NewsFetcher _fetch;
  final Future<List<NewsArticle>> Function()? dailyArticles;
  final Future<NewsArticle?> Function()? fetchDaily;

  /// 테스트용: 앱에 든 기사를 직접 넣는다(없으면 asset을 읽는다).
  final List<NewsArticle>? bundled;

  Future<List<NewsArticle>> _bundled() async {
    if (bundled != null) return bundled!;
    try {
      return [
        ...parseNewsFeed(await rootBundle.loadString(assetPath)),
        ...?await dailyArticles?.call()
      ];
    } catch (_) {
      return const <NewsArticle>[];
    }
  }

  List<NewsArticle> _cached() {
    final raw = _preferences.getString(cacheKey);
    if (raw == null) return const <NewsArticle>[];
    try {
      return parseNewsFeed(raw);
    } catch (_) {
      return const <NewsArticle>[];
    }
  }

  List<NewsArticle> _merge(Iterable<List<NewsArticle>> lists) {
    final byId = <String, NewsArticle>{};
    for (final list in lists) {
      for (final a in list) {
        byId[a.id] = a;
      }
    }
    final now = _clock();
    final result = [
      for (final a in byId.values)
        if (isNewsVisible(a, now)) a.enrich(_lexicon),
    ]..sort((a, b) => b.id.compareTo(a.id));
    return result;
  }

  /// 인터넷 없이 바로 보여줄 수 있는 기사.
  Future<List<NewsArticle>> loadLocal() async =>
      _merge([await _bundled(), _cached()]);

  /// 피드에서 새 기사를 받아 저장하고 전체 목록을 돌려준다. 실패하면 null.
  Future<List<NewsArticle>?> refresh() async {
    if (fetchDaily != null) {
      try {
        final article = await fetchDaily!();
        if (article == null) return loadLocal();
        final all = {for (final a in _cached()) a.id: a, article.id: article};
        final retained = all.values.toList()
          ..sort((a, b) => b.date.compareTo(a.date));
        await _preferences.setString(
            cacheKey,
            jsonEncode({
              'articles': retained.take(60).map((a) => a.toJson()).toList()
            }));
        return loadLocal();
      } catch (_) {
        return null;
      }
    }
    if (feedUrl.isEmpty) return null;
    try {
      final raw = await _fetch(Uri.parse(feedUrl));
      final remote = parseNewsFeed(raw); // 형식 검사
      await _preferences.setString(cacheKey, raw);
      return _merge([await _bundled(), remote]);
    } catch (_) {
      return null;
    }
  }
}
