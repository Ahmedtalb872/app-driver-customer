import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/colors.dart';

/// Lets the captain choose between the device's regular phone dialer and
/// the in-app WebRTC call (see call_service.dart) before either call
/// button (CaptainActiveTripScreen and OpenRideActiveScreen) actually
/// places a call - requested explicitly instead of the in-app call
/// silently replacing the old PhoneCaller behavior.
Future<void> showCallOptionsSheet(
  BuildContext context, {
  required String? phone,
  required VoidCallback onInAppCall,
}) {
  return showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.call_rounded, color: AppColors.primary),
            title: const Text(
              'مكالمة عادية',
              style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
            ),
            subtitle: const Text(
              'عبر شبكة الهاتف',
              style: TextStyle(fontFamily: 'Cairo', fontSize: 11),
            ),
            onTap: () {
              Navigator.of(context).pop();
              _callRegular(phone);
            },
          ),
          ListTile(
            leading: const Icon(Icons.wifi_calling_3_rounded, color: AppColors.accent),
            title: const Text(
              'مكالمة داخل التطبيق',
              style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
            ),
            subtitle: const Text(
              'عبر الإنترنت، دون كشف رقم الهاتف',
              style: TextStyle(fontFamily: 'Cairo', fontSize: 11),
            ),
            onTap: () {
              Navigator.of(context).pop();
              onInAppCall();
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

Future<void> _callRegular(String? phone) async {
  if (phone == null || phone.isEmpty) return;
  final uri = Uri(scheme: 'tel', path: phone);
  if (await canLaunchUrl(uri)) await launchUrl(uri);
}
