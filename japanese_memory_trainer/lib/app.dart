import 'package:flutter/material.dart';
import 'package:kioku_japanese/services/daily_reading_service.dart';
import 'package:kioku_japanese/data/seed_words.dart';
import 'package:kioku_japanese/data/study_store.dart';
import 'package:kioku_japanese/models/vocabulary.dart';
import 'package:kioku_japanese/models/word_catalog.dart';
import 'package:kioku_japanese/pages/study_shell.dart';
import 'package:kioku_japanese/services/listening_store.dart';
import 'package:kioku_japanese/services/news_service.dart';
import 'package:kioku_japanese/services/tts_service.dart';
import 'package:kioku_japanese/widgets/study_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 2026-09-26 앱 전체 의존성을 한 번만 만들고 각 화면에 주입하는 조립 루트다.
/// 2026-09-27 화면 구조를 "급수 → 품사 → 14단어 챕터 → 목록/학습"으로 전면 교체했다.
class KiokuJapaneseApp extends StatefulWidget {
  const KiokuJapaneseApp({
    super.key,
    required this.preferences,
    this.seed = seedWords,
    this.speakJapanese,
    this.speakKorean,
  });

  final SharedPreferences preferences;
  final List<Vocabulary> seed;

  /// 2026-09-27 테스트에서 실제 TTS 대신 쓸 발음 함수(없으면 기기 TTS 사용).
  final Future<void> Function(String text)? speakJapanese;

  /// 2026-09-29 테스트에서 실제 TTS 대신 쓸 한국어 읽기 함수.
  final Future<void> Function(String text)? speakKorean;

  @override
  State<KiokuJapaneseApp> createState() => _KiokuJapaneseAppState();
}

class _KiokuJapaneseAppState extends State<KiokuJapaneseApp> {
  late final StudyStore _store;
  late final WordCatalog _catalog;
  late final NewsRepository _news;
  TtsService? _ttsService;

  @override
  void initState() {
    super.initState();
    _store = StudyStore(widget.preferences);
    _catalog = WordCatalog(widget.seed);
    // 2026-10-04 읽기: 앱에 든 '하루의 일기'(365편)를 하루 한 편씩 공개한다. 인터넷 뉴스는 쓰지 않는다.
    final lexicon = NewsLexicon.fromWords(widget.seed);
    final dailyReading = DailyReadingService(widget.preferences, lexicon);
    _news = NewsRepository(
      widget.preferences,
      lexicon: lexicon,
      dailyArticles: dailyReading.diaries,
    );
    if (widget.speakJapanese == null) _ttsService = TtsService();
  }

  @override
  void dispose() {
    _ttsService?.stop();
    super.dispose();
  }

  Future<void> _speak(String text) {
    final custom = widget.speakJapanese;
    if (custom != null) return custom(text);
    return _ttsService!.speakJapanese(text);
  }

  Future<void> _speakKorean(String text) async {
    final custom = widget.speakKorean;
    if (custom != null) return custom(text);
    if (widget.speakJapanese != null) return; // 테스트: 한국어 음성 없음
    return _ttsService!.speakKorean(text);
  }

  Future<void> _stopSpeaking() async {
    await _ttsService?.stop();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '하루 일본어',
      debugShowCheckedModeBanner: false,
      // 2026-09-27 "일본 감성" 테마: 크림색 종이 배경 + 남색 먹 + 주홍 포인트.
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
            seedColor: Washi.shu,
            primary: Washi.shu,
            surface: Washi.paper,
            onSurface: Washi.ink),
        scaffoldBackgroundColor: Washi.paper,
        // 2026-10-06 디자인 개편: 둥근 카드·부드러운 버튼·정돈된 하단 메뉴.
        appBarTheme: const AppBarTheme(
            backgroundColor: Washi.paper,
            foregroundColor: Washi.ink,
            surfaceTintColor: Colors.transparent,
            scrolledUnderElevation: 0,
            elevation: 0),
        filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
                backgroundColor: Washi.shu,
                foregroundColor: Colors.white,
                textStyle: const TextStyle(fontWeight: FontWeight.w800),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)))),
        outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
                foregroundColor: Washi.ink,
                side: const BorderSide(color: Washi.line),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)))),
        navigationBarTheme: NavigationBarThemeData(
          labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
              fontSize: 12,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w800
                  : FontWeight.w500,
              color: states.contains(WidgetState.selected)
                  ? Washi.shu
                  : Washi.inkSoft)),
        ),
        dividerTheme: const DividerThemeData(color: Washi.line),
        dialogTheme: const DialogThemeData(backgroundColor: Washi.card),
        drawerTheme: const DrawerThemeData(backgroundColor: Washi.paper),
      ),
      home: StudyShell(
        catalog: _catalog,
        store: _store,
        speakJapanese: _speak,
        speakKorean: _speakKorean,
        stop: _stopSpeaking,
        news: _news,
        listening: ListeningStore(widget.preferences),
        speakListening: (text, rate) => widget.speakJapanese != null
            ? widget.speakJapanese!(text)
            : _ttsService!.speakListening(text, rate),
        speakListeningAs: (text, rate, pitch) => widget.speakJapanese != null
            ? widget.speakJapanese!(text)
            : _ttsService!.speakListening(text, rate, pitch: pitch),
      ),
    );
  }
}
