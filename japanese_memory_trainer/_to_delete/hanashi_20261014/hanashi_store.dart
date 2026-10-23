import 'dart:math';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 2026-10-13 「하나시 니홍고」(우마이 일본어) 재생목록 학습 데이터.
/// 영상 대본은 앱에 넣지 않는다. 화마다 사용자가 YouTube 스크립트를 붙여 넣으면
/// 이 기기에만 저장한다. 앱에 든 것은 영상 정보(제목·길이)와, 제목 표현을 풀어 쓴
/// 자체 학습 노트(읽기·뜻·문법·직접 만든 예문)뿐이다.
class HanashiEpisode {
  const HanashiEpisode(this.no, this.videoId, this.title, this.ko, this.minutes,
      {required this.reading,
      required this.point,
      required this.examples});
  final int no;
  final String videoId;
  final String title; // 제목 표현(일본어)
  final String ko; // 제목 뜻
  final int minutes;
  final String reading;
  final String point; // 문법·표현 설명(자체 작성)
  final List<(String, String)> examples; // (일본어, 한국어) 자체 작성 예문
  int get season => no <= 13 ? 1 : 2;
}

const String hanashiPlaylistId = 'PLqDQr9zcEYbGyw7ejD29CHdI89nTqC9zc';

const List<HanashiEpisode> hanashiEpisodes = [
  HanashiEpisode(1, 'XGozGKjL9s4', 'まずい、急がないと', '큰일이다, 서두르지 않으면', 12,
      reading: 'まずい、いそがないと',
      point: '「〜ないと」는 「〜ないといけない」의 뒤를 줄인 회화체. "~하지 않으면 (안 돼)".',
      examples: [('もう時間だ。急がないと。', '벌써 시간이야. 서둘러야 해.'), ('明日は試験だから、勉強しないと。', '내일은 시험이니까 공부해야 해.')]),
  HanashiEpisode(2, 'o6I6PufigNw', 'これくらい、大丈夫だろう', '이 정도쯤이야 괜찮겠지', 13,
      reading: 'これくらい、だいじょうぶだろう',
      point: '「〜くらい」 정도, 「〜だろう」 추측 "~겠지". 정중하게는 「〜でしょう」.',
      examples: [('雨は夜にはやむだろう。', '비는 밤에는 그치겠지.'), ('これくらいなら一人でできるだろう。', '이 정도라면 혼자 할 수 있겠지.')]),
  HanashiEpisode(3, 'Wv5Vs0FFe6o', 'まあ、こんなものまで', '뭐, 이런 것까지', 16,
      reading: 'まあ、こんなものまで',
      point: '「〜まで」는 범위의 끝 "~까지". 예상 밖의 것에 붙으면 놀람을 나타낸다.',
      examples: [('弟は私のおやつまで食べた。', '남동생은 내 간식까지 먹었다.'), ('先生は私の名前まで覚えていた。', '선생님은 내 이름까지 기억하고 있었다.')]),
  HanashiEpisode(4, 'XWYUko1dw7c', 'このままで、いいのかな', '이대로 괜찮은 걸까', 16,
      reading: 'このままで、いいのかな',
      point: '「〜のかな」 혼잣말처럼 스스로에게 묻는 "~인 걸까". 「このまま」 이대로.',
      examples: [('この道で合っているのかな。', '이 길이 맞는 걸까.'), ('彼はもう帰ったのかな。', '그는 벌써 돌아간 걸까.')]),
  HanashiEpisode(5, 'CmrigJa90uw', '声をかけてみよう', '말을 걸어 보자', 17,
      reading: 'こえをかけてみよう',
      point: '「声をかける」 말을 걸다. 「〜てみる」 시험 삼아 ~해 보다 + 의지형 「〜よう」.',
      examples: [('新しい店に行ってみよう。', '새 가게에 가 보자.'), ('一度、自分で作ってみよう。', '한번 직접 만들어 보자.')]),
  HanashiEpisode(6, 'NUEqHoDeAwM', '今日みたいな日も', '오늘 같은 날도', 20,
      reading: 'きょうみたいなひも',
      point: '「명사 + みたいな + 명사」 "~같은 ~" (회화체). 문어체는 「〜のような」.',
      examples: [('夢みたいな話だ。', '꿈같은 이야기다.'), ('春みたいな天気ですね。', '봄 같은 날씨네요.')]),
  HanashiEpisode(7, 'SRecK3-k6LU', '私が 悪かった', '내가 잘못했어', 22,
      reading: 'わたしが わるかった',
      point: '「悪い」의 과거형 「悪かった」로 사과. 「が」는 "다른 누구도 아닌 내가"를 강조.',
      examples: [('遅れてごめん。私が悪かった。', '늦어서 미안해. 내가 잘못했어.'), ('昨日は言い過ぎた。僕が悪かったよ。', '어제는 말이 심했어. 내가 잘못했어.')]),
  HanashiEpisode(8, '8USE2tCy4oM', '長く生きたね', '오래도 살았네', 20,
      reading: 'ながくいきたね',
      point: 'い형용사를 「〜く」로 바꾸면 동사를 꾸미는 부사가 된다(長い → 長く). 「〜ね」 공감.',
      examples: [('今日は早く起きたね。', '오늘은 일찍 일어났네.'), ('たくさん歩いたね。', '많이 걸었네.')]),
  HanashiEpisode(9, '6q155LZfpNk', 'いつものやつで', '늘 먹던 걸로', 21,
      reading: 'いつものやつで',
      point: '「いつもの」 늘 하던, 「やつ」 "것"의 편한 말, 「〜で」 "~로"(고를 때).',
      examples: [('飲み物はいつものでいい？', '음료는 늘 마시던 걸로 괜찮아?'), ('白いやつでお願いします。', '하얀 걸로 부탁해요.')]),
  HanashiEpisode(10, 'TTqYDpQU5Rk', 'もうやめようか', '이제 그만할까?', 24,
      reading: 'もうやめようか',
      point: '의지형 「〜よう」 + 「か」 = 제안하거나 망설이는 "~할까?".',
      examples: [('疲れたから、少し休もうか。', '피곤하니까 좀 쉴까?'), ('今日はもう帰ろうか。', '오늘은 이제 돌아갈까?')]),
  HanashiEpisode(11, '8uYuOhStHy0', 'きっとうまくいく', '분명 잘 될 거야', 24,
      reading: 'きっとうまくいく',
      point: '「きっと」 확신하는 "분명", 「うまくいく」 일이 잘 풀리다.',
      examples: [('たくさん準備したから、きっと大丈夫。', '많이 준비했으니까 분명 괜찮아.'), ('二人ならうまくいくよ。', '둘이라면 잘 될 거야.')]),
  HanashiEpisode(12, '8TTgQo2KpHQ', 'まあ、これが楽だ', '뭐, 이게 편하지', 23,
      reading: 'まあ、これがらくだ',
      point: '「楽(らく)」 편하다(な형용사). 「AがB」로 "다른 것보다 A가"를 강조.',
      examples: [('電車より歩くほうが楽だ。', '전철보다 걷는 게 편하다.'), ('この服は着るのが楽だ。', '이 옷은 입기 편하다.')]),
  HanashiEpisode(13, 'FBAL04F5iaA', 'ここに いたい', '여기에 있고 싶다', 24,
      reading: 'ここに いたい',
      point: '「いる」 + 「〜たい」 "~하고 싶다". 「に」는 있는 장소.',
      examples: [('もう少しここにいたい。', '조금 더 여기 있고 싶어.'), ('いつか日本に住みたい。', '언젠가 일본에 살고 싶다.')]),
  HanashiEpisode(14, '7otVTy-aWWU', '気になる', '신경 쓰여', 25,
      reading: 'きになる',
      point: '「気になる」 마음에 걸리다·궁금하다. 대상은 「が」로: 「〜が気になる」.',
      examples: [('明日の天気が気になる。', '내일 날씨가 신경 쓰인다.'), ('あの音が気になって眠れない。', '그 소리가 신경 쓰여서 잠을 못 자겠다.')]),
  HanashiEpisode(15, 'OVMxllalWwU', '気づいている', '눈치채고 있어', 18,
      reading: 'きづいている',
      point: '「気づく」 알아차리다 + 「〜ている」 = 이미 알아차린 상태. 대상은 「に」.',
      examples: [('彼はもう間違いに気づいている。', '그는 이미 실수를 눈치채고 있다.'), ('誰も気づいていない。', '아무도 눈치채지 못했다.')]),
  HanashiEpisode(16, '37al2Bx4Q8Y', '待っている', '기다리고 있어', 17,
      reading: 'まっている',
      point: '「〜ている」 지금 계속되는 동작 "~하고 있다". 회화에서는 「待ってる」로 줄어든다.',
      examples: [('駅で友達を待っている。', '역에서 친구를 기다리고 있다.'), ('ずっと連絡を待ってるよ。', '계속 연락 기다리고 있을게.')]),
  HanashiEpisode(17, 'NLEXQJCyo_E', 'まだ終わりじゃない', '아직 끝이 아니야', 18,
      reading: 'まだおわりじゃない',
      point: '「〜じゃない」는 「〜ではない」의 회화체 부정. 「終わり」는 「終わる」의 명사형.',
      examples: [('試合はまだ終わりじゃない。', '경기는 아직 끝이 아니다.'), ('これは私のかばんじゃない。', '이건 내 가방이 아니야.')]),
  HanashiEpisode(18, 'H1URyegjkj4', 'お久しぶり', '오랜만이야', 18,
      reading: 'おひさしぶり',
      point: '오랜만에 만났을 때 인사. 정중하게 「お久しぶりです」, 친구끼리는 「久しぶり」.',
      examples: [('お久しぶりです。お元気でしたか。', '오랜만이에요. 잘 지내셨어요?'), ('久しぶりに会えてうれしい。', '오랜만에 만나서 기뻐.')]),
  HanashiEpisode(19, 'zg2k6S4BTzE', '怪しい男', '수상한 남자', 21,
      reading: 'あやしいおとこ',
      point: 'い형용사는 그대로 명사 앞에 붙는다(怪しい + 男). 「怪しい」 수상하다.',
      examples: [('怪しいメールは開かないでください。', '수상한 메일은 열지 마세요.'), ('家の前に怪しい車が止まっている。', '집 앞에 수상한 차가 서 있다.')]),
  HanashiEpisode(20, 'qAgJVAZxXAo', '彼女と一緒に', '그녀와 함께', 21,
      reading: 'かのじょといっしょに',
      point: '「〜と一緒に」 "~와 함께". 「一緒に」만 쓰면 "같이".',
      examples: [('家族と一緒に旅行した。', '가족과 함께 여행했다.'), ('一緒に帰ろう。', '같이 돌아가자.')]),
  HanashiEpisode(21, 'YbG_j5c8X-M', '寂しい心', '아쉬운 마음', 21,
      reading: 'さびしいこころ',
      point: '「寂しい」 쓸쓸하다·외롭다·서운하다. 헤어짐이 아쉬울 때도 쓴다.',
      examples: [('友達が引っ越して寂しい。', '친구가 이사 가서 서운하다.'), ('一人の夜は少し寂しい。', '혼자 있는 밤은 조금 쓸쓸하다.')]),
  HanashiEpisode(22, 'X9QZzP5vPvo', 'もう一度、始めよう', '다시 한 번, 시작해 보자', 22,
      reading: 'もういちど、はじめよう',
      point: '「始める」의 의지형 「始めよう」 "시작하자". 「もう一度」 한 번 더.',
      examples: [('もう一度やってみよう。', '한 번 더 해 보자.'), ('明日から運動を始めよう。', '내일부터 운동을 시작하자.')]),
  HanashiEpisode(23, 'xu55G9L7qC4', '見送り', '배웅', 23,
      reading: 'みおくり',
      point: '동사 「見送る」의 ます형 어간이 그대로 명사가 된다(見送ります → 見送り).',
      examples: [('空港まで見送りに行った。', '공항까지 배웅하러 갔다.'), ('駅で友達を見送った。', '역에서 친구를 배웅했다.')]),
  HanashiEpisode(24, 'NNQsLtn6HB4', '計画通り', '계획대로', 23,
      reading: 'けいかくどおり',
      point: '「명사 + 通り(どおり)」 "~대로". 동사 뒤에는 「〜通り(とおり)に」.',
      examples: [('旅行は予定通りに進んだ。', '여행은 예정대로 진행됐다.'), ('説明書の通りに作った。', '설명서대로 만들었다.')]),
  HanashiEpisode(25, 'us8NZiFnKDs', 'ちょっとやり過ぎだ', '좀 지나친데', 25,
      reading: 'ちょっとやりすぎだ',
      point: '「동사 ます형 + 過ぎる」 "너무 ~하다". 명사형 「〜過ぎ」로 "지나침".',
      examples: [('食べ過ぎてお腹が痛い。', '너무 많이 먹어서 배가 아프다.'), ('それはちょっと言い過ぎだよ。', '그건 좀 말이 심해.')]),
];

