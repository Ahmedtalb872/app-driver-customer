import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/constants/colors.dart';
import '../../core/services/geocoding_service.dart';
import '../../models/models.dart';
import '../destinations/data/models/destination_suggestion.dart';
import '../destinations/data/repositories/destination_search_repository.dart';
import '../destinations/presentation/destination_map_picker_screen.dart';
import 'request_ride_screen.dart';
import 'voice_ride_request_sheet.dart';

/// Shown after tapping "إلى أين تريد الذهاب؟" on the home screen - two
/// independent sections, one per [TripType]: a normal ride needs both a
/// pickup and a destination point, an open ride only a pickup. Each point
/// is picked inline, right on this screen, via [_LocationSearchField] (type
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
              _LocationSearchField(
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
              _LocationSearchField(
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
              _LocationSearchField(
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

/// A pickup/destination field you type directly into, right on
/// [TripPlannerScreen] - no navigating to a separate screen just to search.
/// Debounced live search as you type, plus an explicit "بحث" button for an
/// immediate search, both backed by the same [DestinationSearchRepository]
/// [DestinationSearchScreen] itself uses (this app's own places/districts/
/// neighborhoods merged with Google Places). The map icon still opens
/// [DestinationMapPickerScreen] directly as a fallback for picking a point
/// with no name to search for.
class _LocationSearchField extends StatefulWidget {
  const _LocationSearchField({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onSelected,
    required this.onPickFromMap,
    this.initialText,
    this.nearLat,
    this.nearLng,
    this.showCurrentLocation = false,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String? initialText;
  final double? nearLat;
  final double? nearLng;
  final ValueChanged<DestinationSuggestion> onSelected;
  final VoidCallback onPickFromMap;

  /// Shows an extra "استخدام موقعي الحالي" button that fetches a fresh GPS
  /// fix and fills the field with it directly - a pickup point (unlike a
  /// destination) is overwhelmingly "right where the customer is standing",
  /// so it shouldn't require typing/searching at all. Off by default;
  /// pickup fields turn it on explicitly.
  final bool showCurrentLocation;

  @override
  State<_LocationSearchField> createState() => _LocationSearchFieldState();
}

class _LocationSearchFieldState extends State<_LocationSearchField> {
  final _repository = DestinationSearchRepository();
  late final _controller = TextEditingController(text: widget.initialText ?? '');
  Timer? _debounce;
  List<DestinationSuggestion> _options = [];
  bool _searching = false;
  bool _searched = false;
  bool _locating = false;

  @override
  void didUpdateWidget(covariant _LocationSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Keeps the field in sync when a point is set some other way (voice
    // request, map picker) while this field isn't the one driving the
    // change - e.g. picking the destination from the map still needs the
    // pickup field's already-typed text left alone, but a fresh
    // initialText (voice sheet filling both at once) must actually show.
    if (widget.initialText != oldWidget.initialText &&
        widget.initialText != _controller.text) {
      _controller.text = widget.initialText ?? '';
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 2) {
      setState(() {
        _options = [];
        _searched = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _runSearch(value));
  }

  Future<void> _runSearch(String query) async {
    if (query.trim().length < 2) return;
    _debounce?.cancel();
    setState(() => _searching = true);
    try {
      final results = await _repository.search(
        query: query,
        nearLat: widget.nearLat,
        nearLng: widget.nearLng,
      );
      if (!mounted) return;
      setState(() {
        _options = results;
        _searching = false;
        _searched = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _options = [];
        _searching = false;
        _searched = true;
      });
    }
  }

  void _select(DestinationSuggestion suggestion) {
    _controller.text = suggestion.title;
    setState(() {
      _options = [];
      _searched = false;
    });
    FocusScope.of(context).unfocus();
    widget.onSelected(suggestion);
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      final address = await GeocodingService.instance.reverseGeocode(
        position.latitude,
        position.longitude,
      );
      if (!mounted) return;
      _select(
        DestinationSuggestion(
          resultType: DestinationResultType.place,
          id: 'current_location',
          title: address ?? 'موقعي الحالي',
          latitude: position.latitude,
          longitude: position.longitude,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تعذر تحديد موقعك الحالي - تحقق من تفعيل خدمة الموقع.',
            style: TextStyle(fontFamily: 'Cairo'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 10.5,
            color: AppColors.secondaryText,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(widget.icon, color: widget.iconColor, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _controller,
                onChanged: _onChanged,
                textInputAction: TextInputAction.search,
                onSubmitted: _runSearch,
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: 'اكتب اسم المكان...',
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              height: 34,
              child: FilledButton(
                onPressed: () => _runSearch(_controller.text),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: Size.zero,
                ),
                child: const Text(
                  'بحث',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 12),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.map_outlined, size: 20),
              color: AppColors.secondaryText,
              onPressed: widget.onPickFromMap,
              tooltip: 'اختر من الخريطة',
            ),
            if (widget.showCurrentLocation)
              IconButton(
                icon: _locating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location_rounded, size: 20),
                color: AppColors.primary,
                onPressed: _locating ? null : _useCurrentLocation,
                tooltip: 'استخدام موقعي الحالي',
              ),
          ],
        ),
        if (_searching)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: LinearProgressIndicator(minHeight: 2),
          )
        else if (_options.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 6),
            constraints: const BoxConstraints(maxHeight: 220),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _options.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final option = _options[index];
                return ListTile(
                  dense: true,
                  title: Text(
                    option.title,
                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                  ),
                  subtitle: option.subtitle == null
                      ? null
                      : Text(
                          option.subtitle!,
                          style: const TextStyle(fontFamily: 'Cairo', fontSize: 11),
                        ),
                  onTap: () => _select(option),
                );
              },
            ),
          )
        else if (_searched)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'لا توجد نتائج لهذا البحث',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 11.5,
                color: AppColors.secondaryText,
              ),
            ),
          ),
      ],
    );
  }
}
