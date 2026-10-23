import 'package:flutter/material.dart';

/// 2026-10-10 메뉴별 강의 번호 → 내용에 맞는 장면 그림(assets/illustrations/<장면>.webp).
/// 목록에 없는 메뉴·번호는 기존 menu_chapters/*.jpg 를 그대로 쓴다.
const Map<String, List<String>> chapterScenes = {
  'grammar': ['spring_park', 'letter_desk', 'sea', 'train', 'night_city', 'cafe', 'snow', 'bakery', 'onsen', 'kitchen', 'sunset_sea', 'phone', 'hospital', 'morning_room', 'office', 'autumn', 'library', 'home', 'supermarket', 'rainy_town', 'izakaya', 'river', 'city_tower', 'road_car', 'shrine', 'tv_studio', 'festival', 'airport', 'school', 'summer_field'],
  'reading': ['rainy_town', 'home', 'onsen', 'shrine', 'birthday', 'letter_desk', 'night_river', 'village', 'school', 'train', 'snow', 'autumn', 'spring_park', 'cat_books', 'kitchen', 'cafe', 'tv_studio', 'festival', 'summer_field', 'supermarket'],
  'n4': ['cafe', 'amusement', 'letter_desk', 'school', 'birthday', 'morning_room', 'home', 'village', 'izakaya', 'kitchen', 'library', 'spring_park', 'office', 'train', 'supermarket', 'phone', 'snow', 'festival', 'night_city', 'shrine', 'summer_field', 'sea', 'rainy_town', 'river', 'hospital', 'road_car', 'city_tower', 'bakery', 'cat_books', 'office'],
  'listening': ['train', 'airport', 'village', 'supermarket', 'bakery', 'festival', 'phone', 'city_tower', 'onsen', 'izakaya', 'night_river', 'cafe', 'rainy_town', 'tv_studio', 'road_car', 'amusement', 'home', 'hospital', 'morning_room', 'night_city', 'birthday', 'kitchen', 'letter_desk', 'office', 'supermarket'],
  'jlpt': ['school', 'library', 'train', 'cafe'],
  'mock': ['library', 'school'],

};

/// 메뉴(theme)와 강 번호에 맞는 장면 이름. 없으면 null.
String? chapterSceneOf(String theme, int number) {
  final list = chapterScenes[theme];
  if (list == null || number < 1 || number > list.length) return null;
  return list[number - 1];
}

/// 2026-10-10 장면 그림 한 장(webp). 없으면 부드러운 빈 칸으로 대체한다.
class SceneArt extends StatelessWidget {
  const SceneArt(this.scene, {super.key, this.height = 150, this.width, this.radius = 16});
  final String scene;
  final double height;
  final double? width;
  final double radius;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.asset(
          'assets/illustrations/$scene.webp',
          height: height,
          width: width ?? double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            height: height,
            width: width,
            color: const Color(0xFFF4EAE0),
            alignment: Alignment.center,
            child: const Icon(Icons.image_rounded, size: 34),
          ),
        ),
      );
}

/// 2026-10-10 메뉴와 강의 번호에 맞는 오프라인 삽화를 표시합니다.
class ChapterArt extends StatelessWidget {
  const ChapterArt(this.theme, this.number, {super.key, this.height = 132, this.width});
  final String theme;
  final int number;
  final double height;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final scene = chapterSceneOf(theme, number);
    if (scene != null) {
      return SceneArt(scene, height: height, width: width, radius: 14);
    }
    final index = ((number < 1 ? 1 : number) - 1) % 60 + 1;
    final name = index.toString().padLeft(2, '0');
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.asset(
        'assets/illustrations/menu_chapters/${theme}_$name.jpg',
        height: height,
        width: width ?? double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          height: height,
          width: width,
          color: const Color(0xFFF4EAE0),
          alignment: Alignment.center,
          child: const Icon(Icons.auto_stories_rounded, size: 38),
        ),
      ),
    );
  }
}
