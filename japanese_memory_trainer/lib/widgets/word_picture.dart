import 'package:flutter/material.dart';
import 'package:kioku_japanese/data/n4_word_icons.dart';

/// 2026-10-21 단어 그림 카드(고래 암기장처럼 단어 옆·카드 위에 그림을 보여 준다).
/// 2026-10-22 아이콘만으로는 뜻이 안 보여서, 단어마다 뜻을 그린 컬러 일러스트
/// (assets/n4_word_images/<단어 id>.webp, 만드는 법: tool/n4_word_images_render.py)를 쓴다.
/// 그림 파일이 없으면 예전 아이콘(n4WordIcons) → [fallback] 순으로 대신 보여 준다.
class WordPicture extends StatelessWidget {
  const WordPicture(
      {super.key,
      required this.wordId,
      this.size = 48,
      this.fallback = Icons.translate_rounded});

  final String wordId;
  final double size;
  final IconData fallback;

  /// 2026-10-21 배경(옅은 색)·테두리(진한 색) 짝. 단어 id 로 골라 같은 단어는 늘 같은 색.
  static const List<(Color, Color)> _palette = [
    (Color(0xFFFFE8E0), Color(0xFFE2553F)), // 주홍
    (Color(0xFFE3F1FF), Color(0xFF3B6FD6)), // 하늘
    (Color(0xFFE5F6EC), Color(0xFF2F8A5B)), // 말차
    (Color(0xFFFFF2D6), Color(0xFFD08A12)), // 황매화
    (Color(0xFFF0E9FF), Color(0xFF7A57D1)), // 등나무
    (Color(0xFFFFE6EF), Color(0xFFD94E7A)), // 벚꽃
    (Color(0xFFE0F5F2), Color(0xFF23907A)), // 어린 대나무
    (Color(0xFFEDEFF7), Color(0xFF3D4870)), // 먹
  ];

  /// 2026-10-22 단어 그림 파일 경로.
  static String assetFor(String wordId) => 'assets/n4_word_images/$wordId.webp';

  static IconData? iconFor(String wordId) => n4WordIcons[wordId];

  static (Color, Color) colorsFor(String wordId) {
    var h = 0;
    for (final c in wordId.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return _palette[h % _palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = colorsFor(wordId);
    final r = size * 0.28;
    final pad = size * 0.09;
    return Container(
      key: ValueKey('word-picture-$wordId'),
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(r),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.lerp(bg, Colors.white, 0.55)!, bg],
        ),
        border: Border.all(color: fg.withValues(alpha: 0.18), width: size > 80 ? 2 : 1),
        boxShadow: size > 80
            ? [
                BoxShadow(
                    color: fg.withValues(alpha: 0.16),
                    blurRadius: 14,
                    offset: const Offset(0, 6))
              ]
            : null,
      ),
      padding: EdgeInsets.all(pad),
      child: Image.asset(
        assetFor(wordId),
        key: ValueKey('word-picture-image-$wordId'),
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) =>
            Icon(iconFor(wordId) ?? fallback, size: size * 0.56, color: fg),
      ),
    );
  }
}
