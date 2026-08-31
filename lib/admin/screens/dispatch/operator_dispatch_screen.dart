import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/geocoding_service.dart';
import '../../../core/services/route_estimator.dart';
import '../../../core/widgets/real_map_widget.dart';
import '../../../features/destinations/data/models/destination_suggestion.dart';
import '../../../features/destinations/data/repositories/destination_search_repository.dart';
import '../../core/admin_colors.dart';
import '../../repositories/admin_dispatch_repository.dart';
import '../../widgets/destination_picker_sheet.dart';

enum _TapMode { pickup, destination }

/// Operator Dispatch: lets a dispatch-center operator create a real trip on
/// behalf of a customer who called in, instead of the customer using the
/// mobile app themselves. The created trip enters the exact same broadcast
/// pool a mobile-originated request does (see
/// `20260713000030_operator_dispatch.sql`), so online captains see and can
/// accept it identically either way - no separate dispatch path exists on
/// the captain side.
class OperatorDispatchScreen extends StatefulWidget {
  const OperatorDispatchScreen({super.key});

  @override
  State<OperatorDispatchScreen> createState() => _OperatorDispatchScreenState();
}

class _OperatorDispatchScreenState extends State<OperatorDispatchScreen> {
  final _repository = AdminDispatchRepository();
  // `late` so this is only constructed on first actual search - its
  // constructor chain eagerly touches SupabaseConfig.client (unlike
  // AdminDispatchRepository, which reads it lazily via a getter), which
  // would otherwise throw on every screen mount before Supabase.initialize
  // has run (e.g. in widget tests that never touch the network).
  late final _destinationSearchRepository = DestinationSearchRepository();

  final _phoneController = TextEditingController();
  final _pickupAddressController = TextEditingController();
  final _destAddressController = TextEditingController();
  final _noteController = TextEditingController();
  final _recipientNameController = TextEditingController();
  final _recipientPhoneController = TextEditingController();
  final _packageDescriptionController = TextEditingController();
  final _pickupFocusNode = FocusNode();
  final _destFocusNode = FocusNode();

  List<DestinationSuggestion> _pickupOptions = [];
  List<DestinationSuggestion> _destOptions = [];
  bool _pickupSearching = false;
  bool _destSearching = false;
  // False until a search has actually completed at least once - lets the
  // UI tell "never searched yet" apart from "searched, found nothing",
  // which used to render identically (nothing at all), leaving an
  // operator with no way to know whether the button did anything.
  bool _pickupSearched = false;
  bool _destSearched = false;
  Timer? _pickupSearchDebounce;
  Timer? _destSearchDebounce;
  Timer? _pickupGeocodeDebounce;
  Timer? _destGeocodeDebounce;

  String _serviceType = 'ride'; // 'ride' | 'delivery'
  String _tripType = 'normal'; // 'normal' | 'open'
  _TapMode _tapMode = _TapMode.pickup;

  /// A delivery always has a fixed drop-off point - there is no "open
  /// delivery" concept - so the destination section/map pin behaves exactly
  /// like a normal (non-open) ride whenever it's selected, regardless of
  /// [_tripType] (which becomes irrelevant and is hidden entirely).
  bool get _needsDestination =>
      _serviceType == 'delivery' || _tripType == 'normal';

  double? _pickupLat;
  double? _pickupLng;
  double? _destLat;
  double? _destLng;

  String _vehicleType = 'economy';
  String _paymentMethod = 'cash';

  Map<String, dynamic>? _pricing;
  bool _loadingPricing = false;

  bool _lookingUpCustomer = false;
  Map<String, dynamic>? _foundCustomer;
  bool _customerLookupFailed = false;

  bool _dispatching = false;

  static const _vehicleLabels = {
    'economy': 'إقتصادية',
    'comfort': 'مريحة',
    'family': 'عائلية',
  };

  @override
  void initState() {
    super.initState();
    _loadPricing();
    // A found/failed customer lookup is only valid for the phone digits it
    // was run against - if the operator edits the number afterward without
    // re-searching, the stale green "found" confirmation must not linger
    // (the RPC re-looks-up by whatever phone text is sent at dispatch time,
    // so the UI must never show confidence it doesn't have).
    _phoneController.addListener(_onPhoneChanged);
    // "Suggestions open immediately" - load a starting list (popular
    // places) the moment the field gains focus, before the operator has
    // typed anything, instead of waiting for a first keystroke.
    _pickupFocusNode.addListener(() {
      if (_pickupFocusNode.hasFocus && _pickupAddressController.text.isEmpty) {
        _searchPickup('');
      }
    });
    _destFocusNode.addListener(() {
      if (_destFocusNode.hasFocus && _destAddressController.text.isEmpty) {
        _searchDestination('');
      }
    });
  }

