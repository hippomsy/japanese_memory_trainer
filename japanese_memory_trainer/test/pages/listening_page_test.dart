import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kioku_japanese/pages/listening_page.dart';
import 'package:kioku_japanese/data/listening_bank.dart';
import 'package:kioku_japanese/services/listening_store.dart';

void main() {
  testWidgets(
      'translation is available before answering without unlocking answers',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = ListeningStore(await SharedPreferences.getInstance());
    await tester.pumpWidget(MaterialApp(
        home: ListeningExercisePage(
      lesson: n4ListeningLessons.first,
      store: store,
      speak: (text, rate) async {},
      stop: () async {},
    )));
    await tester
        .tap(find.byKey(const ValueKey('listening-translation-header')));
    await tester.pumpAndSettle();
    expect(find.text('대화 해석'), findsOneWidget);
    expect(
        find.text(n4ListeningLessons.first.lines.first.korean), findsOneWidget);
    expect(find.byKey(const ValueKey('listening-feedback')), findsNothing);
    await tester.tap(find.byTooltip('해석 닫기'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<OutlinedButton>(
                find.byKey(const ValueKey('listening-answer-0')))
            .onPressed,
        isNull);
    expect(store.records, isEmpty);
  });
  testWidgets('listen first, reveal transcript after answer, save miss',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = ListeningStore(await SharedPreferences.getInstance());
    final spoken = <String>[];
    await tester.pumpWidget(MaterialApp(
        home: ListeningExercisePage(
            lesson: n4ListeningLessons.first,
            store: store,
            speak: (text, rate) async {
              spoken.add(text);
            },
            stop: () async {})));
    expect(
        find.text(n4ListeningLessons.first.lines.first.japanese), findsNothing);
    expect(
        tester
            .widget<OutlinedButton>(
                find.byKey(const ValueKey('listening-answer-0')))
            .onPressed,
        isNull);
    await tester.tap(find.byKey(const ValueKey('play-listening')));
    await tester.pumpAndSettle();
    expect(spoken.length, 3);
    await tester
        .ensureVisible(find.byKey(const ValueKey('listening-answer-0')));
    await tester.tap(find.byKey(const ValueKey('listening-answer-0')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('listening-feedback')), 150);
    expect(find.text('다음에 한 번 더 들어요'), findsOneWidget);
    expect(store.records['time']['correct'], false);
    await tester.scrollUntilVisible(
        find.text(n4ListeningLessons.first.lines.first.japanese), 150);
    expect(
        find.text(n4ListeningLessons.first.lines.first.korean), findsOneWidget);
    await tester.ensureVisible(find.byType(SwitchListTile));
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(
        find.text(n4ListeningLessons.first.lines.first.korean), findsNothing);
    expect(find.text(n4ListeningLessons.first.lines.first.japanese),
        findsOneWidget);
  });
  testWidgets('stopping playback never unlocks answers from a stale completion',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final pending = Completer<void>();
    final store = ListeningStore(await SharedPreferences.getInstance());
    await tester.pumpWidget(MaterialApp(
        home: ListeningExercisePage(
            lesson: n4ListeningLessons.first,
            store: store,
            speak: (text, rate) => pending.future,
            stop: () async {})));
    await tester.tap(find.byKey(const ValueKey('play-listening')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('play-listening')));
    await tester.pump();
    pending.complete();
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<OutlinedButton>(
                find.byKey(const ValueKey('listening-answer-0')))
            .onPressed,
        isNull);
  });
  testWidgets('voice errors leave answers locked and display a retry message',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = ListeningStore(await SharedPreferences.getInstance());
    await tester.pumpWidget(MaterialApp(
        home: ListeningExercisePage(
            lesson: n4ListeningLessons.first,
            store: store,
            speak: (text, rate) async => throw StateError('no voice'),
            stop: () async {})));
    await tester.tap(find.byKey(const ValueKey('play-listening')));
    await tester.pumpAndSettle();
    expect(find.textContaining('음성을 재생하지 못했어요'), findsOneWidget);
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('listening-answer-0')), 100);
    expect(
        tester
            .widget<OutlinedButton>(
                find.byKey(const ValueKey('listening-answer-0')))
            .onPressed,
        isNull);
  });
}
