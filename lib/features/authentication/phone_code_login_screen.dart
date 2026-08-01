import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../admin/admin_app.dart';
import '../../core/auth/app_role.dart';
import '../../core/auth/auth_service.dart';
import '../../core/config/demo_mode_config.dart';
import '../../core/constants/colors.dart';
import '../../core/services/session_guard_service.dart';
import '../../providers/app_state_provider.dart';

enum _Step { phone, otp, setPassword, password, directLogin }

/// Phone number + password sign-in/sign-up, shared by every role this app
/// supports on mobile. Hudhud's fixed demo accounts (see [DemoModeConfig])
/// keep working exactly as before, entirely through the OTP step. For a
/// real phone number there are two entry points, from [AuthWelcomeScreen]:
///  - "إنشاء حساب جديد" ([startAsReturningUser] false): starts at the
///    phone-only step, which checks [AuthService.isPhoneRegistered] - a new
///    number sends a real OTP, verifies it (proves the customer owns the
///    number), then [_buildSetPasswordStep] lets them choose a password for
///    every later sign-in; a number that turns out to already be registered
///    falls through to the password step instead ([_buildPasswordStep]).
///  - "لدي حساب بالفعل" ([startAsReturningUser] true): skips straight to
///    [_buildDirectLoginStep], a single combined phone+password form - no
///    OTP, no registered-check round trip.
///
/// Routing after a successful sign-in is role-based: a `customer` account
/// calls [onSignedIn] (the caller owns navigating to the customer home
/// screen) and starts [SessionGuardService] so signing in elsewhere signs
/// this device out; an `admin` account is sent straight into [AdminApp] -
/// which shares the same underlying Supabase session (see
/// `AdminAuthService`), so it never shows its own login screen again for
/// them. There is no mobile flow for a `captain` account since the captain
/// app was removed.
class PhoneCodeLoginScreen extends StatefulWidget {
  const PhoneCodeLoginScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onSignedIn,
    this.startAsReturningUser = false,
  });

  final String title;
  final String subtitle;

  /// Called after a successful sign-in, with the login screen's own
  /// [BuildContext] still valid - use it to navigate to the home screen.
  final VoidCallback onSignedIn;

  /// True when opened from [AuthWelcomeScreen]'s "لدي حساب بالفعل" button -
  /// the customer has already told us they have an account, so this skips
  /// straight to a single combined phone+password form (see
  /// [_buildDirectLoginStep]) instead of the phone-only step that would
  /// otherwise re-derive the same thing via [AuthService.isPhoneRegistered].
  final bool startAsReturningUser;

  @override
  State<PhoneCodeLoginScreen> createState() => _PhoneCodeLoginScreenState();
}

class _PhoneCodeLoginScreenState extends State<PhoneCodeLoginScreen> {
  final _phoneFormKey = GlobalKey<FormState>();
  final _codeFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  late _Step _step;
  bool _isLoading = false;
  bool _isNewRealSignup = false;
  String? _fullPhone;

