import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/constants/colors.dart';
import '../../core/services/new_trip_alert.dart';
import '../../core/widgets/app_logo.dart';

/// Shown once right after login/registration: asks the captain to enable
/// location (needed to show/track trips) and notifications (needed to be
/// alerted about new ride requests). Not a hard gate — "متابعة" always
/// continues to [destination], granted or not.
class PermissionsScreen extends StatefulWidget {
  final Widget destination;
  const PermissionsScreen({super.key, required this.destination});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen>
    with WidgetsBindingObserver {
  PermissionStatus _locationStatus = PermissionStatus.denied;
  PermissionStatus _notificationStatus = PermissionStatus.denied;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshStatuses();
    // Unconditional, not just on the notification button press below: this
    // screen shows on every login (not only first-time onboarding), and a
    // captain who granted the ordinary notification permission on an older
    // app version - before this Android 14+ full-screen-intent permission
    // existed - would otherwise never be asked for it, since the
    // notification card already shows granted and its button never
    // appears. The native call is a no-op if already granted, so this
    // never interrupts a captain who's already set up.
    NewTripAlert.requestFullScreenIntentPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Catches the case where the captain granted the permission from the
    // system Settings screen and came back to the app.
    if (state == AppLifecycleState.resumed) {
      _refreshStatuses();
    }
  }

  Future<void> _refreshStatuses() async {
    final location = await _safeStatus(Permission.locationWhenInUse);
    final notification = await _safeStatus(Permission.notification);
    if (!mounted) return;
    setState(() {
      _locationStatus = location;
      _notificationStatus = notification;
    });
  }

  Future<void> _requestLocation() async {
    final status = await _safeRequest(Permission.locationWhenInUse);
    if (!mounted) return;
    setState(() => _locationStatus = status);
    if (status.isPermanentlyDenied) _showOpenSettingsSnack();
  }

  Future<void> _requestNotification() async {
    final status = await _safeRequest(Permission.notification);
    if (!mounted) return;
    setState(() => _notificationStatus = status);
    if (status.isPermanentlyDenied) _showOpenSettingsSnack();
    // Separate from the notification permission above on Android 14+ -
    // without it, the new-trip alert rings but never actually opens the
    // app on top of the lock screen the way it's supposed to.
    await NewTripAlert.requestFullScreenIntentPermission();
  }

  // Some platforms (e.g. web) don't implement every Permission; fall back to
  // "denied" instead of crashing the screen.
  Future<PermissionStatus> _safeStatus(Permission permission) async {
    try {
      return await permission.status;
    } catch (_) {
      return PermissionStatus.denied;
    }
  }

  Future<PermissionStatus> _safeRequest(Permission permission) async {
    try {
      return await permission.request();
    } catch (_) {
      return PermissionStatus.denied;
    }
  }

  void _showOpenSettingsSnack() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'تم رفض الصلاحية سابقًا، فعّلها يدويًا من إعدادات الهاتف.',
          style: TextStyle(fontFamily: 'Cairo'),
        ),
        action: SnackBarAction(label: 'الإعدادات', onPressed: openAppSettings),
      ),
    );
  }

  void _continue() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => widget.destination),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locationGranted = _locationStatus.isGranted;
    final notificationGranted = _notificationStatus.isGranted;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              const Center(child: AppLogo(width: 88)),
              const SizedBox(height: 24),
              const Text(
                'قبل ما نبدأ...',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkText,
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'فعّل هاتين الصلاحيتين لتحصل على أفضل تجربة ككابتن.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.secondaryText,
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 28),
              _buildPermissionCard(
                icon: Icons.location_on_rounded,
                title: 'تفعيل الموقع',
                description:
                    'لعرض المشاوير القريبة منك وتتبع مسار الرحلة على الخريطة.',
                granted: locationGranted,
                onPressed: _requestLocation,
              ),
              const SizedBox(height: 16),
              _buildPermissionCard(
                icon: Icons.notifications_active_rounded,
                title: 'تفعيل الإشعارات',
                description: 'لتنبيهك فورًا عند وصول طلب مشوار جديد.',
                granted: notificationGranted,
                onPressed: _requestNotification,
              ),
              const Spacer(),
              ElevatedButton(onPressed: _continue, child: const Text('متابعة')),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionCard({
    required IconData icon,
    required String title,
    required String description,
    required bool granted,
    required VoidCallback onPressed,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (granted ? AppColors.success : AppColors.primary)
                  .withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: granted ? AppColors.success : AppColors.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.darkText,
                    fontFamily: 'Cairo',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.secondaryText,
                    fontFamily: 'Cairo',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          granted
              ? const Icon(Icons.check_circle_rounded, color: AppColors.success)
              : SizedBox(
                  width: 76,
                  height: 34,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                    onPressed: onPressed,
                    child: const Text('تفعيل'),
                  ),
                ),
        ],
      ),
    );
  }
}
