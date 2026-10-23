import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kioku_japanese/data/sentence_building_bank.dart';
import 'package:kioku_japanese/data/sentence_building_vocab.dart';
import 'package:kioku_japanese/pages/sentence_building_pages.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 2026-10-16 문장 만들기: 데이터 검사 + 빈칸 → 배열 흐름.
void main() {
  test('every sentence lists key words, longest match first', () {
    for (final l in sbLessons) {
      for (final it in l.items) {
        expect(sbWordsFor(it.japanese), isNotEmpty, reason: it.japanese);
      }
    }
    final w = sbWordsFor('日本語学校に通うつもりです。').map((e) => e.word).toList();
    expect(w, ['日本語', '学校', '通う']);
  });

  test('24 lessons, 4 sentences each, valid keys and traps', () {
    expect(sbLessons, hasLength(24));
    expect(sbLessons.map((l) => l.id).toSet(), hasLength(24));
    expect(sbLessons.where((l) => l.level == 'N4'), hasLength(12));
    expect(sbLessons.where((l) => l.level == 'N3'), hasLength(12));
    for (final l in sbLessons) {
      expect(l.items, hasLength(4), reason: l.id);
      for (final it in l.items) {
        expect(it.key, inInclusiveRange(0, it.chunks.length - 1), reason: it.ko);
        expect(it.wrongs, hasLength(3), reason: it.ko);
        expect(it.wrongs.toSet(), hasLength(3), reason: it.ko);
        expect(it.wrongs.contains(it.chunks[it.key]), isFalse, reason: it.ko);
        expect(it.chunks.contains(it.wrongs.first), isFalse, reason: it.ko);
        expect(it.reading, isNotEmpty, reason: it.ko);
      }
    }
  });

  testWidgets('mode menu switch: word mode first, then char mode',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final spoken = <String>[];
    await tester.pumpWidget(MaterialApp(
        home: SentenceBuildingHomePage(
            speak: (t) async => spoken.add(t), preferences: prefs)));
    await tester.pumpAndSettle();

    // 기본값은 단어별 선택 모드
    expect(find.text('1단계 · 단어별로 선택 조립'), findsOneWidget);
    expect(find.byKey(const ValueKey('sb-mode-word')), findsOneWidget);
    expect(find.byKey(const ValueKey('sb-mode-char')), findsOneWidget);
    expect(find.text('N4 단어 랜덤 10문제'), findsOneWidget);

    // 단어별 레슨 진입
    await tester.tap(find.byKey(const ValueKey('sb-lesson-n4_temoii')));
    await tester.pumpAndSettle();

    final first = sbLessons.first.items.first;
    // 단어 타일 중 오답 함정 타일을 골라 틀려본다
    await tester.tap(find.byKey(ValueKey('sb-tile-${first.wrongs.first}')));
    await tester.pumpAndSettle();

    // 확인 버튼 탭 (정답 조각 수와 맞지 않으면 비활성이므로 chunks 나머지 순서대로 채움)
    for (var i = 0; i < first.chunks.length - 1; i++) {
      await tester.tap(find.byKey(ValueKey('sb-tile-${first.chunks[i]}')));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byKey(const ValueKey('sb-check')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('sb-feedback')), findsOneWidget);
    expect(prefs.getStringList('sb.wrong'), contains('n4_temoii|0'));

    // 목록으로 돌아오기
    await tester.pageBack();
    await tester.pumpAndSettle();

    // 2단계 글자별 선택 메뉴로 전환
    await tester.tap(find.byKey(const ValueKey('sb-mode-char')));
    await tester.pumpAndSettle();

    expect(find.text('2단계 · 글자 하나하나 탭'), findsOneWidget);
    expect(find.text('N4 글자 랜덤 5문제'), findsOneWidget);

    // 글자별 레슨 진입
    await tester.tap(find.byKey(const ValueKey('sb-lesson-n4_temoii')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('sb-char-answer')), findsOneWidget);
    expect(find.text('아래 글자를 순서대로 탭하세요'), findsOneWidget);
  });
}
