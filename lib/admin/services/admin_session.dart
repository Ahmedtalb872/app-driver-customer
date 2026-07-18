import 'package:flutter/foundation.dart';

import '../models/admin_profile.dart';
import 'admin_auth_service.dart';

enum AdminSessionStatus {
  unknown,
  loading,
  signedOut,
  unauthorized,
  authorized,
}

/// Holds the resolved admin session for the whole `/admin` app - the
/// go_router redirect logic and every screen's role checks read from here
/// instead of re-querying Supabase each time.
class AdminSession extends ChangeNotifier {
  AdminSessionStatus status = AdminSessionStatus.unknown;
  AdminProfile? profile;

  Future<void> refresh() async {
    status = AdminSessionStatus.loading;
    notifyListeners();

    if (!AdminAuthService.instance.isAuthenticated) {
      status = AdminSessionStatus.signedOut;
      profile = null;
      notifyListeners();
      return;
    }

    try {
      final result = await AdminAuthService.instance.fetchCurrentAdminProfile();
      if (result == null || !result.isActive) {
        status = AdminSessionStatus.unauthorized;
        profile = null;
      } else {
        status = AdminSessionStatus.authorized;
        profile = result;
      }
    } catch (_) {
      status = AdminSessionStatus.unauthorized;
      profile = null;
    }
    notifyListeners();
  }

  Future<void> signOut() async {
    await AdminAuthService.instance.signOut();
    status = AdminSessionStatus.signedOut;
    profile = null;
    notifyListeners();
  }
}
