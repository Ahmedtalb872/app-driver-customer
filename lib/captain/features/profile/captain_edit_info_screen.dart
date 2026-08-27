import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/constants/captain_documents.dart';
import '../../core/constants/colors.dart';
import '../../core/supabase/auth_exception.dart';
import '../../core/supabase/auth_repository.dart';
import '../../providers/app_state_provider.dart';

/// Lets a captain fix their personal/vehicle/document details after
/// registration - most commonly needed right after an admin rejects the
/// application for a mistake (wrong plate number, blurry document, etc.)
/// and the captain needs to correct it and resubmit.
class CaptainEditInfoScreen extends StatefulWidget {
  const CaptainEditInfoScreen({super.key});

  @override
  State<CaptainEditInfoScreen> createState() => _CaptainEditInfoScreenState();
}

class _CaptainEditInfoScreenState extends State<CaptainEditInfoScreen> {
  final _authRepository = AuthRepository();
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorText;

  final _nameController = TextEditingController();
  String _selectedCity = 'نواكشوط';
  final _addressController = TextEditingController();
  final _dobController = TextEditingController();

  String _vehicleCategory = 'car';
  String _carType = 'economy';
  final _carBrandController = TextEditingController();
  final _carModelController = TextEditingController();
  final _carYearController = TextEditingController();
  final _carColorController = TextEditingController();
  final _carPlateController = TextEditingController();
  int _carSeats = 4;

  // Which service the company should pay this captain through - Mauritania's
  // three national mobile-payment services, or "other" for anything else
  // (bank transfer, cash arrangement, ...).
  String _payoutMethod = 'bankily';
  final _payoutPhoneController = TextEditingController();

  // document_type -> {'status': ..., 'rejection_reason': ...}
  Map<String, Map<String, dynamic>> _docDataByKey = {};
  String? _uploadingDoc;
  String? _accountRejectionReason;

  bool get _isMotorcycle => _vehicleCategory == 'motorcycle';

  @override
  void initState() {
    super.initState();
    _loadCurrentInfo();
  }