HanashiEpisode hanashiEpisode(int no) => hanashiEpisodes[no - 1];

String hanashiUrl(String videoId, [int seconds = 0]) =>
    'https://www.youtube.com/watch?v=$videoId&list=$hanashiPlaylistId'
    '${seconds > 0 ? '&t=${seconds}s' : ''}';

String hanashiClock(int seconds) {
  final h = seconds ~/ 3600, m = seconds % 3600 ~/ 60, s = seconds % 60;
  String two(int v) => v.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '$m:${two(s)}';
}

/// 대본 한 줄. [note]는 사용자가 적은 번역·메모.
class HanashiLine {
  HanashiLine({this.t, required this.ja, this.note = ''});
  int? t;
  String ja;
  String note;

  Map<String, dynamic> toJson() => {'t': t, 'ja': ja, 'n': note};
  factory HanashiLine.fromJson(Map<String, dynamic> j) => HanashiLine(
      t: (j['t'] as num?)?.toInt(),
      ja: (j['ja'] ?? '') as String,
      note: (j['n'] ?? '') as String);
}

/// 단어장 한 개. box 0~5 간격 반복.
class HanashiWord {
  HanashiWord(
      {required this.word,
      this.reading = '',
      required this.meaning,
      this.example = '',
      this.exampleKo = '',
      this.ep = 0,
      this.t,
      this.box = 0,
      required this.due,
      required this.added});
  String word, reading, meaning, example, exampleKo;
  int ep, box;
  int? t;
  DateTime due, added;

