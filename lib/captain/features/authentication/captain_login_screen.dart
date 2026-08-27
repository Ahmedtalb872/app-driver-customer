import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/supabase/auth_exception.dart';
import '../../core/supabase/auth_repository.dart';
import '../../core/widgets/app_logo.dart';
import '../../providers/app_state_provider.dart';
import 'captain_forgot_password_screen.dart';
import 'captain_register_stepper_screen.dart';
import '../captain/captain_home_screen.dart';
import '../onboarding/pending_review_screen.dart';
import '../onboarding/permissions_screen.dart';

/// Captain login by phone number + password (no SMS needed - that's only
/// used once, to confirm the phone at registration).
class CaptainLoginScreen extends StatefulWidget {
  const CaptainLoginScreen({super.key});

  @override
  State<CaptainLoginScreen> createState() => _CaptainLoginScreenState();
}

class _CaptainLoginScreenState extends State<CaptainLoginScreen> {
  final _authRepository = AuthRepository();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorText;

  String get _fullPhone => '+222${_phoneController.text.trim()}';

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final phone = _phoneController.text.trim();
    if (phone.length < 8) {
      setState(() => _errorText = 'الرجاء إدخال رقم هاتف صحيح');
      return;
    }
    if (_passwordController.text.isEmpty) {
      setState(() => _errorText = 'الرجاء إدخال كلمة المرور');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });
    try {
      final profile = await _authRepository.signInWithPassword(
        phone: _fullPhone,
        password: _passwordController.text,
      );

      if (profile['role'] != 'captain') {
        await _authRepository.signOut();
        throw AppAuthException(
          'هذا الحساب غير مسجل ككابتن. الرجاء استخدام تطبيق الزبائن لتسجيل الدخول.',
        );
      }

      if (!mounted) return;
      Map<String, dynamic>? captain;
      bool approved = false;
      try {
        captain = await _authRepository.getCaptain(profile['id'] as String);
        approved = captain['status'] == 'approved';
      } on AppAuthException catch (_) {
        // Fall back to "not approved".
      }
      if (!mounted) return;
      final provider = Provider.of<AppStateProvider>(context, listen: false);
      provider.loginFromProfile(profile, _fullPhone, captain: captain);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => approved
              ? const PermissionsScreen(destination: CaptainHomeScreen())
              : const PendingReviewScreen(),
        ),
        (route) => false,
      );
    } on AppAuthException catch (e) {
      setState(() => _errorText = e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('تسجيل دخول الكابتن')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              const Center(child: AppLogo(width: 96)),
              const SizedBox(height: 20),
              const Text(
                'أهلاً بك يا كابتن!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkText,
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'سجل دخولك برقم هاتفك وكلمة المرور لبدء استقبال طلبات الركاب.',
                style: TextStyle(
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
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                textAlign: TextAlign.left,
                decoration: const InputDecoration(
                  hintText: '2XXXXXXXX',
                  prefixIcon: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      '+222',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkText,
                      ),
                    ),
                  ),
                  prefixIconConstraints: BoxConstraints(minWidth: 0),
                ),
              ),
              const SizedBox(height: 16),

              const Text(
                'كلمة المرور',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkText,
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                onSubmitted: (_) => _login(),
                decoration: InputDecoration(
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            const CaptainForgotPasswordScreen(),
                      ),
                    );
                  },
                  child: const Text('نسيت كلمة المرور؟'),
                ),
              ),

              if (_errorText != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorText!,
                  style: const TextStyle(
                    color: AppColors.error,
                    fontSize: 13,
                    fontFamily: 'Cairo',
                  ),
                ),
              ],
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: _isLoading ? null : _login,
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: AppColors.darkText,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text('تسجيل الدخول ككابتن'),
              ),
              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'تريد الانضمام ككابتن؟',
                    style: TextStyle(
                      color: AppColors.secondaryText,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) =>
                              const CaptainRegisterStepperScreen(),
                        ),
                      );
                    },
                    child: const Text('سجل الآن ككابتن جديد'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
