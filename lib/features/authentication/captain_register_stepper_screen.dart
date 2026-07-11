import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../providers/app_state_provider.dart';
import '../captain/captain_home_screen.dart';

class CaptainRegisterStepperScreen extends StatefulWidget {
  const CaptainRegisterStepperScreen({super.key});

  @override
  State<CaptainRegisterStepperScreen> createState() => _CaptainRegisterStepperScreenState();
}

class _CaptainRegisterStepperScreenState extends State<CaptainRegisterStepperScreen> {
  int _currentStep = 1;
  bool _isSuccess = false;
  bool _termsApproved = false;

  // Step 1 Controllers
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String _selectedCity = 'نواكشوط';
  final _addressController = TextEditingController();
  final _dobController = TextEditingController(text: '1990-01-01');

  // Step 2 Controllers
  String _carType = 'economy'; // economy, comfort, family
  final _carBrandController = TextEditingController(text: 'تويوتا');
  final _carModelController = TextEditingController(text: 'كورولا');
  final _carYearController = TextEditingController(text: '2018');
  final _carColorController = TextEditingController(text: 'فضي');
  final _carPlateController = TextEditingController(text: '1234 AA 00');
  int _carSeats = 4;

  // Step 3 Upload states
  final Map<String, bool> _uploadStates = {
    'الصورة الشخصية': false,
    'بطاقة الهوية الوطنية': false,
    'رخصة السياقة': false,
    'البطاقة الرمادية': false,
    'صورة السيارة': false,
    'تأمين السيارة': false,
    'تصريح العمل الإضافي': false,
  };
  String? _uploadingDoc;

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
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 4) {
      setState(() {
        _currentStep++;
      });
    }
  }

  void _prevStep() {
    if (_currentStep > 1) {
      setState(() {
        _currentStep--;
      });
    }
  }

  void _simulateUpload(String docName) {
    setState(() {
      _uploadingDoc = docName;
    });

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() {
          _uploadStates[docName] = true;
          _uploadingDoc = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم رفع $docName بنجاح'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    });
  }

  void _submitApplication() {
    if (!_termsApproved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الرجاء الموافقة على الشروط والأحكام'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Check if documents are uploaded
    bool allDocsUploaded = _uploadStates.values.every((uploaded) => uploaded);
    if (!allDocsUploaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى رفع جميع المستندات المطلوبة أولاً'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isSuccess = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isSuccess) {
      return _buildSuccessScreen();
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('تسجيل كابتن جديد'),
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
          _buildStepIndicatorItem(2, 'السيارة'),
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
              color: isCompleted || isActive ? AppColors.primary : AppColors.border,
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
        )
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
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.darkText, fontFamily: 'Cairo'),
        ),
        const SizedBox(height: 16),
        _buildTextField('الاسم الكامل', _nameController, hint: 'أدخل اسمك الكامل كما في الهوية'),
        const SizedBox(height: 16),
        _buildPhoneField('رقم الهاتف', _phoneController),
        const SizedBox(height: 16),
        _buildTextField('كلمة المرور', _passwordController, obscure: true, hint: 'أدخل كلمة المرور لحسابك'),
        const SizedBox(height: 16),
        _buildTextField('تأكيد كلمة المرور', _confirmPasswordController, obscure: true, hint: 'أعد كتابة كلمة المرور'),
        const SizedBox(height: 16),
        // City dropdown
        const Text(
          'المدينة',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.darkText, fontFamily: 'Cairo'),
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
              style: const TextStyle(color: AppColors.darkText, fontSize: 16, fontFamily: 'Cairo'),
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
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildTextField('العنوان بالتفصيل', _addressController, hint: 'مثال: تفرغ زينة - كارفور موري سانتر'),
        const SizedBox(height: 16),
        _buildTextField('تاريخ الميلاد', _dobController, hint: 'YYYY-MM-DD'),
      ],
    );
  }

  Widget _buildStep2Vehicle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'معلومات السيارة',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.darkText, fontFamily: 'Cairo'),
        ),
        const SizedBox(height: 4),
        const Text(
          'ملاحظة: الخدمة حالياً مخصصة فقط لنقل الركاب بالسيارات العادية.',
          style: TextStyle(fontSize: 12, color: AppColors.secondaryText, fontFamily: 'Cairo'),
        ),
        const SizedBox(height: 20),
        
        // Car Type selection (Custom cards)
        const Text(
          'فئة السيارة',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.darkText, fontFamily: 'Cairo'),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildCarTypeCard('economy', 'إقتصادية', Icons.directions_car_filled_outlined),
            const SizedBox(width: 8),
            _buildCarTypeCard('comfort', 'مريحة', Icons.local_taxi_rounded),
            const SizedBox(width: 8),
            _buildCarTypeCard('family', 'عائلية', Icons.airport_shuttle_rounded),
          ],
        ),
        const SizedBox(height: 20),
        
        _buildTextField('ماركة السيارة', _carBrandController, hint: 'مثال: تويوتا'),
        const SizedBox(height: 16),
        _buildTextField('الموديل', _carModelController, hint: 'مثال: كورولا / أفينسيس'),
        const SizedBox(height: 16),
        _buildTextField('سنة الصنع', _carYearController, hint: 'مثال: 2018'),
        const SizedBox(height: 16),
        _buildTextField('لون السيارة', _carColorController, hint: 'مثال: رمادي / أبيض'),
        const SizedBox(height: 16),
        _buildTextField('رقم اللوحة', _carPlateController, hint: 'مثال: 1234 AA 00'),
        const SizedBox(height: 16),
        
        // Seats dropdown
        const Text(
          'عدد المقاعد المتاحة للركاب',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.darkText, fontFamily: 'Cairo'),
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
              style: const TextStyle(color: AppColors.darkText, fontSize: 16, fontFamily: 'Cairo'),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _carSeats = value;
                  });
                }
              },
              items: <int>[4, 6, 7]
                  .map<DropdownMenuItem<int>>((int val) {
                return DropdownMenuItem<int>(
                  value: val,
                  child: Text('$val مقاعد'),
                );
              }).toList(),
            ),
          ),
        ),
      ],
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
              Icon(icon, color: isSel ? Colors.white : AppColors.secondaryText, size: 28),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSel ? Colors.white : AppColors.darkText,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo',
                  fontSize: 13,
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep3Documents() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'المستندات والأوراق الرسمية',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.darkText, fontFamily: 'Cairo'),
        ),
        const SizedBox(height: 8),
        const Text(
          'يرجى الضغط على كل مستند لتجربة رفعه من ملفات هاتفك.',
          style: TextStyle(fontSize: 12, color: AppColors.secondaryText, fontFamily: 'Cairo'),
        ),
        const SizedBox(height: 20),
        
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _uploadStates.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            String docName = _uploadStates.keys.elementAt(index);
            bool isUploaded = _uploadStates[docName]!;
            bool isThisUploading = _uploadingDoc == docName;

            return InkWell(
              onTap: isUploaded || isThisUploading ? null : () => _simulateUpload(docName),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isUploaded ? AppColors.success.withOpacity(0.5) : AppColors.border,
                    width: isUploaded ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isUploaded
                            ? AppColors.success.withOpacity(0.1)
                            : AppColors.background,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isUploaded ? Icons.done_rounded : Icons.upload_file_rounded,
                        color: isUploaded ? AppColors.success : AppColors.secondaryText,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            docName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: AppColors.darkText,
                              fontFamily: 'Cairo',
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isUploaded ? 'حالة الملف: تم الرفع' : 'حالة الملف: لم يتم الرفع بعد',
                            style: TextStyle(
                              fontSize: 11,
                              color: isUploaded ? AppColors.success : AppColors.secondaryText,
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
                      const Icon(Icons.check_circle_outline_rounded, color: AppColors.success)
                    else
                      const Icon(Icons.chevron_left_rounded, color: AppColors.secondaryText),
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
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.darkText, fontFamily: 'Cairo'),
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
                _buildReviewRow('رقم الهاتف', '+222 ${_phoneController.text}'),
                _buildReviewRow('المدينة والعنوان', '$_selectedCity - ${_addressController.text}'),
                _buildReviewRow('تاريخ الميلاد', _dobController.text),
                const Divider(height: 24),
                _buildReviewRow('نوع السيارة', _carType == 'economy' ? 'إقتصادية' : _carType == 'comfort' ? 'مريحة' : 'عائلية'),
                _buildReviewRow('الماركة والموديل', '${_carBrandController.text} ${_carModelController.text} (${_carYearController.text})'),
                _buildReviewRow('رقم لوحة السيارة', _carPlateController.text),
                _buildReviewRow('المقاعد المتاحة', '$_carSeats مقاعد'),
                const Divider(height: 24),
                
                // Documents check list
                const Text(
                  'حالة المستندات المرفوعة:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 13),
                ),
                const SizedBox(height: 8),
                ..._uploadStates.entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Row(
                      children: [
                        Icon(
                          entry.value ? Icons.check_circle_outline : Icons.cancel_outlined,
                          size: 16,
                          color: entry.value ? AppColors.success : AppColors.error,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          entry.key,
                          style: const TextStyle(fontSize: 12, fontFamily: 'Cairo', color: AppColors.secondaryText),
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
                style: TextStyle(fontSize: 12, color: AppColors.darkText, fontFamily: 'Cairo'),
              ),
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
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.secondaryText, fontFamily: 'Cairo'),
          ),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : 'غير محدد',
              style: const TextStyle(fontSize: 13, color: AppColors.darkText, fontFamily: 'Cairo'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {bool obscure = false, String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.darkText, fontFamily: 'Cairo'),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          decoration: InputDecoration(
            hintText: hint,
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.darkText, fontFamily: 'Cairo'),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
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
              onPressed: _currentStep == 4 ? _submitApplication : _nextStep,
              child: Text(_currentStep == 4 ? 'إرسال الطلب' : 'التالي'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessScreen() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.success,
                  size: 80,
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'تم إرسال طلبك بنجاح!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.darkText, fontFamily: 'Cairo'),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Text(
                  'حالة الطلب: قيد المراجعة',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.warning,
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'سيتم مراجعة حسابك ومستنداتك وتفعيل الحساب من قبل الإدارة في أقرب وقت. ستتلقى إشعاراً فور تفعيل الحساب.',
                style: TextStyle(fontSize: 14, color: AppColors.secondaryText, fontFamily: 'Cairo'),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              
              // Simulate proceeding to Captain Dashboard
              ElevatedButton(
                onPressed: () {
                  final provider = Provider.of<AppStateProvider>(context, listen: false);
                  provider.registerCaptain(_nameController.text.isNotEmpty ? _nameController.text : 'كابتن هدهد جديد', '+222${_phoneController.text}');
                  
                  // Go to Captain Home Screen directly
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const CaptainHomeScreen()),
                    (route) => false,
                  );
                },
                child: const Text('دخول لوحة تحكم الكابتن تجريبياً'),
              ),
              const SizedBox(height: 12),
              
              TextButton(
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                child: const Text('الرجوع إلى البداية'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
