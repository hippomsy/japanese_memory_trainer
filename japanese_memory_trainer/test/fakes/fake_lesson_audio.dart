import 'dart:async';

import 'package:kioku_japanese/services/lesson_audio.dart';

/// 2026-10-05 원어민 녹음 재생기 테스트용 가짜 구현.
class FakeLessonAudio implements LessonAudio {
  final playing = StreamController<bool>.broadcast();
  String? loaded;
  final calls = <String>[];
  bool disposed = false;
  @override
  Stream<bool> get playingStream => playing.stream;
  @override
  Stream<bool> get completedStream => const Stream.empty();
  @override
  Stream<Duration> get positionStream => const Stream.empty();
  @override
  Stream<Duration?> get durationStream =>
      Stream.value(const Duration(seconds: 40));
  @override
  Future<void> load(String assetPath) async => loaded = assetPath;
  @override
  Future<void> play() async {
    calls.add('play');
    playing.add(true);
  }

  @override
  Future<void> pause() async {
    calls.add('pause');
    playing.add(false);
  }

  @override
  Future<void> seek(Duration position) async => calls.add('seek');
  @override
  Future<void> setSpeed(double speed) async => calls.add('speed $speed');
  @override
  Future<void> setLoop(bool loop) async => calls.add('loop $loop');
  @override
  Future<void> playClip(String assetPath, Duration start, Duration end) async {
    calls.add('clip $assetPath ${start.inMilliseconds}-${end.inMilliseconds}');
    playing.add(true);
  }

  @override
  Future<void> dispose() async => disposed = true;
}
