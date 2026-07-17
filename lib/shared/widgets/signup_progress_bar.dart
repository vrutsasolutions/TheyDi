import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class SignupProgressBar extends StatelessWidget {
  const SignupProgressBar({
    super.key,
    required this.step,
    required this.totalSteps,
  });

  final int step;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          'Step $step of $totalSteps',
          style: TheyDiTextStyles.caption,
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: step / totalSteps,
          backgroundColor: TheyDiColors.divider,
          valueColor: const AlwaysStoppedAnimation<Color>(
            TheyDiColors.primary,
          ),
          borderRadius: BorderRadius.circular(4),
          minHeight: 4,
        ),
      ],
    );
  }
}