  String get id => '$word|$reading';

  Map<String, dynamic> toJson() => {
        'w': word,
        'r': reading,
        'm': meaning,
        'x': example,
        'xk': exampleKo,
        'ep': ep,
        't': t,
        'b': box,
        'due': due.millisecondsSinceEpoch,
        'add': added.millisecondsSinceEpoch,
      };
  factory HanashiWord.fromJson(Map<String, dynamic> j) => HanashiWord(
        word: (j['w'] ?? '') as String,
        reading: (j['r'] ?? '') as String,
        meaning: (j['m'] ?? '') as String,
        example: (j['x'] ?? '') as String,
        exampleKo: (j['xk'] ?? '') as String,
        ep: (j['ep'] as num?)?.toInt() ?? 0,
        t: (j['t'] as num?)?.toInt(),
        box: (j['b'] as num?)?.toInt() ?? 0,
        due: DateTime.fromMillisecondsSinceEpoch((j['due'] as num?)?.toInt() ?? 0),
        added: DateTime.fromMillisecondsSinceEpoch((j['add'] as num?)?.toInt() ?? 0),
      );
}

/// 복습 간격(일). box 1→1일, 2→2일, 3→4일, 4→8일, 5→16일.
const List<int> hanashiIntervals = [0, 1, 2, 4, 8, 16];

