import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/demo_mode_config.dart';
import '../../core/admin_colors.dart';
import '../../services/admin_auth_service.dart';
import '../../services/admin_session.dart';

/// Admin dashboard sign-in. Supports two modes on the same screen:
/// password (the existing phone/email + password flow) and phone +
/// verification code. Hudhud's fixed demo admin account (see
/// [DemoModeConfig]) only works through the code mode; real admin phone
/// numbers work through either, though code mode still requires an SMS
/// provider to be configured on the Supabase project before a real code is
/// ever delivered.
class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  bool _useCode = false;

  // Password-mode state
  final _passwordFormKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;

  // Code-mode state
  final _phoneFormKey = GlobalKey<FormState>();
  final _codeFormKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  bool _codeSent = false;
  String? _fullPhone;

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submitPassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await AdminAuthService.instance.signIn(
        identifier: _identifierController.text.trim(),
        password: _passwordController.text,
      );
      await _afterSignIn();
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(
        () => _error = 'تعذر تسجيل الدخول، تحقق من البيانات وحاول مرة أخرى.',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendCode() async {
    if (!_phoneFormKey.currentState!.validate()) return;
    final phone = '+222${_phoneController.text}';

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AdminAuthService.instance.requestPhoneCode(phone);
      if (!mounted) return;
      setState(() {
        _fullPhone = phone;
        _codeSent = true;
      });
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(
        () => _error =
            'تعذر إرسال رمز التحقق. تحقق من الاتصال بالإنترنت وحاول مرة أخرى.',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyCode() async {
    if (!_codeFormKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await AdminAuthService.instance.verifyPhoneCode(
        phone: _fullPhone!,
        code: _codeController.text.trim(),
      );
      await _afterSignIn();
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'رمز التحقق غير صحيح أو انتهت صلاحيته.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _afterSignIn() async {
    if (!mounted) return;
    await context.read<AdminSession>().refresh();
    if (!mounted) return;

    final session = context.read<AdminSession>();
    if (session.status == AdminSessionStatus.authorized) {
      context.go('/admin/dashboard');
    } else {
      await AdminAuthService.instance.signOut();
      setState(
        () => _error = 'هذا الحساب لا يملك صلاحية الوصول إلى لوحة التحكم.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminColors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset(
                        'assets/images/al-houdhoud-logo.png',
                        height: 96,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'لوحة تحكم الهدهد',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AdminColors.textPrimary,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'AL HODHOD Admin Dashboard',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: AdminColors.textSecondary,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    const SizedBox(height: 24),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: false, label: Text('كلمة المرور')),
                        ButtonSegment(value: true, label: Text('رمز التحقق')),
                      ],
                      selected: {_useCode},
                      onSelectionChanged: (selection) {
                        setState(() {
                          _useCode = selection.first;
                          _error = null;
                        });
                      },
                    ),
                    const SizedBox(height: 20),
                    if (_useCode)
                      ..._buildCodeMode()
                    else
                      ..._buildPasswordMode(),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: const TextStyle(
                          color: AdminColors.error,
                          fontSize: 12,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildPasswordMode() {
    return [
      Form(
        key: _passwordFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _identifierController,
              decoration: const InputDecoration(
                labelText: 'رقم الهاتف أو البريد الإلكتروني',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'كلمة المرور',
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) => (v == null || v.isEmpty) ? 'مطلوب' : null,
              onFieldSubmitted: (_) => _submitPassword(),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loading ? null : _submitPassword,
              child: _loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Text('تسجيل الدخول'),
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _buildCodeMode() {
    if (_codeSent) {
      return [
        Form(
          key: _codeFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'تم إرسال رمز التحقق إلى $_fullPhone',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: AdminColors.textSecondary,
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                style: const TextStyle(fontSize: 22, letterSpacing: 6),
                decoration: const InputDecoration(
                  labelText: 'رمز التحقق',
                  counterText: '',
                ),
                validator: (v) => (v == null || v.length != 6)
                    ? 'أدخل رمز التحقق المكون من 6 أرقام'
                    : null,
                onFieldSubmitted: (_) => _verifyCode(),
              ),
              TextButton(
                onPressed: _loading
                    ? null
                    : () => setState(() {
                        _codeSent = false;
                        _codeController.clear();
                        _error = null;
                      }),
                child: const Text('تغيير رقم الهاتف'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _loading ? null : _verifyCode,
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text('تأكيد وتسجيل الدخول'),
              ),
            ],
          ),
        ),
      ];
    }

    return [
      Form(
        key: _phoneFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'رقم الهاتف',
                prefixText: '+222 ',
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'الرجاء إدخال رقم الهاتف';
                if (v.length < 8) {
                  return 'رقم الهاتف يجب أن يتكون من 8 أرقام على الأقل';
                }
                return null;
              },
              onFieldSubmitted: (_) => _sendCode(),
            ),
            if (DemoModeConfig.isEnabled) ...[
              const SizedBox(height: 8),
              const Text(
                'وضع التجربة مفعّل على هذا الإصدار: رقم حساب المدير '
                'التجريبي يعمل مباشرة برمزه الثابت.',
                style: TextStyle(
                  fontSize: 11,
                  color: AdminColors.textSecondary,
                  fontFamily: 'Cairo',
                ),
              ),
            ],
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loading ? null : _sendCode,
              child: _loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Text('إرسال رمز التحقق'),
            ),
          ],
        ),
      ),
    ];
  }
}
