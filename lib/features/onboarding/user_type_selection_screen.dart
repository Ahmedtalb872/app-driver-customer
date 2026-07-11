import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../providers/app_state_provider.dart';
import '../authentication/customer_login_screen.dart';
import '../authentication/captain_login_screen.dart';
import '../../models/models.dart';

class UserTypeSelectionScreen extends StatefulWidget {
  const UserTypeSelectionScreen({super.key});

  @override
  State<UserTypeSelectionScreen> createState() => _UserTypeSelectionScreenState();
}

class _UserTypeSelectionScreenState extends State<UserTypeSelectionScreen> {
  UserType _selectedType = UserType.customer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              // App name / Logo
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.local_taxi_rounded,
                      color: AppColors.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'الهدهد',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkText,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 50),
              
              // Title
              const Text(
                'كيف تريد المتابعة؟',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkText,
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'يرجى اختيار نوع الحساب الذي ترغب في استخدامه في التطبيق.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.secondaryText,
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 32),
              
              // Customer Selection Card
              GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedType = UserType.customer;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: _selectedType == UserType.customer 
                          ? AppColors.primary 
                          : AppColors.border,
                      width: _selectedType == UserType.customer ? 2 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _selectedType == UserType.customer
                            ? AppColors.primary.withOpacity(0.08)
                            : AppColors.darkText.withOpacity(0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _selectedType == UserType.customer
                              ? AppColors.primary.withOpacity(0.1)
                              : AppColors.background,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Icons.person_rounded,
                          size: 32,
                          color: _selectedType == UserType.customer
                              ? AppColors.primary
                              : AppColors.secondaryText,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'زبون',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.darkText,
                                fontFamily: 'Cairo',
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'ابحث عن سيارة واطلب رحلة بسهولة',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.secondaryText,
                                fontFamily: 'Cairo',
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_selectedType == UserType.customer)
                        const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.primary,
                          size: 24,
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Captain Selection Card
              GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedType = UserType.captain;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: _selectedType == UserType.captain 
                          ? AppColors.primary 
                          : AppColors.border,
                      width: _selectedType == UserType.captain ? 2 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _selectedType == UserType.captain
                            ? AppColors.primary.withOpacity(0.08)
                            : AppColors.darkText.withOpacity(0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _selectedType == UserType.captain
                              ? AppColors.primary.withOpacity(0.1)
                              : AppColors.background,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Icons.drive_eta_rounded,
                          size: 32,
                          color: _selectedType == UserType.captain
                              ? AppColors.primary
                              : AppColors.secondaryText,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'كابتن',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.darkText,
                                fontFamily: 'Cairo',
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'استقبل المشاوير وحقق دخلاً إضافياً',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.secondaryText,
                                fontFamily: 'Cairo',
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_selectedType == UserType.captain)
                        const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.primary,
                          size: 24,
                        ),
                    ],
                  ),
                ),
              ),
              
              const Spacer(),
              
              // Proceed Button
              ElevatedButton(
                onPressed: () {
                  // Save user selection type in state provider
                  Provider.of<AppStateProvider>(context, listen: false).setUserType(_selectedType);
                  
                  // Navigate to the respective login screen
                  if (_selectedType == UserType.customer) {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const CustomerLoginScreen()),
                    );
                  } else {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const CaptainLoginScreen()),
                    );
                  }
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _selectedType == UserType.customer
                          ? 'المتابعة كزبون'
                          : 'المتابعة ككابتن',
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded, size: 20),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Already have account
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'لدي حساب بالفعل؟',
                    style: TextStyle(
                      color: AppColors.secondaryText,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Provider.of<AppStateProvider>(context, listen: false).setUserType(_selectedType);
                      if (_selectedType == UserType.customer) {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) => const CustomerLoginScreen()),
                        );
                      } else {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) => const CaptainLoginScreen()),
                        );
                      }
                    },
                    child: const Text('تسجيل الدخول'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
