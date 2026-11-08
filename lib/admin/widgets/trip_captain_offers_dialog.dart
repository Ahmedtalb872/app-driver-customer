import 'package:flutter/material.dart';

import '../core/admin_colors.dart';
import '../repositories/admin_trips_repository.dart';
import 'copyable_phone.dart';
import 'status_badge.dart';

/// "كم كابتن يراها": a live eligible-now count plus the persisted
/// per-captain log from `trip_captain_offers` (empty for any trip placed
/// before that table existed - nothing retroactive to show for those).
Future<void> showTripCaptainOffersDialog(
  BuildContext context,
  AdminTripsRepository repository,
  Map<String, dynamic> trip,
) async {
  final tripId = trip['id'] as String;
  final results = await Future.wait([
    repository.countEligibleCaptains(trip),
    repository.loadCaptainOffers(tripId),
  ]);
  final liveCount = results[0] as int;
  final offers = results[1] as List<Map<String, dynamic>>;
  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('الكباتن الذين عُرض عليهم الطلب'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$liveCount كابتن متصل حالياً مؤهل لرؤية هذا الطلب (عدد حي الآن).',
              style: const TextStyle(fontFamily: 'Tajawal'),
            ),
            const SizedBox(height: 16),
            const Text(
              'سجل من عُرض عليه الطلب فعلياً وقت إرساله:',
              style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (offers.isEmpty)
              const Text(
                'لا توجد بيانات مسجلة لهذا الطلب - إما أنه طُلب قبل تفعيل '
                'هذه الميزة، أو لم يكن أي كابتن متصل ومؤهل في تلك اللحظة.',
                style: TextStyle(fontFamily: 'Tajawal', color: AdminColors.textSecondary),
              )
            else
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: offers.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final offer = offers[index];
                      final profile =
                          offer['captains']?['profiles'] as Map<String, dynamic>?;
                      final name = (profile?['full_name'] as String?) ?? '-';
                      final phone = profile?['phone'] as String?;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(fontFamily: 'Tajawal'),
                                  ),
                                  CopyablePhone(phone),
                                ],
                              ),
                            ),
                            _offerStatusBadge(offer['status'] as String?),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('حسناً'),
        ),
      ],
    ),
  );
}

Widget _offerStatusBadge(String? status) {
  switch (status) {
    case 'accepted':
      return StatusBadge.success('قَبِله');
    case 'missed':
      return StatusBadge.error('فاتته');
    default:
      return StatusBadge.warning('عُرض عليه');
  }
}
