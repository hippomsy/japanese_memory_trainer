import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kioku_japanese/pages/news_pages.dart';
import 'package:kioku_japanese/services/news_service.dart';

void main() {
  testWidgets('tap a word for meaning, listen to a sentence and answer a question', (tester) async {
    final spoken = <String>[];
    const token = NewsToken(parts: [('本', 'ほん')], word: '本', level: 5, meaning: '책', reading: 'ほん');
    const article = NewsArticle(id: 'fixture', date: '2026-10-04', category: '하루의 일기',
      title: [NewsToken(parts: [('日記', 'にっき')])], titleKorean: '일기',
      paragraphs: [NewsParagraph(tokens: [token, NewsToken(parts: [('です。', '')])], korean: '책입니다.')],
      distribution: {'N5': 1}, words: [],
      question: NewsQuestion(prompt: '본문에 나온 물건은?', options: ['우산', '책', '가방', '신발'], answer: 1, explanation: '本은 책입니다.'));
    await tester.pumpWidget(MaterialApp(home: NewsArticlePage(article: article, speakJapanese: (s) async => spoken.add(s))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('本').first);
    await tester.pumpAndSettle();
    expect(find.text('책'), findsOneWidget);
    expect(find.text('JLPT N5'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('word-popup-speak')));
    expect(spoken, ['本']);
    Navigator.of(tester.element(find.text('책'))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('news-speak-0')));
    expect(spoken.last, '本です。');
    await tester.scrollUntilVisible(find.byKey(const ValueKey('reading-answer-0')), 150);
    await tester.tap(find.byKey(const ValueKey('reading-answer-0')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(const ValueKey('reading-feedback')), 150);
    expect(find.text('정답은 2번이에요.'), findsOneWidget);
    expect(find.text('本은 책입니다.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
