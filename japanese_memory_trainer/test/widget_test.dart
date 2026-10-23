import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:kioku_japanese/app.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 2026-09-27 앱이 첫 화면(급수 목록)으로 정상 실행되는지 확인한다.
void main() {
  testWidgets('dashboard and records fit a narrow phone with larger text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
        KiokuJapaneseApp(preferences: prefs, speakJapanese: (_) async {}));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('기록').last);
    await tester.pumpAndSettle();
    expect(find.text('이번 주 청해 기록'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('app starts on today and opens vocabulary tab', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
        KiokuJapaneseApp(preferences: prefs, speakJapanese: (_) async {}));
    await tester.pumpAndSettle();

    expect(find.text('하루 일본어'), findsOneWidget);
    expect(find.text('오늘의 10분 학습'), findsOneWidget);
    await tester.tap(find.text('학습').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('category-words')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('category-words')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(const ValueKey('grade-N4')), 200);
    expect(find.text('JLPT N4'), findsOneWidget);
  });
}
