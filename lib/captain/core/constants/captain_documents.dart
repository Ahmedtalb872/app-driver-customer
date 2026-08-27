/// `document_type` -> Arabic display label, matching the
/// `captain_documents_document_type_check` constraint exactly. Shared
/// between registration (uploads) and info-editing (status + re-upload) so
/// both always agree on the same set of documents.
const Map<String, String> kCaptainDocTypes = {
  'profile_photo': 'الصورة الشخصية',
  'national_id_front': 'بطاقة الهوية الوطنية - الوجه الأمامي',
  'national_id_back': 'بطاقة الهوية الوطنية - الوجه الخلفي',
  'driving_license_front': 'رخصة السياقة - الوجه الأمامي',
  'driving_license_back': 'رخصة السياقة - الوجه الخلفي',
  'vehicle_registration_front': 'البطاقة الرمادية - الوجه الأمامي',
  'vehicle_registration_back': 'البطاقة الرمادية - الوجه الخلفي',
  'vehicle_photo': 'صورة السيارة',
  'vehicle_insurance': 'تأمين السيارة',
  'additional_document': 'مستند إضافي (اختياري)',
};

/// The only document_type that isn't required to complete registration.
const String kOptionalDocType = 'additional_document';

/// Wording override for a motorcycle captain - same document_type, same
/// everything else, just different guiding text (e.g. "driving license"
/// reads as "motorcycle license").
const Map<String, String> kMotorcycleDocLabels = {
  'رخصة السياقة - الوجه الأمامي': 'رخصة قيادة دراجة نارية - الوجه الأمامي',
  'رخصة السياقة - الوجه الخلفي': 'رخصة قيادة دراجة نارية - الوجه الخلفي',
  'البطاقة الرمادية - الوجه الأمامي': 'تسجيل الدراجة - الوجه الأمامي',
  'البطاقة الرمادية - الوجه الخلفي': 'تسجيل الدراجة - الوجه الخلفي',
  'صورة السيارة': 'صورة الدراجة النارية',
  'تأمين السيارة': 'تأمين الدراجة النارية',
};

String captainDocLabel(String docType, {required bool isMotorcycle}) {
  final base = kCaptainDocTypes[docType] ?? docType;
  if (!isMotorcycle) return base;
  return kMotorcycleDocLabels[base] ?? base;
}
