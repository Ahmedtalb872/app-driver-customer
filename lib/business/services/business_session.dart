import 'package:flutter/foundation.dart';

import '../models/business_account.dart';
import '../repositories/business_account_repository.dart';
import 'business_auth_service.dart';

enum BusinessSessionStatus {
  unknown,
  loading,
  signedOut,
  // Signed in, but createMyAccount() hasn't run yet (mid-registration) -
  // the register screen is the only place that should ever see this.
  noAccount,
  pending,
  rejected,
  suspended,
  approved,
}

/// Mirrors [AdminSession]'s role in the admin app: the business portal's
/// go_router redirect logic and every screen read the resolved state from
/// here instead of re-querying Supabase each time.
class BusinessSession extends ChangeNotifier {
  BusinessSessionStatus status = BusinessSessionStatus.unknown;
  BusinessAccount? account;

  Future<void> refresh() async {
    status = BusinessSessionStatus.loading;
    notifyListeners();

    if (!BusinessAuthService.instance.isAuthenticated) {
      status = BusinessSessionStatus.signedOut;
      account = null;
      notifyListeners();
      return;
    }

    try {
      final result = await BusinessAccountRepository.instance.fetchMyAccount();
      account = result;
      status = switch (result) {
        null => BusinessSessionStatus.noAccount,
        BusinessAccount(isApproved: true) => BusinessSessionStatus.approved,
        BusinessAccount(isRejected: true) => BusinessSessionStatus.rejected,
        BusinessAccount(isSuspended: true) => BusinessSessionStatus.suspended,
        _ => BusinessSessionStatus.pending,
      };
    } catch (_) {
      status = BusinessSessionStatus.noAccount;
      account = null;
    }
    notifyListeners();
  }

  Future<void> signOut() async {
    await BusinessAuthService.instance.signOut();
    status = BusinessSessionStatus.signedOut;
    account = null;
    notifyListeners();
  }
}
