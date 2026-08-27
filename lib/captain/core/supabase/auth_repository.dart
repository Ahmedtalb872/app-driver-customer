import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_exception.dart';
import 'supabase_config.dart';

/// One captain verification document picked on-device, ready to upload.
class CaptainDocumentFile {
  final String docKey;
  final String docName;
  final Uint8List bytes;
  const CaptainDocumentFile({
    required this.docKey,
    required this.docName,
    required this.bytes,
  });
}

/// Wraps Supabase Auth (phone number + password, with a one-time SMS code to
/// confirm the phone at sign-up) and the matching `profiles` row created
/// automatically by the `handle_new_user` DB trigger.
class AuthRepository {
  SupabaseClient get _client => SupabaseConfig.client;

  User? get currentUser =>
      SupabaseConfig.isReady ? _client.auth.currentUser : null;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  void _requireConfigured() {
    if (!SupabaseConfig.isReady) {
      throw AppAuthException(
        'لم يتم إعداد الاتصال بالخادم بعد. راجع ملف env.json.example.',
      );
    }
  }

  /// Creates a new captain account with [phone] + [password], and (if phone
  /// confirmations are enabled in Supabase) sends a 6-digit SMS code that
  /// must be confirmed with [verifySignUpOtp] before the account is usable.
  Future<void> signUpWithPassword({
    required String phone,
    required String password,
    required String fullName,
  }) async {
    _requireConfigured();
    try {
      await _client.auth.signUp(
        phone: phone,
        password: password,
        data: {'full_name': fullName, 'phone': phone, 'role': 'captain'},
      );
    } on AuthException catch (e) {
      throw AppAuthException(_translateAuthError(e));
    }
  }

  /// Confirms the phone number for an account created by
  /// [signUpWithPassword], completing the sign-up.
  Future<Map<String, dynamic>> verifySignUpOtp({
    required String phone,
    required String code,
  }) async {
    _requireConfigured();
    try {
      final response = await _client.auth.verifyOTP(
        phone: phone,
        token: code,
        type: OtpType.sms,
      );

      final user = response.user;
      if (user == null) {
        throw AppAuthException('رمز التحقق غير صحيح.');
      }

      return await getProfile(user.id);
    } on AuthException catch (e) {
      throw AppAuthException(_translateAuthError(e));
    }
  }

  /// Logs an existing captain in with their phone + password. No SMS needed.
  Future<Map<String, dynamic>> signInWithPassword({
    required String phone,
    required String password,
  }) async {
    _requireConfigured();
    try {
      final response = await _client.auth.signInWithPassword(
        phone: phone,
        password: password,
      );
      final user = response.user;
      if (user == null) {
        throw AppAuthException('تعذر تسجيل الدخول.');
      }
      return await getProfile(user.id);
    } on AuthException catch (e) {
      throw AppAuthException(_translateAuthError(e));
    }
  }

  /// Uploads each picked document to the private `captain-documents` bucket
  /// (under a path prefixed with [captainId], matching its storage RLS
  /// policy) and records it in `captain_documents` for admin review.
  /// [CaptainDocumentFile.docKey] must be one of the values allowed by
  /// `captain_documents_document_type_check` (profile_photo,
  /// national_id_front/back, driving_license_front/back,
  /// vehicle_registration_front/back, vehicle_photo, vehicle_insurance,
  /// additional_document) - it maps to the `document_type` column.
  Future<void> uploadCaptainDocuments(
    String captainId,
    List<CaptainDocumentFile> documents,
  ) async {
    _requireConfigured();
    try {
      for (final doc in documents) {
        final path = '$captainId/${doc.docKey}.jpg';
        await _client.storage
            .from('captain-documents')
            .uploadBinary(
              path,
              doc.bytes,
              fileOptions: const FileOptions(
                upsert: true,
                contentType: 'image/jpeg',
              ),
            );

        await _client.from('captain_documents').upsert(
          {
            'captain_id': captainId,
            'document_type': doc.docKey,
            'file_name': doc.docName,
            'file_path': path,
            'mime_type': 'image/jpeg',
            'file_size': doc.bytes.length,
            'status': 'pending',
          },
          onConflict: 'captain_id,document_type',
        );
      }
    } catch (e) {
      // The underlying Postgrest/Storage error (RLS denial, NOT NULL
      // violation, etc.) is swallowed into a generic Arabic message for the
      // UI - keep it in the debug console so a real failure here doesn't
      // need another round of manual SQL queries to diagnose.
      debugPrint('uploadCaptainDocuments failed: $e');
      throw AppAuthException(
        'تم إنشاء حسابك، لكن تعذر رفع بعض المستندات. يمكنك رفعها لاحقًا من صفحة حسابك.',
      );
    }
  }

