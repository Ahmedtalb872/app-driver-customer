import 'package:flutter/material.dart';

import '../../core/constants/colors.dart';
import '../../models/models.dart';
import '../destinations/data/models/destination_suggestion.dart';
import '../destinations/presentation/destination_map_picker_screen.dart';
import '../destinations/presentation/location_search_field.dart';
import 'request_ride_screen.dart';
import 'voice_ride_request_sheet.dart';

/// Shown after tapping "إلى أين تريد الذهاب؟" on the home screen - two
/// independent sections, one per [TripType]: a normal ride needs both a
/// pickup and a destination point, an open ride only a pickup. Each point
/// is picked inline, right on this screen, via [LocationSearchField] (type
/// to search, or the map icon for a full-screen map picker), pre-filled
/// with the GPS location detected on the home screen but freely changeable
/// here. A normal ride can also fill both points at once by speaking them
/// together - see [VoiceRideRequestSheet] - since there's a well-formed "من
/// X إلى Y" sentence to parse.
class TripPlannerScreen extends StatefulWidget {
  const TripPlannerScreen({
    super.key,
    required this.initialPickupLat,
    required this.initialPickupLng,
    required this.initialPickupAddress,
  });

  final double? initialPickupLat;
  final double? initialPickupLng;
  final String initialPickupAddress;

  @override
  State<TripPlannerScreen> createState() => _TripPlannerScreenState();
}

class _TripPlannerScreenState extends State<TripPlannerScreen> {
  late double? _normalPickupLat = widget.initialPickupLat;
  late double? _normalPickupLng = widget.initialPickupLng;
  late String? _normalPickupAddress = widget.initialPickupLat == null
      ? null
      : widget.initialPickupAddress;
  DestinationSuggestion? _normalDestination;

  late double? _openPickupLat = widget.initialPickupLat;
  late double? _openPickupLng = widget.initialPickupLng;
  late String? _openPickupAddress = widget.initialPickupLat == null
      ? null
      : widget.initialPickupAddress;

  void _selectNormalPickup(DestinationSuggestion result) {
    setState(() {
      _normalPickupLat = result.latitude;
      _normalPickupLng = result.longitude;
      _normalPickupAddress = result.title;
    });
  }

  void _selectNormalDestination(DestinationSuggestion result) {
    setState(() => _normalDestination = result);
  }

  void _selectOpenPickup(DestinationSuggestion result) {
    setState(() {
      _openPickupLat = result.latitude;
      _openPickupLng = result.longitude;
      _openPickupAddress = result.title;
    });
  }

  Future<void> _pickNormalPickupFromMap() async {
    final result = await Navigator.of(context).push<DestinationSuggestion>(
      MaterialPageRoute(
        builder: (context) =>
            const DestinationMapPickerScreen(title: 'اختر نقطة الانطلاق من الخريطة'),
      ),
    );
    if (result != null && mounted) _selectNormalPickup(result);
  }

  Future<void> _pickNormalDestinationFromMap() async {
    final result = await Navigator.of(context).push<DestinationSuggestion>(
      MaterialPageRoute(
        builder: (context) =>
            const DestinationMapPickerScreen(title: 'اختر الوجهة من الخريطة'),
      ),
    );
    if (result != null && mounted) _selectNormalDestination(result);
  }

  Future<void> _pickOpenPickupFromMap() async {
    final result = await Navigator.of(context).push<DestinationSuggestion>(
      MaterialPageRoute(
        builder: (context) =>
            const DestinationMapPickerScreen(title: 'اختر نقطة الانطلاق من الخريطة'),
      ),
    );
    if (result != null && mounted) _selectOpenPickup(result);
  }