class HanashiStore {
  HanashiStore(this._prefs) {
    _load();
  }
  final SharedPreferences _prefs;
  final Map<int, List<HanashiLine>> lines = {};
  final Map<String, HanashiWord> words = {};
  final Set<int> done = {};
  int lastEpisode = 1;

  static Future<HanashiStore> open([SharedPreferences? prefs]) async =>
      HanashiStore(prefs ?? await SharedPreferences.getInstance());

  void _load() {
    for (final e in hanashiEpisodes) {
      final raw = _prefs.getString('hanashi2.ep.${e.no}');
      lines[e.no] = raw == null
          ? []
          : (jsonDecode(raw) as List)
              .map((x) => HanashiLine.fromJson(Map<String, dynamic>.from(x as Map)))
              .toList();
    }
    final w = _prefs.getString('hanashi2.words');
    if (w != null) {
      (jsonDecode(w) as Map).forEach((k, v) =>
          words[k as String] = HanashiWord.fromJson(Map<String, dynamic>.from(v as Map)));
    }
    done.addAll(_prefs.getStringList('hanashi2.done')?.map(int.parse) ?? const []);
    lastEpisode = _prefs.getInt('hanashi2.last') ?? 1;
  }

  Future<void> saveEpisode(int no) => _prefs.setString(
      'hanashi2.ep.$no', jsonEncode(lines[no]!.map((l) => l.toJson()).toList()));
  Future<void> saveWords() => _prefs.setString(
      'hanashi2.words', jsonEncode(words.map((k, v) => MapEntry(k, v.toJson()))));
  Future<void> setDone(int no, bool value) {
    value ? done.add(no) : done.remove(no);
    return _prefs.setStringList('hanashi2.done', done.map((e) => '$e').toList());
  }

