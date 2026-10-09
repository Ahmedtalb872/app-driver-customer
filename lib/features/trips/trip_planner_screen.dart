import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/services/ride_repository.dart';
import '../../core/services/saved_places_repository.dart';
import '../../core/services/support_ticket_repository.dart';
import '../../models/models.dart';
import '../../providers/app_state_provider.dart';
import '../destinations/data/models/destination_suggestion.dart';
import '../destinations/presentation/destination_map_picker_screen.dart';
import '../destinations/presentation/location_search_field.dart';
import 'request_ride_screen.dart';
import 'trip_tracking_screen.dart';
import 'voice_ride_request_sheet.dart';

/// Shown after tapping "إلى أين تريد الذهاب؟" on the home screen - three
/// sections: a normal ride (needs both a pickup and a destination point),
/// an open ride (just a pickup), and "راسل لطلب مشوار" for a customer who'd
/// rather just describe it in writing than type/choose anything - see
/// [_requestRideByMessage], which reuses the open-ride section's own pickup
/// point rather than asking for one a third time. Each location field is
/// picked inline, right on this screen, via [LocationSearchField] (type to
/// search, or the map icon for a full-screen map picker), pre-filled with
/// the GPS location detected on the home screen but freely changeable
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

  /// This customer's saved المنزل/العمل/مكان آخر, if any - fetched once so
  /// they can be offered as one-tap destination shortcuts below. Best-effort:
  /// a fetch failure just means the shortcuts don't show, same as having
  /// none saved, rather than blocking the screen.
  List<SavedPlace> _savedPlaces = const [];

  @override
  void initState() {
    super.initState();
    _loadSavedPlaces();
  }

  Future<void> _loadSavedPlaces() async {
    try {
      final places = await SavedPlacesRepository.instance.fetchMine();
      if (mounted) setState(() => _savedPlaces = places);
    } catch (_) {
      // Keep whatever's already there (nothing, on first load).
    }
  }

  List<SavedPlace> _savedPlacesByLabel(String label) =>
      _savedPlaces.where((p) => p.label == label).toList();

  /// Shows a pick-list when the customer has saved more than one place
  /// under the same label (see SavedPlacesRepository.savePlace) - each
  /// named by [SavedPlace.displayLabel] so e.g. "بيت الوالد" and "بيت
  /// الزوجة" are distinguishable. [title] is the label's own text (e.g.
  /// "المنزل") for the sheet's heading.
  Future<SavedPlace?> _pickAmongSaved(
    List<SavedPlace> places, {
    required String title,
    required IconData icon,
  }) {
    return showModalBottomSheet<SavedPlace>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'اختر أحد أماكن "$title" المحفوظة',
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
            ...places.map(
              (place) => ListTile(
                leading: Icon(icon, color: AppColors.accent),
                title: Text(
                  place.displayLabel,
                  style: const TextStyle(fontFamily: 'Cairo'),
                ),
                subtitle: place.customName != null
                    ? Text(
                        place.address,
                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    : null,
                onTap: () => Navigator.of(context).pop(place),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _selectNormalDestinationFromSaved(SavedPlace place) {
    _selectNormalDestination(
      DestinationSuggestion(
        resultType: DestinationResultType.place,
        id: place.id,
        title: place.address,
        latitude: place.lat,
        longitude: place.lng,
      ),
    );
  }

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

  bool _isRequestingByMessage = false;

  /// "راسل لطلب مشوار" - requests an open trip at whatever pickup point the
  /// "مشوار مفتوح" section above already has (same GPS-detected point,
  /// freely edited there) - reusing it instead of asking for a pickup a
  /// second time - then sends a first message to admin support about it
  /// and lands on that conversation, where the customer can describe the
  /// destination/details in writing. Admin fills in the trip accordingly
  /// (the same route-editing tools already used for a phone-in dispatch),
  /// reachable right from inside the chat.
  Future<void> _requestRideByMessage() async {
    if (_isRequestingByMessage) return;
    final lat = _openPickupLat;
    final lng = _openPickupLng;
    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'حدّد نقطة الانطلاق أولاً (في قسم "مشوار مفتوح" أعلاه) قبل المراسلة.',
            style: TextStyle(fontFamily: 'Cairo'),
          ),
        ),
      );
      return;
    }
    setState(() => _isRequestingByMessage = true);
    try {
      final pickupAddress = _openPickupAddress ?? 'موقعي الحالي';
      final trip = await RideRepository.instance.requestTrip(
        pickupAddress: pickupAddress,
        pickupLat: lat,
        pickupLng: lng,
        tripType: TripType.open,
        vehicleType: VehicleType.economy,
        paymentMethod: 'نقداً',
      );
      if (!mounted) return;
      context.read<AppStateProvider>().setActiveTripFromBackend(trip);
      final ticketId = await SupportTicketRepository.instance.getOrCreateMyTicket(
        tripId: trip.id,
      );
      await SupportTicketRepository.instance.sendMessage(
        ticketId,
        '🚕 طلب مشوار جديد\nنقطة الانطلاق: $pickupAddress\nالوجهة: ',
      );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) =>
              TripTrackingScreen(tripId: trip.id, autoOpenSupportChat: true),
        ),
        (route) => route.isFirst,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تعذر بدء الطلب حالياً - تحقق من اتصالك وحاول مرة أخرى.',
              style: TextStyle(fontFamily: 'Cairo'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isRequestingByMessage = false);
    }
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
              const SizedBox(height: 10),
              _buildSavedPlacesRow(),
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
          const SizedBox(height: 20),
          _buildSection(
            icon: Icons.support_agent_rounded,
            color: AppColors.secondary,
            title: 'راسل لطلب مشوار',
            subtitle: 'اكتب طلبك للإدارة بدل الكتابة أو الاختيار هنا',
            children: [
              ElevatedButton.icon(
                onPressed: _isRequestingByMessage ? null : _requestRideByMessage,
                icon: _isRequestingByMessage
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.chat_bubble_rounded, size: 18),
                label: const Text('أرسل الآن'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// One-tap destination shortcuts for the customer's saved المنزل/العمل/
  /// مكان آخر (see [SavedPlacesRepository]) - a label with nothing saved
  /// under it yet still shows, greyed out, so the option is discoverable
  /// rather than silently missing.
  Widget _buildSavedPlacesRow() {
    return Row(
      children: [
        _buildSavedPlaceChip(
          label: 'home',
          icon: Icons.home_rounded,
          text: 'المنزل',
        ),
        const SizedBox(width: 8),
        _buildSavedPlaceChip(
          label: 'work',
          icon: Icons.work_rounded,
          text: 'العمل',
        ),
        const SizedBox(width: 8),
        _buildSavedPlaceChip(
          label: 'other',
          icon: Icons.push_pin_rounded,
          text: 'مكان آخر',
        ),
      ],
    );
  }

  Widget _buildSavedPlaceChip({
    required String label,
    required IconData icon,
    required String text,
  }) {
    final saved = _savedPlacesByLabel(label);
    final isSelected =
        _normalDestination != null &&
        saved.any((p) => p.id == _normalDestination!.id);

    Future<void> onTap() async {
      if (saved.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'لم تحفظ "$text" بعد - يمكنك حفظه من شاشة ملخص الرحلة بعد انتهاء مشوارك القادم.',
              style: const TextStyle(fontFamily: 'Cairo'),
            ),
          ),
        );
        return;
      }
      final chosen = saved.length == 1
          ? saved.first
          : await _pickAmongSaved(saved, title: text, icon: icon);
      if (chosen != null) _selectNormalDestinationFromSaved(chosen);
    }

    final hasSaved = saved.isNotEmpty;
    return Expanded(
      child: OutlinedButton.icon(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 8),
          backgroundColor: isSelected ? AppColors.accent.withOpacity(0.12) : null,
          side: BorderSide(
            color: isSelected ? AppColors.accent : AppColors.border,
          ),
          foregroundColor: !hasSaved
              ? AppColors.secondaryText
              : isSelected
              ? AppColors.secondary
              : AppColors.darkText,
        ),
        icon: Icon(icon, size: 15),
        label: Text(
          text,
          style: const TextStyle(fontFamily: 'Cairo', fontSize: 11),
          overflow: TextOverflow.ellipsis,
        ),
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
