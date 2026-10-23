import 'package:flutter/material.dart';
import 'package:kioku_japanese/models/review_result.dart';

/// 2026-09-26 사용자가 체감한 기억 난이도 네 단계를 입력받는다.
class MemoryAnswerButtons extends StatelessWidget {
  const MemoryAnswerButtons({
    super.key,
    required this.onSelected,
    this.enabled = true,
  });

  final ValueChanged<MemoryFeeling> onSelected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        _button('몰랐음', MemoryFeeling.didNotKnow),
        _button('힘들게 기억', MemoryFeeling.hardRecall),
        _button('기억함', MemoryFeeling.remembered),
        _button('바로 기억', MemoryFeeling.instantRecall),
      ],
    );
  }

  Widget _button(String label, MemoryFeeling feeling) {
    return OutlinedButton(
      onPressed: enabled ? () => onSelected(feeling) : null,
      child: Text(label),
    );
  }
}
