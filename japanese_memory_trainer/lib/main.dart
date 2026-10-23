import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kioku_japanese/app.dart';
import 'package:kioku_japanese/data/elementary_words.dart';
import 'package:kioku_japanese/data/kanji_dictionary.dart';
import 'package:kioku_japanese/data/kanji_parts.dart';
import 'package:kioku_japanese/data/sentence_bank.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 사용자 제공 초등학교 한자 PDF의 어휘를 전체 학습 목록으로 사용한다.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  final allWords = await loadElementaryWords();
  // 2026-09-29 한자 풀이 사전을 읽고, 한자별 관련 단어 색인을 만든다.
  final kanji = await KanjiDictionary.load();
  kanji.attachWords(allWords);
  KanjiDictionary.instance = kanji;
  // 2026-10-11 한자 부품(쪼개기) 사전은 뒤에서 미리 읽어 둔다.
  unawaited(KanjiPartsBank.load());
  // 2026-09-30 챕터별 문장 만들기 문제.
  SentenceBank.instance = await SentenceBank.load();
  runApp(KiokuJapaneseApp(preferences: preferences, seed: allWords));
}