  @override
  void dispose() {
    _phoneController.removeListener(_onPhoneChanged);
    _phoneController.dispose();
    _pickupAddressController.dispose();
    _destAddressController.dispose();
    _noteController.dispose();
    _recipientNameController.dispose();
    _recipientPhoneController.dispose();
    _packageDescriptionController.dispose();
    _pickupFocusNode.dispose();
    _destFocusNode.dispose();
    _pickupSearchDebounce?.cancel();
    _destSearchDebounce?.cancel();
    _pickupGeocodeDebounce?.cancel();
    _destGeocodeDebounce?.cancel();
    super.dispose();
  }

  void _onPhoneChanged() {
    if (_foundCustomer != null || _customerLookupFailed) {
      setState(() {
        _foundCustomer = null;
        _customerLookupFailed = false;
      });
    }
  }

  /// Every phone number elsewhere in this app (login, registration, the
  /// mobile captain/customer flows) is stored and matched as a fixed
  /// `+222` country code plus an 8-digit local number - see
  /// `admin_login_screen.dart`, `phone_code_login_screen.dart`. This field
  /// used to accept free-form
  /// text with only a hint suggesting the `+222` prefix, so an operator
  /// typing just the 8 local digits (as trained by every other phone field
  /// in the app) silently never matched `profiles.phone` in the database -
  /// the lookup always returned "not found" and the send button stayed
  /// disabled with no way to succeed. The field is now digits-only and the
  /// `+222` prefix is applied here, exactly like the rest of the app.
  String get _fullPhone => '+222${_phoneController.text.trim()}';

  /// The RPC always forces 'motorcycle' server-side for a delivery (see
  /// 20260802000048_admin_dispatch_delivery.sql) regardless of
  /// [_vehicleType] - which stays whatever car tier was last picked, since
  /// the vehicle-type chips are simply hidden in delivery mode rather than
  /// reset. The fare estimate below must price against the same vehicle
  /// type the server will actually use, or it would show a car fare for a
  /// motorcycle job.
  String get _effectiveVehicleType =>
      _serviceType == 'delivery' ? 'motorcycle' : _vehicleType;

  Future<void> _loadPricing() async {
    setState(() => _loadingPricing = true);
    try {
      _pricing = await _repository.fetchPricingConfig(_effectiveVehicleType);
    } catch (_) {
      _pricing = null;
    } finally {
      if (mounted) setState(() => _loadingPricing = false);
    }
  }

  /// Straight-line (Haversine) distance/duration fallback - see
  /// [HaversineRouteEstimator]. No live routing API is wired up in this
  /// project yet, so this is always an estimate, never an actual road
  /// distance; the UI must label it as such (see `_buildEstimateCard`).
  static const _routeEstimator = HaversineRouteEstimator();

  RouteEstimate? get _routeEstimate {
    if (_pickupLat == null || _pickupLng == null) return null;
    if (_destLat == null || _destLng == null) return null;
    return _routeEstimator.estimate(
      pickup: LatLng(_pickupLat!, _pickupLng!),
      destination: LatLng(_destLat!, _destLng!),
    );
  }

  double? get _distanceKm => _routeEstimate?.distanceKm;

  int? get _estimatedDurationMinutes => _routeEstimate?.durationMinutes;

  double? get _estimatedFare {
    final pricing = _pricing;
    if (pricing == null) return null;
    final baseFare = (pricing['base_fare'] as num?)?.toDouble() ?? 0;
    final minimumFare = (pricing['minimum_fare'] as num?)?.toDouble() ?? 0;
    final surge = (pricing['surge_multiplier'] as num?)?.toDouble() ?? 1.0;

    if (!_needsDestination) {
      // No destination yet - the honest estimate is just the flat base
      // charge, exactly like the mobile Open Trip request flow shows.
      return minimumFare > baseFare ? minimumFare : baseFare;
    }

    final km = _distanceKm;
    if (km == null) return null;

    // Mirrors captain_end_trip's normal-trip formula exactly
    // (20260816000077_restore_completed_trips_count.sql): base_fare covers
    // every km up to base_distance_km outright, only the km beyond that are
    // charged, and normal trips are not time-priced at all - price_per_minute
    // only applies to open trips server-side. This estimate had drifted from
    // that formula (still multiplying the full distance by price_per_km and
    // adding a time charge the backend never bills for normal trips),
    // showing operators a fare inflated well above what the trip will
    // actually settle for - e.g. 141 quoted for a 1.4km ride the backend
    // prices at the 100 minimum.
    final pricePerKm = (pricing['price_per_km'] as num?)?.toDouble() ?? 0;
    final baseDistanceKm =
        (pricing['base_distance_km'] as num?)?.toDouble() ?? 0;
    final billableKm = km > baseDistanceKm ? km - baseDistanceKm : 0;
    final subtotal = (baseFare + (billableKm * pricePerKm)) * surge;
    return subtotal < minimumFare ? minimumFare : subtotal;
  }

