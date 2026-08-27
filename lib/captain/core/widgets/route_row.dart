import 'package:flutter/material.dart';
import '../constants/colors.dart';

/// A single pickup/destination line: a colored dot followed by a shortened
/// address (just the point and wilaya, not the full geocoded string), with
/// an optional trailing note (e.g. a distance). Two of these stacked - green
/// dot for pickup, red for destination - is the app's standard way of
/// showing a trip's route, each point on its own line.
class RouteRow extends StatelessWidget {
  final Color dotColor;
  final String text;
  final String? trailing;
  final String? label;

  const RouteRow({
    super.key,
    required this.dotColor,
    required this.text,
    this.trailing,
    this.label,
  });

  // Some places are geocoded under a formal name captains don't actually
  // use day to day - substitute the local name so the app reads the way
  // captains actually talk about these spots.
  static const Map<String, String> _placeAliases = {'المفترق': 'كرفور'};

  // The full geocoded address ("point, quarter, moughataa, wilaya, ...") is
  // too much detail for this compact row - just the specific point and the
  // wilaya (its first and last comma-separated parts) is enough to place it.
  static String shortAddress(String raw) {
    final parts = raw
        .split(',')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return raw.trim();

    final point = _placeAliases[parts.first] ?? parts.first;
    if (parts.length == 1) return point;
    if (parts.length == 2) {
      final second = parts[1];
      return point == second ? point : '$point، $second';
    }
    final wilaya = parts.last;
    return point == wilaya ? point : '$point، $wilaya';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(left: 10, top: 4),
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
        if (label != null) ...[
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Text(
              label!,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.secondaryText,
                fontFamily: 'Cairo',
              ),
            ),
          ),
          const SizedBox(width: 6),
        ],
        Expanded(
          child: Text(
            shortAddress(text),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.darkText,
              fontFamily: 'Cairo',
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Text(
              trailing!,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.secondaryText,
                fontFamily: 'Cairo',
              ),
            ),
          ),
        ],
      ],
    );
  }
}
