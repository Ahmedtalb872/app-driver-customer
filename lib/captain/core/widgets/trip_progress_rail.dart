import 'package:flutter/material.dart';
import '../constants/colors.dart';

/// A quiet 5-segment progress indicator for the trip lifecycle: request →
/// en route → arrived → in progress → summary. No numbers or labels - just
/// a calm visual cue of how far along the trip is, matching the "quiet
/// card" design direction (one accent color, minimal visual noise).
class TripProgressRail extends StatelessWidget {
  final int step; // 1-5
  const TripProgressRail({super.key, required this.step});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(5, (i) {
        final done = i < step;
        return Expanded(
          child: Container(
            height: 4,
            margin: EdgeInsets.only(left: i == 4 ? 0 : 6),
            decoration: BoxDecoration(
              color: done ? AppColors.primary : AppColors.border,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      }),
    );
  }
}
