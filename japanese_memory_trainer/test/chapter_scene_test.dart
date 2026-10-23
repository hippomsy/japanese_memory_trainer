import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kioku_japanese/widgets/chapter_art.dart';

/// 2026-10-10 챕터별 장면 그림이 실제 파일로 모두 존재하는지 확인한다.
void main() {
  bool has(String scene) => File('assets/illustrations/$scene.webp').existsSync();

  test('메뉴별 장면 지도는 모두 실제 그림을 가리킨다', () {
    for (final entry in chapterScenes.entries) {
      for (final scene in entry.value) {
        expect(has(scene), isTrue, reason: '${entry.key}: $scene');
      }
    }
    expect(chapterSceneOf('grammar', 1), 'spring_park');
    expect(chapterSceneOf('vocab', 1), isNull);
  });

  test('스크린 일본어 강의·대본 장면 그림이 모두 존재한다', () {
    final data = jsonDecode(
        File('assets/screen/screen_lessons.json').readAsStringSync()) as Map;
    var lessons = 0;
    for (final m in data['movies'] as List) {
      for (final l in (m as Map)['lessons'] as List) {
        final scene = (l as Map)['scene'] as String? ?? '';
        expect(scene, isNotEmpty);
        expect(has(scene), isTrue, reason: scene);
        lessons++;
        for (final s in l['script'] as List) {
          final img = (s as Map)['img'] as String?;
          if (img != null) expect(has(img), isTrue, reason: img);
        }
      }
    }
    expect(lessons, 115);
  });
}
