import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kioku_japanese/pages/theme_listening_page.dart';
import 'package:kioku_japanese/services/lesson_audio.dart';

import 'fakes/fake_lesson_audio.dart';

void main() {
  test('all imported lessons have meanings, kana and complete dialogues', () {
    final lessons =
        jsonDecode(File('assets/data/basicjl_lessons.json').readAsStringSync())
            as List;
    expect(lessons.length, 25);
    expect(lessons.map((l) => l['category']).toSet().length, 7);
    for (final lesson in lessons) {
      expect((lesson['script'] as List).length, 8);
      expect(lesson['koreanScript'], isNotEmpty);
      for (final word in lesson['words']) {
        expect(word['japanese'], isNotEmpty);
        expect(word['korean'], isNotEmpty);
        expect(word['reading'], isNotEmpty);
        expect(RegExp(r'[一-龯]').hasMatch(word['reading']), isFalse);
      }
    }
    expect(lessons[20]['script'][0], contains('上野さん'));
    expect(lessons[19]['script'][2], contains('盗まれて'));
  });

  test('every lesson has its native recording bundled', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('assets/basicjl_audio/'));
    for (var n = 1; n <= 25; n++) {
      final file = File(lessonAudioAsset(n));
      expect(file.existsSync(), isTrue, reason: file.path);
      expect(file.lengthSync(), greaterThan(100000), reason: file.path);
    }
    expect(lessonAudioAsset(7), 'assets/basicjl_audio/lesson_07.mp3');
  });

  // 2026-10-18 강의 화면의 단어 게임 버튼이 짝맞추기 게임(단어 3개 → 카드 6장)을 연다.
  testWidgets('word game button opens the card matching game', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: ThemeListeningLessonPage(
      lesson: {
        'number': 3,
        'title': '테스트',
        'words': [
          {'japanese': '駅', 'reading': 'えき', 'korean': '역'},
          {'japanese': '水', 'reading': 'みず', 'korean': '물'},
          {'japanese': '本', 'reading': 'ほん', 'korean': '책'}
        ],
        'script': ['文。'],
        'koreanScript': '문장.'
      },
      audioFactory: () => FakeLessonAudio(),
      speak: (text, rate) async {},
      stop: () async {},
    )));
    await tester.pump();
    final button = find.byKey(const ValueKey('theme-word-game'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('theme-word-match')), findsOneWidget);
    expect(find.byKey(const ValueKey('match-card-5')), findsOneWidget);
    expect(find.byKey(const ValueKey('match-card-6')), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('play-all uses the lesson recording, words and lines use TTS',
      (tester) async {
    // 2026-10-18 단어 게임 버튼이 위에 생겨 목록이 길어졌으므로 화면 높이를 키워 모든 줄이 만들어지게 한다.
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final spoken = <String>[];
    Completer<void>? pending;
    var stops = 0;
    final audio = FakeLessonAudio();
    await tester.pumpWidget(MaterialApp(
        home: ThemeListeningLessonPage(
      lesson: {
        'number': 7,
        'title': '테스트',
        'words': [
          {'japanese': '空く', 'reading': 'あく', 'korean': '비다'}
        ],
        'script': ['最初の文。', '次の文。'],
        'koreanScript': '첫 문장. 다음 문장.'
      },
      audioFactory: () => audio,
      speak: (text, rate) async {
        spoken.add(text);
        if (text == '最初の文。') {
          pending = Completer<void>();
          await pending!.future;
        }
      },
      stop: () async {
        stops++;
      },
    )));
    await tester.pump();
    expect(audio.loaded, 'assets/basicjl_audio/lesson_07.mp3');

    await tester.tap(find.byTooltip('단어 발음 듣기'));
    await tester.pump();
    expect(spoken, ['あく']);

    final all = find.byKey(const ValueKey('theme-play-all'));
    await tester.ensureVisible(all);
    await tester.tap(all);
    await tester.pump();
    expect(audio.calls, contains('play'));
    expect(spoken, ['あく'], reason: 'recording, not TTS, plays the dialogue');
    expect(find.text('일시정지'), findsOneWidget);

    // 문장 TTS를 누르면 녹음은 일시정지된다.
    final line = find.byTooltip('문장 듣기').first;
    await tester.ensureVisible(line);
    await tester.tap(line);
    await tester.pump();
    expect(audio.calls.last, 'pause');
    expect(spoken.last, '最初の文。');
    final stopBtn = find.text('문장 듣기 멈추기');
    await tester.ensureVisible(stopBtn);
    await tester.tap(stopBtn);
    await tester.pump();
    pending!.complete();
    await tester.pump();
    expect(stops, greaterThanOrEqualTo(1));

    await tester.ensureVisible(find.text('천천히'));
    await tester.tap(find.text('천천히'));
    await tester.pump();
    expect(audio.calls.last, 'speed 0.75');

    await tester.pumpWidget(const SizedBox());
    expect(audio.disposed, isTrue);
    expect(tester.takeException(), isNull);
  });
}
