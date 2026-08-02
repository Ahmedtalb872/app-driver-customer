import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/services/geocoding_service.dart';
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

  bool _editingRoute = false;
  bool _savingRoute = false;
  late double? _pickupLat;
  late double? _pickupLng;
  late double? _destLat;
  late double? _destLng;
  late final TextEditingController _pickupAddressController;
  late final TextEditingController _destAddressController;
  Timer? _pickupGeocodeDebounce;
  Timer? _destGeocodeDebounce;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController(
      text: widget.trip['admin_notes'] as String? ?? '',
    );
    _pickupLat = (widget.trip['pickup_lat'] as num?)?.toDouble();
    _pickupLng = (widget.trip['pickup_lng'] as num?)?.toDouble();
    _destLat = (widget.trip['destination_lat'] as num?)?.toDouble();
    _destLng = (widget.trip['destination_lng'] as num?)?.toDouble();
    _pickupAddressController = TextEditingController(
      text: widget.trip['pickup_address'] as String? ?? '',
    );
    _destAddressController = TextEditingController(
      text: widget.trip['destination_address'] as String? ?? '',
    );
  }

  @override
  void dispose() {
    _notesController.dispose();
    _pickupAddressController.dispose();
    _destAddressController.dispose();
    _pickupGeocodeDebounce?.cancel();
    _destGeocodeDebounce?.cancel();
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

  /// Correcting a wrong pickup/destination only makes sense before or
  /// during the ride - once it's over, the fare/distance were already
  /// computed against the original points, so editing them retroactively
  /// would be misleading rather than a real fix.
  bool get _canEditRoute => _canCancel;

  bool get _hasDestination => _destLat != null && _destLng != null;

  void _toggleEditRoute() {
    setState(() => _editingRoute = !_editingRoute);
  }

  // Shared by tap-to-place and marker dragging, mirroring
  // OperatorDispatchScreen's pattern - dragging fires this repeatedly while
  // the marker moves, so the actual reverse-geocode network call is
  // debounced to fire once after the admin stops moving it. Unlike that
  // screen (which only ever seeds an empty field), this always overwrites
  // the address text on drag: the whole point of dragging here is
  // correcting a wrong point *and* its address together.
  void _setPickup(LatLng point) {
    setState(() {
      _pickupLat = point.latitude;
      _pickupLng = point.longitude;
    });
    _pickupGeocodeDebounce?.cancel();
    _pickupGeocodeDebounce = Timer(const Duration(milliseconds: 700), () {
      _reverseGeocode(
        lat: point.latitude,
        lng: point.longitude,
        controller: _pickupAddressController,
      );
    });
  }

  void _setDestination(LatLng point) {
    setState(() {
      _destLat = point.latitude;
      _destLng = point.longitude;
    });
    _destGeocodeDebounce?.cancel();
    _destGeocodeDebounce = Timer(const Duration(milliseconds: 700), () {
      _reverseGeocode(
        lat: point.latitude,
        lng: point.longitude,
        controller: _destAddressController,
      );
    });
  }

  Future<void> _reverseGeocode({
    required double lat,
    required double lng,
    required TextEditingController controller,
  }) async {
    final address = await GeocodingService.instance.reverseGeocode(lat, lng);
    if (address == null || !mounted) return;
    controller.text = address;
  }

  Future<void> _saveRoute() async {
    if (_pickupLat == null || _pickupLng == null) return;
    setState(() => _savingRoute = true);
    try {
      await _repository.updateRoute(
        widget.trip['id'] as String,
        pickupAddress: _pickupAddressController.text.trim(),
        pickupLat: _pickupLat!,
        pickupLng: _pickupLng!,
        destinationAddress: _hasDestination
            ? _destAddressController.text.trim()
            : null,
        destinationLat: _hasDestination ? _destLat : null,
        destinationLng: _hasDestination ? _destLng : null,
      );
      widget.onChanged();
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تعذر حفظ التعديل على المسار.',
              style: TextStyle(fontFamily: 'Cairo'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _savingRoute = false);
    }
  }

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
              _buildRouteSection(),
              const SizedBox(height: 16),
              Wrap(
                spacing: 24,
                runSpacing: 12,
                children: [
                  _infoTile(
                    'نوع الطلب',
                    (trip['service_type'] as String?) == 'delivery'
                        ? 'توصيل طرد'
                        : 'مشوار ركاب',
                  ),
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
              if ((trip['service_type'] as String?) == 'delivery') ...[
                const SizedBox(height: 16),
                const Text(
                  'بيانات المستلم',
                  style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 24,
                  runSpacing: 12,
                  children: [
                    _infoTile(
                      'اسم المستلم',
                      trip['recipient_name'] as String? ?? '-',
                    ),
                    _infoTile(
                      'هاتف المستلم',
                      trip['recipient_phone'] as String? ?? '-',
                    ),
                    _infoTile(
                      'وصف الطرد',
                      trip['package_description'] as String? ?? '-',
                    ),
                  ],
                ),
              ],
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

  Widget _buildRouteSection() {
    final hasCoordinates = _pickupLat != null && _pickupLng != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'المسار',
              style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
            ),
            if (_canEditRoute && hasCoordinates)
              TextButton.icon(
                onPressed: _toggleEditRoute,
                icon: Icon(
                  _editingRoute ? Icons.close_rounded : Icons.edit_location_alt_outlined,
                  size: 18,
                ),
                label: Text(_editingRoute ? 'إلغاء التعديل' : 'تعديل المسار'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (hasCoordinates)
          SizedBox(
            height: 220,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: RealMapWidget(
                pickupLat: _pickupLat,
                pickupLng: _pickupLng,
                destLat: _destLat,
                destLng: _destLng,
                showRoute: _hasDestination,
                interactive: _editingRoute,
                pickupDraggable: _editingRoute,
                destDraggable: _editingRoute && _hasDestination,
                onPickupDragged: _editingRoute ? _setPickup : null,
                onDestDragged: _editingRoute && _hasDestination
                    ? _setDestination
                    : null,
              ),
            ),
          )
        else
          const Text(
            'لا توجد إحداثيات مسجّلة لهذه الرحلة.',
            style: TextStyle(fontFamily: 'Cairo', color: AdminColors.textSecondary),
          ),
        const SizedBox(height: 12),
        if (_editingRoute) ...[
          const Text(
            'اسحب العلامة لتصحيح الموقع - العنوان يتحدّث تلقائياً ويمكن تعديله يدوياً.',
            style: TextStyle(
              fontSize: 11,
              fontFamily: 'Cairo',
              color: AdminColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _pickupAddressController,
            decoration: const InputDecoration(labelText: 'نقطة الانطلاق'),
          ),
          if (_hasDestination) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _destAddressController,
              decoration: const InputDecoration(labelText: 'الوجهة'),
            ),
          ],
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _savingRoute ? null : _saveRoute,
            icon: _savingRoute
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined, size: 18),
            label: const Text('حفظ المسار'),
          ),
        ] else ...[
          _infoTile('نقطة الانطلاق', _pickupAddressController.text.isEmpty ? '-' : _pickupAddressController.text),
          const SizedBox(height: 8),
          _infoTile('الوجهة', _destAddressController.text.isEmpty ? '-' : _destAddressController.text),
        ],
      ],
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
