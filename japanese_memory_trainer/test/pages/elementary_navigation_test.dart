import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kioku_japanese/data/elementary_words.dart';
import 'package:kioku_japanese/data/study_store.dart';
import 'package:kioku_japanese/models/word_catalog.dart';
import 'package:kioku_japanese/pages/grade_list_page.dart';
import 'package:kioku_japanese/pages/category_list_page.dart';

void main() {
  testWidgets('all elementary grades open chapters directly', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final words = await tester.runAsync(loadElementaryWords);
    await tester.pumpWidget(MaterialApp(home: GradeListPage(
      catalog: WordCatalog(words!), store: StudyStore(prefs),
      speakJapanese: (_) async {},
    )));
    for (final grade in WordCatalog.elementaryGrades) {
      await tester.scrollUntilVisible(find.byKey(ValueKey('grade-$grade')), 200);
      await tester.tap(find.byKey(ValueKey('grade-$grade')));
      await tester.pumpAndSettle();
      expect(find.byType(ChapterListPage), findsOneWidget);
      expect(find.byType(CategoryListPage), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
  });
}
