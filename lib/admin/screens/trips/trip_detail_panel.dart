import 'package:flutter/material.dart';

import '../../../core/widgets/real_map_widget.dart';
import '../../core/admin_colors.dart';
import '../../repositories/admin_trips_repository.dart';
import '../../widgets/captain_picker_dialog.dart';
import '../../widgets/confirm_dialog.dart';

class TripDetailPanel extends StatefulWidget {
  final Map<String, dynamic> trip;
  final VoidCallback onChanged;

  const TripDetailPanel({
    super.key,
    required this.trip,
    required this.onChanged,
  });

  @override
  State<TripDetailPanel> createState() => _TripDetailPanelState();
}

class _TripDetailPanelState extends State<TripDetailPanel> {
  final _repository = AdminTripsRepository();
  late final TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController(
      text: widget.trip['admin_notes'] as String? ?? '',
    );
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  static const _assignableStatuses = [
    'searching',
    'accepted',
    'arrived',
    'in_progress',
  ];

  bool get _canCancel {
    final status = widget.trip['status'] as String?;
    return status != null &&
        status != 'completed' &&
        status != 'cancelled' &&
        status != 'expired';
  }

  bool get _canAssign =>
      _assignableStatuses.contains(widget.trip['status'] as String?);

  bool get _canBoard => (widget.trip['status'] as String?) == 'arrived';

  /// The `customers` join is only present when this panel was opened from
  /// a screen that fetched it (Live Operations); when opened from the plain
  /// trips list, or when the trip has no registered customer account at all
  /// (20260718000040_guest_dispatch_trip.sql), fall back to the phone
  /// number the dispatch operator typed - always present as a plain column
  /// either way.
  String get _customerLabel {
    final customer =
        widget.trip['customers']?['profiles'] as Map<String, dynamic>?;
    final name = customer?['full_name'] as String?;
    if (name != null && name.trim().isNotEmpty) return name;
    final guestPhone = widget.trip['guest_customer_phone'] as String?;
    if (guestPhone != null && guestPhone.trim().isNotEmpty) {
      return '$guestPhone (غير مسجل)';
    }
    return '-';
  }

  Future<void> _saveNotes() async {
    await _repository.updateAdminNotes(
      widget.trip['id'] as String,
      _notesController.text.trim(),
    );
    widget.onChanged();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _cancelTrip() async {
    final reason = await showReasonDialog(
      context,
      title: 'سبب إلغاء الرحلة (إلزامي)',
    );
    if (reason == null) return;
    try {
      await _repository.cancel(widget.trip['id'] as String, reason);
      widget.onChanged();
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تعذر إلغاء الرحلة.',
              style: TextStyle(fontFamily: 'Cairo'),
            ),
          ),
        );
      }
    }
  }

  bool _boarding = false;

  Future<void> _boardTrip() async {
    if (_boarding) return;
    setState(() => _boarding = true);
    try {
      await _repository.boardTrip(widget.trip['id'] as String);
      widget.onChanged();
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تعذر بدء الرحلة.',
              style: TextStyle(fontFamily: 'Cairo'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _boarding = false);
    }
  }

  Future<void> _assignCaptain() async {
    final captainId = await showCaptainPickerDialog(
      context,
      currentCaptainId: widget.trip['captain_id'] as String?,
    );
    if (captainId == null) return;
    try {
      await _repository.assignCaptain(widget.trip['id'] as String, captainId);
      widget.onChanged();
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تعذر تعيين الكابتن.',
              style: TextStyle(fontFamily: 'Cairo'),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    final pickupLat = (trip['pickup_lat'] as num?)?.toDouble();
    final pickupLng = (trip['pickup_lng'] as num?)?.toDouble();
    final destLat = (trip['destination_lat'] as num?)?.toDouble();
    final destLng = (trip['destination_lng'] as num?)?.toDouble();
    final hasCoordinates = pickupLat != null && pickupLng != null;

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AdminColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'رحلة #${(trip['id'] as String).substring(0, 8)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 16),
              if (hasCoordinates)
                SizedBox(
                  height: 220,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: RealMapWidget(
                      pickupLat: pickupLat,
                      pickupLng: pickupLng,
                      destLat: destLat,
                      destLng: destLng,
                      showRoute: destLat != null,
                      interactive: false,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 24,
                runSpacing: 12,
                children: [
                  _infoTile('الزبون', _customerLabel),
                  _infoTile('الحالة', trip['status'] as String? ?? '-'),
                  _infoTile(
                    'طريقة الدفع',
                    trip['payment_method'] as String? ?? '-',
                  ),
                  _infoTile('المسافة', '${trip['distance_km'] ?? '-'} كم'),
                  _infoTile(
                    'المدة المقدرة',
                    '${trip['estimated_duration_minutes'] ?? '-'} د',
                  ),
                  _infoTile(
                    'المدة الفعلية',
                    '${trip['actual_duration_minutes'] ?? '-'} د',
                  ),
                  _infoTile(
                    'السعر المقدر',
                    '${trip['estimated_price'] ?? '-'}',
                  ),
                  _infoTile('السعر النهائي', '${trip['final_price'] ?? '-'}'),
                  _infoTile('العمولة', '${trip['commission_amount'] ?? '-'}'),
                  _infoTile(
                    'صافي أرباح الكابتن',
                    '${trip['captain_net_earnings'] ?? '-'}',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _infoTile(
                'نقطة الانطلاق',
                trip['pickup_address'] as String? ?? '-',
              ),
              const SizedBox(height: 8),
              _infoTile(
                'الوجهة',
                trip['destination_address'] as String? ?? '-',
              ),
              if (trip['cancellation_reason'] != null) ...[
                const SizedBox(height: 8),
                _infoTile('سبب الإلغاء', trip['cancellation_reason'] as String),
              ],
              const SizedBox(height: 24),
              const Text(
                'ملاحظات إدارية',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(hintText: 'أضف ملاحظة...'),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  ElevatedButton(
                    onPressed: _saveNotes,
                    child: const Text('حفظ الملاحظة'),
                  ),
                  if (_canAssign)
                    OutlinedButton.icon(
                      onPressed: _assignCaptain,
                      icon: const Icon(Icons.person_pin_circle_outlined),
                      label: const Text('تعيين / إعادة تعيين كابتن'),
                    ),
                  if (_canBoard)
                    OutlinedButton.icon(
                      onPressed: _boarding ? null : _boardTrip,
                      icon: const Icon(Icons.play_circle_outline),
                      label: const Text('بدء الرحلة (ركوب الراكب)'),
                    ),
                  if (_canCancel)
                    OutlinedButton.icon(
                      onPressed: _cancelTrip,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AdminColors.error,
                      ),
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('إلغاء الرحلة'),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _infoTile(String label, String value) {
    return SizedBox(
      width: 160,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AdminColors.textSecondary,
              fontFamily: 'Cairo',
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              fontFamily: 'Cairo',
            ),
          ),
        ],
      ),
    );
  }
}
