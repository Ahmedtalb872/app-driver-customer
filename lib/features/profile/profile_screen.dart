import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../providers/app_state_provider.dart';
import '../../models/models.dart';
import '../wallet/wallet_screen.dart';
import '../trips/my_trips_screen.dart';
import '../support/support_screen.dart';
import '../support/settings_screen.dart';
import 'captain_documents_status_screen.dart';
import '../../dummy_data/dummy_data.dart';

class ProfileScreen extends StatelessWidget {
  final bool showAppBar;
  const ProfileScreen({super.key, this.showAppBar = false});

  void _showInfoDialog(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(title, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        content: Text(content, style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, height: 1.5), textAlign: TextAlign.center),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppStateProvider>(context);
    final isCustomer = provider.userType == UserType.customer;

    final avatarUrl = isCustomer 
        ? DummyData.dummyCustomer.avatar 
        : DummyData.dummyCaptain.user.avatar;
    final userName = isCustomer ? provider.customerName : provider.captainName;
    final userPhone = isCustomer ? provider.customerPhone : provider.captainPhone;
    final rating = isCustomer ? DummyData.dummyCustomer.rating : DummyData.dummyCaptain.user.rating;
    final tripsCount = isCustomer ? DummyData.dummyCustomer.tripsCount : provider.captainTripsCount;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: showAppBar
          ? AppBar(
              title: const Text('الملف الشخصي'),
            )
          : null,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            if (!showAppBar) const SizedBox(height: 20),
            
            // Profile Header Card
            _buildProfileHeader(avatarUrl, userName, userPhone, rating, tripsCount),
            const SizedBox(height: 24),
            
            // Menu Items List
            isCustomer 
                ? _buildCustomerMenu(context, provider)
                : _buildCaptainMenu(context, provider),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(String avatar, String name, String phone, double rating, int trips) {
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
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.darkText, fontFamily: 'Cairo'),
            ),
            const SizedBox(height: 4),
            Text(
              phone,
              style: const TextStyle(fontSize: 13, color: AppColors.secondaryText),
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
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.secondaryText, fontFamily: 'Cairo')),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.darkText, fontFamily: 'Cairo')),
      ],
    );
  }

  Widget _buildCustomerMenu(BuildContext context, AppStateProvider provider) {
    return Column(
      children: [
        _buildMenuCard([
          _buildMenuItem(
            icon: Icons.person_outline_rounded,
            title: 'معلوماتي الشخصية',
            onTap: () => _showInfoDialog(context, 'معلوماتي الشخصية', 'الاسم الكامل: ${provider.customerName}\nرقم الهاتف: ${provider.customerPhone}\nالدور: زبون في تطبيق الهدهد'),
          ),
          _buildMenuItem(
            icon: Icons.payment_rounded,
            title: 'طرق الدفع المفضلة',
            onTap: () => _showInfoDialog(context, 'طرق الدفع', 'يدعم التطبيق الدفع نقداً، والمحفظة، وحساب Bankily و Masrvi و Sedad كخيارات دفع رئيسية.'),
          ),
          _buildMenuItem(
            icon: Icons.wallet_rounded,
            title: 'المحفظة والرصيد',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const WalletScreen(showAppBar: true))),
          ),
          _buildMenuItem(
            icon: Icons.history_rounded,
            title: 'رحلاتي السابقة',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const MyTripsScreen(showAppBar: true))),
          ),
        ]),
        const SizedBox(height: 16),
        _buildMenuCard([
          _buildMenuItem(
            icon: Icons.bookmark_border_rounded,
            title: 'الأماكن المحفوظة والمفضلة',
            onTap: () => _showInfoDialog(context, 'الأماكن المحفوظة', 'المنزل: تفرغ زينة - مجمع البيت\nالعمل: لكصر - وسط المدينة\nالمطار: مطار أم التونسي الدولي'),
          ),
          _buildMenuItem(
            icon: Icons.support_agent_rounded,
            title: 'المساعدة والدعم الفني',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const SupportScreen(showAppBar: true))),
          ),
          _buildMenuItem(
            icon: Icons.settings_outlined,
            title: 'الإعدادات العامة',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const SettingsScreen())),
          ),
        ]),
        const SizedBox(height: 16),
        _buildMenuCard([
          _buildMenuItem(
            icon: Icons.description_outlined,
            title: 'الشروط والأحكام العامة',
            onTap: () => _showInfoDialog(context, 'الشروط والأحكام', 'تطبيق الهدهد مخصص فقط لنقل الركاب بالسيارات العادية داخل المدينة. يُحظر استخدام التطبيق لأي خدمات توصيل أو نقل بضائع أو مركبات غير مصرحة.'),
          ),
          _buildMenuItem(
            icon: Icons.privacy_tip_outlined,
            title: 'سياسة الخصوصية',
            onTap: () => _showInfoDialog(context, 'سياسة الخصوصية', 'نهتم بخصوصية بياناتك وموقعك الجغرافي. تُستخدم بيانات الموقع حصراً لمطابقة الرحلات وتتبع مسار المشوار الفعلي لضمان الأمان والنزاهة.'),
          ),
        ]),
      ],
    );
  }

  Widget _buildCaptainMenu(BuildContext context, AppStateProvider provider) {
    return Column(
      children: [
        _buildMenuCard([
          _buildMenuItem(
            icon: Icons.person_outline_rounded,
            title: 'معلومات الحساب الشخصي',
            onTap: () => _showInfoDialog(context, 'بيانات الكابتن', 'الاسم: ${provider.captainName}\nرقم الهاتف: ${provider.captainPhone}\nالدور: كابتن معتمد'),
          ),
          _buildMenuItem(
            icon: Icons.directions_car_rounded,
            title: 'بيانات وتفاصيل السيارة',
            onTap: () {
              final vehicle = DummyData.dummyCaptain.vehicle;
              _showInfoDialog(
                context, 
                'بيانات سيارتي', 
                'فئة السيارة: ${vehicle.typeArabic}\nالماركة والموديل: ${vehicle.brand} ${vehicle.model} (${vehicle.year})\nاللون: ${vehicle.color}\nرقم اللوحة: ${vehicle.plate}\nعدد المقاعد: ${vehicle.seats} ركاب'
              );
            },
          ),
          _buildMenuItem(
            icon: Icons.assignment_rounded,
            title: 'حالة المستندات المرفوعة',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const CaptainDocumentsStatusScreen())),
          ),
        ]),
        const SizedBox(height: 16),
        _buildMenuCard([
          _buildMenuItem(
            icon: Icons.wallet_rounded,
            title: 'المحفظة والأرباح اليومية',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const WalletScreen(showAppBar: true))),
          ),
          _buildMenuItem(
            icon: Icons.history_rounded,
            title: 'سجل مشاوير الكابتن',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const MyTripsScreen(showAppBar: true))),
          ),
          _buildMenuItem(
            icon: Icons.settings_outlined,
            title: 'إعدادات تطبيق الكابتن',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const SettingsScreen())),
          ),
        ]),
        const SizedBox(height: 16),
        _buildMenuCard([
          _buildMenuItem(
            icon: Icons.help_outline_rounded,
            title: 'الدعم والمساعدة الفورية',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const SupportScreen(showAppBar: true))),
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
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 20, endIndent: 20),
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