  Future<void> _lookupCustomer() async {
    final localDigits = _phoneController.text.trim();
    if (localDigits.length != 8) return;
    final phone = _fullPhone;
    setState(() {
      _lookingUpCustomer = true;
      _customerLookupFailed = false;
      _foundCustomer = null;
    });
    try {
      final result = await _repository.findCustomerByPhone(phone);
      if (kDebugMode) {
        debugPrint(
          '[OperatorDispatch] customer lookup for "$phone" -> '
          '${result == null ? "not found" : "found (${result['id']})"}',
        );
      }
      setState(() {
        _foundCustomer = result;
        _customerLookupFailed = result == null;
      });
    } catch (e, st) {
      debugPrint('[OperatorDispatch] customer lookup failed: $e');
      if (kDebugMode) debugPrint('$st');
      setState(() => _customerLookupFailed = true);
    } finally {
      if (mounted) setState(() => _lookingUpCustomer = false);
    }
  }

  void _handleMapTap(LatLng point) {
    if (_tapMode == _TapMode.pickup) {
      _setPickup(point);
    } else {
      _setDestination(point);
    }
  }

  // Shared by tap-to-place and marker dragging, so fine-tuning a pin's
  // position after the initial tap keeps working the same way either time.
  // Also triggers a debounced reverse-geocode to auto-fill the address
  // field when it's empty - dragging fires this repeatedly while the
  // marker moves, so the actual network call is debounced to fire once
  // after the operator stops moving it, not on every frame (see
  // GeocodingService's Nominatim usage-policy note).
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

  /// Auto-fills [controller] from reverse geocoding only when it's still
  /// empty (never overwrites an address the operator typed or picked from
  /// the registry/autocomplete) - manual edit afterward always remains
  /// possible, this only ever seeds an initial value.
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

  /// Debounced, called on every keystroke - kept so a fast typist still
  /// gets suggestions without pressing anything. [_searchPickupNow] is the
  /// same search fired immediately, for the explicit "بحث" button.
  void _searchPickup(String query) {
    _pickupSearchDebounce?.cancel();
    _pickupSearchDebounce = Timer(
      const Duration(milliseconds: 300),
      () => _runPickupSearch(query),
    );
  }

  Future<void> _searchPickupNow() {
    _pickupSearchDebounce?.cancel();
    return _runPickupSearch(_pickupAddressController.text);
  }

  Future<void> _runPickupSearch(String query) async {
    setState(() => _pickupSearching = true);
    try {
      final results = await _destinationSearchRepository.search(
        query: query.trim(),
      );
      if (mounted) {
        setState(() {
          _pickupOptions = results;
          _pickupSearched = true;
        });
      }
    } catch (e) {
      debugPrint('[OperatorDispatch] pickup suggestion search failed: $e');
      if (mounted) {
        setState(() {
          _pickupOptions = [];
          _pickupSearched = true;
        });
      }
    } finally {
      if (mounted) setState(() => _pickupSearching = false);
    }
  }

  void _searchDestination(String query) {
    _destSearchDebounce?.cancel();
    _destSearchDebounce = Timer(
      const Duration(milliseconds: 300),
      () => _runDestinationSearch(query),
    );
  }

  Future<void> _searchDestinationNow() {
    _destSearchDebounce?.cancel();
    return _runDestinationSearch(_destAddressController.text);
  }

  Future<void> _runDestinationSearch(String query) async {
    setState(() => _destSearching = true);
    try {
      final results = await _destinationSearchRepository.search(
        query: query.trim(),
      );
      if (mounted) {
        setState(() {
          _destOptions = results;
          _destSearched = true;
        });
      }
    } catch (e) {
      debugPrint(
        '[OperatorDispatch] destination suggestion search failed: $e',
      );
      if (mounted) {
        setState(() {
          _destOptions = [];
          _destSearched = true;
        });
      }
    } finally {
      if (mounted) setState(() => _destSearching = false);
    }
  }