  Future<void> setLast(int no) {
    lastEpisode = no;
    return _prefs.setInt('hanashi2.last', no);
  }

  int noteCount(int no) => lines[no]!.where((l) => l.note.trim().isNotEmpty).length;

  /// 붙여 넣은 대본을 [no]화에 저장한다(기존 대본·메모는 바뀐다).
  Future<int> importLines(int no, List<HanashiLine> list) async {
    lines[no] = list;
    await saveEpisode(no);
    return list.length;
  }

  Future<void> clearEpisode(int no) async {
    lines[no] = [];
    await saveEpisode(no);
  }

  bool hasWord(String word, String reading) => words.containsKey('$word|$reading');

  Future<void> addWord(HanashiWord w) async {
    words[w.id] = w;
    await saveWords();
  }

  Future<void> removeWord(String id) async {
    words.remove(id);
    await saveWords();
  }

  List<HanashiWord> due(DateTime now) =>
      words.values.where((w) => !w.due.isAfter(now)).toList()
        ..sort((a, b) => a.due.compareTo(b.due));

  /// 0: 다시(5분 뒤) · 1: 애매(12시간 뒤) · 2: 알아요(다음 상자 간격).
  Future<void> grade(HanashiWord w, int g, DateTime now) async {
    if (g == 0) {
      w.box = 0;
      w.due = now.add(const Duration(minutes: 5));
    } else if (g == 1) {
      if (w.box < 1) w.box = 1;
      w.due = now.add(const Duration(hours: 12));
    } else {
      w.box = min(w.box + 1, 5);
      w.due = now.add(Duration(days: hanashiIntervals[w.box]));
    }
    await saveWords();
  }
}

