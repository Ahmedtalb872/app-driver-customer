import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../providers/app_state_provider.dart';
import 'customer_register_screen.dart';
import '../customer/customer_home_screen.dart';
import '../../models/models.dart';

class CustomerLoginScreen extends StatefulWidget {
  const CustomerLoginScreen({super.key});

  @override
  State<CustomerLoginScreen> createState() => _CustomerLoginScreenState();
}

class _CustomerLoginScreenState extends State<CustomerLoginScreen> {
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

  void _handleLogin() {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      // Simulate network request
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          
          final provider = Provider.of<AppStateProvider>(context, listen: false);
          provider.login('+222${_phoneController.text}', UserType.customer);
          
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const CustomerHomeScreen()),
            (route) => false,
          );
        }
      });
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
        title: const Text('تسجيل دخول الزبون'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                const Text(
                  'أهلاً بك مجدداً!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkText,
                    fontFamily: 'Cairo',
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'سجل دخولك الآن لطلب مشاوير آمنة وسريعة.',
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
                  style: const TextStyle(fontSize: 16, letterSpacing: 1.5, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    hintText: '36 00 00 00',
                    hintStyle: const TextStyle(letterSpacing: 1.0, fontWeight: FontWeight.normal),
                    prefixIcon: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
                      margin: const EdgeInsets.only(left: 10),
                      decoration: const BoxDecoration(
                        border: Border(left: BorderSide(color: AppColors.border, width: 1)),
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
                    prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.secondaryText),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
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
                            'تم إرسال رمز إعادة تعيين كلمة المرور إلى هاتفك.',
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
                      : const Text('تسجيل الدخول'),
                ),
                const SizedBox(height: 24),
                
                // Create account link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'ليس لديك حساب؟',
                      style: TextStyle(
                        color: AppColors.secondaryText,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) => const CustomerRegisterScreen()),
                        );
                      },
                      child: const Text('إنشاء حساب جديد'),
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
