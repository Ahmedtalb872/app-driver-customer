import '../../admin/services/admin_auth_service.dart';
import '../../core/auth/app_role.dart';
import '../../core/auth/auth_service.dart';

/// Wraps the shared [AuthService] for the business portal - a business
/// account is a plain `role: customer` account under the hood (see
/// 20261103000119_business_accounts.sql's own comment for why), signed up
/// through the same synthetic-email/password path [AuthService.signUp]/
/// [AuthService.signIn] already use for admin/demo accounts, not the real
/// phone-OTP flow - no SMS provider dependency for a business to register.
class BusinessAuthService {
  BusinessAuthService._();

  static final BusinessAuthService instance = BusinessAuthService._();

  bool get isAuthenticated => AuthService.instance.isAuthenticated;

  /// Accepts a bare local number or one already carrying +222, same
  /// normalization the admin login screen uses.
  static String normalizePhone(String input) =>
      AdminAuthService.normalizePhone(input);

  Future<void> signUp({
    required String phone,
    required String password,
    required String contactName,
  }) async {
    await AuthService.instance.signUp(
      phone: normalizePhone(phone),
      password: password,
      fullName: contactName,
      role: AppRole.customer,
    );
  }

  Future<void> signIn({required String phone, required String password}) {
    return AuthService.instance.signIn(
      phone: normalizePhone(phone),
      password: password,
    );
  }

  Future<void> signOut() => AuthService.instance.signOut();
}