  /// The current review status (and, if rejected, the reason) of every
  /// `captain_documents` row for [captainId] - a document_type with no row
  /// here just hasn't been uploaded yet.
  Future<List<Map<String, dynamic>>> getCaptainDocuments(
    String captainId,
  ) async {
    try {
      return await _client
          .from('captain_documents')
          .select('document_type, status, rejection_reason')
          .eq('captain_id', captainId);
    } on PostgrestException {
      throw AppAuthException('تعذر تحميل حالة المستندات.');
    }
  }

  /// A temporary signed URL for the captain's uploaded profile photo (the
  /// `captain-documents` bucket is private, so it isn't reachable by a
  /// plain public URL). Returns null if no photo has been uploaded yet -
  /// callers should fall back to a placeholder avatar in that case.
  Future<String?> getProfilePhotoUrl(String captainId) async {
    try {
      return await _client.storage
          .from('captain-documents')
          .createSignedUrl('$captainId/profile_photo.jpg', 3600);
    } on StorageException {
      return null;
    }
  }

  Future<Map<String, dynamic>> getProfile(String userId) async {
    try {
      return await _client.from('profiles').select().eq('id', userId).single();
    } on PostgrestException {
      throw AppAuthException('تعذر تحميل بيانات الحساب.');
    }
  }

  Future<void> updateProfileName(String profileId, String fullName) async {
    try {
      await _client
          .from('profiles')
          .update({'full_name': fullName})
          .eq('id', profileId);
    } on PostgrestException {
      throw AppAuthException('تعذر حفظ الاسم.');
    }
  }

  /// The `captains` row for [captainId] - created automatically (bare) by
  /// the sign-up trigger. `status` ('pending'/'approved'/'rejected'/
  /// 'suspended') is the real approval gate, separate from
  /// `profiles.is_approved`.
  Future<Map<String, dynamic>> getCaptain(String captainId) async {
    try {
      return await _client
          .from('captains')
          .select()
          .eq('id', captainId)
          .single();
    } on PostgrestException {
      throw AppAuthException('تعذر تحميل بيانات حساب الكابتن.');
    }
  }

  /// The captain's currently in-progress trip, if any - active-trip state
  /// otherwise only lives in the app's in-memory provider, so without this
  /// a captain who gets kicked back to the app after Android kills the
  /// process mid-trip would land on the dashboard with no sign their trip
  /// still exists. Returns null if they have no accepted/arrived/in_progress/
  /// boarded trip right now.
  Future<Map<String, dynamic>?> getActiveTripForCaptain(
    String captainId,
  ) async {
    try {
      final rows = await _client
          .from('trips')
          .select()
          .eq('captain_id', captainId)
          .inFilter('status', ['accepted', 'arrived', 'in_progress', 'boarded'])
          .order('created_at', ascending: false)
          .limit(1);
      final list = rows as List;
      if (list.isEmpty) return null;
      return list.first as Map<String, dynamic>;
    } on PostgrestException {
      return null;
    }
  }

  /// Fills in the vehicle/city/address/birth-date details collected during
  /// registration on the bare `captains` row the sign-up trigger created.
  /// [vehicleType] is 'economy'/'comfort'/'family' for a car, or literally
  /// 'motorcycle' - there's no separate vehicle-category column, a
  /// motorcycle is just another value of this same column.
  Future<void> updateCaptainVehicleInfo({
    required String captainId,
    required String city,
    required String address,
    required String dateOfBirth,
    required String vehicleType,
    required String vehicleBrand,
    required String vehicleModel,
    required int vehicleYear,
    required String vehicleColor,
    required String vehiclePlate,
    required int vehicleSeats,
  }) async {
    try {
      await _client
          .from('captains')
          .update({
            'city': city,
            'address': address,
            'date_of_birth': dateOfBirth,
            'vehicle_type': vehicleType,
            'vehicle_brand': vehicleBrand,
            'vehicle_model': vehicleModel,
            'vehicle_year': vehicleYear,
            'vehicle_color': vehicleColor,
            'vehicle_plate': vehiclePlate,
            'vehicle_seats': vehicleSeats,
          })
          .eq('id', captainId);
    } on PostgrestException {
      throw AppAuthException('تعذر حفظ بيانات السيارة.');
    }
  }

  // Which mobile-payment service (and phone number on it) the company
  // should use to pay this captain - salary settlements, bonuses/rewards.
  // Purely informational for now: an admin reads it directly from the
  // captains table when it's time to pay, there's no in-app payout flow.
  Future<void> updateCaptainPayoutInfo({
    required String captainId,
    required String payoutMethod,
    required String payoutPhone,
  }) async {
    try {
      await _client
          .from('captains')
          .update({'payout_method': payoutMethod, 'payout_phone': payoutPhone})
          .eq('id', captainId);
    } on PostgrestException {
      throw AppAuthException('تعذر حفظ معلومات استلام المدفوعات.');
    }
  }

