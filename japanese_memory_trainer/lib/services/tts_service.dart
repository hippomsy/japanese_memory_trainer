import 'package:flutter_tts/flutter_tts.dart';

/// 2026-09-26 일본어 발음을 재생하고 TTS 오류가 학습 흐름을 중단하지 않게 감싼다.
/// 2026-09-29 자동 학습(일본어 → 한국어 읽어 주기)을 위해 한국어 읽기와, 말이 끝날 때까지
/// 기다리는 기능을 추가했다.
class TtsService {
  TtsService({FlutterTts? flutterTts}) : _tts = flutterTts ?? FlutterTts();

  final FlutterTts _tts;
  bool _awaitConfigured = false;
  String? _language;

  /// 2026-09-26 ja-JP 음성으로 일본어 텍스트를 읽는다(읽기가 끝나면 완료).
  Future<void> speakJapanese(String text) => _speak(text, 'ja-JP', 0.45);

  /// 2026-09-29 ko-KR 음성으로 한국어 텍스트를 읽는다(읽기가 끝나면 완료).
  Future<void> speakKorean(String text) => _speak(text, 'ko-KR', 0.5);

  /// Listening must report failures so a silent attempt cannot unlock answers.
  /// 2026-10-15 [pitch]로 화자마다 목소리 높이를 다르게 해 대화를 구분한다.
  Future<void> speakListening(String text, double rate, {double pitch = 1.0}) async {
    if (!_awaitConfigured) {
      await _tts.awaitSpeakCompletion(true);
      _awaitConfigured = true;
    }
    if (await _tts.isLanguageAvailable('ja-JP') != true) {
      throw StateError('Japanese voice is not installed');
    }
    await _tts.setLanguage('ja-JP');
    _language = 'ja-JP';
    await _tts.setSpeechRate(rate);
    await _tts.setPitch(pitch);
    await _tts.stop();
    final result = await _tts.speak(text).timeout(const Duration(seconds: 90));
    if (result != 1) throw StateError('Japanese speech failed');
  }

  Future<void> _speak(String text, String language, double rate) async {
    if (text.trim().isEmpty) return;
    try {
      if (!_awaitConfigured) {
        await _tts.awaitSpeakCompletion(true);
        _awaitConfigured = true;
      }
      if (_language != language) {
        await _tts.setLanguage(language);
        _language = language;
      }
      await _tts.setSpeechRate(rate);
      await _tts.setPitch(1.0);
      await _tts.stop();
      await _tts
          .speak(text)
          .timeout(const Duration(seconds: 10), onTimeout: () => null);
    } catch (_) {
      // 2026-09-26 TTS 실패는 학습 자체를 중단할 이유가 없으므로 무시한다.
    }
  }

  /// 2026-09-26 화면 전환 시 재생 중인 음성을 안전하게 중지한다.
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {
      // 2026-09-26 플러그인 종료 오류도 화면 전환을 막지 않는다.
    }
  }
}
