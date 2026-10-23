import 'package:just_audio/just_audio.dart';

/// 2026-10-05 테마별 기초 청취의 원어민 녹음(MP3) 재생기.
/// 테스트에서 가짜 구현으로 바꿀 수 있도록 인터페이스로 분리했다.
abstract class LessonAudio {
  Stream<bool> get playingStream;
  Stream<bool> get completedStream;
  Stream<Duration> get positionStream;
  Stream<Duration?> get durationStream;
  Future<void> load(String assetPath);
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> setSpeed(double speed);
  Future<void> setLoop(bool loop);

  /// 2026-10-05 [assetPath]의 [start]~[end] 구간만 재생한다(문장·문제 듣기).
  Future<void> playClip(String assetPath, Duration start, Duration end);
  Future<void> dispose();
}

/// 2026-10-05 강 번호에 맞는 녹음 파일 경로 (1강 → assets/basicjl_audio/lesson_01.mp3).
String lessonAudioAsset(int number) =>
    'assets/basicjl_audio/lesson_${number.toString().padLeft(2, '0')}.mp3';

/// 2026-10-05 just_audio 기반 실제 구현.
class JustLessonAudio implements LessonAudio {
  final AudioPlayer _player = AudioPlayer();
  String? _asset;

  @override
  Stream<bool> get playingStream => _player.playingStream;
  @override
  Stream<bool> get completedStream => _player.processingStateStream
      .map((s) => s == ProcessingState.completed);
  @override
  Stream<Duration> get positionStream => _player.positionStream;
  @override
  Stream<Duration?> get durationStream => _player.durationStream;
  @override
  Future<void> load(String assetPath) async {
    await _player.setAsset(assetPath);
    _asset = assetPath;
  }
  @override
  Future<void> play() async {
    if (_player.processingState == ProcessingState.completed) {
      await _player.seek(Duration.zero);
    }
    // play()는 재생이 끝날 때까지 완료되지 않으므로 기다리지 않는다.
    _player.play();
  }

  @override
  Future<void> pause() => _player.pause();
  @override
  Future<void> seek(Duration position) => _player.seek(position);
  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);
  @override
  Future<void> setLoop(bool loop) =>
      _player.setLoopMode(loop ? LoopMode.one : LoopMode.off);
  @override
  Future<void> playClip(String assetPath, Duration start, Duration end) async {
    await _player.pause();
    if (_asset != assetPath) await load(assetPath);
    await _player.setClip(start: start, end: end);
    await _player.seek(Duration.zero);
    _player.play();
  }

  @override
  Future<void> dispose() => _player.dispose();
}
