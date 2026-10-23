import 'package:flutter/material.dart';

/// 2026-10-10 학습 화면에서 공통으로 사용하는 오프라인 삽화.
class StudyIllustration extends StatelessWidget {
  const StudyIllustration(this.name, {super.key, this.height = 156, this.fit = BoxFit.cover});
  final String name;
  final double height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(18),
    child: Image.asset(
      name.contains('.') ? 'assets/illustrations/$name' : 'assets/illustrations/$name.png',
      height: height, width: double.infinity, fit: fit,
      errorBuilder: (_, __, ___) => const SizedBox.shrink()),
  );
}
