import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/business_colors.dart';
import '../../core/business_theme.dart';
import '../../repositories/business_account_repository.dart';
import '../../services/business_auth_service.dart';
import '../../services/business_session.dart';
import '../../widgets/hidden_admin_key.dart';

class BusinessRegisterScreen extends StatefulWidget {
  const BusinessRegisterScreen({super.key});

  @override
  State<BusinessRegisterScreen> createState() =>
      _BusinessRegisterScreenState();
}

class _BusinessRegisterScreenState extends State<BusinessRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _businessNameController = TextEditingController();
  final _contactNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  String _businessType = 'restaurant';
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  static const _typeOptions = {
    'restaurant': 'مطعم',
    'institution': 'مؤسسة',
    'other': 'أخرى',
  };

  @override
  void dispose() {
    _businessNameController.dispose();
    _contactNameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_passwordController.text != _confirmController.text) {
      setState(() => _error = 'كلمتا المرور غير متطابقتين.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await BusinessAuthService.instance.signUp(
        phone: _phoneController.text.trim(),
        password: _passwordController.text,
        contactName: _contactNameController.text.trim(),
      );
      // signUp already signs the new user in (Supabase's own behavior), so
      // this account creation call runs as that same just-created user -
      // required by the table's own insert policy (`id = auth.uid()`).
      await BusinessAccountRepository.instance.createMyAccount(
        businessName: _businessNameController.text.trim(),
        businessType: _businessType,
      );
      if (!mounted) return;
      await context.read<BusinessSession>().refresh();
      if (!mounted) return;
      context.go('/business/dashboard');
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(
        () => _error = 'تعذر إنشاء الحساب، تحقق من البيانات وحاول مرة أخرى.',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(data: BusinessTheme.theme, child: Scaffold(
      backgroundColor: BusinessColors.background,
      body: Stack(
        children: [
          Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'سجّل مطعمك أو مؤسستك',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: BusinessColors.textPrimary,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'بعد التسجيل، يراجع فريقنا حسابك قبل أن تتمكن من '
                        'إرسال طلبات المشاوير.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: BusinessColors.textSecondary,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _businessNameController,
                        decoration: const InputDecoration(
                          labelText: 'اسم المطعم / المؤسسة',
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _businessType,
                        decoration: const InputDecoration(labelText: 'النوع'),
                        items: _typeOptions.entries
                            .map(
                              (e) => DropdownMenuItem(
                                value: e.key,
                                child: Text(e.value),
                              ),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _businessType = v ?? _businessType),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _contactNameController,
                        decoration: const InputDecoration(
                          labelText: 'اسم الشخص المسؤول',
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'رقم الهاتف',
                          prefixText: '+222 ',
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'مطلوب';
                          if (v.trim().length < 8) {
                            return 'رقم الهاتف يجب أن يتكون من 8 أرقام على الأقل';
                          }
                          return null;
                        },
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
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator: (v) => (v == null || v.length < 6)
                            ? 'ستة أحرف على الأقل'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _confirmController,
                        obscureText: _obscure,
                        decoration: const InputDecoration(
                          labelText: 'تأكيد كلمة المرور',
                        ),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'مطلوب' : null,
                        onFieldSubmitted: (_) => _submit(),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: const TextStyle(
                            color: BusinessColors.error,
                            fontSize: 12,
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _loading ? null : _submit,
                        child: _loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('إنشاء الحساب'),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => context.go('/business/login'),
                        child: const Text('لديك حساب بالفعل؟ سجّل الدخول'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
          ),
          const HiddenAdminKey(),
        ],
      ),
    ));
  }
}
