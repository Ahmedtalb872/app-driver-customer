import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../providers/app_state_provider.dart';

/// Demo captain leaderboard, ranked by completed trips. The list below is
/// placeholder data - once trip completions are written to Supabase, this
/// should be replaced with a real query grouping trips by captain_id.
const List<Map<String, dynamic>> _kDummyLeaderboard = [
  {'name': 'محمد ولد أحمد', 'trips': 214},
  {'name': 'سيدي ولد المختار', 'trips': 187},
  {'name': 'عبد الله ولد الشيخ', 'trips': 165},
  {'name': 'إسلم ولد بلال', 'trips': 142},
  {'name': 'محمد الأمين ولد الطالب', 'trips': 129},
  {'name': 'أحمدو ولد سالم', 'trips': 118},
  {'name': 'الشيخ ولد محمدن', 'trips': 104},
  {'name': 'بلال ولد إبراهيم', 'trips': 96},
  {'name': 'الحسن ولد آدمين', 'trips': 81},
  {'name': 'يحيى ولد الطايع', 'trips': 67},
];

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppStateProvider>(context, listen: false);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('المسابقات وترتيب الكباتنة')),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.emoji_events_rounded,
                  color: AppColors.primaryDark,
                  size: 28,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'الترتيب الشهري حسب عدد المشاوير المكتملة. تصدّر القائمة لتفوز بجوائز شهرية!',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkText,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _kDummyLeaderboard.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final entry = _kDummyLeaderboard[index];
                final rank = index + 1;
                final isMe = entry['name'] == provider.captainName;
                return _buildRankRow(
                  rank: rank,
                  name: entry['name'] as String,
                  trips: entry['trips'] as int,
                  isMe: isMe,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRankRow({
    required int rank,
    required String name,
    required int trips,
    required bool isMe,
  }) {
    Color? medalColor;
    if (rank == 1) medalColor = const Color(0xFFFFD700);
    if (rank == 2) medalColor = const Color(0xFFC0C0C0);
    if (rank == 3) medalColor = const Color(0xFFCD7F32);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isMe ? AppColors.primary.withOpacity(0.12) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isMe
            ? Border.all(color: AppColors.primaryDark, width: 1.5)
            : null,
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: medalColor != null
                ? Icon(Icons.emoji_events_rounded, color: medalColor, size: 26)
                : Text(
                    '$rank',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.secondaryText,
                      fontFamily: 'Cairo',
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          const CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.background,
            child: Icon(Icons.person, color: AppColors.secondaryText),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isMe ? '$name (أنت)' : name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: AppColors.darkText,
                fontFamily: 'Cairo',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '$trips مشوار',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryDark,
              fontFamily: 'Cairo',
            ),
          ),
        ],
      ),
    );
  }
}