// ───────────────────────── 대본 읽기 ─────────────────────────

int? _toSeconds(String s) {
  final parts = s.trim().replaceAll(',', '.').split(':');
  var total = 0.0;
  for (final p in parts) {
    final v = double.tryParse(p);
    if (v == null) return null;
    total = total * 60 + v;
  }
  return total.floor();
}

final RegExp _japanese = RegExp(r'[぀-ヿ㐀-鿿]');
final RegExp _sentenceEnd = RegExp(r'[。！？!?」』…]$');

/// YouTube 스크립트 복사본(시간 줄 + 문장 줄), "0:24 문장" 한 줄 형식,
/// .srt / .vtt 자막, 시간 없는 문장 목록을 모두 읽는다.
List<HanashiLine> parseHanashiTranscript(String text, {bool merge = true}) {
  text = text.replaceAll('\r', '').replaceFirst('﻿', '');
  var out = <HanashiLine>[];
  if (text.contains('-->')) {
    for (final block in text.split(RegExp(r'\n\s*\n'))) {
      final ls = block.split('\n');
      final i = ls.indexWhere((l) => l.contains('-->'));
      if (i < 0) continue;
      final t = _toSeconds(ls[i].split('-->').first);
      final body = ls
          .sublist(i + 1)
          .join(' ')
          .replaceAll(RegExp(r'<[^>]+>'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (body.isEmpty) continue;
      if (out.isNotEmpty && out.last.ja == body) continue;
      out.add(HanashiLine(t: t, ja: body));
    }
  } else {
    final ts = RegExp(r'^(\d{1,2}:)?\d{1,2}:\d{2}$');
    final tsInline = RegExp(r'^((?:\d{1,2}:)?\d{1,2}:\d{2})\s+(.+)$');
    final noise = RegExp(
        r'^((\d+\s*(시간|분|초)\s*)+|(\d+\s*(hours?|minutes?|seconds?),?\s*)+|(\d+\s*(時間|分|秒)\s*)+)$',
        caseSensitive: false);
    final chapter = RegExp(r'^(타이틀|에피소드\s*\d+|챕터|chapter\s*\d+|スクリプト|스크립트|transcript)',
        caseSensitive: false);
    HanashiLine? cur;
    var hasTime = false;
    for (final raw in text.split('\n')) {
      final r = raw.trim();
      if (r.isEmpty) continue;
      if (ts.hasMatch(r)) {
        hasTime = true;
        cur = HanashiLine(t: _toSeconds(r), ja: '');
        out.add(cur);
        continue;
      }
      final m = tsInline.firstMatch(r);
      if (m != null) {
        hasTime = true;
        cur = HanashiLine(t: _toSeconds(m.group(1)!), ja: m.group(2)!);
        out.add(cur);
        continue;
      }
      if (noise.hasMatch(r) || chapter.hasMatch(r)) continue;
      if (hasTime && cur != null) {
        cur.ja = cur.ja.isEmpty ? r : '${cur.ja} $r';
      } else {
        out.add(HanashiLine(ja: r));
      }
    }
  }
  out = out
      .map((l) => HanashiLine(t: l.t, ja: l.ja.replaceAll(RegExp(r'\s+'), ' ').trim()))
      .where((l) => l.ja.isNotEmpty && _japanese.hasMatch(l.ja))
      .toList();
  if (!merge) return out;
  final merged = <HanashiLine>[];
  for (final l in out) {
    final p = merged.isEmpty ? null : merged.last;
    if (p != null &&
        !_sentenceEnd.hasMatch(p.ja) &&
        p.ja.length + l.ja.length < 70 &&
        (p.t == null || l.t == null || l.t! - p.t! < 10)) {
      p.ja = '${p.ja}${l.ja}';
    } else {
      merged.add(HanashiLine(t: l.t, ja: l.ja));
    }
  }
  return merged;
}
