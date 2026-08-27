import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../providers/app_state_provider.dart';
import '../wallet/wallet_screen.dart';
import '../trips/my_trips_screen.dart';
import '../support/support_screen.dart';
import '../support/settings_screen.dart';
import 'captain_edit_info_screen.dart';
import '../../dummy_data/dummy_data.dart';

class ProfileScreen extends StatelessWidget {
  final bool showAppBar;
  const ProfileScreen({super.key, this.showAppBar = false});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppStateProvider>(context);

    final avatarUrl = DummyData.dummyCaptain.user.avatar;
    final userName = provider.captainName;
    final userPhone = provider.captainPhone;
    final rating = DummyData.dummyCaptain.user.rating;
    final tripsCount = provider.captainTripsCount;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: showAppBar ? AppBar(title: const Text('الملف الشخصي')) : null,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            if (!showAppBar) const SizedBox(height: 20),

            // Profile Header Card
            _buildProfileHeader(
              avatarUrl,
              userName,
              userPhone,
              rating,
              tripsCount,
            ),
            const SizedBox(height: 24),

            // Menu Items List
            _buildCaptainMenu(context, provider),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(
    String avatar,
    String name,
    String phone,
    double rating,
    int trips,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            CircleAvatar(
              radius: 46,
              backgroundImage: NetworkImage(avatar),
              backgroundColor: AppColors.background,
            ),
            const SizedBox(height: 16),
            Text(
              name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.darkText,
                fontFamily: 'Cairo',
              ),
            ),
            const SizedBox(height: 4),
            Text(
              phone,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.secondaryText,
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildHeaderStat('التقييم', '$rating ⭐'),
                Container(width: 1, height: 30, color: AppColors.border),
                _buildHeaderStat('المشاوير', '$trips مشوار'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderStat(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.secondaryText,
            fontFamily: 'Cairo',
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.darkText,
            fontFamily: 'Cairo',
          ),
        ),
      ],
    );
  }

  Widget _buildCaptainMenu(BuildContext context, AppStateProvider provider) {
    return Column(
      children: [
        _buildMenuCard([
          _buildMenuItem(
            icon: Icons.edit_rounded,
            title: 'تعديل المعلومات والمستندات',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const CaptainEditInfoScreen(),
              ),
            ),
          ),
        ]),
        // Available to every captain: for a motorcycle captain this is the
        // only kind of request they ever receive; for a car captain it's
        // on top of their normal passenger rides.
        const SizedBox(height: 16),
        _buildMenuCard([
          ListTile(
            leading: Icon(
              Icons.inventory_2_rounded,
              color: provider.deliveryModeEnabled
                  ? AppColors.primaryDark
                  : AppColors.secondaryText,
              size: 22,
            ),
            title: const Text(
              'قبول طلبات توصيل',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.darkText,
                fontFamily: 'Cairo',
              ),
            ),
            trailing: Switch(
              value: provider.deliveryModeEnabled,
              activeColor: AppColors.primaryDark,
              onChanged: (_) => provider.toggleDeliveryMode(),
            ),
          ),
        ]),
        const SizedBox(height: 16),
        _buildMenuCard([
          _buildMenuItem(
            icon: Icons.wallet_rounded,
            title: 'المحفظة والأرباح اليومية',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const WalletScreen(showAppBar: true),
              ),
            ),
          ),
          _buildMenuItem(
            icon: Icons.history_rounded,
            title: 'سجل مشاوير الكابتن',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const MyTripsScreen(showAppBar: true),
              ),
            ),
          ),
          _buildMenuItem(
            icon: Icons.settings_outlined,
            title: 'إعدادات تطبيق الكابتن',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const SettingsScreen()),
            ),
          ),
        ]),
        const SizedBox(height: 16),
        _buildMenuCard([
          _buildMenuItem(
            icon: Icons.help_outline_rounded,
            title: 'الدعم والمساعدة الفورية',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const SupportScreen(showAppBar: true),
              ),
            ),
          ),
        ]),
      ],
    );
  }

  Widget _buildMenuCard(List<Widget> children) {
    return Card(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: children.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, indent: 20, endIndent: 20),
        itemBuilder: (context, index) => children[index],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary, size: 22),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppColors.darkText,
          fontFamily: 'Cairo',
        ),
      ),
      trailing: const Icon(Icons.chevron_left_rounded, size: 20),
      onTap: onTap,
    );
  }
}