  @override
  void initState() {
    super.initState();
    _step = widget.startAsReturningUser ? _Step.directLogin : _Step.phone;
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submitPhone() async {
    if (!_phoneFormKey.currentState!.validate()) return;
    final phone = '+222${_phoneController.text}';

    setState(() => _isLoading = true);
    try {
      if (DemoModeConfig.isDemoPhone(phone)) {
        setState(() {
          _fullPhone = phone;
          _isNewRealSignup = false;
          _step = _Step.otp;
        });
        return;
      }

      final registered = await AuthService.instance.isPhoneRegistered(phone);
      if (!mounted) return;
      if (registered) {
        setState(() {
          _fullPhone = phone;
          _step = _Step.password;
        });
        return;
      }

      await AuthService.instance.requestPhoneCode(phone);
      if (!mounted) return;
      setState(() {
        _fullPhone = phone;
        _isNewRealSignup = true;
        _step = _Step.otp;
      });
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (e) {
      // TODO(temporary): surfacing the raw exception to diagnose a
      // persistent failure at this step - revert to the generic Arabic
      // message once resolved.
      _showError(
        'تعذر إتمام العملية الآن. تحقق من الاتصال بالإنترنت وحاول مرة أخرى.\n$e',
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

      if (_isNewRealSignup) {
        setState(() => _step = _Step.setPassword);
        return;
      }
      await _routeAfterAuth();
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('رمز التحقق غير صحيح أو انتهت صلاحيته.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitNewPassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await AuthService.instance.setPasswordForCurrentUser(
        _passwordController.text,
      );
      if (!mounted) return;
      await _routeAfterAuth();
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('تعذر حفظ كلمة السر الآن. حاول مرة أخرى.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitPasswordLogin() async {
    if (!_passwordFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await AuthService.instance.signInWithPhonePassword(
        phone: _fullPhone!,
        password: _passwordController.text,
      );
      if (!mounted) return;
      await _routeAfterAuth();
    } on AuthException catch (_) {
      _showError('كلمة السر غير صحيحة.');
    } catch (_) {
      _showError('تعذر تسجيل الدخول الآن. تحقق من الاتصال وحاول مرة أخرى.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// For [_Step.directLogin]: phone and password are entered together on
  /// one form, so this skips [AuthService.isPhoneRegistered] entirely - if
  /// the number turns out not to be registered (or the password is wrong),
  /// [AuthException] covers both cases with one generic message, same as a
  /// real ride-hailing app would rather than confirming which one it was.
  Future<void> _submitDirectLogin() async {
    if (!_phoneFormKey.currentState!.validate()) return;
    final phone = '+222${_phoneController.text}';

    setState(() => _isLoading = true);
    try {
      _fullPhone = phone;
      await AuthService.instance.signInWithPhonePassword(
        phone: phone,
        password: _passwordController.text,
      );
      if (!mounted) return;
      await _routeAfterAuth();
    } on AuthException catch (_) {
      _showError('رقم الهاتف أو كلمة السر غير صحيحة.');
    } catch (_) {
      _showError('تعذر تسجيل الدخول الآن. تحقق من الاتصال وحاول مرة أخرى.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Shared tail for every successful sign-in path (password login, new
  /// OTP+password sign-up, or a demo account) - reads the account's role and
  /// routes accordingly.
  Future<void> _routeAfterAuth() async {
    final role = await AuthService.instance.fetchCurrentRole();
    if (!mounted) return;

    switch (role) {
      case AppRole.admin:
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AdminApp()),
          (route) => false,
        );
        break;
      case AppRole.customer:
        final fullName = await _ensureFullName();
        if (!mounted) return;

        // Best effort - a transient failure here shouldn't block an
        // otherwise-successful sign-in; this device just won't be forcibly
        // signed out by a later login elsewhere until the next successful
        // call.
        try {
          final sessionId = SessionGuardService.generateSessionId();
          await AuthService.instance.setActiveSession(sessionId);
          SessionGuardService.instance.start(sessionId);
        } catch (_) {}

        final provider = Provider.of<AppStateProvider>(
          context,
          listen: false,
        );
        provider.login(_fullPhone!, fullName: fullName);
        widget.onSignedIn();
        break;
      case AppRole.captain:
      case null:
        await AuthService.instance.signOut();
        if (!mounted) return;
        _showError(
          'هذا الحساب غير مدعوم على تطبيق الموبايل حالياً. تواصل مع الدعم.',
        );
        break;
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
          child: switch (_step) {
            _Step.phone => _buildPhoneStep(),
            _Step.otp => _buildCodeStep(),
            _Step.setPassword => _buildSetPasswordStep(),
            _Step.password => _buildPasswordStep(),
            _Step.directLogin => _buildDirectLoginStep(),
          },
        ),
      ),
    );
  }

  static const _labelStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.bold,
    color: AppColors.darkText,
    fontFamily: 'Cairo',
  );

  Widget _buildPhoneStep() {
    return Form(
      key: _phoneFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Center(
            child: SizedBox(
              width: 72,
              height: 72,
              // BoxFit.cover inside a circular clip cropped most of the
              // logo's fanned feathers and car away - contain always shows
              // the full artwork.
              child: Image.asset(
                'assets/images/al-houdhoud-logo.png',
                fit: BoxFit.contain,
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
          const Text('رقم الهاتف', style: _labelStyle),
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
            onPressed: _isLoading ? null : _submitPhone,
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : const Text('متابعة'),
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
          const Text('رمز التحقق', style: _labelStyle),
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
                      _step = _Step.phone;
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
                : const Text('تأكيد'),
          ),
        ],
      ),
    );
  }

  Widget _buildSetPasswordStep() {
    return Form(
      key: _passwordFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          const Text(
            'أنشئ كلمة سر لحسابك',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: AppColors.darkText,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'ستستخدمها لتسجيل الدخول لاحقاً بدلاً من طلب رمز تحقق جديد فى كل مرة.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.secondaryText,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 24),
          const Text('كلمة السر', style: _labelStyle),
          const SizedBox(height: 8),
          TextFormField(
            controller: _passwordController,
            obscureText: true,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(hintText: '••••••••'),
            validator: (value) => (value == null || value.length < 6)
                ? 'كلمة السر يجب أن تتكون من 6 أحرف على الأقل'
                : null,
          ),
          const SizedBox(height: 16),
          const Text('تأكيد كلمة السر', style: _labelStyle),
          const SizedBox(height: 8),
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: true,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(hintText: '••••••••'),
            validator: (value) => value != _passwordController.text
                ? 'كلمتا السر غير متطابقتين'
                : null,
            onFieldSubmitted: (_) => _submitNewPassword(),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isLoading ? null : _submitNewPassword,
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : const Text('متابعة'),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordStep() {
    return Form(
      key: _passwordFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Text(
            'تسجيل الدخول إلى $_fullPhone',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.secondaryText,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 24),
          const Text('كلمة السر', style: _labelStyle),
          const SizedBox(height: 8),
          TextFormField(
            controller: _passwordController,
            obscureText: true,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(hintText: '••••••••'),
            validator: (value) => (value == null || value.length < 6)
                ? 'كلمة السر يجب أن تتكون من 6 أحرف على الأقل'
                : null,
            onFieldSubmitted: (_) => _submitPasswordLogin(),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _isLoading
                  ? null
                  : () => setState(() {
                      _step = _Step.phone;
                      _passwordController.clear();
                    }),
              child: const Text('تغيير رقم الهاتف'),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _isLoading ? null : _submitPasswordLogin,
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : const Text('تسجيل الدخول'),
          ),
        ],
      ),
    );
  }

  /// Phone + password together on one form - see [_submitDirectLogin] and
  /// the [PhoneCodeLoginScreen.startAsReturningUser] doc comment.
  Widget _buildDirectLoginStep() {
    return Form(
      key: _phoneFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Center(
            child: SizedBox(
              width: 72,
              height: 72,
              // BoxFit.cover inside a circular clip cropped most of the
              // logo's fanned feathers and car away - contain always shows
              // the full artwork.
              child: Image.asset(
                'assets/images/al-houdhoud-logo.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'أدخل رقم هاتفك وكلمة السر لتسجيل الدخول.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.secondaryText,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 32),
          const Text('رقم الهاتف', style: _labelStyle),
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
          const SizedBox(height: 16),
          const Text('كلمة السر', style: _labelStyle),
          const SizedBox(height: 8),
          TextFormField(
            controller: _passwordController,
            obscureText: true,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(hintText: '••••••••'),
            validator: (value) => (value == null || value.length < 6)
                ? 'كلمة السر يجب أن تتكون من 6 أحرف على الأقل'
                : null,
            onFieldSubmitted: (_) => _submitDirectLogin(),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _isLoading
                  ? null
                  : () => setState(() {
                      _step = _Step.phone;
                      _phoneController.clear();
                      _passwordController.clear();
                    }),
              child: const Text('ليس لدي حساب؟ إنشاء حساب جديد'),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _isLoading ? null : _submitDirectLogin,
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : const Text('تسجيل الدخول'),
          ),
        ],
      ),
    );
  }
}