  /// Lets the customer say pickup and destination in one sentence instead
  /// of picking each separately - see [VoiceRideRequestSheet]. Only offered
  /// for a normal ride (it needs both points; an open ride only ever has a
  /// pickup, so the two-part "من X إلى Y" phrasing wouldn't fit).
  ///
  /// Goes straight on to [RequestRideScreen] (same as tapping "متابعة" would)
  /// once the sheet confirms - the customer already reviewed and, if
  /// needed, corrected both points inside the sheet itself, so a second,
  /// separate confirmation tap here would just repeat that same review for
  /// no reason and delay seeing the actual trip price.
  Future<void> _requestNormalByVoice() async {
    final result = await showModalBottomSheet<
        ({DestinationSuggestion pickup, DestinationSuggestion destination})?>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => VoiceRideRequestSheet(
        nearLat: _normalPickupLat,
        nearLng: _normalPickupLng,
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _normalPickupLat = result.pickup.latitude;
      _normalPickupLng = result.pickup.longitude;
      _normalPickupAddress = result.pickup.title;
      _normalDestination = result.destination;
    });
    _continueNormal();
  }

  void _continueNormal() {
    final lat = _normalPickupLat;
    final lng = _normalPickupLng;
    final destination = _normalDestination;
    if (lat == null || lng == null || destination == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => RequestRideScreen(
          pickupLat: lat,
          pickupLng: lng,
          pickupAddress: _normalPickupAddress ?? destination.title,
          destination: destination,
          tripType: TripType.normal,
        ),
      ),
    );
  }

  void _continueOpen() {
    final lat = _openPickupLat;
    final lng = _openPickupLng;
    if (lat == null || lng == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => RequestRideScreen(
          pickupLat: lat,
          pickupLng: lng,
          pickupAddress: _openPickupAddress ?? 'موقعي الحالي',
          tripType: TripType.open,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('إلى أين تريد الذهاب؟'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection(
            icon: Icons.route_rounded,
            color: AppColors.primary,
            title: 'مشوار عادي',
            subtitle: 'تحدد نقطة الانطلاق والوجهة',
            children: [
              OutlinedButton.icon(
                onPressed: _requestNormalByVoice,
                icon: const Icon(Icons.mic_rounded, size: 18),
                label: const Text('اطلب بالصوت'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 44),
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                ),
              ),
              const SizedBox(height: 14),
              LocationSearchField(
                icon: Icons.radio_button_checked_rounded,
                iconColor: AppColors.success,
                label: 'نقطة الانطلاق',
                initialText: _normalPickupAddress,
                nearLat: _normalPickupLat,
                nearLng: _normalPickupLng,
                onSelected: _selectNormalPickup,
                onPickFromMap: _pickNormalPickupFromMap,
                showCurrentLocation: true,
              ),
              const SizedBox(height: 10),
              LocationSearchField(
                icon: Icons.location_on_rounded,
                iconColor: AppColors.error,
                label: 'نقطة الوصول',
                initialText: _normalDestination?.title,
                nearLat: _normalPickupLat,
                nearLng: _normalPickupLng,
                onSelected: _selectNormalDestination,
                onPickFromMap: _pickNormalDestinationFromMap,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed:
                    (_normalPickupLat != null && _normalDestination != null)
                    ? _continueNormal
                    : null,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: const Text('متابعة'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildSection(
            icon: Icons.timelapse_rounded,
            color: AppColors.accent,
            title: 'مشوار مفتوح',
            subtitle: 'بدون وجهة محددة - السائق تحت تصرفك، تحدد نقطة الانطلاق فقط',
            children: [
              LocationSearchField(
                icon: Icons.radio_button_checked_rounded,
                iconColor: AppColors.success,
                label: 'نقطة الانطلاق',
                initialText: _openPickupAddress,
                nearLat: _openPickupLat,
                nearLng: _openPickupLng,
                onSelected: _selectOpenPickup,
                onPickFromMap: _pickOpenPickupFromMap,
                showCurrentLocation: true,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _openPickupLat != null ? _continueOpen : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: const Text('متابعة'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColors.darkText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}
