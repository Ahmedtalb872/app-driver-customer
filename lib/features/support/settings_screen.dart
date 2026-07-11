import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../providers/app_state_provider.dart';
import '../onboarding/user_type_selection_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _darkModeEnabled = false;
  bool _shareLocationEnabled = true;
  String _selectedLanguage = 'العربية';

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: const Text(
            'حذف الحساب نهائياً',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: AppColors.error),
            textAlign: TextAlign.center,
          ),
          content: const Text(
            'هل أنت متأكد من رغبتك في حذف حسابك؟ هذا الإجراء نهائي ولا يمكن الرجوع عنه وستفقد جميع بياناتك وأرصدة محفظتك.',
            style: TextStyle(fontFamily: 'Cairo', fontSize: 13),
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _handleLogout();
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              child: const Text('نعم، احذف الحساب'),
            ),
          ],
        );
      },
    );
  }

  void _handleLogout() {
    final provider = Provider.of<AppStateProvider>(context, listen: false);
    provider.logout();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const UserTypeSelectionScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('الإعدادات العامة'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // General Settings Card
            Card(
              child: Column(
                children: [
                  // Language Selection
                  ListTile(
                    title: const Text('لغة التطبيق', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14)),
                    trailing: DropdownButton<String>(
                      value: _selectedLanguage,
                      underline: Container(),
                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.bold),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedLanguage = newValue;
                          });
                        }
                      },
                      items: <String>['العربية', 'Français', 'English']
                          .map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                    ),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  
                  // Notifications Switch
                  SwitchListTile(
                    activeColor: AppColors.primary,
                    title: const Text('تفعيل الإشعارات', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text('استلام تحديثات الرحلات والعروض المتاحة.', style: TextStyle(fontFamily: 'Cairo', fontSize: 11)),
                    value: _notificationsEnabled,
                    onChanged: (bool value) {
                      setState(() {
                        _notificationsEnabled = value;
                      });
                    },
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  
                  // Dark Mode Switch
                  SwitchListTile(
                    activeColor: AppColors.primary,
                    title: const Text('الوضع الداكن (Dark Mode)', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text('تفعيل مظهر مريح للعينين ليلاً (تجريبي).', style: TextStyle(fontFamily: 'Cairo', fontSize: 11)),
                    value: _darkModeEnabled,
                    onChanged: (bool value) {
                      setState(() {
                        _darkModeEnabled = value;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('الوضع الداكن سيتم دعمه بشكل كامل في التحديثات القادمة.', style: TextStyle(fontFamily: 'Cairo')),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  
                  // Location Share Switch
                  SwitchListTile(
                    activeColor: AppColors.primary,
                    title: const Text('مشاركة الموقع الجغرافي', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text('السماح للتطبيق بمشاركة موقعك لتسهيل الالتقاء.', style: TextStyle(fontFamily: 'Cairo', fontSize: 11)),
                    value: _shareLocationEnabled,
                    onChanged: (bool value) {
                      setState(() {
                        _shareLocationEnabled = value;
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            // Security Card
            const Text(
              'الأمان والحساب',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.darkText, fontFamily: 'Cairo'),
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.lock_reset_rounded, color: AppColors.secondaryText),
                    title: const Text('تغيير كلمة المرور', style: TextStyle(fontFamily: 'Cairo', fontSize: 14)),
                    trailing: const Icon(Icons.chevron_left_rounded),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('تم إرسال رابط تغيير كلمة المرور لهاتفك.', style: TextStyle(fontFamily: 'Cairo')),
                          backgroundColor: AppColors.primary,
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    leading: const Icon(Icons.delete_forever_rounded, color: AppColors.error),
                    title: const Text('حذف الحساب نهائياً', style: TextStyle(fontFamily: 'Cairo', fontSize: 14, color: AppColors.error)),
                    trailing: const Icon(Icons.chevron_left_rounded, color: AppColors.error),
                    onTap: _showDeleteAccountDialog,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            // Log out Button
            ElevatedButton.icon(
              onPressed: _handleLogout,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('تسجيل الخروج'),
            ),
          ],
        ),
      ),
    );
  }
}
