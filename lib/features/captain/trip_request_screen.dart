import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants/colors.dart';
import '../../core/services/map_tile_provider.dart';
import '../../core/services/ride_repository.dart';
import '../../models/models.dart';

/// Full-screen incoming-trip-request view for the captain, shown as a
/// full-screen route (not a dialog) so the map and trip details each get
/// real room to breathe - a from-scratch design independent of the old
/// `IncomingRideDialog`, aimed at Uber/Careem-level polish while staying on
/// the Al Hodhod brand palette (teal-green + orange only, no red).
///
/// Ownership split mirrors the dialog it replaces: this screen owns none of
/// the accept/ignore backend calls - it calls back into [onAccept]/
/// [onIgnore]/[onExpired] and only manages its own busy/error/countdown UI
/// state, so the caller (captain home screen) stays the single place
/// responsible for sound/vibration/navigation side effects.
class TripRequestScreen extends StatefulWidget {
  final Trip trip;
  final Future<void> Function() onAccept;
  final Future<void> Function() onIgnore;
  final VoidCallback onExpired;

  const TripRequestScreen({
    super.key,
    required this.trip,
    required this.onAccept,
    required this.onIgnore,
    required this.onExpired,
  });

  @override
  State<TripRequestScreen> createState() => _TripRequestScreenState();
}

class _TripRequestScreenState extends State<TripRequestScreen> {
  bool _accepting = false;
  bool _ignoring = false;
  bool _expired = false;
  String? _errorMessage;

  bool get _busy => _accepting || _ignoring;

