import 'package:kioku_japanese/widgets/study_illustration.dart';
import 'package:flutter/material.dart';
import 'package:kioku_japanese/models/vocabulary.dart';
import 'package:kioku_japanese/widgets/word_card.dart';

/// 2026-09-26 오늘의 신규 단어를 한 장씩 보고 뜻과 예문을 먼저 익히는 화면이다.
class LearnPage extends StatefulWidget {
  const LearnPage({
    super.key,
    required this.words,
    required this.speakJapanese,
    required this.onFinished,
  });

  final List<Vocabulary> words;
  final Future<void> Function(String text) speakJapanese;
  final VoidCallback onFinished;

  @override
  State<LearnPage> createState() => _LearnPageState();
}

class _LearnPageState extends State<LearnPage> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.words.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('신규 단어 학습')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('오늘 새로 배울 단어가 없습니다.'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: widget.onFinished,
                child: const Text('복습으로 이동'),
              ),
            ],
          ),
        ),
      );
    }

    final word = widget.words[_index];
    return Scaffold(
      backgroundColor: const Color(0xFFFFFAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFAFC),
        surfaceTintColor: Colors.transparent,
        title: const Text('신규 단어 학습'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${_index + 1} / ${widget.words.length}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  minHeight: 9,
                  value: (_index + 1) / widget.words.length,
                  backgroundColor: Colors.pink.shade50,
                  color: Colors.pinkAccent,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(children: [
                    const StudyIllustration('words', height: 124),
                    const SizedBox(height: 10),
                    WordCard(
                    word: word,
                    onSpeak: () => _speak(word.reading),
                    onSpeakExample: () => _speak(word.exampleJapanese),
                  ),
                  ]),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.pinkAccent,
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _next,
                child: const Text(
                  '다음으로  →',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 2026-09-26 마지막 신규 단어 뒤에는 복습 화면으로 진행한다.
  void _next() {
    if (_index >= widget.words.length - 1) {
      widget.onFinished();
      return;
    }
    setState(() => _index++);
  }

  Future<void> _speak(String text) async {
    try {
      await widget.speakJapanese(text);
    } catch (_) {
      // 2026-09-26 발음 재생 실패는 다음 학습을 막지 않는다.
    }
  }
}
