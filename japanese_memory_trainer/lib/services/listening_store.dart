import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kioku_japanese/data/listening_bank.dart';

class ListeningStore {
  ListeningStore(this.preferences, {DateTime Function()? clock})
      : clock = clock ?? DateTime.now;
  final SharedPreferences preferences;
  final DateTime Function() clock;
  static const key = 'n4_listening_records_v1';
  static const lastKey = 'n4_listening_last_v1';
  Map<String, dynamic> get records {
    try {
      return jsonDecode(preferences.getString(key) ?? '{}')
          as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  String get today => dateKey(clock());
  static String dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  bool completed(String id) => records[id]?['correct'] == true;
  bool due(String id) {
    final entry = records[id];
    return entry != null &&
        entry['correct'] == false &&
        !DateTime.parse(entry['due'] as String).isAfter(clock());
  }

  ListeningLesson get nextLesson {
    for (final lesson in n4ListeningLessons) {
      if (due(lesson.id)) return lesson;
    }
    final last = preferences.getString(lastKey);
    for (final lesson in n4ListeningLessons) {
      if (lesson.id == last && !records.containsKey(lesson.id)) return lesson;
    }
    return n4ListeningLessons.firstWhere((l) => !records.containsKey(l.id),
        orElse: () => n4ListeningLessons.firstWhere((l) => !completed(l.id),
            orElse: () => n4ListeningLessons.first));
  }

  Future<void> start(String id) async {
    await preferences.setString(lastKey, id);
  }

  Future<void> record(String id, bool correct) async {
    final data = records;
    final now = clock();
    final next = DateTime(now.year, now.month, now.day + 1);
    data[id] = {
      'correct': correct,
      'due': next.toIso8601String(),
      'date': dateKey(now),
      'attempts': ((data[id]?['attempts'] as int?) ?? 0) + 1
    };
    if (!await preferences.setString(key, jsonEncode(data))) {
      throw StateError('청해 기록을 저장하지 못했습니다.');
    }
    final days = (preferences.getStringList('n4_listening_days_v1') ?? [])
        .toSet()
      ..add(dateKey(now));
    await preferences.setStringList(
        'n4_listening_days_v1', days.toList()..sort());
  }

  Set<String> get days =>
      (preferences.getStringList('n4_listening_days_v1') ?? []).toSet();
  int get correctCount =>
      n4ListeningLessons.where((l) => completed(l.id)).length;
  int get dueCount => n4ListeningLessons.where((l) => due(l.id)).length;
  int get todayCount => records.values.where((e) => e['date'] == today).length;
}
