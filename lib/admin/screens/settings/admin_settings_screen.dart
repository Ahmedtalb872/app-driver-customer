import 'package:flutter/material.dart';

import '../../repositories/admin_settings_repository.dart';
import '../../widgets/confirm_dialog.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  final _repository = AdminSettingsRepository();
  bool _loading = true;
  Map<String, dynamic> _settings = {};

  late final TextEditingController _appNameController;
  late final TextEditingController _supportPhoneController;
  late final TextEditingController _supportEmailController;
  late final TextEditingController _privacyUrlController;
  late final TextEditingController _termsUrlController;
  late final TextEditingController _minVersionController;
  bool _maintenanceMode = false;
  bool _forceUpdate = false;
  bool _captainRegistrationEnabled = true;

  @override
  void initState() {
    super.initState();
    _appNameController = TextEditingController();
    _supportPhoneController = TextEditingController();
    _supportEmailController = TextEditingController();
    _privacyUrlController = TextEditingController();
    _termsUrlController = TextEditingController();
    _minVersionController = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _appNameController.dispose();
    _supportPhoneController.dispose();
    _supportEmailController.dispose();
    _privacyUrlController.dispose();
    _termsUrlController.dispose();
    _minVersionController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final settings = await _repository.load();
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _appNameController.text = settings['app_name'] as String? ?? '';
      _supportPhoneController.text = settings['support_phone'] as String? ?? '';
      _supportEmailController.text = settings['support_email'] as String? ?? '';
      _privacyUrlController.text =
          settings['privacy_policy_url'] as String? ?? '';
      _termsUrlController.text = settings['terms_url'] as String? ?? '';
      _minVersionController.text =
          settings['min_supported_version'] as String? ?? '';
      _maintenanceMode = settings['maintenance_mode'] as bool? ?? false;
      _forceUpdate = settings['force_update'] as bool? ?? false;
      _captainRegistrationEnabled =
          settings['captain_registration_enabled'] as bool? ?? true;
      _loading = false;
    });
  }

  Future<void> _save() async {
    final ok = await showConfirmDialog(
      context,
      title: 'حفظ إعدادات التطبيق',
      message: 'هل تريد حفظ التغييرات على إعدادات التطبيق؟',
    );
    if (!ok) return;

    final payload = {
      'app_name': _appNameController.text.trim(),
      'support_phone': _supportPhoneController.text.trim(),
      'support_email': _supportEmailController.text.trim(),
      'privacy_policy_url': _privacyUrlController.text.trim(),
      'terms_url': _termsUrlController.text.trim(),
      'min_supported_version': _minVersionController.text.trim(),
      'maintenance_mode': _maintenanceMode,
      'force_update': _forceUpdate,
      'captain_registration_enabled': _captainRegistrationEnabled,
    };
    await _repository.update(_settings, payload);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تم حفظ الإعدادات بنجاح',
            style: TextStyle(fontFamily: 'Cairo'),
          ),
        ),
      );
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Padding(
      padding: const EdgeInsets.all(20),
      child: ListView(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _appNameController,
                    decoration: const InputDecoration(labelText: 'اسم التطبيق'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _supportPhoneController,
                    decoration: const InputDecoration(labelText: 'هاتف الدعم'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _supportEmailController,
                    decoration: const InputDecoration(
                      labelText: 'بريد الدعم الإلكتروني',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _privacyUrlController,
                    decoration: const InputDecoration(
                      labelText: 'رابط سياسة الخصوصية',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _termsUrlController,
                    decoration: const InputDecoration(
                      labelText: 'رابط الشروط والأحكام',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _minVersionController,
                    decoration: const InputDecoration(
                      labelText: 'أقل نسخة مدعومة',
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text(
                      'وضع الصيانة',
                      style: TextStyle(fontFamily: 'Cairo'),
                    ),
                    value: _maintenanceMode,
                    onChanged: (v) => setState(() => _maintenanceMode = v),
                  ),
                  SwitchListTile(
                    title: const Text(
                      'إجبار التحديث',
                      style: TextStyle(fontFamily: 'Cairo'),
                    ),
                    value: _forceUpdate,
                    onChanged: (v) => setState(() => _forceUpdate = v),
                  ),
                  SwitchListTile(
                    title: const Text(
                      'تفعيل تسجيل الكباتن',
                      style: TextStyle(fontFamily: 'Cairo'),
                    ),
                    value: _captainRegistrationEnabled,
                    onChanged: (v) =>
                        setState(() => _captainRegistrationEnabled = v),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ElevatedButton(
                      onPressed: _save,
                      child: const Text('حفظ الإعدادات'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
