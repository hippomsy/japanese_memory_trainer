import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kioku_japanese/services/story_course.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 2026-10-14 N4 이야기 극장 데이터·기록 저장 검사.
void main() {
  final stories = Story.parse(File(storiesAsset).readAsStringSync());

  test('10편, 번호 1~10, 내용이 빠짐없이 들어 있다', () {
    expect(stories, hasLength(10));
    expect(stories.map((s) => s.number), List.generate(10, (i) => i + 1));
    for (final s in stories) {
      expect(s.sentences.length, greaterThanOrEqualTo(12), reason: s.title);
      expect(s.words.length, greaterThanOrEqualTo(10), reason: s.title);
      expect(s.grammar, hasLength(3), reason: s.title);
      expect(s.questions, hasLength(3), reason: s.title);
      for (final sentence in s.sentences) {
        // 토큰을 이어 붙이면 원문과 같아야 한다.
        expect(sentence.tokens.map((t) => t.text).join(), sentence.japanese);
        expect(sentence.korean, isNotEmpty);
      }
      for (final q in s.questions) {
        expect(q.options, hasLength(4));
        expect(q.answer, inInclusiveRange(0, 3));
      }
      expect(File('assets/illustrations/${s.scene}.webp').existsSync(), isTrue,
          reason: s.scene);
    }
  });

  test('핵심 단어는 본문에서 눌러 볼 수 있다', () {
    for (final s in stories) {
      final tapped = {
        for (final se in s.sentences)
          for (final t in se.tokens)
            if (t.word != null) t.word
      };
      final missing = [
        for (final w in s.words)
          if (!tapped.contains(w.word)) w.word
      ];
      expect(missing, isEmpty, reason: s.title);
    }
  });

  test('읽음·점수·외운 단어를 저장한다', () async {
    SharedPreferences.setMockInitialValues({});
    final p = StoryProgress(await SharedPreferences.getInstance());
    await p.markRead('story_1');
    await p.saveScore('story_2', 2);
    await p.setKnown('story_1', '猫', true);
    await p.setKnown('story_1', '傘', true);
    await p.setKnown('story_1', '傘', false);
    expect(p.read('story_1'), isTrue);
    expect(p.score('story_2'), 2);
    expect(p.known('story_1'), {'猫'});
    expect(p.readCount, 2);
  });
}
