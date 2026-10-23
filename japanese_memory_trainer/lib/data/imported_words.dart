import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:kioku_japanese/models/vocabulary.dart';

/// 2026-09-27 assets/data 아래에 있는 JLPT 공개 단어 목록 JSON 파일들이다. 급수별로
/// 파일을 나눠 두면 이후 단어를 더 추가할 때 이 목록에 파일명만 이어 붙이면 된다.
/// 출처: elzup/jlpt-word-list(MIT 라이선스, 표기·읽기·급수 원본)를 바탕으로
/// 한국어 뜻과 예문은 이 프로젝트에서 새로 작성했다.
const List<String> importedWordAssetPaths = <String>[
  'assets/data/jlpt_n5_part1.json',
  'assets/data/jlpt_n5_part2.json',
  'assets/data/jlpt_n5_part3.json',
  'assets/data/jlpt_n5_part4.json',
  'assets/data/jlpt_n4_part1.json',
  'assets/data/jlpt_n4_part2.json',
  'assets/data/jlpt_n4_part3.json',
  'assets/data/jlpt_n4_part4.json',
  'assets/data/jlpt_n3_part1.json',
  'assets/data/jlpt_n3_part2.json',
  'assets/data/jlpt_n3_part3.json',
  'assets/data/jlpt_n3_part4.json',
  'assets/data/jlpt_n3_part5.json',
  'assets/data/jlpt_n3_part6.json',
  'assets/data/jlpt_n3_part7.json',
  'assets/data/jlpt_n3_part8.json',
  'assets/data/jlpt_n3_part9.json',
  'assets/data/jlpt_n3_part10.json',
  'assets/data/jlpt_n3_part11.json',
  'assets/data/jlpt_n3_part12.json',
  'assets/data/jlpt_n3_part13.json',
  'assets/data/jlpt_n3_part14.json',
  'assets/data/jlpt_n3_part15.json',
  'assets/data/jlpt_n2_part1.json',
  'assets/data/jlpt_n2_part2.json',
  'assets/data/jlpt_n2_part3.json',
  'assets/data/jlpt_n2_part4.json',
  'assets/data/jlpt_n2_part5.json',
  'assets/data/jlpt_n2_part6.json',
  'assets/data/jlpt_n2_part7.json',
  'assets/data/jlpt_n2_part8.json',
  'assets/data/jlpt_n2_part9.json',
  'assets/data/jlpt_n2_part10.json',
  'assets/data/jlpt_n2_part11.json',
  'assets/data/jlpt_n1_part1.json',
  'assets/data/jlpt_n1_part2.json',
  'assets/data/jlpt_n1_part3.json',
  'assets/data/jlpt_n1_part4.json',
  'assets/data/jlpt_n1_part5.json',
  'assets/data/jlpt_n1_part6.json',
  'assets/data/jlpt_n1_part7.json',
  'assets/data/jlpt_n1_part8.json',
  'assets/data/jlpt_n1_part9.json',
  'assets/data/jlpt_n1_part10.json',
  'assets/data/jlpt_n1_part11.json',
  'assets/data/jlpt_n1_part12.json',
];

/// 2026-09-27 대량 수입 단어 JSON을 읽어 Vocabulary 목록으로 변환한다. 파일 하나가
/// 없거나 손상돼도 나머지 파일은 정상적으로 로드되도록 파일 단위로 오류를 무시한다.
Future<List<Vocabulary>> loadImportedWords() async {
  final result = <Vocabulary>[];
  for (final path in importedWordAssetPaths) {
    try {
      final raw = await rootBundle.loadString(path);
      final decoded = jsonDecode(raw);
      if (decoded is! List) continue;
      for (final item in decoded) {
        if (item is! Map) continue;
        result.add(Vocabulary.fromJson(Map<String, dynamic>.from(item)));
      }
    } catch (_) {
      // 2026-09-27 개별 데이터 파일 문제로 앱 전체가 실행 불가능해지지 않도록 건너뛴다.
      continue;
    }
  }
  return result;
}
