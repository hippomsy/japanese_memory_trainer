import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:kioku_japanese/models/vocabulary.dart';

Future<List<Vocabulary>> loadElementaryWords() async {
  final raw =
      await rootBundle.loadString('assets/data/elementary_pdf_words.json');
  return (jsonDecode(raw) as List)
      .map(
          (item) => Vocabulary.fromJson(Map<String, dynamic>.from(item as Map)))
      .toList();
}
