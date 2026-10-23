import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kioku_japanese/config.dart';

// 2026-10-17 메인 화면 버전 표시(appVersion)가 pubspec.yaml 버전과 같은지 확인.
void main() {
  test('appVersion matches pubspec version', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final m = RegExp(r'^version:\s*([0-9.]+)\+', multiLine: true).firstMatch(pubspec);
    expect(m, isNotNull);
    expect(appVersion, m!.group(1));
  });
}
