import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kioku_japanese/pages/news_pages.dart';
import 'package:kioku_japanese/services/news_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 2026-10-01 쉬운 뉴스 화면 검증
void main() {
  final articles = parseNewsFeed(File('test/fixtures/news_sample.json').readAsStringSync());

  testWidgets('list opens article; toggles hide translation and ruby; speak paragraph', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final spoken = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: NewsListPage(
        repository: NewsRepository(prefs, bundled: articles),
        speakJapanese: (t) async => spoken.add(t),
      ),
    ));
    await tester.pumpAndSettle();
    final first = articles.first;
    expect(find.text(first.titleText), findsOneWidget);

    await tester.tap(find.byKey(ValueKey('news-${first.id}')));
    await tester.pumpAndSettle();
    expect(find.text('JLPT 단어 분포'), findsOneWidget);
    expect(find.byKey(const ValueKey('news-korean-0')), findsOneWidget);
    expect(find.text(first.paragraphs.first.korean), findsOneWidget);

    final rubyFinder = find.text(first.paragraphs.first.tokens.expand((t) => t.parts).firstWhere((p) => p.$2.isNotEmpty).$2);
    expect(rubyFinder, findsWidgets);
    await tester.tap(find.byKey(const ValueKey('news-toggle-ruby')));
    await tester.pumpAndSettle();
    expect(rubyFinder, findsNothing);

    await tester.ensureVisible(find.byKey(const ValueKey('news-korean-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('news-toggle-korean')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('news-korean-0')), findsNothing);

    await tester.drag(find.byType(ListView), const Offset(0, 3000)); // 맨 위로
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('news-speak-0')));
    expect(spoken, [first.paragraphs.first.japanese]);
  });
}
