import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/auth/auth_service.dart';
import '../../core/config/demo_mode_config.dart';
import '../../core/constants/colors.dart';
import '../../dummy_data/demo_credentials.dart';
import '../../providers/app_state_provider.dart';
import 'captain_register_stepper_screen.dart';
import 'phone_code_login_screen.dart';
import '../captain/captain_home_screen.dart';
import '../../models/models.dart';

class CaptainLoginScreen extends StatefulWidget {
  const CaptainLoginScreen({super.key});

  @override
  State<CaptainLoginScreen> createState() => _CaptainLoginScreenState();
}

class _CaptainLoginScreenState extends State<CaptainLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    final rawPhone = _phoneController.text;
    final phone = '+222$rawPhone';

    try {
      final demoRole = DemoCredentials.matchRole(
        rawPhone,
        _passwordController.text,
      );

      if (demoRole == UserType.captain) {
        // BUGFIX: this used to be `await Future.delayed(...)` only - a pure
        // client-side fake with no real Supabase session. That silently
        // broke every backend-dependent captain feature (going online,
        // receiving live requests, ...): captain_set_online reads
        // auth.uid() server-side, which was null, so the RPC always
        // rejected with "No captain profile found for the current user".
        // Sign in for real, reusing the same backend-connected demo
        // captain account (and its `internalPassword`) that the
        // phone-code login screen already uses via DemoModeConfig - same
        // account, no new captain created, just a genuine session this
        // time.
        final demoAccount = DemoModeConfig.demoAccounts[phone];
        if (demoAccount == null) {
          throw const AuthException(
            'تعذر العثور على بيانات الحساب التجريبي لهذا الرقم.',
          );
        }
        debugPrint(
          '[CaptainLogin] demo captain login: phone=$phone - '
          'signing in for real via DemoModeConfig internal credential',
        );
        await AuthService.instance.signIn(
          phone: phone,
          password: demoAccount.internalPassword,
        );
      } else {
        await AuthService.instance.signIn(
          phone: phone,
          password: _passwordController.text,
        );
      }

      if (!mounted) return;

      final provider = Provider.of<AppStateProvider>(context, listen: false);
      provider.login(phone, UserType.captain);

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const CaptainHomeScreen()),
        (route) => false,
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message, style: const TextStyle(fontFamily: 'Cairo')),
          backgroundColor: AppColors.error,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تعذر تسجيل الدخول. تحقق من الاتصال بالإنترنت وحاول مرة أخرى.',
            style: TextStyle(fontFamily: 'Cairo'),
          ),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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
        title: const Text('تسجيل دخول الكابتن'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Form(
            key: _formKey,
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
                  'سجل دخولك لبدء استقبال طلبات الركاب وتحقيق أرباح يومية.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.secondaryText,
                    fontFamily: 'Cairo',
                  ),
                ),
                const SizedBox(height: 32),

                // Phone field
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
                const SizedBox(height: 20),

                // Password field
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
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    hintText: 'أدخل كلمة المرور الخاصة بك',
                    prefixIcon: const Icon(
                      Icons.lock_outline_rounded,
                      color: AppColors.secondaryText,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: AppColors.secondaryText,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'الرجاء إدخال كلمة المرور';
                    }
                    if (value.length < 6) {
                      return 'كلمة المرور يجب أن لا تقل عن 6 أحرف';
                    }
                    return null;
                  },
                ),

                // Forgot Password link
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'تم إرسال رمز إعادة تعيين كلمة المرور لهاتفك.',
                            style: TextStyle(fontFamily: 'Cairo'),
                          ),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    },
                    child: const Text('نسيت كلمة المرور؟'),
                  ),
                ),
                const SizedBox(height: 24),

                // Submit Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text('تسجيل الدخول ككابتن'),
                ),
                const SizedBox(height: 12),

                // Phone + verification-code login link
                Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => PhoneCodeLoginScreen(
                            userType: UserType.captain,
                            title: 'تسجيل الدخول برمز التحقق',
                            subtitle: 'أدخل رقم هاتفك لإرسال رمز التحقق إليه.',
                            onSignedIn: () {
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const CaptainHomeScreen(),
                                ),
                                (route) => false,
                              );
                            },
                          ),
                        ),
                      );
                    },
                    child: const Text('تسجيل الدخول برمز التحقق'),
                  ),
                ),
                const SizedBox(height: 12),

                // Create account link
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
      ),
    );
  }
}
