import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/geocoding_service.dart';
import '../../../core/services/ride_repository.dart';
import '../../../core/services/route_estimator.dart';
import '../../../core/widgets/real_map_widget.dart';
import '../../../models/models.dart';
import '../../core/business_colors.dart';
import '../../services/business_session.dart';

enum _TapMode { pickup, destination }

/// The business portal's "طلب مشوار جديد" - the restaurant/institution
/// places the trip on a customer's behalf. Reuses
/// [RideRepository.requestTrip] directly, exactly as the mobile customer
/// app does: the signed-in business account already *is* the trip's
/// customer_id (see the migration's own comment for why), so no separate
/// dispatch RPC or customer lookup is needed here, unlike the admin
/// operator-dispatch screen this is modeled on.
class BusinessNewRequestScreen extends StatefulWidget {
  const BusinessNewRequestScreen({super.key});

  @override
  State<BusinessNewRequestScreen> createState() =>
      _BusinessNewRequestScreenState();
}

class _BusinessNewRequestScreenState extends State<BusinessNewRequestScreen> {
  final _pickupAddressController = TextEditingController();
  final _destAddressController = TextEditingController();
  final _recipientNameController = TextEditingController();
  final _recipientPhoneController = TextEditingController();
  final _packageDescriptionController = TextEditingController();
  final _noteController = TextEditingController();

  Timer? _pickupGeocodeDebounce;
  Timer? _destGeocodeDebounce;

  String _serviceType = 'delivery'; // 'delivery' | 'ride'
  _TapMode _tapMode = _TapMode.pickup;
  String _vehicleType = 'economy';

  double? _pickupLat;
  double? _pickupLng;
  double? _destLat;
  double? _destLng;

  Map<String, dynamic>? _pricing;
  bool _loadingPricing = false;
  bool _sending = false;

  static const _vehicleLabels = {
    'economy': 'اقتصادية',
    'comfort': 'مريحة',
    'family': 'عائلية',
  };

  String get _effectiveVehicleType =>
      _serviceType == 'delivery' ? 'motorcycle' : _vehicleType;

  static const _routeEstimator = HaversineRouteEstimator();

  @override
  void initState() {
    super.initState();
    final account = context.read<BusinessSession>().account;
    if (account?.defaultPickupAddress != null) {
      _pickupAddressController.text = account!.defaultPickupAddress!;
      _pickupLat = account.defaultPickupLat;
      _pickupLng = account.defaultPickupLng;
    }
    _loadPricing();
  }

