import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/auth/auth_service.dart';
import '../../core/config/demo_mode_config.dart';
import '../../core/constants/colors.dart';
import '../../providers/app_state_provider.dart';

/// Phone number + verification-code sign-in/sign-up for the customer app.
/// Hudhud's fixed demo accounts (see [DemoModeConfig]) work end-to-end
/// through this screen today; a real phone number goes through the exact
/// same [AuthService.requestPhoneCode] / `verifyPhoneCode` calls, which
/// requires an SMS provider to be configured on the Supabase project before
/// a real code is ever delivered. Supabase's phone-OTP flow creates the
/// account automatically on first verification, so this screen doubles as
/// both login and sign-up - a brand-new customer is prompted for their name
/// once, right after verifying (see [_ensureFullName]).
class PhoneCodeLoginScreen extends StatefulWidget {
  const PhoneCodeLoginScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onSignedIn,
  });

  final String title;
  final String subtitle;

  /// Called after a successful sign-in, with the login screen's own
  /// [BuildContext] still valid - use it to navigate to the home screen.
  final VoidCallback onSignedIn;

  @override
  State<PhoneCodeLoginScreen> createState() => _PhoneCodeLoginScreenState();
}

class _PhoneCodeLoginScreenState extends State<PhoneCodeLoginScreen> {
  final _phoneFormKey = GlobalKey<FormState>();
  final _codeFormKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();

  bool _codeSent = false;
  bool _isLoading = false;
  String? _fullPhone;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (!_phoneFormKey.currentState!.validate()) return;
    final phone = '+222${_phoneController.text}';

    setState(() => _isLoading = true);
    try {
      await AuthService.instance.requestPhoneCode(phone);
      if (!mounted) return;
      setState(() {
        _fullPhone = phone;
        _codeSent = true;
      });
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError(
        'تعذر إرسال رمز التحقق. تحقق من الاتصال بالإنترنت وحاول مرة أخرى.',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyCode() async {
    if (!_codeFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await AuthService.instance.verifyPhoneCode(
        phone: _fullPhone!,
        code: _codeController.text.trim(),
      );
      if (!mounted) return;

      final fullName = await _ensureFullName();
      if (!mounted) return;

      final provider = Provider.of<AppStateProvider>(context, listen: false);
      provider.login(_fullPhone!, fullName: fullName);
      widget.onSignedIn();
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('رمز التحقق غير صحيح أو انتهت صلاحيته.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Returns the signed-in customer's name, prompting for one first if this
  /// is a brand-new account (phone-OTP sign-up never collects a name up
  /// front - see [AuthService.requestPhoneCode]).
  Future<String> _ensureFullName() async {
    String existing = '';
    try {
      existing = await AuthService.instance.fetchCurrentFullName();
    } catch (_) {
      // Best effort - a transient profile-fetch failure shouldn't block an
      // otherwise-successful sign-in; fall through and prompt for a name.
    }
    if (existing.isNotEmpty) return existing;
    if (!mounted) return '';

    final nameController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final name = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: const Text(
            'مرحباً بك في الهدهد!',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ما اسمك الكامل؟',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 13),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: nameController,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(hintText: 'مثال: أحمد سالم'),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'الرجاء إدخال اسمك'
                      : null,
                  onFieldSubmitted: (_) {
                    if (formKey.currentState!.validate()) {
                      Navigator.of(
                        dialogContext,
                      ).pop(nameController.text.trim());
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.of(dialogContext).pop(nameController.text.trim());
                }
              },
              child: const Text('متابعة'),
            ),
          ],
        ),
      ),
    );
    nameController.dispose();

    final fullName = name ?? '';
    if (fullName.isNotEmpty) {
      await AuthService.instance.updateFullName(fullName);
    }
    return fullName;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'Cairo')),
        backgroundColor: AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(widget.title),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: _codeSent ? _buildCodeStep() : _buildPhoneStep(),
        ),
      ),
    );
  }

  Widget _buildPhoneStep() {
    return Form(
      key: _phoneFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Center(
            child: ClipOval(
              child: Image.asset(
                'assets/images/al-houdhoud-logo.png',
                width: 72,
                height: 72,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            widget.subtitle,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.secondaryText,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'رقم الهاتف',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.darkText,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            textAlign: TextAlign.left,
            style: const TextStyle(
              fontSize: 16,
              letterSpacing: 1.5,
              fontWeight: FontWeight.bold,
            ),
            decoration: InputDecoration(
              hintText: '36 00 00 00',
              hintStyle: const TextStyle(
                letterSpacing: 1.0,
                fontWeight: FontWeight.normal,
              ),
              prefixIcon: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 15,
                ),
                margin: const EdgeInsets.only(left: 10),
                decoration: const BoxDecoration(
                  border: Border(
                    left: BorderSide(color: AppColors.border, width: 1),
                  ),
                ),
                child: const Text(
                  '+222',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkText,
                  ),
                ),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'الرجاء إدخال رقم الهاتف';
              }
              if (value.length < 8) {
                return 'رقم الهاتف يجب أن يتكون من 8 أرقام على الأقل';
              }
              return null;
            },
          ),
          if (DemoModeConfig.isEnabled) ...[
            const SizedBox(height: 12),
            const Text(
              'وضع التجربة مفعّل على هذا الإصدار: أرقام الحسابات التجريبية '
              'التي زُوّدت بها تعمل مباشرة برمزها الثابت.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.secondaryText,
                fontFamily: 'Cairo',
              ),
            ),
          ],
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isLoading ? null : _sendCode,
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : const Text('إرسال رمز التحقق'),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeStep() {
    return Form(
      key: _codeFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Text(
            'تم إرسال رمز التحقق إلى $_fullPhone',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.secondaryText,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'رمز التحقق',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.darkText,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _codeController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 6,
            style: const TextStyle(
              fontSize: 24,
              letterSpacing: 8,
              fontWeight: FontWeight.bold,
            ),
            decoration: const InputDecoration(
              hintText: '••••••',
              counterText: '',
            ),
            validator: (value) {
              if (value == null || value.length != 6) {
                return 'أدخل رمز التحقق المكون من 6 أرقام';
              }
              return null;
            },
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _isLoading
                  ? null
                  : () => setState(() {
                      _codeSent = false;
                      _codeController.clear();
                    }),
              child: const Text('تغيير رقم الهاتف'),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _isLoading ? null : _verifyCode,
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : const Text('تأكيد وتسجيل الدخول'),
          ),
        ],
      ),
    );
  }
}
