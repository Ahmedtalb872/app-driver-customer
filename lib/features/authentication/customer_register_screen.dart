import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../providers/app_state_provider.dart';
import '../customer/customer_home_screen.dart';

class CustomerRegisterScreen extends StatefulWidget {
  const CustomerRegisterScreen({super.key});

  @override
  State<CustomerRegisterScreen> createState() => _CustomerRegisterScreenState();
}

class _CustomerRegisterScreenState extends State<CustomerRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptTerms = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleRegister() {
    if (_formKey.currentState!.validate()) {
      if (!_acceptTerms) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'الرجاء الموافقة على الشروط والأحكام للمتابعة',
              style: TextStyle(fontFamily: 'Cairo'),
            ),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      setState(() {
        _isLoading = true;
      });

      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          
          final provider = Provider.of<AppStateProvider>(context, listen: false);
          provider.registerCustomer(_nameController.text, '+222${_phoneController.text}');
          
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
        title: const Text('إنشاء حساب زبون'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                const Text(
                  'انضم إلى عائلة الهدهد!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkText,
                    fontFamily: 'Cairo',
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'املأ الحقول التالية لإنشاء حسابك والاستمتاع بالرحلات.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.secondaryText,
                    fontFamily: 'Cairo',
                  ),
                ),
                const SizedBox(height: 24),
                
                // Name Field
                const Text(
                  'الاسم الكامل',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkText,
                    fontFamily: 'Cairo',
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    hintText: 'أدخل اسمك الكامل',
                    prefixIcon: Icon(Icons.person_outline_rounded, color: AppColors.secondaryText),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'الرجاء إدخال الاسم الكامل';
                    }
                    if (value.trim().split(' ').length < 2) {
                      return 'الرجاء إدخال الاسم الأول واسم العائلة';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                // Phone Field
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
                const SizedBox(height: 16),
                
                // Password Field
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
                    hintText: 'أدخل كلمة المرور (6 أحرف على الأقل)',
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
                const SizedBox(height: 16),
                
                // Confirm Password Field
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
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  decoration: InputDecoration(
                    hintText: 'أعد كتابة كلمة المرور',
                    prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.secondaryText),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: AppColors.secondaryText,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'الرجاء تأكيد كلمة المرور';
                    }
                    if (value != _passwordController.text) {
                      return 'كلمتا المرور غير متطابقتين';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                // Terms Checkbox
                Row(
                  children: [
                    Checkbox(
                      value: _acceptTerms,
                      activeColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      onChanged: (value) {
                        setState(() {
                          _acceptTerms = value ?? false;
                        });
                      },
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _acceptTerms = !_acceptTerms;
                          });
                        },
                        child: const Text(
                          'أوافق على الشروط والأحكام وسياسة الخصوصية الخاصة بالهدهد',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.darkText,
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Register Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleRegister,
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text('إنشاء الحساب'),
                ),
                const SizedBox(height: 24),
                
                // Login redirect
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'لديك حساب بالفعل؟',
                      style: TextStyle(
                        color: AppColors.secondaryText,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const Text('تسجيل الدخول'),
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
