import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../../core/supabase/auth_exception.dart';
import '../../core/supabase/auth_repository.dart';
import '../../core/widgets/app_logo.dart';

/// Lets a captain who forgot their password prove ownership of their phone
/// via a one-time SMS code, then set a new password. Three steps: enter
/// phone -> enter code + new password -> confirmation.
class CaptainForgotPasswordScreen extends StatefulWidget {
  const CaptainForgotPasswordScreen({super.key});

  @override
  State<CaptainForgotPasswordScreen> createState() =>
      _CaptainForgotPasswordScreenState();
}

class _CaptainForgotPasswordScreenState
    extends State<CaptainForgotPasswordScreen> {
  final _authRepository = AuthRepository();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  int _step = 1; // 1: phone, 2: code + new password, 3: done
  bool _isLoading = false;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorText;

  String get _fullPhone => '+222${_phoneController.text.trim()}';

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (_phoneController.text.trim().length < 8) {
      setState(() => _errorText = 'الرجاء إدخال رقم هاتف صحيح');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorText = null;
    });
    try {
      await _authRepository.sendPasswordResetOtp(_fullPhone);
      if (!mounted) return;
      setState(() => _step = 2);
    } on AppAuthException catch (e) {
      setState(() => _errorText = e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    if (_codeController.text.trim().length < 4) {
      setState(() => _errorText = 'أدخل رمز التحقق كاملاً');
      return;
    }
    if (_newPasswordController.text.length < 6) {
      setState(() => _errorText = 'كلمة المرور يجب أن تكون 6 أحرف على الأقل');
      return;
    }
    if (_newPasswordController.text != _confirmPasswordController.text) {
      setState(() => _errorText = 'كلمتا المرور غير متطابقتين');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorText = null;
    });
    try {
      await _authRepository.resetPasswordWithOtp(
        phone: _fullPhone,
        code: _codeController.text.trim(),
        newPassword: _newPasswordController.text,
      );
      if (!mounted) return;
      setState(() => _step = 3);
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
      appBar: AppBar(title: const Text('نسيت كلمة المرور')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              const Center(child: AppLogo(width: 80)),
              const SizedBox(height: 24),
              if (_step == 1) ..._buildStep1(),
              if (_step == 2) ..._buildStep2(),
              if (_step == 3) ..._buildStep3(),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildStep1() {
    return [
      const Text(
        'إعادة تعيين كلمة المرور',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppColors.darkText,
          fontFamily: 'Cairo',
        ),
      ),
      const SizedBox(height: 8),
      const Text(
        'أدخل رقم هاتفك المسجّل ككابتن، سنرسل لك رمز تحقق عبر رسالة نصية.',
        style: TextStyle(
          fontSize: 14,
          color: AppColors.secondaryText,
          fontFamily: 'Cairo',
        ),
      ),
      const SizedBox(height: 24),
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
        onSubmitted: (_) => _sendCode(),
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
        onPressed: _isLoading ? null : _sendCode,
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: AppColors.darkText,
                  strokeWidth: 2.5,
                ),
              )
            : const Text('إرسال رمز التحقق'),
      ),
    ];
  }

  List<Widget> _buildStep2() {
    return [
      const Text(
        'أدخل رمز التحقق وكلمة المرور الجديدة',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppColors.darkText,
          fontFamily: 'Cairo',
        ),
      ),
      const SizedBox(height: 8),
      Text(
        'أرسلنا رمزًا برسالة نصية إلى $_fullPhone',
        style: const TextStyle(
          fontSize: 13,
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
      TextField(
        controller: _codeController,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 22, letterSpacing: 8, fontWeight: FontWeight.bold),
        decoration: const InputDecoration(hintText: '- - - - - -'),
      ),
      const SizedBox(height: 16),
      const Text(
        'كلمة المرور الجديدة',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppColors.darkText,
          fontFamily: 'Cairo',
        ),
      ),
      const SizedBox(height: 8),
      TextField(
        controller: _newPasswordController,
        obscureText: _obscureNewPassword,
        decoration: InputDecoration(
          hintText: '6 أحرف على الأقل',
          suffixIcon: IconButton(
            icon: Icon(
              _obscureNewPassword
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded,
            ),
            onPressed: () =>
                setState(() => _obscureNewPassword = !_obscureNewPassword),
          ),
        ),
      ),
      const SizedBox(height: 16),
      const Text(
        'تأكيد كلمة المرور',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppColors.darkText,
          fontFamily: 'Cairo',
        ),
      ),
      const SizedBox(height: 8),
      TextField(
        controller: _confirmPasswordController,
        obscureText: _obscureConfirmPassword,
        decoration: InputDecoration(
          suffixIcon: IconButton(
            icon: Icon(
              _obscureConfirmPassword
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded,
            ),
            onPressed: () => setState(
              () => _obscureConfirmPassword = !_obscureConfirmPassword,
            ),
          ),
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
        onPressed: _isLoading ? null : _resetPassword,
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: AppColors.darkText,
                  strokeWidth: 2.5,
                ),
              )
            : const Text('تعيين كلمة المرور الجديدة'),
      ),
      const SizedBox(height: 12),
      Center(
        child: TextButton(
          onPressed: _isLoading
              ? null
              : () => setState(() {
                    _step = 1;
                    _errorText = null;
                  }),
          child: const Text('لم يصلني الرمز، تغيير الرقم'),
        ),
      ),
    ];
  }

  List<Widget> _buildStep3() {
    return [
      const SizedBox(height: 20),
      const Center(
        child: Icon(
          Icons.check_circle_rounded,
          color: AppColors.success,
          size: 56,
        ),
      ),
      const SizedBox(height: 16),
      const Text(
        'تم تغيير كلمة المرور بنجاح',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.darkText,
          fontFamily: 'Cairo',
        ),
      ),
      const SizedBox(height: 8),
      const Text(
        'يمكنك الآن تسجيل الدخول برقم هاتفك وكلمة المرور الجديدة.',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 13,
          color: AppColors.secondaryText,
          fontFamily: 'Cairo',
        ),
      ),
      const SizedBox(height: 24),
      ElevatedButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('العودة لتسجيل الدخول'),
      ),
    ];
  }
}