  // Fills the field from the picked suggestion (RawAutocomplete used to do
  // this automatically; the plain list below doesn't) and clears the
  // results so the list disappears once a choice is made.
  void _selectPickupSuggestion(DestinationSuggestion suggestion) {
    setState(() {
      _pickupAddressController.text = suggestion.displayLabel;
      _pickupLat = suggestion.latitude;
      _pickupLng = suggestion.longitude;
      _pickupOptions = [];
      _pickupSearched = false;
    });
  }

  void _selectDestSuggestion(DestinationSuggestion suggestion) {
    setState(() {
      _destAddressController.text = suggestion.displayLabel;
      _destLat = suggestion.latitude;
      _destLng = suggestion.longitude;
      _destOptions = [];
      _destSearched = false;
    });
  }

  /// Opens the district->category->place picker (reusing the existing
  /// Phase-2 destinations system) for the pickup point. Picking "منزل أو
  /// موقع غير مسجل" or dismissing the sheet leaves the free-text address +
  /// map tap/drag flow untouched.
  Future<void> _pickPickupFromRegistry() async {
    final picked = await showDestinationPickerSheet(context);
    if (picked == null) return;
    setState(() {
      _pickupAddressController.text = picked.address;
      _pickupLat = picked.latitude;
      _pickupLng = picked.longitude;
    });
  }

  Future<void> _pickDestinationFromRegistry() async {
    final picked = await showDestinationPickerSheet(context);
    if (picked == null) return;
    setState(() {
      _destAddressController.text = picked.address;
      _destLat = picked.latitude;
      _destLng = picked.longitude;
    });
  }

  /// Every unmet requirement for sending the trip, in Arabic, in the order
  /// an operator should resolve them. Empty means the button is enabled.
  /// This is deliberately a list (not a single bool) so the UI can always
  /// explain *why* the button is disabled instead of leaving it looking
  /// broken - see the "Send request to captains" bug where operators typed
  /// the customer phone without the `+222` prefix used everywhere else in
  /// the app, the lookup silently never matched, and nothing on screen said
  /// so.
  ///
  /// Note a registered customer account is intentionally NOT required here:
  /// `admin_dispatch_trip` (20260718000040_guest_dispatch_trip.sql) creates
  /// the trip either way, so an unmatched phone number only blocks dispatch
  /// on the phone format itself, never on account existence.
  List<String> get _validationMessages {
    final messages = <String>[];
    final localDigits = _phoneController.text.trim();

    if (localDigits.isEmpty) {
      messages.add('أدخل رقم هاتف الزبون');
    } else if (localDigits.length != 8) {
      messages.add('رقم الهاتف يجب أن يتكون من 8 أرقام');
    } else if (_lookingUpCustomer) {
      messages.add('جارٍ البحث عن الزبون...');
    }

    if (_pickupLat == null || _pickupLng == null) {
      messages.add('حدد نقطة الانطلاق على الخريطة');
    }
    if (_needsDestination && (_destLat == null || _destLng == null)) {
      messages.add(
        _serviceType == 'delivery'
            ? 'حدد نقطة تسليم الطرد على الخريطة'
            : 'حدد الوجهة على الخريطة (مطلوبة للمشوار المحدد)',
      );
    }

    if (_serviceType == 'delivery') {
      if (_recipientNameController.text.trim().isEmpty) {
        messages.add('أدخل اسم المستلم');
      }
      final recipientDigits = _recipientPhoneController.text.trim();
      if (recipientDigits.isEmpty) {
        messages.add('أدخل رقم هاتف المستلم');
      } else if (recipientDigits.length != 8) {
        messages.add('رقم هاتف المستلم يجب أن يتكون من 8 أرقام');
      }
    }

    return messages;
  }

  bool get _canDispatch => !_dispatching && _validationMessages.isEmpty;

  void _logValidationState() {
    if (!kDebugMode) return;
    debugPrint(
      '[OperatorDispatch] validation: '
      'serviceType=$_serviceType '
      'phoneDigits=${_phoneController.text.trim().length} '
      'customerFound=${_foundCustomer != null} '
      'customerLookupFailed=$_customerLookupFailed '
      'tripType=$_tripType vehicleType=$_vehicleType '
      'paymentMethod=$_paymentMethod '
      'pickup=(${_pickupLat ?? '-'}, ${_pickupLng ?? '-'}) '
      'destination=(${_destLat ?? '-'}, ${_destLng ?? '-'}) '
      'estimatedFare=$_estimatedFare '
      'dispatching=$_dispatching '
      '=> canDispatch=$_canDispatch',
    );
  }

