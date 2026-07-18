import 'package:flutter/foundation.dart';

import '../auth/auth_service.dart';
import '../config/demo_mode_config.dart';
import '../config/supabase_config.dart';
import 'ride_repository.dart';

/// Resolves and holds the signed-in captain's real id/profile/online status,
/// which nothing on the mobile side previously did (see architecture notes -
/// `AppStateProvider` only ever stored a phone string, never a captain_id).
/// Every captain-side real-backend call (incoming requests, accept/ignore,
/// live tracking, ...) needs `captainId`, so this is created once and
/// registered alongside `AppStateProvider` in `main.dart`.
class CaptainSession extends ChangeNotifier {
  String? _captainId;
  String? get captainId => _captainId;

  String? _fullName;
  String? get fullName => _fullName;

  bool _isOnline = false;
  bool get isOnline => _isOnline;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _togglingOnline = false;
  bool get isTogglingOnline => _togglingOnline;

  /// True when the signed-in captain is [DemoModeConfig.alwaysOnlineCaptainPhone]
  /// - the dev/QA trial captain that should never go offline, so testers
  /// don't have to remember to flip it back on after every sign-in. Always
  /// false in release builds (the phone getter is null there).
  bool get _isAlwaysOnlineDemoCaptain {
    final target = DemoModeConfig.alwaysOnlineCaptainPhone;
    if (target == null) return false;
    final phone =
        AuthService.instance.currentUser?.userMetadata?['phone'] as String?;
    return phone == target;
  }

  /// Loads the current captain's id/name/online status from Supabase.
  /// Safe to call repeatedly (e.g. on every captain-home mount); a no-op
  /// while already loading.
  Future<void> refresh() async {
    final uid = AuthService.instance.currentUser?.id;
    if (uid == null) {
      _captainId = null;
      _isOnline = false;
      notifyListeners();
      return;
    }
    if (_isLoading) return;
    _isLoading = true;
    notifyListeners();

    try {
      final row = await SupabaseConfig.client
          .from('captains')
          .select('id, is_online, profiles!inner(full_name)')
          .eq('id', uid)
          .maybeSingle();

      _captainId = uid;
      _isOnline = row?['is_online'] as bool? ?? false;
      final profile = row?['profiles'] as Map<String, dynamic>?;
      _fullName = profile?['full_name'] as String?;

      if (_isAlwaysOnlineDemoCaptain && !_isOnline) {
        // Re-sync the DB row too, since ride matching reads it server-side.
        await RideRepository.instance.setCaptainOnline(true);
        _isOnline = true;
      }
    } catch (_) {
      _captainId = uid;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Persists the online/offline toggle to `captains.is_online` via the
  /// `captain_set_online` RPC. Returns the new state; on failure the local
  /// state is left unchanged and the error is rethrown so the UI can show a
  /// message instead of silently pretending the toggle worked.
  ///
  /// For [_isAlwaysOnlineDemoCaptain], attempts to go offline are silently
  /// ignored - that account stays online during development regardless of
  /// the toggle.
  Future<void> setOnline(bool value) async {
    if (!value && _isAlwaysOnlineDemoCaptain) return;
    if (_togglingOnline) return;
    _togglingOnline = true;
    notifyListeners();
    // TEMP DIAGNOSTIC LOGGING - remove once the online-toggle bug is
    // confirmed fixed in production. Traces every piece of state involved
    // in the captain_set_online round trip.
    final userId = AuthService.instance.currentUser?.id;
    debugPrint(
      '[CaptainSession.setOnline] userId=$userId captainId=$_captainId '
      'current=$_isOnline requested=$value',
    );
    try {
      await RideRepository.instance.setCaptainOnline(value);
      _isOnline = value;
      debugPrint(
        '[CaptainSession.setOnline] success: is_online is now $value in DB',
      );
    } catch (e) {
      debugPrint('[CaptainSession.setOnline] FAILED: ${e.runtimeType}: $e');
      rethrow;
    } finally {
      _togglingOnline = false;
      notifyListeners();
    }
  }

  Future<void> toggleOnline() => setOnline(!_isOnline);

  /// Called on logout: takes the captain offline server-side (best effort)
  /// and clears local session state so the next captain to sign in on this
  /// device starts from a clean slate. Skipped for
  /// [_isAlwaysOnlineDemoCaptain] so it stays online in the DB across
  /// sign-outs too.
  Future<void> clear() async {
    if (_isOnline && !_isAlwaysOnlineDemoCaptain) {
      try {
        await RideRepository.instance.setCaptainOnline(false);
      } catch (_) {
        // Best effort only - signing out proceeds regardless.
      }
    }
    _captainId = null;
    _fullName = null;
    _isOnline = false;
    notifyListeners();
  }
}
