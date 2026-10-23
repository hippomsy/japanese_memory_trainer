import 'package:flutter/material.dart';
import 'package:kioku_japanese/services/news_service.dart';
import 'package:kioku_japanese/widgets/study_widgets.dart';

/// 2026-10-01 후리가나(루비)와 JLPT 급수 색 밑줄을 붙여 문장을 그린다.
/// 단어 단위로 줄바꿈되며, 후리가나를 끄면 줄 간격도 함께 줄어든다.
class RubyText extends StatelessWidget {
  const RubyText({
    super.key,
    required this.tokens,
    this.fontSize = 22,
    this.fontWeight = FontWeight.w500,
    this.showRuby = true,
    this.showUnderline = true,
    this.color = Washi.ink,
    this.onWordTap,
  });

  final List<NewsToken> tokens;
  final double fontSize;
  final FontWeight fontWeight;
  final bool showRuby;
  final bool showUnderline;
  final Color color;
  final void Function(NewsToken)? onWordTap;

  @override
  Widget build(BuildContext context) {
    final rubySize = (fontSize * 0.46).clamp(9.0, 14.0);
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.end,
      runSpacing: showRuby ? 6 : 4,
      children: [
        for (final token in tokens)
          if (token.word == null &&
              token.parts.every((p) => p.$2.isEmpty) &&
              token.text.runes.length > 6)
            for (final rune in token.text.runes)
              _token(
                  NewsToken(parts: [(String.fromCharCode(rune), '')]), rubySize)
          else
            _token(token, rubySize),
      ],
    );
  }

  Widget _token(NewsToken token, double rubySize) {
    final lineColor = (showUnderline && token.level != null)
        ? GradeColors.of('N${token.level}').main
        : Colors.transparent;
    final hasRuby = showRuby && token.parts.any((p) => p.$2.isNotEmpty);
    final content = Container(
      margin: const EdgeInsets.symmetric(horizontal: 1),
      padding: const EdgeInsets.only(bottom: 1),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: lineColor, width: 2.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final part in token.parts)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showRuby)
                  SizedBox(
                    height: rubySize * 1.35,
                    child: part.$2.isEmpty || !hasRuby
                        ? null
                        : Text(
                            part.$2,
                            maxLines: 1,
                            softWrap: false,
                            style: TextStyle(
                                fontSize: rubySize,
                                color: Washi.inkSoft,
                                height: 1.2),
                          ),
                  ),
                Text(
                  part.$1,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: fontWeight,
                    color: color,
                    height: 1.25,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
    if (onWordTap == null || token.meaning.isEmpty) return content;
    return Semantics(
        button: true,
        label: '${token.text}, 뜻 보기',
        child: InkWell(onTap: () => onWordTap!(token), child: content));
  }
}
