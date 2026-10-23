import 'package:flutter/material.dart';

/// 2026-09-26 홈 화면의 기억 지표를 일관된 카드 형태로 보여준다.
class ProgressCard extends StatelessWidget {
  const ProgressCard({
    super.key,
    required this.label,
    required this.value,
    this.subtitle,
    this.prominent = false,
    this.onTap,
  });

  final String label;
  final String value;
  final String? subtitle;
  final bool prominent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(prominent ? 22 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(
                value,
                style: prominent
                    ? theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      )
                    : theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: theme.textTheme.bodySmall),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
