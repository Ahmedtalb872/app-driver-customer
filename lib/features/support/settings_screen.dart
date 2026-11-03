import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/auth/auth_service.dart';
import '../../core/constants/colors.dart';
import '../../core/services/session_guard_service.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/app_state_provider.dart';
import '../../providers/locale_provider.dart';
import '../authentication/auth_welcome_screen.dart';
import 'about_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _darkModeEnabled = false;
  bool _shareLocationEnabled = true;

  void _showDeleteAccountDialog() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Text(
            l10n.deleteAccount,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.bold,
              color: AppColors.error,
            ),
            textAlign: TextAlign.center,
          ),
          content: Text(
            l10n.deleteAccountDialogContent,
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _handleDeleteAccount();
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              child: Text(l10n.deleteAccountConfirm),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleLogout() async {
    SessionGuardService.instance.stop();
    await AuthService.instance.signOut();
    if (!mounted) return;
    final provider = Provider.of<AppStateProvider>(context, listen: false);
    provider.logout();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const AuthWelcomeScreen()),
      (route) => false,
    );
  }

  /// Really deletes the account, unlike before - this button used to just
  /// call [_handleLogout] while the confirmation dialog promised the data
  /// was gone forever. See AuthService.deleteAccount.
  Future<void> _handleDeleteAccount() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      await AuthService.instance.deleteAccount();
      SessionGuardService.instance.stop();
      if (!mounted) return;
      Navigator.of(context).pop(); // the progress dialog
      final provider = Provider.of<AppStateProvider>(context, listen: false);
      provider.logout();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const AuthWelcomeScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // the progress dialog
      final l10n = AppLocalizations.of(context)!;
      final message = e.toString().contains('ACTIVE_TRIP')
          ? l10n.deleteAccountErrorActiveTrip
          : e.toString().contains('OUTSTANDING_DEBT')
          ? l10n.deleteAccountErrorDebt
          : l10n.deleteAccountErrorGeneric;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(fontFamily: 'Cairo')),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final localeProvider = context.watch<LocaleProvider>();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.asset(
            'assets/images/al-houdhoud-logo-mark.png',
            fit: BoxFit.contain,
          ),
        ),
        title: Text(l10n.settingsTitle),
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
                    title: Text(
                      l10n.appLanguage,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    trailing: DropdownButton<String>(
                      value: localeProvider.locale.languageCode,
                      underline: Container(),
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13,
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          context.read<LocaleProvider>().setLocale(
                            Locale(newValue),
                          );
                        }
                      },
                      items: const <String, String>{
                        'ar': 'العربية',
                        'fr': 'Français',
                      }.entries
                          .map<DropdownMenuItem<String>>((entry) {
                            return DropdownMenuItem<String>(
                              value: entry.key,
                              child: Text(entry.value),
                            );
                          })
                          .toList(),
                    ),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),

                  // Notifications Switch
                  SwitchListTile(
                    activeColor: AppColors.primary,
                    title: Text(
                      l10n.enableNotifications,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      l10n.notificationsSubtitle,
                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 11),
                    ),
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
                    title: Text(
                      l10n.darkMode,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      l10n.darkModeSubtitle,
                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 11),
                    ),
                    value: _darkModeEnabled,
                    onChanged: (bool value) {
                      setState(() {
                        _darkModeEnabled = value;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            l10n.darkModeSnack,
                            style: const TextStyle(fontFamily: 'Cairo'),
                          ),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),

                  // Location Share Switch
                  SwitchListTile(
                    activeColor: AppColors.primary,
                    title: Text(
                      l10n.shareLocation,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      l10n.shareLocationSubtitle,
                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 11),
                    ),
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
            Text(
              l10n.securityAndAccount,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.darkText,
                fontFamily: 'Cairo',
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.delete_forever_rounded,
                      color: AppColors.error,
                    ),
                    title: Text(
                      l10n.deleteAccount,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 14,
                        color: AppColors.error,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.chevron_left_rounded,
                      color: AppColors.error,
                    ),
                    onTap: _showDeleteAccountDialog,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // About Card
            Card(
              child: ListTile(
                leading: SizedBox(
                  width: 32,
                  height: 32,
                  child: Image.asset(
                    'assets/images/al-houdhoud-logo-mark.png',
                    fit: BoxFit.contain,
                  ),
                ),
                title: Text(
                  l10n.aboutApp,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                trailing: const Icon(Icons.chevron_left_rounded),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const AboutScreen(),
                    ),
                  );
                },
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
              label: Text(l10n.logout),
            ),
          ],
        ),
      ),
    );
  }
}
