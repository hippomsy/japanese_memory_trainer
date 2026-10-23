import 'package:kioku_japanese/widgets/study_illustration.dart';
import 'package:flutter/material.dart';

/// 2026-09-27 "일본 감성" 디자인 색상: 크림색 종이 배경 + 남색 먹 + 붉은 도장색.
/// 2026-10-06 전체 디자인 개편: 더 밝은 종이색, 깊은 남색, 산호빛 주홍과 보조색을 정리했다.
class Washi {
  Washi._();

  static const Color paper = Color(0xFFF7F3EC); // 종이(배경)
  static const Color card = Color(0xFFFFFFFF); // 카드
  static const Color ink = Color(0xFF1C2340); // 남색 먹(글자)
  static const Color inkSoft = Color(0xFF6A7088); // 연한 먹
  static const Color line = Color(0xFFEAE3D6); // 테두리
  static const Color shu = Color(0xFFE2553F); // 주홍(도장, 강조)
  static const Color matcha = Color(0xFF3E9B6A); // 정답

  // 2026-10-06 카테고리 색(메뉴가 늘어나도 구분되도록).
  static const Color sora = Color(0xFF4A7BE0); // 하늘
  static const Color fuji = Color(0xFF8B6CD9); // 등나무
  static const Color yamabuki = Color(0xFFE9A23B); // 황매화
  static const Color sakura = Color(0xFFE56B8F); // 벚꽃
  static const Color wakatake = Color(0xFF3FA88B); // 어린 대나무
  static const Color night = Color(0xFF2B2D42); // 밤(영화)
}

/// 2026-09-27 급수별 전통색(진한 색, 옅은 색)과 짧은 설명이다.
class GradeColors {
  const GradeColors(this.main, this.light, this.nickname);

  final Color main;
  final Color light;
  final String nickname;

  static const Map<String, GradeColors> _colors = <String, GradeColors>{
    'N1': GradeColors(Color(0xFFC8412E), Color(0xFFF3D6CF), '朱 · 최상급'),
    'N2': GradeColors(Color(0xFFD69A1C), Color(0xFFF6E6C0), '山吹 · 상급'),
    'N3': GradeColors(Color(0xFF7B6BA8), Color(0xFFE3DDF0), '藤 · 중급'),
    'N4': GradeColors(Color(0xFF4F8F5B), Color(0xFFD7EAD9), '若竹 · 초중급'),
    'N5': GradeColors(Color(0xFFCF7A93), Color(0xFFF6DCE3), '桜 · 입문'),
  };

  static GradeColors of(String grade) =>
      _colors[grade] ?? const GradeColors(Washi.ink, Washi.line, '');
}

/// 2026-09-27 둥근 도장(한코) 모양 배지. 급수 이름이나 "済" 같은 글자를 찍는다.
class HankoBadge extends StatelessWidget {
  const HankoBadge({
    super.key,
    required this.text,
    required this.color,
    this.size = 56,
    this.filled = false,
  });

  final String text;
  final Color color;
  final double size;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? color : Colors.transparent,
        border: Border.all(color: color, width: size * 0.06),
      ),
      alignment: Alignment.center,
      child: Padding(
        padding: EdgeInsets.all(size * 0.14),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            text,
            style: TextStyle(
              color: filled ? Colors.white : color,
              fontWeight: FontWeight.w900,
              fontSize: size * 0.36,
            ),
          ),
        ),
      ),
    );
  }
}

/// 2026-09-27 원형 진행 링. 가운데에 글자(예: 42%)를 넣는다.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.ratio,
    required this.color,
    required this.child,
    this.size = 60,
    this.stroke = 6,
  });

  final double ratio;
  final Color color;
  final Widget child;
  final double size;
  final double stroke;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: 1,
            strokeWidth: stroke,
            color: color.withValues(alpha: 0.15),
          ),
          CircularProgressIndicator(
            value: ratio.clamp(0.0, 1.0).toDouble(),
            strokeWidth: stroke,
            strokeCap: StrokeCap.round,
            color: color,
          ),
          Center(child: child),
        ],
      ),
    );
  }
}

/// 2026-09-27 둥근 모서리의 얇은 진행 막대다.
class SlimProgress extends StatelessWidget {
  const SlimProgress({super.key, required this.ratio, required this.color, this.height = 6});

  final double ratio;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: LinearProgressIndicator(
        value: ratio.clamp(0.0, 1.0).toDouble(),
        minHeight: height,
        color: color,
        backgroundColor: color.withValues(alpha: 0.15),
      ),
    );
  }
}

/// 2026-09-27 종이 느낌의 둥근 카드(얇은 테두리 + 옅은 그림자)다.
class PaperCard extends StatelessWidget {
  const PaperCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.color = Washi.card,
    this.borderColor = Washi.line,
    this.radius = 18,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color borderColor;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Washi.ink.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: borderColor),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// 2026-09-27 화면 위쪽의 크림색 제목 줄(뒤로가기 + 제목 + 오른쪽 버튼)이다.
