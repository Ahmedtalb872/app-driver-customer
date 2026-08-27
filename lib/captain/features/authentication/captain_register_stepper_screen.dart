import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_links.dart';
import '../../core/constants/captain_documents.dart';
import '../../core/constants/colors.dart';
import '../../core/supabase/auth_exception.dart';
import '../../core/supabase/auth_repository.dart';
import '../../core/widgets/app_logo.dart';
import '../../providers/app_state_provider.dart';
import '../captain/captain_home_screen.dart';
import '../onboarding/pending_review_screen.dart';
import '../onboarding/permissions_screen.dart';

class CaptainRegisterStepperScreen extends StatefulWidget {
  const CaptainRegisterStepperScreen({super.key});

  @override
  State<CaptainRegisterStepperScreen> createState() =>
      _CaptainRegisterStepperScreenState();
}

class _CaptainRegisterStepperScreenState
    extends State<CaptainRegisterStepperScreen> {
  final _authRepository = AuthRepository();
  int _currentStep = 1;
  bool _isSubmitting = false;
  bool _termsApproved = false;
  bool _phoneVerified = false;
  Map<String, dynamic>? _registeredProfile;

  // Step 1 Controllers
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String _selectedCity = 'نواكشوط';
  final _addressController = TextEditingController();
  final _dobController = TextEditingController(text: '1990-01-01');

  // Step 2 Controllers
  String _vehicleCategory = 'car'; // car, motorcycle
  String _carType = 'economy'; // economy, comfort, family
  final _carBrandController = TextEditingController(text: 'تويوتا');
  final _carModelController = TextEditingController(text: 'كورولا');
  final _carYearController = TextEditingController(text: '2018');
  final _carColorController = TextEditingController(text: 'فضي');
  final _carPlateController = TextEditingController(text: '1234 AA 00');
  int _carSeats = 4;

  // Which service the company should pay this captain through - collected
  // at registration instead of only via a later profile edit, so it's on
  // file from the very first payout.
  String _payoutMethod = 'bankily';
  final _payoutPhoneController = TextEditingController();

  // Step 3 Upload states - keyed by document_type.
  final Map<String, bool> _uploadStates = {
    for (final docType in kCaptainDocTypes.keys) docType: false,
  };
  String? _uploadingDoc;
  final Map<String, Uint8List> _pickedFileBytes = {};

  String get _fullPhone => '+222${_phoneController.text.trim()}';

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _addressController.dispose();
    _dobController.dispose();
    _carBrandController.dispose();
    _carModelController.dispose();
    _carYearController.dispose();
    _carColorController.dispose();
    _carPlateController.dispose();
    _payoutPhoneController.dispose();
    super.dispose();
  }

  Future<void> _nextStep() async {
    if (_currentStep == 1) {
      if (!_validateStep1()) return;
      if (_phoneVerified) {
        setState(() => _currentStep = 2);
        return;
      }
      await _sendOtpAndVerify();
      return;
    }
    if (_currentStep == 3 && !_validateStep3()) return;
    if (_currentStep < 4) {
      setState(() {
        _currentStep++;
      });
    }
  }

  Future<void> _sendOtpAndVerify() async {
    setState(() => _isSubmitting = true);
    try {
      await _authRepository.signUpWithPassword(
        phone: _fullPhone,
        password: _passwordController.text,
        fullName: _nameController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تم إرسال رمز التحقق عبر رسالة نصية.',
            style: TextStyle(fontFamily: 'Cairo'),
          ),
          backgroundColor: AppColors.success,
        ),
      );
      final verified = await _showOtpSheet();
      if (verified && mounted) {
        setState(() {
          _phoneVerified = true;
          _currentStep = 2;
        });
      }
    } on AppAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message, style: const TextStyle(fontFamily: 'Cairo')),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  /// Shows the SMS code entry sheet, returns true once verified (and stores
  /// the now-created/logged-in profile in [_registeredProfile]).
  Future<bool> _showOtpSheet() async {
    final codeController = TextEditingController();
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        bool isVerifying = false;
        String? error;
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'أدخل رمز التحقق',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      fontFamily: 'Cairo',
                      color: AppColors.darkText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'أرسلنا رمزًا برسالة نصية إلى $_fullPhone',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.secondaryText,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: codeController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    autofocus: true,
                    style: const TextStyle(
                      fontSize: 22,
                      letterSpacing: 8,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: const InputDecoration(hintText: '- - - - - -'),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      error!,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 12,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: isVerifying
                        ? null
                        : () async {
                            if (codeController.text.trim().length < 4) {
                              setSheetState(
                                () => error = 'أدخل رمز التحقق كاملاً',
                              );
                              return;
                            }
                            setSheetState(() {
                              isVerifying = true;
                              error = null;
                            });
                            try {
                              final profile = await _authRepository
                                  .verifySignUpOtp(
                                    phone: _fullPhone,
                                    code: codeController.text.trim(),
                                  );
                              _registeredProfile = profile;
                              if (sheetContext.mounted) {
                                Navigator.pop(sheetContext, true);
                              }
                            } on AppAuthException catch (e) {
                              setSheetState(() {
                                isVerifying = false;
                                error = e.message;
                              });
                            }
                          },
                    child: isVerifying
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: AppColors.darkText,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text('تحقق'),
                  ),
                  TextButton(
                    onPressed: isVerifying
                        ? null
                        : () => Navigator.pop(sheetContext, false),
                    child: const Text('إلغاء'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    return result ?? false;
  }

  bool _validateStep3() {
    final requiredUploaded = _uploadStates.entries
        .where((e) => e.key != kOptionalDocType)
        .every((e) => e.value);
    if (requiredUploaded) return true;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'يرجى رفع جميع المستندات المطلوبة أولاً',
          style: TextStyle(fontFamily: 'Cairo'),
        ),
        backgroundColor: AppColors.error,
      ),
    );
    return false;
  }

  bool _validateStep1() {
    String? error;
    if (_nameController.text.trim().isEmpty) {
      error = 'الرجاء إدخال الاسم الكامل';
    } else if (_phoneController.text.trim().length < 8) {
      error = 'الرجاء إدخال رقم هاتف صحيح';
    } else if (!_phoneVerified && _passwordController.text.length < 6) {
      error = 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
    } else if (!_phoneVerified &&
        _passwordController.text != _confirmPasswordController.text) {
      error = 'كلمتا المرور غير متطابقتين';
    }

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error, style: const TextStyle(fontFamily: 'Cairo')),
          backgroundColor: AppColors.error,
        ),
      );
      return false;
    }
    return true;
  }

  void _prevStep() {
    if (_currentStep > 1) {
      setState(() {
        _currentStep--;
      });
    }
  }

  Future<void> _pickDocument(String docType) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'إرفاق المستند',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    fontFamily: 'Cairo',
                    color: AppColors.darkText,
                  ),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(
                Icons.camera_alt_rounded,
                color: AppColors.primary,
              ),
              title: const Text(
                'التقاط صورة',
                style: TextStyle(fontFamily: 'Cairo'),
              ),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library_rounded,
                color: AppColors.primary,
              ),
              title: const Text(
                'اختيار من المعرض',
                style: TextStyle(fontFamily: 'Cairo'),
              ),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    setState(() => _uploadingDoc = docType);
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        imageQuality: 65,
        // imageQuality alone isn't reliably honored on Flutter web, which
        // can otherwise upload a raw multi-MB camera photo as-is - capping
        // the dimensions keeps every platform's upload small and fast.
        // 1280px is still plenty to read a document photo clearly.
        maxWidth: 1280,
        maxHeight: 1280,
      );
      if (file == null) {
        if (mounted) setState(() => _uploadingDoc = null);
        return;
      }
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _pickedFileBytes[docType] = bytes;
        _uploadStates[docType] = true;
        _uploadingDoc = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _uploadingDoc = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تعذر الوصول للكاميرا أو المعرض. تحقق من صلاحيات التطبيق.',
            style: TextStyle(fontFamily: 'Cairo'),
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _submitApplication() async {
    if (!_phoneVerified || _registeredProfile == null) {
      setState(() => _currentStep = 1);
      return;
    }
    if (!_termsApproved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الرجاء الموافقة على الشروط والأحكام'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (!_validateStep3()) {
      setState(() => _currentStep = 3);
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final profile = _registeredProfile!;
      String? documentsWarning;
      try {
        await _authRepository.uploadCaptainDocuments(
          profile['id'] as String,
          _pickedFileBytes.entries
              .map(
                (e) => CaptainDocumentFile(
                  docKey: e.key,
                  docName: kCaptainDocTypes[e.key] ?? e.key,
                  bytes: e.value,
                ),
              )
              .toList(),
        );
      } on AppAuthException catch (e) {
        documentsWarning = e.message;
      }

      final captainId = profile['id'] as String;
      try {
        await _authRepository.updateCaptainVehicleInfo(
          captainId: captainId,
          city: _selectedCity,
          address: _addressController.text.trim(),
          dateOfBirth: _dobController.text.trim(),
          // No separate vehicle-category column: a motorcycle is just
          // another value of vehicle_type, alongside the car tiers.
          vehicleType: _isMotorcycle ? 'motorcycle' : _carType,
          vehicleBrand: _carBrandController.text.trim(),
          vehicleModel: _carModelController.text.trim(),
          vehicleYear: int.tryParse(_carYearController.text.trim()) ?? 2018,
          vehicleColor: _carColorController.text.trim(),
          vehiclePlate: _carPlateController.text.trim(),
          vehicleSeats: _carSeats,
        );
        // Motorcycle captains start opted in to delivery requests - they
        // can still turn it off later from the home screen.
        if (_isMotorcycle) {
          await _authRepository.setAcceptsDelivery(captainId, true);
        }
        if (_payoutPhoneController.text.trim().isNotEmpty) {
          await _authRepository.updateCaptainPayoutInfo(
            captainId: captainId,
            payoutMethod: _payoutMethod,
            payoutPhone: _payoutPhoneController.text.trim(),
          );
        }
      } on AppAuthException catch (_) {
        // Non-fatal: the captain row still exists (bare) from sign-up: the
        // vehicle/payout details can be corrected later from the profile
        // screen.
      }

      // A brand-new captain is never pre-approved, so this always lands on
      // the pending-review screen - there is no "continue into the app"
      // button to skip past admin approval.
      Map<String, dynamic>? captain;
      bool approved = false;
      try {
        captain = await _authRepository.getCaptain(captainId);
        approved = captain['status'] == 'approved';
      } on AppAuthException catch (_) {
        // Fall back to "not approved" if the captain row can't be read yet.
      }
      if (!mounted) return;
      final provider = Provider.of<AppStateProvider>(context, listen: false);
      provider.loginFromProfile(profile, _fullPhone, captain: captain);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => approved
              ? const PermissionsScreen(destination: CaptainHomeScreen())
              : PendingReviewScreen(uploadWarning: documentsWarning),
        ),
        (route) => false,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            const AppLogo(width: 28),
            const SizedBox(width: 10),
            const Text('تسجيل كابتن جديد'),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Stepper indicator
            _buildStepperIndicator(),

            // Step contents
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: _buildCurrentStepContent(),
              ),
            ),

            // Bottom buttons
            _buildBottomButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildStepperIndicator() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildStepIndicatorItem(1, 'الشخصية'),
          _buildStepLine(1),
          _buildStepIndicatorItem(2, 'المركبة'),
          _buildStepLine(2),
          _buildStepIndicatorItem(3, 'المستندات'),
          _buildStepLine(3),
          _buildStepIndicatorItem(4, 'المراجعة'),
        ],
      ),
    );
  }

  Widget _buildStepIndicatorItem(int step, String label) {
    bool isCompleted = _currentStep > step;
    bool isActive = _currentStep == step;

    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCompleted
                ? AppColors.primary
                : isActive
                ? AppColors.primary
                : Colors.white,
            border: Border.all(
              color: isCompleted || isActive
                  ? AppColors.primary
                  : AppColors.border,
              width: 2,
            ),
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, color: Colors.white, size: 18)
                : Text(
                    '$step',
                    style: TextStyle(
                      color: isActive ? Colors.white : AppColors.secondaryText,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive ? AppColors.primary : AppColors.secondaryText,
            fontFamily: 'Cairo',
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine(int afterStep) {
    bool isPassed = _currentStep > afterStep;
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 20),
        color: isPassed ? AppColors.primary : AppColors.border,
      ),
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 1:
        return _buildStep1Personal();
      case 2:
        return _buildStep2Vehicle();
      case 3:
        return _buildStep3Documents();
      case 4:
        return _buildStep4Review();
      default:
        return Container();
    }
  }

  Widget _buildStep1Personal() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'المعلومات الشخصية',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.darkText,
            fontFamily: 'Cairo',
          ),
        ),
        const SizedBox(height: 16),
        _buildTextField(
          'الاسم الكامل',
          _nameController,
          hint: 'أدخل اسمك الكامل كما في الهوية',
        ),
        const SizedBox(height: 16),
        const SizedBox(height: 16),
        _buildPhoneField(
          'رقم الهاتف',
          _phoneController,
          readOnly: _phoneVerified,
        ),
        if (_phoneVerified) ...[
          const SizedBox(height: 8),
          const Row(
            children: [
              Icon(
                Icons.check_circle_rounded,
                color: AppColors.success,
                size: 16,
              ),
              SizedBox(width: 6),
              Text(
                'تم التحقق من هذا الرقم',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.success,
                  fontFamily: 'Cairo',
                ),
              ),
            ],
          ),
        ] else ...[
          const SizedBox(height: 16),
          _buildTextField(
            'كلمة المرور',
            _passwordController,
            obscure: _obscurePassword,
            hint: '6 أحرف على الأقل',
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
          const SizedBox(height: 16),
          _buildTextField(
            'تأكيد كلمة المرور',
            _confirmPasswordController,
            obscure: _obscureConfirmPassword,
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
          const SizedBox(height: 4),
          const Text(
            'ستستخدم رقم هاتفك وكلمة المرور هذه لتسجيل الدخول لاحقًا.',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.secondaryText,
              fontFamily: 'Cairo',
            ),
          ),
        ],
        const SizedBox(height: 16),
        // City dropdown
        const Text(
          'المدينة',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.darkText,
            fontFamily: 'Cairo',
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedCity,
              isExpanded: true,
              style: const TextStyle(
                color: AppColors.darkText,
                fontSize: 16,
                fontFamily: 'Cairo',
              ),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedCity = value;
                  });
                }
              },
              items: <String>['نواكشوط', 'نواذيبو', 'روصو', 'أطار', 'كيفه']
                  .map<DropdownMenuItem<String>>((String val) {
                    return DropdownMenuItem<String>(
                      value: val,
                      child: Text(val),
                    );
                  })
                  .toList(),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildTextField(
          'العنوان بالتفصيل',
          _addressController,
          hint: 'مثال: تفرغ زينة - كارفور موري سانتر',
        ),
        const SizedBox(height: 16),
        _buildTextField('تاريخ الميلاد', _dobController, hint: 'YYYY-MM-DD'),
      ],
    );
  }

  bool get _isMotorcycle => _vehicleCategory == 'motorcycle';
  String get _vehicleNoun => _isMotorcycle ? 'الدراجة النارية' : 'السيارة';

  Widget _buildStep2Vehicle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'معلومات المركبة',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.darkText,
            fontFamily: 'Cairo',
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _isMotorcycle
              ? 'كباتن الدراجات النارية يمكنهم لاحقاً تفعيل استقبال طلبات توصيل الطرود.'
              : 'ملاحظة: الخدمة حالياً مخصصة فقط لنقل الركاب بالسيارات العادية.',
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.secondaryText,
            fontFamily: 'Cairo',
          ),
        ),
        const SizedBox(height: 20),

        // Vehicle category selection (car / motorcycle) - large, unmissable
        // cards since this choice decides whether delivery mode unlocks.
        const Text(
          'ما هي مركبتك؟',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.darkText,
            fontFamily: 'Cairo',
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'اختر نوع مركبتك - يحدد هذا الخيار خدمات النقل المتاحة لك.',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.secondaryText,
            fontFamily: 'Cairo',
          ),
        ),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildVehicleCategoryCard(
                'car',
                'سيارة',
                'نقل الركاب',
                Icons.directions_car_filled_rounded,
              ),
              const SizedBox(width: 12),
              _buildVehicleCategoryCard(
                'motorcycle',
                'دراجة نارية',
                'نقل الركاب + توصيل الطرود',
                Icons.two_wheeler_rounded,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Car Type selection (Custom cards) - only meaningful for cars,
        // which have passenger comfort tiers; a motorcycle only delivers.
        if (!_isMotorcycle) ...[
          const Text(
            'فئة السيارة',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.darkText,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildCarTypeCard(
                'economy',
                'إقتصادية',
                Icons.directions_car_filled_outlined,
              ),
              const SizedBox(width: 8),
              _buildCarTypeCard('comfort', 'مريحة', Icons.local_taxi_rounded),
              const SizedBox(width: 8),
              _buildCarTypeCard(
                'family',
                'عائلية',
                Icons.airport_shuttle_rounded,
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],

        _buildTextField(
          'ماركة $_vehicleNoun',
          _carBrandController,
          hint: _isMotorcycle ? 'مثال: هوندا' : 'مثال: تويوتا',
        ),
        const SizedBox(height: 16),
        _buildTextField(
          'الموديل',
          _carModelController,
          hint: 'مثال: كورولا / أفينسيس',
        ),
        const SizedBox(height: 16),
        _buildTextField('سنة الصنع', _carYearController, hint: 'مثال: 2018'),
        const SizedBox(height: 16),
        _buildTextField(
          'لون $_vehicleNoun',
          _carColorController,
          hint: 'مثال: رمادي / أبيض',
        ),
        const SizedBox(height: 16),
        _buildTextField(
          'رقم اللوحة',
          _carPlateController,
          hint: 'مثال: 1234 AA 00',
        ),

        // Seats dropdown - not applicable to a motorcycle.
        if (!_isMotorcycle) ...[
          const SizedBox(height: 16),
          const Text(
            'عدد المقاعد المتاحة للركاب',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.darkText,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _carSeats,
                isExpanded: true,
                style: const TextStyle(
                  color: AppColors.darkText,
                  fontSize: 16,
                  fontFamily: 'Cairo',
                ),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _carSeats = value;
                    });
                  }
                },
                items: <int>[4, 6, 7].map<DropdownMenuItem<int>>((int val) {
                  return DropdownMenuItem<int>(
                    value: val,
                    child: Text('$val مقاعد'),
                  );
                }).toList(),
              ),
            ),
          ),
        ],

        const SizedBox(height: 28),
        const Text(
          'معلومات استلام المدفوعات',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.darkText,
            fontFamily: 'Cairo',
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'تستخدمها الشركة لتحويل مستحقاتك أو أي مكافأة إليك.',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.secondaryText,
            fontFamily: 'Cairo',
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildPayoutMethodCard('bankily', 'Bankily'),
            const SizedBox(width: 8),
            _buildPayoutMethodCard('masrvi', 'Masrvi'),
            const SizedBox(width: 8),
            _buildPayoutMethodCard('sedad', 'Sedad'),
            const SizedBox(width: 8),
            _buildPayoutMethodCard('other', 'أخرى'),
          ],
        ),
        const SizedBox(height: 16),
        _buildTextField(
          'رقم الهاتف على هذه الخدمة',
          _payoutPhoneController,
          hint: 'مثال: 22XXXXXXXX',
        ),
      ],
    );
  }

  Widget _buildPayoutMethodCard(String method, String label) {
    bool isSel = _payoutMethod == method;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _payoutMethod = method),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSel ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSel ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSel ? Colors.white : AppColors.darkText,
              fontWeight: FontWeight.bold,
              fontFamily: 'Cairo',
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVehicleCategoryCard(
    String category,
    String label,
    String subtitle,
    IconData icon,
  ) {
    bool isSel = _vehicleCategory == category;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _vehicleCategory = category),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
          decoration: BoxDecoration(
            color: isSel ? AppColors.primary.withOpacity(0.12) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSel ? AppColors.primary : AppColors.border,
              width: isSel ? 2.5 : 1.5,
            ),
          ),
          child: Stack(
            children: [
              if (isSel)
                const Positioned(
                  top: -4,
                  left: -4,
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.primaryDark,
                    size: 22,
                  ),
                ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: isSel ? AppColors.primary : AppColors.background,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      color: isSel ? Colors.white : AppColors.secondaryText,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.darkText,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo',
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.secondaryText,
                      fontFamily: 'Cairo',
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCarTypeCard(String type, String label, IconData icon) {
    bool isSel = _carType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _carType = type;
            if (type == 'family') {
              _carSeats = 6;
            } else {
              _carSeats = 4;
            }
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSel ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSel ? AppColors.primary : AppColors.border,
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSel ? Colors.white : AppColors.secondaryText,
                size: 28,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSel ? Colors.white : AppColors.darkText,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo',
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _docDisplayLabel(String docType) {
    return captainDocLabel(docType, isMotorcycle: _isMotorcycle);
  }

  Widget _buildStep3Documents() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'المستندات والأوراق الرسمية',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.darkText,
            fontFamily: 'Cairo',
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'اضغط على كل مستند لالتقاط صورة له بالكاميرا أو اختياره من هاتفك. جميع المستندات إلزامية لإكمال التسجيل باستثناء المستند الإضافي.',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.secondaryText,
            fontFamily: 'Cairo',
          ),
        ),
        const SizedBox(height: 20),

        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _uploadStates.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            String docType = _uploadStates.keys.elementAt(index);
            bool isUploaded = _uploadStates[docType]!;
            bool isThisUploading = _uploadingDoc == docType;
            Uint8List? preview = _pickedFileBytes[docType];

            return InkWell(
              onTap: isThisUploading ? null : () => _pickDocument(docType),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isUploaded
                        ? AppColors.success.withOpacity(0.5)
                        : AppColors.border,
                    width: isUploaded ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: preview != null
                          ? Image.memory(
                              preview,
                              width: 44,
                              height: 44,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              width: 44,
                              height: 44,
                              decoration: const BoxDecoration(
                                color: AppColors.background,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.upload_file_rounded,
                                color: AppColors.secondaryText,
                                size: 24,
                              ),
                            ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _docDisplayLabel(docType),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: AppColors.darkText,
                              fontFamily: 'Cairo',
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isUploaded
                                ? 'تم إرفاق الصورة (اضغط لتغييرها)'
                                : 'لم يتم إرفاق صورة بعد',
                            style: TextStyle(
                              fontSize: 11,
                              color: isUploaded
                                  ? AppColors.success
                                  : AppColors.secondaryText,
                              fontFamily: 'Cairo',
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isThisUploading)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      )
                    else if (isUploaded)
                      const Icon(
                        Icons.check_circle_outline_rounded,
                        color: AppColors.success,
                      )
                    else
                      const Icon(
                        Icons.chevron_left_rounded,
                        color: AppColors.secondaryText,
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildStep4Review() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'مراجعة وتأكيد البيانات',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.darkText,
            fontFamily: 'Cairo',
          ),
        ),
        const SizedBox(height: 16),

        // Summary Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildReviewRow('الاسم الكامل', _nameController.text),
                _buildReviewRow('رقم الهاتف', _fullPhone),
                _buildReviewRow(
                  'المدينة والعنوان',
                  '$_selectedCity - ${_addressController.text}',
                ),
                _buildReviewRow('تاريخ الميلاد', _dobController.text),
                const Divider(height: 24),
                _buildReviewRow(
                  'نوع المركبة',
                  _isMotorcycle ? 'دراجة نارية' : 'سيارة',
                ),
                if (!_isMotorcycle)
                  _buildReviewRow(
                    'فئة السيارة',
                    _carType == 'economy'
                        ? 'إقتصادية'
                        : _carType == 'comfort'
                        ? 'مريحة'
                        : 'عائلية',
                  ),
                _buildReviewRow(
                  'الماركة والموديل',
                  '${_carBrandController.text} ${_carModelController.text} (${_carYearController.text})',
                ),
                _buildReviewRow('رقم اللوحة', _carPlateController.text),
                if (!_isMotorcycle)
                  _buildReviewRow('المقاعد المتاحة', '$_carSeats مقاعد'),
                const Divider(height: 24),

                // Documents check list
                const Text(
                  'حالة المستندات المرفوعة:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                ..._uploadStates.entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Row(
                      children: [
                        Icon(
                          entry.value
                              ? Icons.check_circle_outline
                              : Icons.cancel_outlined,
                          size: 16,
                          color: entry.value
                              ? AppColors.success
                              : AppColors.error,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _docDisplayLabel(entry.key),
                          style: const TextStyle(
                            fontSize: 12,
                            fontFamily: 'Cairo',
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Edit Button
        OutlinedButton(
          onPressed: () {
            setState(() {
              _currentStep = 1; // Back to beginning
            });
          },
          child: const Text('تعديل المعلومات الشخصية والسيارة'),
        ),
        const SizedBox(height: 16),

        // Approve Checkbox
        Row(
          children: [
            Checkbox(
              value: _termsApproved,
              activeColor: AppColors.primary,
              onChanged: (value) {
                setState(() {
                  _termsApproved = value ?? false;
                });
              },
            ),
            const Expanded(
              child: Text(
                'أقر بأن جميع البيانات والمستندات المرفوعة صحيحة وأوافق على شروط كابتن الهدهد.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.darkText,
                  fontFamily: 'Cairo',
                ),
              ),
            ),
          ],
        ),
        Wrap(
          alignment: WrapAlignment.end,
          children: [
            TextButton(
              onPressed: () => launchUrl(
                Uri.parse(kTermsUrl),
                mode: LaunchMode.externalApplication,
              ),
              child: const Text('اطّلع على شروط الاستخدام'),
            ),
            TextButton(
              onPressed: () => launchUrl(
                Uri.parse(kPrivacyPolicyUrl),
                mode: LaunchMode.externalApplication,
              ),
              child: const Text('اطّلع على سياسة الخصوصية'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: AppColors.secondaryText,
              fontFamily: 'Cairo',
            ),
          ),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : 'غير محدد',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.darkText,
                fontFamily: 'Cairo',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    bool obscure = false,
    String? hint,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.darkText,
            fontFamily: 'Cairo',
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          decoration: InputDecoration(hintText: hint, suffixIcon: suffixIcon),
        ),
      ],
    );
  }

  Widget _buildPhoneField(
    String label,
    TextEditingController controller, {
    bool readOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.darkText,
            fontFamily: 'Cairo',
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          readOnly: readOnly,
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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
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
        ),
      ],
    );
  }

  Widget _buildBottomButtons() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          if (_currentStep > 1) ...[
            Expanded(
              flex: 1,
              child: OutlinedButton(
                onPressed: _prevStep,
                child: const Text('السابق'),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isSubmitting
                  ? null
                  : (_currentStep == 4 ? _submitApplication : _nextStep),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Text(_currentStep == 4 ? 'إرسال الطلب' : 'التالي'),
            ),
          ),
        ],
      ),
    );
  }

}