  /// Permanently deletes the signed-in captain's account and data via the
  /// delete_my_account RPC (migration 0025): auth user, profile, captain
  /// row, documents (rows + storage files), wallet, locations - with their
  /// trips kept but anonymized. Signs out locally afterwards.
  Future<void> deleteMyAccount() async {
    _requireConfigured();
    try {
      await _client.rpc('delete_my_account');
    } on PostgrestException {
      throw AppAuthException('تعذر حذف الحساب، حاول مرة أخرى أو تواصل مع الدعم.');
    }
    try {
      await _client.auth.signOut();
    } catch (_) {
      // The server-side account is already gone; a failed local sign-out
      // just leaves a dead session that stops working on its own.
    }
  }

  Future<void> setCaptainOnline(String captainId, bool isOnline) async {
    try {
      await _client
          .from('captains')
          .update({'is_online': isOnline})
          .eq('id', captainId);
    } catch (_) {
      // Best-effort - local online state still works even if this fails.
    }
  }

  /// Motorcycle captains can opt in/out of receiving delivery requests
  /// alongside their normal passenger requests.
  Future<void> setAcceptsDelivery(String captainId, bool enabled) async {
    try {
      await _client
          .from('captains')
          .update({'accepts_delivery': enabled})
          .eq('id', captainId);
    } catch (_) {
      // Best-effort - local toggle state still works even if this fails.
    }
  }

  /// Atomically claims a searching trip via the `captain_accept_trip`
  /// RPC, which re-checks server-side that the captain is approved/online
  /// (and, for a delivery, a motorcycle captain with accepts_delivery on)
  /// before handing it over. Throws if the trip is no longer available or
  /// the captain isn't eligible.
  Future<Map<String, dynamic>> acceptTrip(String tripId) async {
    try {
      final result = await _client.rpc(
        'captain_accept_trip',
        params: {'p_trip_id': tripId},
      );
      return result as Map<String, dynamic>;
    } on PostgrestException catch (e) {
      debugPrint('acceptTrip failed: ${e.message}');
      if (e.message.contains('TRIP_UNAVAILABLE')) {
        throw AppAuthException('تم قبول هذا الطلب من كابتن آخر، أو لم يعد متاحًا.');
      }
      if (e.message.contains('approved, online captain')) {
        throw AppAuthException('يجب أن يكون حسابك معتمدًا ومتصلاً لقبول الطلبات.');
      }
      throw AppAuthException('تعذر قبول الطلب، حاول مرة أخرى.');
    }
  }

  Future<void> signOut() async {
    if (!SupabaseConfig.isReady) return;
    await _client.auth.signOut();
  }

  /// Sends a 6-digit SMS code to an already-registered captain's [phone] so
  /// they can reset a forgotten password. `shouldCreateUser: false` makes
  /// sure this never silently creates a new account for an unknown number.
  Future<void> sendPasswordResetOtp(String phone) async {
    _requireConfigured();
    try {
      await _client.auth.signInWithOtp(phone: phone, shouldCreateUser: false);
    } on AuthException catch (e) {
      throw AppAuthException(_translateAuthError(e));
    }
  }

  /// Confirms the code from [sendPasswordResetOtp] and sets [newPassword]
  /// as the account's password. Always signs the captain back out
  /// afterwards, successful or not, so they log in explicitly with the new
  /// password through the normal flow (which also runs the role/approval
  /// checks) rather than being left in a half-authenticated app state.
  Future<void> resetPasswordWithOtp({
    required String phone,
    required String code,
    required String newPassword,
  }) async {
    _requireConfigured();
    try {
      final response = await _client.auth.verifyOTP(
        phone: phone,
        token: code,
        type: OtpType.sms,
      );
      if (response.user == null) {
        throw AppAuthException('تعذر التحقق من الرمز.');
      }
      await _client.auth.updateUser(UserAttributes(password: newPassword));
    } on AuthException catch (e) {
      throw AppAuthException(_translateAuthError(e));
    } finally {
      await _client.auth.signOut();
    }
  }

  String _translateAuthError(AuthException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('invalid otp') || msg.contains('token has expired')) {
      return 'رمز التحقق غير صحيح أو انتهت صلاحيته، اطلب رمزًا جديدًا.';
    }
    if (msg.contains('sms rate limit') || msg.contains('rate limit')) {
      return 'تم إرسال عدة رموز مؤخرًا، انتظر قليلاً قبل طلب رمز جديد.';
    }
    if (msg.contains('invalid phone')) {
      return 'رقم الهاتف غير صحيح.';
    }
    if (msg.contains('invalid login credentials')) {
      return 'رقم الهاتف أو كلمة المرور غير صحيحة.';
    }
    if (msg.contains('user already registered') ||
        msg.contains('already been registered')) {
      return 'هذا الرقم مسجل بالفعل. سجل الدخول بدلاً من إنشاء حساب جديد.';
    }
    if (msg.contains('password') && msg.contains('at least')) {
      return 'كلمة المرور قصيرة جدًا، استخدم 6 أحرف على الأقل.';
    }
    if (msg.contains('signups not allowed') || msg.contains('user not found')) {
      return 'هذا الرقم غير مسجل في التطبيق.';
    }
    return e.message;
  }
}