  Future<void> _dispatch() async {
    if (!_canDispatch) return;
    setState(() => _dispatching = true);
    try {
      await _repository.dispatchTrip(
        customerPhone: _fullPhone,
        pickupAddress: _pickupAddressController.text.trim().isEmpty
            ? 'نقطة الانطلاق (محددة على الخريطة)'
            : _pickupAddressController.text.trim(),
        pickupLat: _pickupLat!,
        pickupLng: _pickupLng!,
        tripType: _tripType,
        destinationAddress: !_needsDestination
            ? null
            : (_destAddressController.text.trim().isEmpty
                  ? 'الوجهة (محددة على الخريطة)'
                  : _destAddressController.text.trim()),
        destinationLat: !_needsDestination ? null : _destLat,
        destinationLng: !_needsDestination ? null : _destLng,
        vehicleType: _effectiveVehicleType,
        paymentMethod: _paymentMethod,
        estimatedPrice: _estimatedFare,
        estimatedDurationMinutes: _estimatedDurationMinutes,
        distanceKm: _distanceKm,
        customerNote: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
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
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _serviceType == 'delivery'
                ? 'تم إرسال طلب التوصيل وبثه للكباتن المتصلين بنجاح'
                : 'تم إرسال المشوار وبثه للكباتن المتصلين بنجاح',
          ),
          backgroundColor: AdminColors.success,
        ),
      );
      _resetForm();
    } on PostgrestException catch (e, st) {
      // Surface the real server-side reason (e.g. an RLS/role rejection
      // from admin_dispatch_trip, or an invalid-status/invalid-type guard)
      // instead of a generic message that hides what actually went wrong.
      debugPrint(
        '[OperatorDispatch] Supabase error dispatching trip: '
        'message="${e.message}" code=${e.code} details=${e.details} hint=${e.hint}',
      );
      debugPrint('$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر إرسال الطلب: ${e.message}'),
            backgroundColor: AdminColors.error,
          ),
        );
      }
    } catch (e, st) {
      debugPrint('[OperatorDispatch] Unexpected error dispatching trip: $e');
      debugPrint('$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر إرسال الطلب: $e'),
            backgroundColor: AdminColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _dispatching = false);
    }
  }

  void _resetForm() {
    setState(() {
      _phoneController.clear();
      _pickupAddressController.clear();
      _destAddressController.clear();
      _noteController.clear();
      _recipientNameController.clear();
      _recipientPhoneController.clear();
      _packageDescriptionController.clear();
      _pickupLat = null;
      _pickupLng = null;
      _destLat = null;
      _destLng = null;
      _foundCustomer = null;
      _customerLookupFailed = false;
      _tapMode = _TapMode.pickup;
    });
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
              style: TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<_TapMode>(
              segments: [
                const ButtonSegment(
                  value: _TapMode.pickup,
                  label: Text(
                    'نقرة = نقطة الانطلاق',
                    style: TextStyle(fontFamily: 'Cairo'),
                  ),
                  icon: Icon(
                    Icons.radio_button_checked_rounded,
                    color: AdminColors.success,
                  ),
                ),
                ButtonSegment(
                  value: _TapMode.destination,
                  enabled: _needsDestination,
                  label: Text(
                    _serviceType == 'delivery'
                        ? 'نقرة = نقطة التسليم'
                        : 'نقرة = الوجهة',
                    style: const TextStyle(fontFamily: 'Cairo'),
                  ),
                  icon: const Icon(
                    Icons.location_on_rounded,
                    color: AdminColors.error,
                  ),
                ),
              ],
              selected: {_tapMode},
              onSelectionChanged: (selection) =>
                  setState(() => _tapMode = selection.first),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 460,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: RealMapWidget(
                  pickupLat: _pickupLat,
                  pickupLng: _pickupLng,
                  destLat: _needsDestination ? _destLat : null,
                  destLng: _needsDestination ? _destLng : null,
                  showRoute: _needsDestination,
                  onMapTap: _handleMapTap,
                  pickupDraggable: true,
                  destDraggable: _needsDestination,
                  onPickupDragged: _setPickup,
                  onDestDragged: _needsDestination ? _setDestination : null,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _tapMode == _TapMode.pickup
                  ? 'انقر على الخريطة لتحديد نقطة الانطلاق (علامة خضراء)، أو اسحب العلامة لتعديل الموقع بدقة.'
                  : (_serviceType == 'delivery'
                        ? 'انقر على الخريطة لتحديد نقطة تسليم الطرد (علامة حمراء)، أو اسحب العلامة لتعديل الموقع بدقة.'
                        : 'انقر على الخريطة لتحديد الوجهة (علامة حمراء)، أو اسحب العلامة لتعديل الموقع بدقة.'),
              style: const TextStyle(
                fontSize: 12,
                color: AdminColors.textSecondary,
                fontFamily: 'Cairo',
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
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),

              const Text(
                'نوع الطلب',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 6),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'ride',
                    label: Text('ركاب', style: TextStyle(fontFamily: 'Cairo')),
                    icon: Icon(Icons.local_taxi_rounded),
                  ),
                  ButtonSegment(
                    value: 'delivery',
                    label: Text(
                      'توصيل طرد',
                      style: TextStyle(fontFamily: 'Cairo'),
                    ),
                    icon: Icon(Icons.two_wheeler_rounded),
                  ),
                ],
                selected: {_serviceType},
                onSelectionChanged: (selection) => setState(() {
                  _serviceType = selection.first;
                  // A delivery always needs a destination and is always a
                  // motorcycle job - reset whatever car-trip-only state was
                  // left over from ride mode so the map/fare/validation
                  // logic above (all keyed off _needsDestination) sees a
                  // clean slate rather than a stale 'open' trip type.
                  if (_serviceType == 'delivery') {
                    _tripType = 'normal';
                    _tapMode = _TapMode.pickup;
                  }
                  _loadPricing();
                }),
              ),

              const SizedBox(height: 18),
              Text(
                _serviceType == 'delivery' ? 'رقم هاتف المرسل' : 'رقم هاتف الزبون',
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(8),
                      ],
                      decoration: const InputDecoration(
                        prefixText: '+222 ',
                        hintText: 'XXXXXXXX',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _lookupCustomer(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _lookingUpCustomer ? null : _lookupCustomer,
                    child: _lookingUpCustomer
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'بحث',
                            style: TextStyle(fontFamily: 'Cairo'),
                          ),
                  ),
                ],
              ),
              if (_foundCustomer != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AdminColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        color: AdminColors.success,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          (_foundCustomer!['profiles']?['full_name']
                                  as String?) ??
                              'زبون',
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (_customerLookupFailed) ...[
                const SizedBox(height: 8),
                // Informational, not blocking: admin_dispatch_trip creates
                // the trip either way (customer_id left null), so this only
                // tells the operator what to expect, never stops dispatch.
                const Text(
                  'لا يوجد حساب مسجل بهذا الرقم - سيتم إرسال المشوار كزبون '
                  'غير مسجل وسيصل لجميع الكباتن كالمعتاد',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11,
                    color: AdminColors.warning,
                  ),
                ),
              ],

              if (_serviceType == 'ride') ...[
                const SizedBox(height: 18),
                const Text(
                  'نوع المشوار',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'normal',
                      label: Text(
                        'مشوار محدد',
                        style: TextStyle(fontFamily: 'Cairo'),
                      ),
                    ),
                    ButtonSegment(
                      value: 'open',
                      label: Text(
                        'مشوار مفتوح',
                        style: TextStyle(fontFamily: 'Cairo'),
                      ),
                    ),
                  ],
                  selected: {_tripType},
                  onSelectionChanged: (selection) => setState(() {
                    _tripType = selection.first;
                    if (_tripType == 'open') _tapMode = _TapMode.pickup;
                  }),
                ),
              ],

              const SizedBox(height: 18),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'عنوان نقطة الانطلاق',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _pickPickupFromRegistry,
                    icon: const Icon(Icons.list_alt_rounded, size: 16),
                    label: const Text(
                      'من الأماكن المسجلة',
                      style: TextStyle(fontFamily: 'Cairo', fontSize: 11),
                    ),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _buildAddressSearchField(
                controller: _pickupAddressController,
                focusNode: _pickupFocusNode,
                hintText: 'اكتب اسم المكان ثم اضغط بحث',
                options: _pickupOptions,
                searching: _pickupSearching,
                searched: _pickupSearched,
                onChanged: _searchPickup,
                onSearchPressed: _searchPickupNow,
                onSelected: _selectPickupSuggestion,
              ),
              _buildCoordinatesLabel(_pickupLat, _pickupLng),

              if (_needsDestination) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _serviceType == 'delivery'
                            ? 'عنوان نقطة التسليم'
                            : 'عنوان الوجهة',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _pickDestinationFromRegistry,
                      icon: const Icon(Icons.list_alt_rounded, size: 16),
                      label: const Text(
                        'من الأماكن المسجلة',
                        style: TextStyle(fontFamily: 'Cairo', fontSize: 11),
                      ),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _buildAddressSearchField(
                  controller: _destAddressController,
                  focusNode: _destFocusNode,
                  hintText: 'اكتب اسم المكان ثم اضغط بحث',
                  options: _destOptions,
                  searching: _destSearching,
                  searched: _destSearched,
                  onChanged: _searchDestination,
                  onSearchPressed: _searchDestinationNow,
                  onSelected: _selectDestSuggestion,
                ),
                _buildCoordinatesLabel(_destLat, _destLng),
              ],

              if (_serviceType == 'delivery') ...[
                const SizedBox(height: 18),
                const Text(
                  'بيانات المستلم',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _recipientNameController,
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'اسم المستلم',
                    border: OutlineInputBorder(),
                  ),
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
                    hintText: 'هاتف المستلم (XXXXXXXX)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _packageDescriptionController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'وصف الطرد (اختياري)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],

              const SizedBox(height: 18),
              if (_serviceType == 'delivery') ...[
                const Text(
                  'نوع المركبة',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'كل طلبات التوصيل تُبَث للكباتن الذين يقودون دراجة نارية '
                  'ويقبلون التوصيل، بغض النظر عن أي اختيار آخر.',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11,
                    color: AdminColors.textSecondary,
                  ),
                ),
              ] else ...[
                const Text(
                  'نوع السيارة',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: _vehicleLabels.entries.map((entry) {
                    final selected = _vehicleType == entry.key;
                    return ChoiceChip(
                      label: Text(
                        entry.value,
                        style: const TextStyle(fontFamily: 'Cairo'),
                      ),
                      selected: selected,
                      onSelected: (_) {
                        setState(() => _vehicleType = entry.key);
                        _loadPricing();
                      },
                    );
                  }).toList(),
                ),
              ],

              const SizedBox(height: 18),
              const Text(
                'طريقة الدفع',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text(
                      'نقداً',
                      style: TextStyle(fontFamily: 'Cairo'),
                    ),
                    selected: _paymentMethod == 'cash',
                    onSelected: (_) => setState(() => _paymentMethod = 'cash'),
                  ),
                  ChoiceChip(
                    label: const Text(
                      'المحفظة',
                      style: TextStyle(fontFamily: 'Cairo'),
                    ),
                    selected: _paymentMethod == 'wallet',
                    onSelected: (_) =>
                        setState(() => _paymentMethod = 'wallet'),
                  ),
                ],
              ),

              const SizedBox(height: 14),
              const Text(
                'ملاحظة (اختياري)',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _noteController,
                maxLines: 2,
                decoration: const InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 20),
              _buildEstimateCard(),

              const SizedBox(height: 16),
              Builder(
                builder: (context) {
                  _logValidationState();
                  return _buildValidationSummary();
                },
              ),

              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _canDispatch ? _dispatch : null,
                  icon: _dispatching
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(
                    _serviceType == 'delivery'
                        ? 'إرسال طلب التوصيل للكباتن'
                        : 'إرسال المشوار للكباتن',
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AdminColors.primary,
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

  /// Always-visible explanation of why "إرسال المشوار للكباتن" is disabled,
  /// or a positive "ready to send" confirmation when it isn't - the button
  /// must never just sit there disabled with no reason shown.
  Widget _buildValidationSummary() {
    final messages = _validationMessages;
    if (messages.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AdminColors.success.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Row(
          children: [
            Icon(
              Icons.check_circle_rounded,
              color: AdminColors.success,
              size: 16,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'جميع البيانات مكتملة، جاهز لإرسال المشوار',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: AdminColors.success,
                ),
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
        color: AdminColors.warning.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: AdminColors.warning,
                size: 16,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'لإرسال المشوار، أكمل ما يلي:',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: AdminColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          for (final message in messages)
            Padding(
              padding: const EdgeInsets.only(top: 4, right: 24),
              child: Text(
                '• $message',
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11,
                  color: AdminColors.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Pickup/destination address field with an explicit "بحث" button, plus
  /// the same live-as-you-type search kept underneath (debounced 300ms via
  /// [onChanged]) for an operator who prefers to just keep typing. Results
  /// render as a plain, always-visible list directly under the field
  /// (rather than RawAutocomplete's floating overlay, which some operators
  /// found easy to miss or lose after the field lost focus) and stay shown
  /// until a suggestion is tapped or the list is searched again - selecting
  /// one, via [onSelected], fills the field and sets the coordinates, which
  /// already flows into [RealMapWidget] to move both the marker and (for
  /// pickup - see the destination auto-recenter fix in real_map_widget.dart)
  /// the map camera.
  Widget _buildAddressSearchField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hintText,
    required List<DestinationSuggestion> options,
    required bool searching,
    required bool searched,
    required ValueChanged<String> onChanged,
    required Future<void> Function() onSearchPressed,
    required ValueChanged<DestinationSuggestion> onSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                decoration: InputDecoration(
                  hintText: hintText,
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
                onChanged: onChanged,
                onSubmitted: (_) => onSearchPressed(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: searching ? null : onSearchPressed,
              icon: searching
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search_rounded, size: 18),
              label: const Text(
                'بحث',
                style: TextStyle(fontFamily: 'Cairo', fontSize: 13),
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
            ),
          ],
        ),
        if (options.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            constraints: const BoxConstraints(maxHeight: 240),
            decoration: BoxDecoration(
              border: Border.all(color: AdminColors.border),
              borderRadius: BorderRadius.circular(10),
            ),
            child: ListView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: options.length,
              itemBuilder: (context, index) {
                final option = options[index];
                return _SuggestionTile(
                  suggestion: option,
                  onTap: () => onSelected(option),
                );
              },
            ),
          )
        else if (searching)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'جارٍ البحث...',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                color: AdminColors.textSecondary,
              ),
            ),
          )
        else if (searched)
          // Distinguishes "searched, found literally nothing" from "never
          // pressed بحث yet" - both used to render as an empty, silent
          // gap with no way to tell them apart, which read as "the button
          // does nothing" even when a search genuinely ran and came back
          // empty (e.g. the map-search half failing while the registry
          // half also has no match for this query).
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'لا توجد نتائج لهذا البحث',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                color: AdminColors.textSecondary,
              ),
            ),
          ),
      ],
    );
  }

  /// Shows the raw coordinates picked on the map (tap or drag) under an
  /// address field, so the operator can see exactly what will be sent to
  /// the captain even when the address text is a free-form description.
  Widget _buildCoordinatesLabel(double? lat, double? lng) {
    if (lat == null || lng == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        'الإحداثيات: ${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
        style: const TextStyle(
          fontFamily: 'Cairo',
          fontSize: 10.5,
          color: AdminColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildEstimateCard() {
    final fare = _estimatedFare;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AdminColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'الأجرة المقدرة',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 11,
              color: AdminColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          if (_loadingPricing)
            const Text('...', style: TextStyle(fontFamily: 'Cairo'))
          else
            Text(
              fare != null
                  ? '${fare.toStringAsFixed(0)} أوقية'
                  : 'حدد نقطة الانطلاق والوجهة',
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: AdminColors.primary,
              ),
            ),
          if (_tripType == 'open')
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'مشوار مفتوح: الأجرة النهائية تُحتسب حسب الوقت والمسافة الفعليين.',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 10.5,
                  color: AdminColors.textSecondary,
                ),
              ),
            ),
          if (_distanceKm != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '* تقدير بخط مستقيم (وليست مسافة الطريق الفعلية): '
                '${_distanceKm!.toStringAsFixed(1)} كم • ${_estimatedDurationMinutes ?? '-'} د تقريباً',
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 10.5,
                  color: AdminColors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One row in the address autocomplete's suggestions dropdown - shows the
/// name/address plus verified/popular badges for a place, or just the
/// name for a district/neighborhood result.
class _SuggestionTile extends StatelessWidget {
  final DestinationSuggestion suggestion;
  final VoidCallback onTap;

  const _SuggestionTile({required this.suggestion, required this.onTap});

  IconData get _icon {
    switch (suggestion.resultType) {
      case DestinationResultType.district:
        return Icons.map_rounded;
      case DestinationResultType.neighborhood:
        return Icons.holiday_village_rounded;
      case DestinationResultType.place:
        return Icons.place_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(_icon, size: 18, color: AdminColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    suggestion.title,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if ((suggestion.subtitle ?? '').isNotEmpty)
                    Text(
                      suggestion.subtitle!,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11,
                        color: AdminColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            if (suggestion.isVerified)
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(
                  Icons.verified_rounded,
                  size: 14,
                  color: AdminColors.success,
                ),
              ),
            if (suggestion.isPopular)
              const Icon(
                Icons.local_fire_department_rounded,
                size: 14,
                color: AdminColors.accent,
              ),
          ],
        ),
      ),
    );
  }
}
