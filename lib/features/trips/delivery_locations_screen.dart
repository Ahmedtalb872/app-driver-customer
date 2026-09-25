import 'package:flutter/material.dart';

import '../../core/constants/colors.dart';
import '../../l10n/app_localizations.dart';
import '../destinations/data/models/destination_suggestion.dart';
import '../destinations/presentation/destination_map_picker_screen.dart';
import '../destinations/presentation/location_search_field.dart';
import 'delivery_request_screen.dart';

/// Shown after tapping "توصيل طرد" on the home screen - pickup and
/// destination are picked inline, right on this screen, via
/// [LocationSearchField] (same widget [TripPlannerScreen] uses for a normal
/// ride: type to search, or the map icon for a full-screen map picker),
/// instead of navigating through two separate full-screen search pages one
/// after the other. Pre-filled with the GPS-detected pickup point from the
/// home screen but freely changeable here, same as a normal ride's pickup.
class DeliveryLocationsScreen extends StatefulWidget {
  const DeliveryLocationsScreen({
    super.key,
    required this.initialPickupLat,
    required this.initialPickupLng,
    required this.initialPickupAddress,
  });

  final double? initialPickupLat;
  final double? initialPickupLng;
  final String? initialPickupAddress;

  @override
  State<DeliveryLocationsScreen> createState() =>
      _DeliveryLocationsScreenState();
}

class _DeliveryLocationsScreenState extends State<DeliveryLocationsScreen> {
  late double? _pickupLat = widget.initialPickupLat;
  late double? _pickupLng = widget.initialPickupLng;
  late String? _pickupAddress = widget.initialPickupAddress;
  DestinationSuggestion? _destination;

  void _selectPickup(DestinationSuggestion result) {
    setState(() {
      _pickupLat = result.latitude;
      _pickupLng = result.longitude;
      _pickupAddress = result.title;
    });
  }

  void _selectDestination(DestinationSuggestion result) {
    setState(() => _destination = result);
  }

  Future<void> _pickPickupFromMap() async {
    final l10n = AppLocalizations.of(context)!;
    final result = await Navigator.of(context).push<DestinationSuggestion>(
      MaterialPageRoute(
        builder: (context) =>
            DestinationMapPickerScreen(title: l10n.deliveryPickupMapPicker),
      ),
    );
    if (result != null && mounted) _selectPickup(result);
  }

  Future<void> _pickDestinationFromMap() async {
    final l10n = AppLocalizations.of(context)!;
    final result = await Navigator.of(context).push<DestinationSuggestion>(
      MaterialPageRoute(
        builder: (context) =>
            DestinationMapPickerScreen(title: l10n.deliveryDestMapPicker),
      ),
    );
    if (result != null && mounted) _selectDestination(result);
  }

  void _continue() {
    final lat = _pickupLat;
    final lng = _pickupLng;
    final destination = _destination;
    final address = _pickupAddress;
    if (lat == null || lng == null || destination == null || address == null) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DeliveryRequestScreen(
          pickupLat: lat,
          pickupLng: lng,
          pickupAddress: address,
          destination: destination,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.deliveryLocationsTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LocationSearchField(
                  icon: Icons.radio_button_checked_rounded,
                  iconColor: AppColors.success,
                  label: l10n.deliveryPickupFieldLabel,
                  initialText: _pickupAddress,
                  nearLat: _pickupLat,
                  nearLng: _pickupLng,
                  onSelected: _selectPickup,
                  onPickFromMap: _pickPickupFromMap,
                  showCurrentLocation: true,
                ),
                const SizedBox(height: 10),
                LocationSearchField(
                  icon: Icons.location_on_rounded,
                  iconColor: AppColors.error,
                  label: l10n.deliveryDestFieldLabel,
                  initialText: _destination?.title,
                  nearLat: _pickupLat,
                  nearLng: _pickupLng,
                  onSelected: _selectDestination,
                  onPickFromMap: _pickDestinationFromMap,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: (_pickupLat != null && _destination != null)
                      ? _continue
                      : null,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                  child: Text(l10n.continueButton),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
