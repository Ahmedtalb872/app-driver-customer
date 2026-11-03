import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../core/services/geocoding_service.dart';
import '../../../core/widgets/real_map_widget.dart';
import '../../core/business_colors.dart';
import '../../repositories/business_account_repository.dart';
import '../../services/business_session.dart';

/// Lets a business set/update the default pickup point (usually their own
/// location) that [BusinessNewRequestScreen] pre-fills every new request
/// with - saves re-pinning the same spot on every single order.
class BusinessSettingsScreen extends StatefulWidget {
  const BusinessSettingsScreen({super.key});

  @override
  State<BusinessSettingsScreen> createState() =>
      _BusinessSettingsScreenState();
}

class _BusinessSettingsScreenState extends State<BusinessSettingsScreen> {
  final _addressController = TextEditingController();
  double? _lat;
  double? _lng;
  Timer? _geocodeDebounce;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final account = context.read<BusinessSession>().account;
    _addressController.text = account?.defaultPickupAddress ?? '';
    _lat = account?.defaultPickupLat;
    _lng = account?.defaultPickupLng;
  }

  @override
  void dispose() {
    _addressController.dispose();
    _geocodeDebounce?.cancel();
    super.dispose();
  }

  void _setPoint(LatLng point) {
    setState(() {
      _lat = point.latitude;
      _lng = point.longitude;
    });
    _geocodeDebounce?.cancel();
    _geocodeDebounce = Timer(const Duration(milliseconds: 700), () async {
      if (_addressController.text.trim().isNotEmpty) return;
      final address = await GeocodingService.instance.reverseGeocode(
        point.latitude,
        point.longitude,
      );
      if (address == null || !mounted) return;
      if (_addressController.text.trim().isNotEmpty) return;
      setState(() => _addressController.text = address);
    });
  }

  Future<void> _save() async {
    if (_lat == null || _lng == null) return;
    setState(() => _saving = true);
    try {
      await BusinessAccountRepository.instance.updateDefaultPickup(
        address: _addressController.text.trim(),
        lat: _lat!,
        lng: _lng!,
      );
      if (!mounted) return;
      await context.read<BusinessSession>().refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ موقع الانطلاق الافتراضي.')),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر الحفظ، حاول مرة أخرى.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = context.watch<BusinessSession>().account;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'الإعدادات',
              style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(account?.businessName ?? '-',
                        style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(account?.typeLabel ?? '-',
                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: BusinessColors.textSecondary)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'موقع الانطلاق الافتراضي',
              style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 4),
            const Text(
              'يُستخدم تلقائياً كنقطة انطلاق كل طلب جديد - عادة موقع مطعمك أو مؤسستك.',
              style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: BusinessColors.textSecondary),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 320,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: RealMapWidget(
                          pickupLat: _lat,
                          pickupLng: _lng,
                          onMapTap: _setPoint,
                          pickupDraggable: true,
                          onPickupDragged: _setPoint,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _addressController,
                      decoration: const InputDecoration(labelText: 'العنوان'),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ElevatedButton(
                        onPressed: (_lat == null || _saving) ? null : _save,
                        child: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('حفظ'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