  Future<void> _handleAccept() async {
    if (_busy || _expired) return;
    setState(() {
      _accepting = true;
      _errorMessage = null;
    });
    try {
      await widget.onAccept();
      // Success: the caller pops this screen and navigates onward.
    } on TripUnavailableException {
      if (!mounted) return;
      setState(() {
        _accepting = false;
        _errorMessage = 'تم قبول هذا المشوار من طرف كابتن آخر';
      });
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) widget.onExpired();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _accepting = false;
        _errorMessage = 'تعذر قبول المشوار، حاول مجدداً';
      });
    }
  }

  Future<void> _handleIgnore() async {
    if (_busy || _expired) return;
    setState(() => _ignoring = true);
    try {
      await widget.onIgnore();
    } catch (_) {
      // Ignoring is best-effort - the screen closes either way.
    }
  }

  void _handleExpired() {
    if (_expired || _busy) return;
    setState(() => _expired = true);
    widget.onExpired();
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    final isOpenTrip = trip.isOpenTrip;
    final expiresAt =
        trip.requestExpiresAt ??
        DateTime.now().add(Duration(seconds: trip.openRideTimeout));
    final mapHeight = MediaQuery.sizeOf(context).height * 0.45;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          SizedBox(
            height: mapHeight,
            width: double.infinity,
            child: SafeArea(
              bottom: false,
              child: _RequestMap(
                pickupLat: trip.pickupLat,
                pickupLng: trip.pickupLng,
                destLat: isOpenTrip ? null : trip.destLat,
                destLng: isOpenTrip ? null : trip.destLng,
              ),
            ),
          ),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 18,
                    offset: Offset(0, -6),
                  ),
                ],
              ),
              child: Transform.translate(
                offset: const Offset(0, -18),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 26, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildRequestBadge(isOpenTrip),
                      const SizedBox(height: 16),
                      _buildCustomerRow(trip),
                      const SizedBox(height: 18),
                      _buildDivider(),
                      const SizedBox(height: 18),
                      _buildRouteSection(trip, isOpenTrip),
                      const SizedBox(height: 18),
                      if (isOpenTrip)
                        _buildOpenTripNotice()
                      else
                        _buildStatsRow(trip),
                      const SizedBox(height: 16),
                      _buildTagsRow(trip),
                      if ((trip.customerNote ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _buildNoteCard(trip.customerNote!.trim()),
                      ],
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 16),
                        _buildErrorBanner(_errorMessage!),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          _buildBottomBar(expiresAt),
        ],
      ),
    );
  }

  Widget _buildRequestBadge(bool isOpenTrip) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(30),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bolt_rounded, size: 15, color: AppColors.primaryDark),
              SizedBox(width: 5),
              Text(
                'مشوار ركاب جديد',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryDark,
                  fontFamily: 'Cairo',
                ),
              ),
            ],
          ),
        ),
        if (isOpenTrip)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.all_inclusive_rounded,
                  size: 13,
                  color: AppColors.darkText,
                ),
                SizedBox(width: 5),
                Text(
                  'مشوار مفتوح',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkText,
                    fontFamily: 'Cairo',
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildCustomerRow(Trip trip) {
    return Row(
      children: [
        _CustomerAvatar(url: trip.customerAvatarUrl, name: trip.customerName),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      trip.customerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        color: AppColors.darkText,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ),
                  if (trip.customerVerified) ...[
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.verified_rounded,
                      color: AppColors.primary,
                      size: 17,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 5),
              if (trip.customerRating != null)
                Row(
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      color: AppColors.accent,
                      size: 17,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      trip.customerRating!.toStringAsFixed(1),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                        color: AppColors.darkText,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    if (trip.customerRatingsCount != null) ...[
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          '(${trip.customerRatingsCount} تقييماً)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.secondaryText,
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ),
                    ],
                  ],
                )
              else
                const Text(
                  'راكب جديد بلا تقييم بعد',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.secondaryText,
                    fontFamily: 'Cairo',
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() =>
      Container(height: 1, color: AppColors.border.withValues(alpha: 0.7));

  Widget _buildRouteSection(Trip trip, bool isOpenTrip) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            const Icon(
              Icons.trip_origin_rounded,
              color: AppColors.primary,
              size: 18,
            ),
            Container(
              width: 2,
              height: isOpenTrip ? 20 : 34,
              margin: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Icon(
              isOpenTrip ? Icons.help_outline_rounded : Icons.flag_rounded,
              color: AppColors.accent,
              size: 18,
            ),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                trip.pickupLocation.isEmpty
                    ? 'الموقع الحالي للراكب'
                    : trip.pickupLocation,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppColors.darkText,
                  fontFamily: 'Cairo',
                ),
              ),
              SizedBox(height: isOpenTrip ? 12 : 22),
              Text(
                isOpenTrip
                    ? 'الوجهة تُحدد أثناء الرحلة'
                    : trip.destinationLocation,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: isOpenTrip
                      ? AppColors.secondaryText
                      : AppColors.darkText,
                  fontFamily: 'Cairo',
                  fontStyle: isOpenTrip ? FontStyle.italic : FontStyle.normal,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOpenTripNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 16),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'الوجهة غير محددة، يتم احتساب الأجرة حسب الوقت والمسافة الفعليين.',
              style: TextStyle(
                fontSize: 11.5,
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w700,
                fontFamily: 'Cairo',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(Trip trip) {
    final stats = [
      _StatData(
        Icons.route_rounded,
        '${trip.distance.toStringAsFixed(1)} كم',
        'المسافة',
      ),
      _StatData(Icons.timer_rounded, '${trip.duration} د', 'الوقت المتوقع'),
      _StatData(
        Icons.payments_rounded,
        '${trip.price.toStringAsFixed(0)} أوقية',
        'السعر التقديري',
      ),
    ];
    return Row(
      children: [
        for (var i = 0; i < stats.length; i++) ...[
          if (i != 0) const SizedBox(width: 10),
          Expanded(child: _buildStatTile(stats[i])),
        ],
      ],
    );
  }

  Widget _buildStatTile(_StatData stat) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(stat.icon, size: 19, color: AppColors.primary),
          const SizedBox(height: 8),
          Text(
            stat.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13.5,
              color: AppColors.darkText,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 2),
          Text(
            stat.label,
            style: const TextStyle(
              fontSize: 10.5,
              color: AppColors.secondaryText,
              fontFamily: 'Cairo',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagsRow(Trip trip) {
    final tags = [
      _StatData(
        Icons.account_balance_wallet_rounded,
        trip.paymentMethod,
        'طريقة الدفع',
      ),
      _StatData(
        Icons.directions_car_filled_rounded,
        trip.carTypeNameArabic,
        'نوع السيارة',
      ),
      _StatData(
        Icons.people_alt_rounded,
        '${trip.passengerCount}',
        'عدد الركاب',
      ),
    ];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: tags.map(_buildTagChip).toList(),
    );
  }

  Widget _buildTagChip(_StatData tag) {
    return Container(
      constraints: const BoxConstraints(minWidth: 104),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(tag.icon, size: 15, color: AppColors.primaryDark),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tag.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                    color: AppColors.darkText,
                    fontFamily: 'Cairo',
                  ),
                ),
                Text(
                  tag.label,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.secondaryText,
                    fontFamily: 'Cairo',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteCard(String note) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.sticky_note_2_outlined,
                size: 15,
                color: AppColors.accent,
              ),
              SizedBox(width: 6),
              Text(
                'ملاحظة من الراكب',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.accent,
                  fontFamily: 'Cairo',
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            note,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.darkText,
              fontFamily: 'Cairo',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.primaryDark,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.primaryDark,
                fontFamily: 'Cairo',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(DateTime expiresAt) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 58,
                child: OutlinedButton.icon(
                  onPressed: _busy || _expired ? null : _handleIgnore,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.secondaryText,
                    side: const BorderSide(color: AppColors.border, width: 1.4),
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  icon: _ignoring
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.close_rounded, size: 19),
                  label: const Text(
                    'تجاهل الطلب',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.w800,
                      fontSize: 14.5,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: _AcceptButton(
                expiresAt: expiresAt,
                busy: _accepting,
                disabled: _ignoring || _expired,
                onPressed: _handleAccept,
                onExpired: _handleExpired,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatData {
  final IconData icon;
  final String value;
  final String label;
  const _StatData(this.icon, this.value, this.label);
}

/// Big green accept button with a 45-second wall-clock countdown drawn
/// inside it: a draining fill overlay plus a live numeral badge. Driven by
/// [expiresAt] rather than a plain decrementing counter so it stays correct
/// across rebuilds/backgrounding, matching the pattern already established
/// by `RideCountdownRing` elsewhere in the app.
class _AcceptButton extends StatefulWidget {
  final DateTime expiresAt;
  final bool busy;
  final bool disabled;
  final VoidCallback onPressed;
  final VoidCallback onExpired;

  const _AcceptButton({
    required this.expiresAt,
    required this.busy,
    required this.disabled,
    required this.onPressed,
    required this.onExpired,
  });

  @override
  State<_AcceptButton> createState() => _AcceptButtonState();
}

class _AcceptButtonState extends State<_AcceptButton> {
  Timer? _timer;
  late final Duration _total;
  Duration _remaining = Duration.zero;
  bool _expiredFired = false;

  @override
  void initState() {
    super.initState();
    final total = widget.expiresAt.difference(DateTime.now());
    _total = total > Duration.zero ? total : const Duration(seconds: 1);
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (!mounted) return;
    final remaining = widget.expiresAt.difference(DateTime.now());
    setState(() {
      _remaining = remaining.isNegative ? Duration.zero : remaining;
    });
    if (_remaining == Duration.zero && !_expiredFired) {
      _expiredFired = true;
      _timer?.cancel();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onExpired();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalMs = _total.inMilliseconds;
    final fraction = totalMs <= 0
        ? 0.0
        : (_remaining.inMilliseconds / totalMs).clamp(0.0, 1.0);
    final seconds = _remaining.inSeconds;
    final urgent = seconds <= 10;
    final interactive =
        !widget.busy && !widget.disabled && !_expiredFired && seconds > 0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Material(
        color: AppColors.primary,
        child: InkWell(
          onTap: interactive ? widget.onPressed : null,
          child: SizedBox(
            height: 58,
            child: Stack(
              children: [
                Positioned.fill(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: fraction, end: fraction),
                    duration: const Duration(milliseconds: 320),
                    builder: (context, value, _) => FractionallySizedBox(
                      alignment: AlignmentDirectional.centerStart,
                      widthFactor: value,
                      child: Container(
                        color: Colors.white.withValues(alpha: 0.14),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.busy)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      else
                        const Icon(
                          Icons.check_circle_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      const SizedBox(width: 10),
                      const Flexible(
                        child: Text(
                          'قبول الطلب',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ),
                      const Spacer(),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: urgent
                              ? AppColors.accent
                              : Colors.white.withValues(alpha: 0.22),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$seconds',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Circular passenger photo, falling back to a teal initial-letter avatar
/// when the passenger has none or it fails to load - never a broken image.
class _CustomerAvatar extends StatelessWidget {
  final String? url;
  final String name;
  static const double size = 60;

  const _CustomerAvatar({required this.url, required this.name});

  @override
  Widget build(BuildContext context) {
    final trimmedName = name.trim();
    final initial = trimmedName.isNotEmpty ? trimmedName.substring(0, 1) : '؟';

    if (url == null || url!.trim().isEmpty) {
      return _fallback(initial);
    }

    return ClipOval(
      child: Image.network(
        url!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return SizedBox(
            width: size,
            height: size,
            child: const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        },
        errorBuilder: (context, error, stack) => _fallback(initial),
      ),
    );
  }

  Widget _fallback(String initial) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.4,
          fontWeight: FontWeight.bold,
          fontFamily: 'Cairo',
        ),
      ),
    );
  }
}

/// Self-contained map for this screen: frames the pickup/destination bounds
/// on first render (rather than centering on the captain's live GPS, the
/// way the shared `RealMapWidget` does for trip-tracking screens), and
/// draws pickup/destination pins in the logo's own green/orange instead of
/// the green/red used elsewhere in the app. Still reads tiles through the
/// same [MapTileProvider] abstraction as every other map in the app, so a
/// future tile-provider swap covers this screen too.
class _RequestMap extends StatefulWidget {
  final double pickupLat;
  final double pickupLng;
  final double? destLat;
  final double? destLng;

  const _RequestMap({
    required this.pickupLat,
    required this.pickupLng,
    this.destLat,
    this.destLng,
  });

  @override
  State<_RequestMap> createState() => _RequestMapState();
}

class _RequestMapState extends State<_RequestMap> {
  final MapController _mapController = MapController();
  bool _locating = false;

  Future<void> _locateMe() async {
    if (_locating) return;
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
      _mapController.move(LatLng(position.latitude, position.longitude), 15);
    } catch (_) {
      // Best-effort - the button can simply be tapped again.
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pickup = LatLng(widget.pickupLat, widget.pickupLng);
    final hasDest = widget.destLat != null && widget.destLng != null;
    final dest = hasDest ? LatLng(widget.destLat!, widget.destLng!) : null;
    const tileProvider = OpenStreetMapTileProvider();

    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: pickup,
              initialZoom: 14,
              initialCameraFit: dest != null
                  ? CameraFit.coordinates(
                      coordinates: [pickup, dest],
                      padding: const EdgeInsets.fromLTRB(56, 56, 56, 56),
                    )
                  : null,
              interactionOptions: const InteractionOptions(
                flags:
                    InteractiveFlag.pinchZoom |
                    InteractiveFlag.drag |
                    InteractiveFlag.doubleTapZoom,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: tileProvider.urlTemplate,
                userAgentPackageName: tileProvider.userAgentPackageName,
              ),
              if (dest != null)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [pickup, dest],
                      strokeWidth: 4.5,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: pickup,
                    width: 46,
                    height: 46,
                    child: const _MapPin(
                      color: AppColors.primary,
                      icon: Icons.trip_origin_rounded,
                    ),
                  ),
                  if (dest != null)
                    Marker(
                      point: dest,
                      width: 46,
                      height: 46,
                      child: const _MapPin(
                        color: AppColors.accent,
                        icon: Icons.flag_rounded,
                      ),
                    ),
                ],
              ),
            ],
          ),
          Positioned(
            left: 10,
            bottom: 10,
            child: _MapAttribution(text: tileProvider.attribution),
          ),
          Positioned(
            right: 16,
            bottom: 16,
            child: _LocateButton(loading: _locating, onTap: _locateMe),
          ),
        ],
      ),
    );
  }
}

class _MapPin extends StatelessWidget {
  final Color color;
  final IconData icon;
  const _MapPin({required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 18),
    );
  }
}

/// Compact map-tile attribution pill. Deliberately not flutter_map's own
/// `SimpleAttributionWidget` - that widget's internal Row doesn't constrain
/// its own width and overflows on narrow screens, which this fixed-size,
/// ellipsis-truncated pill avoids while still crediting the tile source.
class _MapAttribution extends StatelessWidget {
  final String text;
  const _MapAttribution({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 160),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '© $text',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textDirection: TextDirection.ltr,
        style: const TextStyle(fontSize: 9, color: AppColors.secondaryText),
      ),
    );
  }
}

class _LocateButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;
  const _LocateButton({required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 4,
      shadowColor: Colors.black26,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: loading ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                )
              : const Icon(
                  Icons.my_location_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
        ),
      ),
    );
  }
}