PreferredSizeWidget washiAppBar({
  required String title,
  String? subtitle,
  List<Widget>? actions,
  Widget? leading,
}) {
  return AppBar(
    backgroundColor: Washi.paper,
    foregroundColor: Washi.ink,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    leading: leading,
    centerTitle: false,
    title: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 21)),
        if (subtitle != null)
          Text(
            subtitle,
            style: const TextStyle(fontSize: 13, color: Washi.inkSoft),
          ),
      ],
    ),
    actions: actions,
  );
}


/// 2026-10-06 그라데이션 머리 배너(화면 맨 위 소개 카드).
class HeroBanner extends StatelessWidget {
  const HeroBanner({
    super.key,
    required this.colors,
    required this.icon,
    required this.eyebrow,
    required this.title,
    this.subtitle,
    this.progress,
    this.action,
  });

  final List<Color> colors;
  final IconData icon;
  final String eyebrow, title;
  final String? subtitle;
  final double? progress;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
            colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        boxShadow: [
          BoxShadow(
              color: colors.last.withValues(alpha: 0.25),
              blurRadius: 20,
              offset: const Offset(0, 10)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(children: [
        Positioned(
          right: -24,
          top: -24,
          child: Icon(icon, size: 150, color: Colors.white.withValues(alpha: 0.08)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, color: const Color(0xFFFFD29E), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(eyebrow,
                    style: const TextStyle(
                        color: Color(0xFFFFD29E),
                        fontSize: 11.5,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w800)),
              ),
            ]),
            const SizedBox(height: 14),
            Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    height: 1.3,
                    fontWeight: FontWeight.w900)),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(subtitle!,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.78), height: 1.6)),
            ],
            if (progress != null) ...[
              const SizedBox(height: 12),
              SlimProgress(ratio: progress!, color: const Color(0xFFFFD29E)),
            ],
            if (action != null) ...[
              const SizedBox(height: 16),
              action!,
            ],
          ]),
        ),
      ]),
    );
  }
}

/// 2026-10-06 둥근 사각형 안의 아이콘(목록·카드 머리).
class IconBadge extends StatelessWidget {
  const IconBadge({super.key, required this.icon, required this.color, this.size = 46});
  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(size * 0.32)),
        child: Icon(icon, color: color, size: size * 0.52),
      );
}

/// 2026-10-06 구역 제목(왼쪽 굵은 제목 + 오른쪽 작은 보조 글).
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.trailing});
  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
                color: Washi.shu, borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 8),
        Expanded(
          child: Text(title,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800, color: Washi.ink)),
        ),
        if (trailing != null)
          Text(trailing!,
              style: const TextStyle(fontSize: 12, color: Washi.inkSoft)),
      ]);
}

/// 2026-10-06 대본의 화자 이름표.
class SpeakerChip extends StatelessWidget {
  const SpeakerChip({super.key, required this.name, required this.color});
  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20)),
        child: Text(name,
            style: TextStyle(
                color: color, fontSize: 12.5, fontWeight: FontWeight.w800)),
      );
}

/// 2026-10-06 일본어 듣기(스피커) 버튼. 읽는 동안에는 색이 채워진다.
class SpeakButton extends StatelessWidget {
  const SpeakButton(
      {super.key,
      required this.onPressed,
      this.speaking = false,
      this.color = Washi.shu,
      this.tooltip = '일본어로 듣기'});
  final VoidCallback onPressed;
  final bool speaking;
  final Color color;
  final String tooltip;

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor:
              speaking ? color : color.withValues(alpha: 0.10),
          foregroundColor: speaking ? Colors.white : color,
        ),
        icon: Icon(speaking ? Icons.graphic_eq_rounded : Icons.volume_up_rounded,
            size: 20),
      );
}

/// 2026-10-06 학습 카테고리 타일(학습 탭의 메뉴 격자).
class CategoryTile extends StatelessWidget {
  const CategoryTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    this.badge,
  });

  final String title, subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) => PaperCard(
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        radius: 22,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            IconBadge(icon: icon, color: color, size: 42),
            const Spacer(),
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                    color: color, borderRadius: BorderRadius.circular(10)),
                child: Text(badge!,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900)),
              ),
          ]),
          const SizedBox(height: 12),
          // 2026-10-10 글자 중심의 학습 메뉴에 분야별 상황 삽화를 표시한다.
          StudyIllustration(
            title.contains('스크린') ? 'rain' :
            title.contains('하나시') ? 'listening' :
            title.contains('청해') || title.contains('청취') ? 'listening' :
            title.contains('독해') || title.contains('일기') ? 'reading' :
            title.contains('문법') ? 'grammar' :
            title.contains('모의') ? 'exam' :
            title.contains('복습') ? 'progress' : 'words',
            height: 84,
          ),
          const SizedBox(height: 10),
          Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text(subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 12, color: Washi.inkSoft, height: 1.35)),
        ]),
      );
}
