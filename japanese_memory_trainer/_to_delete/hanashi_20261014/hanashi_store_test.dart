import 'package:flutter_test/flutter_test.dart';
import 'package:kioku_japanese/services/hanashi_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 2026-10-13 하나시 니홍고: 대본 붙여넣기·25화 목록·간격 반복 검사(예문은 테스트용 자작 문장).
void main() {
  test('reads YouTube transcript copy and drops duration noise', () {
    const text = '0:24\n朝、目が覚めた。\n0:30\n30초\n駅まで\n0:33\n走った。\n12:00\n傘を忘れた。';
    final lines = parseHanashiTranscript(text);
    expect(lines.map((l) => l.ja), ['朝、目が覚めた。', '駅まで走った。', '傘を忘れた。']);
    expect(lines.map((l) => l.t), [24, 30, 720]);
  });

  test('reads srt and inline timestamps', () {
    const srt = '1\n00:00:25,000 --> 00:00:27,000\n少し休もう。\n\n2\n00:11:45,500 --> 00:11:47,000\n<i>また明日。</i>';
    expect(parseHanashiTranscript(srt).map((l) => l.t), [25, 705]);
    expect(parseHanashiTranscript('1:02:03 心が温かい。').single.t, 3723);
  });

  test('playlist has 25 episodes with own notes and video links', () {
    expect(hanashiEpisodes, hasLength(25));
    expect(hanashiEpisodes.map((e) => e.no), List.generate(25, (i) => i + 1));
    expect(hanashiEpisodes.map((e) => e.videoId).toSet(), hasLength(25));
    expect(hanashiEpisode(24).videoId, 'NNQsLtn6HB4');
    expect(hanashiEpisode(14).season, 2);
    for (final e in hanashiEpisodes) {
      expect(e.examples, hasLength(2));
      expect(e.reading, isNotEmpty);
    }
    expect(hanashiUrl('NNQsLtn6HB4', 75), contains('t=75s'));
    expect(hanashiUrl('NNQsLtn6HB4'), isNot(contains('t=')));
  });

  test('stores lines and grades words with growing intervals', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await HanashiStore.open();
    await store.importLines(3, [HanashiLine(t: 15, ja: '少しだけ休もう。', note: '조금만 쉬자.')]);
    final now = DateTime(2026, 10, 12, 9);
    await store.addWord(HanashiWord(word: '休む', reading: 'やすむ', meaning: '쉬다', due: now, added: now));
    final w = store.due(now).single;
    await store.grade(w, 2, now);
    expect(w.box, 1);
    expect(store.due(now), isEmpty);
    expect(store.due(now.add(const Duration(days: 1))), hasLength(1));

    final again = await HanashiStore.open();
    expect(again.lines[3]!.single.note, '조금만 쉬자.');
    expect(again.words.containsKey('休む|やすむ'), isTrue);
  });
}