  @override
  void dispose() {
    _pickupAddressController.dispose();
    _destAddressController.dispose();
    _recipientNameController.dispose();
    _recipientPhoneController.dispose();
    _packageDescriptionController.dispose();
    _noteController.dispose();
    _pickupGeocodeDebounce?.cancel();
    _destGeocodeDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadPricing() async {
    setState(() => _loadingPricing = true);
    try {
      _pricing = await RideRepository.instance.fetchPricingConfig(
        _effectiveVehicleType,
      );
    } catch (_) {
      _pricing = null;
    } finally {
      if (mounted) setState(() => _loadingPricing = false);
    }
  }

  RouteEstimate? get _routeEstimate {
    if (_pickupLat == null || _pickupLng == null) return null;
    if (_destLat == null || _destLng == null) return null;
    return _routeEstimator.estimate(
      pickup: LatLng(_pickupLat!, _pickupLng!),
      destination: LatLng(_destLat!, _destLng!),
    );
  }

  double? get _estimatedFare {
    final pricing = _pricing;
    final km = _routeEstimate?.distanceKm;
    if (pricing == null || km == null) return null;
    final baseFare = (pricing['base_fare'] as num?)?.toDouble() ?? 0;
    final minimumFare = (pricing['minimum_fare'] as num?)?.toDouble() ?? 0;
    final pricePerKm = (pricing['price_per_km'] as num?)?.toDouble() ?? 0;
    final baseDistanceKm =
        (pricing['base_distance_km'] as num?)?.toDouble() ?? 0;
    final billableKm = km > baseDistanceKm ? km - baseDistanceKm : 0;
    final subtotal = baseFare + (billableKm * pricePerKm);
    return subtotal < minimumFare ? minimumFare : subtotal;
  }

  void _handleMapTap(LatLng point) {
    if (_tapMode == _TapMode.pickup) {
      _setPickup(point);
    } else {
      _setDestination(point);
    }
  }

  void _setPickup(LatLng point) {
    setState(() {
      _pickupLat = point.latitude;
      _pickupLng = point.longitude;
    });
    _pickupGeocodeDebounce?.cancel();
    _pickupGeocodeDebounce = Timer(const Duration(milliseconds: 700), () {
      _maybeReverseGeocode(
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
      _maybeReverseGeocode(
        lat: point.latitude,
        lng: point.longitude,
        controller: _destAddressController,
      );
    });
  }

  Future<void> _maybeReverseGeocode({
    required double lat,
    required double lng,
    required TextEditingController controller,
  }) async {
    if (controller.text.trim().isNotEmpty) return;
    final address = await GeocodingService.instance.reverseGeocode(lat, lng);
    if (address == null || !mounted) return;
    if (controller.text.trim().isNotEmpty) return;
    setState(() => controller.text = address);
  }

  List<String> get _validationMessages {
    final messages = <String>[];
    if (_pickupLat == null || _pickupLng == null) {
      messages.add('حدد نقطة الانطلاق على الخريطة');
    }
    if (_destLat == null || _destLng == null) {
      messages.add(
        _serviceType == 'delivery'
            ? 'حدد نقطة تسليم الطرد على الخريطة'
            : 'حدد الوجهة على الخريطة',
      );
    }
    if (_serviceType == 'delivery') {
      if (_recipientNameController.text.trim().isEmpty) {
        messages.add('أدخل اسم الزبون المستلم');
      }
      final digits = _recipientPhoneController.text.trim();
      if (digits.isEmpty) {
        messages.add('أدخل رقم هاتف الزبون المستلم');
      } else if (digits.length != 8) {
        messages.add('رقم هاتف المستلم يجب أن يتكون من 8 أرقام');
      }
    }
    return messages;
  }

  bool get _canSend => !_sending && _validationMessages.isEmpty;

  Future<void> _submit() async {
    if (!_canSend) return;
    setState(() => _sending = true);
    try {
      await RideRepository.instance.requestTrip(
        pickupAddress: _pickupAddressController.text.trim().isEmpty
            ? 'نقطة الانطلاق (محددة على الخريطة)'
            : _pickupAddressController.text.trim(),
        pickupLat: _pickupLat!,
        pickupLng: _pickupLng!,
        tripType: TripType.normal,
        destinationAddress: _destAddressController.text.trim().isEmpty
            ? 'الوجهة (محددة على الخريطة)'
            : _destAddressController.text.trim(),
        destinationLat: _destLat,
        destinationLng: _destLng,
        vehicleType: VehicleType.values.firstWhere(
          (v) => v.name == _vehicleType,
          orElse: () => VehicleType.economy,
        ),
        paymentMethod: 'نقداً',
        paymentMethodCode: 'cash',
        serviceType: _serviceType,
        recipientName: _serviceType == 'delivery'
            ? _recipientNameController.text.trim()
            : null,
        recipientPhone: _serviceType == 'delivery'
            ? '+222${_recipientPhoneController.text.trim()}'
            : null,
        packageDescription: _serviceType == 'delivery'
            ? (_packageDescriptionController.text.trim().isEmpty
                  ? null
                  : _packageDescriptionController.text.trim())
            : null,
        customerNote: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _serviceType == 'delivery'
                ? 'تم إرسال طلب التوصيل للكباتن المتصلين بنجاح'
                : 'تم إرسال المشوار للكباتن المتصلين بنجاح',
          ),
          backgroundColor: BusinessColors.success,
        ),
      );
      if (mounted) context.go('/business/requests');
    } on PostgrestException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر إرسال الطلب: ${e.message}'),
            backgroundColor: BusinessColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر إرسال الطلب: $e'),
            backgroundColor: BusinessColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 900;
          final map = _buildMapCard();
          final form = _buildFormCard();
          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: map),
                const SizedBox(width: 20),
                SizedBox(width: 380, child: form),
              ],
            );
          }
          return SingleChildScrollView(
            child: Column(children: [map, const SizedBox(height: 20), form]),
          );
        },
      ),
    );
  }

  Widget _buildMapCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'تحديد الموقع على الخريطة',
              style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            SegmentedButton<_TapMode>(
              segments: [
                const ButtonSegment(
                  value: _TapMode.pickup,
                  label: Text('نقرة = نقطة الانطلاق', style: TextStyle(fontFamily: 'Cairo')),
                  icon: Icon(Icons.radio_button_checked_rounded, color: BusinessColors.success),
                ),
                ButtonSegment(
                  value: _TapMode.destination,
                  label: Text(
                    _serviceType == 'delivery' ? 'نقرة = نقطة التسليم' : 'نقرة = الوجهة',
                    style: const TextStyle(fontFamily: 'Cairo'),
                  ),
                  icon: const Icon(Icons.location_on_rounded, color: BusinessColors.error),
                ),
              ],
              selected: {_tapMode},
              onSelectionChanged: (selection) => setState(() => _tapMode = selection.first),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 460,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: RealMapWidget(
                  pickupLat: _pickupLat,
                  pickupLng: _pickupLng,
                  destLat: _destLat,
                  destLng: _destLng,
                  showRoute: true,
                  onMapTap: _handleMapTap,
                  pickupDraggable: true,
                  destDraggable: true,
                  onPickupDragged: _setPickup,
                  onDestDragged: _setDestination,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _serviceType == 'delivery' ? 'بيانات طلب التوصيل' : 'بيانات المشوار',
                style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 16),
              const Text('نوع الطلب', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 6),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'delivery',
                    label: Text('توصيل طرد لزبون', style: TextStyle(fontFamily: 'Cairo')),
                    icon: Icon(Icons.two_wheeler_rounded),
                  ),
                  ButtonSegment(
                    value: 'ride',
                    label: Text('مشوار لزبون', style: TextStyle(fontFamily: 'Cairo')),
                    icon: Icon(Icons.local_taxi_rounded),
                  ),
                ],
                selected: {_serviceType},
                onSelectionChanged: (selection) => setState(() {
                  _serviceType = selection.first;
                  _loadPricing();
                }),
              ),
              const SizedBox(height: 18),
              const Text('عنوان نقطة الانطلاق', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 6),
              TextField(
                controller: _pickupAddressController,
                decoration: const InputDecoration(isDense: true, hintText: 'مثال: مطعمكم', border: OutlineInputBorder()),
              ),
              _buildCoordinatesLabel(_pickupLat, _pickupLng),
              const SizedBox(height: 14),
              Text(
                _serviceType == 'delivery' ? 'عنوان نقطة التسليم' : 'عنوان الوجهة',
                style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _destAddressController,
                decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
              ),
              _buildCoordinatesLabel(_destLat, _destLng),
              if (_serviceType == 'delivery') ...[
                const SizedBox(height: 18),
                const Text('بيانات الزبون المستلم', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 6),
                TextField(
                  controller: _recipientNameController,
                  decoration: const InputDecoration(isDense: true, hintText: 'اسم الزبون', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _recipientPhoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(8),
                  ],
                  decoration: const InputDecoration(
                    isDense: true,
                    prefixText: '+222 ',
                    hintText: 'هاتف الزبون (XXXXXXXX)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _packageDescriptionController,
                  maxLines: 2,
                  decoration: const InputDecoration(isDense: true, hintText: 'وصف الطلب (اختياري)', border: OutlineInputBorder()),
                ),
              ] else ...[
                const SizedBox(height: 18),
                const Text('نوع السيارة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: _vehicleLabels.entries.map((entry) {
                    final selected = _vehicleType == entry.key;
                    return ChoiceChip(
                      label: Text(entry.value, style: const TextStyle(fontFamily: 'Cairo')),
                      selected: selected,
                      onSelected: (_) {
                        setState(() => _vehicleType = entry.key);
                        _loadPricing();
                      },
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 14),
              const Text('ملاحظة (اختياري)', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 6),
              TextField(
                controller: _noteController,
                maxLines: 2,
                decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
              ),
              const SizedBox(height: 20),
              _buildEstimateCard(),
              const SizedBox(height: 16),
              _buildValidationSummary(),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _canSend ? _submit : null,
                  icon: _sending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(
                    _serviceType == 'delivery' ? 'إرسال طلب التوصيل' : 'إرسال المشوار',
                    style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: BusinessColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildValidationSummary() {
    final messages = _validationMessages;
    if (messages.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: BusinessColors.success.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: BusinessColors.success, size: 16),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'جميع البيانات مكتملة، جاهز للإرسال',
                style: TextStyle(fontFamily: 'Cairo', fontSize: 11.5, fontWeight: FontWeight.bold, color: BusinessColors.success),
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: BusinessColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: BusinessColors.warning, size: 16),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'لإرسال الطلب، أكمل ما يلي:',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 11.5, fontWeight: FontWeight.bold, color: BusinessColors.textPrimary),
                ),
              ),
            ],
          ),
          for (final message in messages)
            Padding(
              padding: const EdgeInsets.only(top: 4, right: 24),
              child: Text(
                '• $message',
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: BusinessColors.textSecondary),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCoordinatesLabel(double? lat, double? lng) {
    if (lat == null || lng == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        'الإحداثيات: ${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
        style: const TextStyle(fontFamily: 'Cairo', fontSize: 10.5, color: BusinessColors.textSecondary),
      ),
    );
  }

  Widget _buildEstimateCard() {
    final fare = _estimatedFare;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BusinessColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('الأجرة المقدرة', style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: BusinessColors.textSecondary)),
          const SizedBox(height: 4),
          if (_loadingPricing)
            const Text('...', style: TextStyle(fontFamily: 'Cairo'))
          else
            Text(
              fare != null ? '${fare.toStringAsFixed(0)} أوقية' : 'حدد نقطة الانطلاق والوجهة',
              style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18, color: BusinessColors.primary),
            ),
          if (_routeEstimate != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '* تقدير بخط مستقيم: ${_routeEstimate!.distanceKm.toStringAsFixed(1)} كم • '
                '${_routeEstimate!.durationMinutes} د تقريباً',
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 10.5, color: BusinessColors.textSecondary, fontStyle: FontStyle.italic),
              ),
            ),
        ],
      ),
    );
  }
}
