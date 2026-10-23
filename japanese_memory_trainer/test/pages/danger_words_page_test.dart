import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kioku_japanese/data/local_database.dart';
import 'package:kioku_japanese/models/memory_state.dart';
import 'package:kioku_japanese/models/vocabulary.dart';
import 'package:kioku_japanese/pages/danger_words_page.dart';
import 'package:kioku_japanese/services/learning_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

const dangerSeed = <Vocabulary>[
  Vocabulary(
    id: 'w1',
    japanese: '覚える',
    reading: 'おぼえる',
    korean: '외우다',
    exampleJapanese: '単語を覚えます。',
    exampleKorean: '단어를 외웁니다.',
    jlptLevel: 'N4',
    wordType: '동사',
    frequencyRank: 1,
  ),
  Vocabulary(
    id: 'w2',
    japanese: '増える',
    reading: 'ふえる',
    korean: '늘다',
    exampleJapanese: '人が増えます。',
    exampleKorean: '사람이 늘어납니다.',
    jlptLevel: 'N4',
    wordType: '동사',
    frequencyRank: 2,
  ),
];

void main() {
  testWidgets('DangerWordsPage shows descending danger order with score and wrong count', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = LocalDatabase(prefs);
    await db.saveMemoryStates({
      'w1': MemoryState.initial('w1').copyWith(dangerScore: 40, wrongCount: 2),
      'w2': MemoryState.initial('w2').copyWith(dangerScore: 80, wrongCount: 5),
    });
    final repo = LearningRepository(seed: dangerSeed, database: db);

    await tester.pumpWidget(MaterialApp(home: DangerWordsPage(repository: repo)));
    await tester.pumpAndSettle();

    expect(find.text('위험 80'), findsOneWidget);
    expect(find.text('오답 5회'), findsOneWidget);
    // 2026-09-27 목록 제목은 "표기  읽기" 형태라 표기가 포함된 텍스트로 찾는다.
    final highY = tester.getTopLeft(find.textContaining('増える')).dy;
    final lowY = tester.getTopLeft(find.textContaining('覚える')).dy;
    expect(highY, lessThan(lowY));
  });
}