  @override
  void dispose() {
    _nameController.dispose();
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

  Future<void> _loadCurrentInfo() async {
    final userId = _authRepository.currentUser?.id;
    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final profile = await _authRepository.getProfile(userId);
      final captain = await _authRepository.getCaptain(userId);
      final docs = await _authRepository.getCaptainDocuments(userId);
      if (!mounted) return;
      setState(() {
        _nameController.text = profile['full_name'] as String? ?? '';
        _selectedCity = captain['city'] as String? ?? 'نواكشوط';
        _addressController.text = captain['address'] as String? ?? '';
        _dobController.text = captain['date_of_birth'] as String? ?? '';
        final vehicleType = captain['vehicle_type'] as String? ?? 'economy';
        _vehicleCategory = vehicleType == 'motorcycle' ? 'motorcycle' : 'car';
        _carType = _vehicleCategory == 'car' ? vehicleType : 'economy';
        _carBrandController.text = captain['vehicle_brand'] as String? ?? '';
        _carModelController.text = captain['vehicle_model'] as String? ?? '';
        _carYearController.text =
            (captain['vehicle_year'] as num?)?.toString() ?? '2018';
        _carColorController.text = captain['vehicle_color'] as String? ?? '';
        _carPlateController.text = captain['vehicle_plate'] as String? ?? '';
        _carSeats = (captain['vehicle_seats'] as num?)?.toInt() ?? 4;
        _payoutMethod = captain['payout_method'] as String? ?? 'bankily';
        _payoutPhoneController.text = captain['payout_phone'] as String? ?? '';
        _docDataByKey = {
          for (final row in docs) row['document_type'] as String: row,
        };
        _accountRejectionReason = captain['status'] == 'rejected'
            ? captain['rejection_reason'] as String?
            : null;
      });
    } on AppAuthException catch (e) {
      if (mounted) setState(() => _errorText = e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    final userId = _authRepository.currentUser?.id;
    if (userId == null) return;
    if (_nameController.text.trim().isEmpty) {
      setState(() => _errorText = 'الرجاء إدخال الاسم الكامل');
      return;
    }
    setState(() {
      _isSaving = true;
      _errorText = null;
    });
    try {
      await _authRepository.updateProfileName(
        userId,
        _nameController.text.trim(),
      );
      final vehicleType = _isMotorcycle ? 'motorcycle' : _carType;
      await _authRepository.updateCaptainVehicleInfo(
        captainId: userId,
        city: _selectedCity,
        address: _addressController.text.trim(),
        dateOfBirth: _dobController.text.trim(),
        vehicleType: vehicleType,
        vehicleBrand: _carBrandController.text.trim(),
        vehicleModel: _carModelController.text.trim(),
        vehicleYear: int.tryParse(_carYearController.text.trim()) ?? 2018,
        vehicleColor: _carColorController.text.trim(),
        vehiclePlate: _carPlateController.text.trim(),
        vehicleSeats: _carSeats,
      );
      if (_payoutPhoneController.text.trim().isNotEmpty) {
        await _authRepository.updateCaptainPayoutInfo(
          captainId: userId,
          payoutMethod: _payoutMethod,
          payoutPhone: _payoutPhoneController.text.trim(),
        );
      }
      if (!mounted) return;
      final provider = Provider.of<AppStateProvider>(context, listen: false);
      provider.updateCaptainDisplayName(_nameController.text.trim());
      provider.updateVehicleCategoryLocally(vehicleType);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تم حفظ التعديلات بنجاح.',
            style: TextStyle(fontFamily: 'Cairo'),
          ),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.of(context).pop();
    } on AppAuthException catch (e) {
      setState(() => _errorText = e.message);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _reuploadDoc(String docType) async {
    final userId = _authRepository.currentUser?.id;
    if (userId == null) return;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
      final Uint8List bytes = await file.readAsBytes();
      await _authRepository.uploadCaptainDocuments(userId, [
        CaptainDocumentFile(
          docKey: docType,
          docName: kCaptainDocTypes[docType] ?? docType,
          bytes: bytes,
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _docDataByKey[docType] = {'status': 'pending', 'rejection_reason': null};
        _uploadingDoc = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تم رفع المستند من جديد، وهو الآن قيد المراجعة.',
            style: TextStyle(fontFamily: 'Cairo'),
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      debugPrint('Document re-upload failed: $e');
      if (!mounted) return;
      setState(() => _uploadingDoc = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تعذر رفع المستند، حاول مرة أخرى.',
            style: TextStyle(fontFamily: 'Cairo'),
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('تعديل المعلومات')),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_accountRejectionReason != null &&
                        _accountRejectionReason!.isNotEmpty) ...[
                      _buildNoticeBanner(
                        'ملاحظة من الإدارة',
                        _accountRejectionReason!,
                      ),
                      const SizedBox(height: 20),
                    ],
                    const Text(
                      'المعلومات الشخصية',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkText,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildTextField('الاسم الكامل', _nameController),
                    const SizedBox(height: 16),
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
                              setState(() => _selectedCity = value);
                            }
                          },
                          items:
                              <String>['نواكشوط', 'نواذيبو', 'روصو', 'أطار', 'كيفه']
                                  .map(
                                    (v) => DropdownMenuItem(
                                      value: v,
                                      child: Text(v),
                                    ),
                                  )
                                  .toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildTextField('العنوان بالتفصيل', _addressController),
                    const SizedBox(height: 16),
                    _buildTextField(
                      'تاريخ الميلاد',
                      _dobController,
                      hint: 'YYYY-MM-DD',
                    ),
                    const SizedBox(height: 28),

                    const Text(
                      'المركبة',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkText,
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
                            Icons.directions_car_filled_rounded,
                          ),
                          const SizedBox(width: 12),
                          _buildVehicleCategoryCard(
                            'motorcycle',
                            'دراجة نارية',
                            Icons.two_wheeler_rounded,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
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
                          _buildCarTypeChip('economy', 'إقتصادية'),
                          const SizedBox(width: 8),
                          _buildCarTypeChip('comfort', 'مريحة'),
                          const SizedBox(width: 8),
                          _buildCarTypeChip('family', 'عائلية'),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                    _buildTextField(
                      _isMotorcycle ? 'ماركة الدراجة' : 'ماركة السيارة',
                      _carBrandController,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField('الموديل', _carModelController),
                    const SizedBox(height: 16),
                    _buildTextField('سنة الصنع', _carYearController),
                    const SizedBox(height: 16),
                    _buildTextField(
                      _isMotorcycle ? 'لون الدراجة' : 'لون السيارة',
                      _carColorController,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField('رقم اللوحة', _carPlateController),
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
                                setState(() => _carSeats = value);
                              }
                            },
                            items: <int>[4, 6, 7]
                                .map(
                                  (v) => DropdownMenuItem(
                                    value: v,
                                    child: Text('$v مقاعد'),
                                  ),
                                )
                                .toList(),
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
                        _buildPayoutMethodChip('bankily', 'Bankily'),
                        const SizedBox(width: 8),
                        _buildPayoutMethodChip('masrvi', 'Masrvi'),
                        const SizedBox(width: 8),
                        _buildPayoutMethodChip('sedad', 'Sedad'),
                        const SizedBox(width: 8),
                        _buildPayoutMethodChip('other', 'أخرى'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      'رقم الهاتف على هذه الخدمة',
                      _payoutPhoneController,
                      hint: 'مثال: 22XXXXXXXX',
                    ),
                    const SizedBox(height: 28),

                    const Text(
                      'المستندات',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkText,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'يُرفع كل مستند فور اختياره - لا حاجة لزر الحفظ بالأسفل لهذا القسم.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.secondaryText,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...kCaptainDocTypes.keys.map(_buildDocRow),

                    if (_errorText != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _errorText!,
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 13,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),
                    ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      child: _isSaving
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: AppColors.darkText,
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Text('حفظ التعديلات'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildNoticeBanner(String title, String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: AppColors.error,
                    fontFamily: 'Cairo',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.darkText,
                    fontFamily: 'Cairo',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocRow(String docType) {
    final docLabel = captainDocLabel(docType, isMotorcycle: _isMotorcycle);
    final data = _docDataByKey[docType];
    final status = data?['status'] as String?;
    final docReason = data?['rejection_reason'] as String?;
    final isThisUploading = _uploadingDoc == docType;

    Color statusColor = AppColors.secondaryText;
    String statusText = 'لم يُرفع بعد';
    IconData statusIcon = Icons.upload_file_rounded;
    if (status == 'approved') {
      statusColor = AppColors.success;
      statusText = 'تم القبول';
      statusIcon = Icons.check_circle_outline;
    } else if (status == 'pending') {
      statusColor = AppColors.warning;
      statusText = 'قيد المراجعة';
      statusIcon = Icons.hourglass_empty_rounded;
    } else if (status == 'rejected') {
      statusColor = AppColors.error;
      statusText = 'مرفوض - يحتاج إعادة رفع';
      statusIcon = Icons.cancel_outlined;
    } else if (status == 'expired') {
      statusColor = AppColors.secondaryText;
      statusText = 'منتهي الصلاحية';
      statusIcon = Icons.timer_off_outlined;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      docLabel,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkText,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, color: statusColor, size: 13),
                        const SizedBox(width: 4),
                        Text(
                          statusText,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (status == 'rejected' && docReason != null && docReason.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  docReason,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.error,
                    fontFamily: 'Cairo',
                  ),
                ),
              ],
              if (status != 'approved') ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: isThisUploading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.primary,
                          ),
                        )
                      : ElevatedButton.icon(
                          onPressed: () => _reuploadDoc(docType),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(130, 32),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(Icons.upload_rounded, size: 14),
                          label: Text(
                            status == null ? 'رفع المستند' : 'إعادة رفع المستند',
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVehicleCategoryCard(String category, String label, IconData icon) {
    bool isSel = _vehicleCategory == category;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _vehicleCategory = category),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSel ? AppColors.primary.withOpacity(0.12) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSel ? AppColors.primary : AppColors.border,
              width: isSel ? 2 : 1.5,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSel ? AppColors.primaryDark : AppColors.secondaryText,
                size: 32,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.darkText,
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

  Widget _buildCarTypeChip(String type, String label) {
    bool isSel = _carType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _carType = type),
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

  Widget _buildPayoutMethodChip(String method, String label) {
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

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    String? hint,
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
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    );
  }
}
