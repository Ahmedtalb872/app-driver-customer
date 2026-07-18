import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/services/fare_calculator.dart';
import '../../core/services/ride_repository.dart';
import '../../core/utils/format_utils.dart';
import '../../core/widgets/real_map_widget.dart';
import '../../models/models.dart';
import '../../providers/app_state_provider.dart';
import '../support/chat_screen.dart';
import 'open_trip_controller.dart';
import 'open_trip_summary_screen.dart';

class _ActionConfig {
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback? onTap;
  const _ActionConfig({
    required this.label,
    required this.color,
    required this.icon,
    required this.onTap,
  });
}

class OpenTripActiveScreen extends StatefulWidget {
  const OpenTripActiveScreen({super.key});

  @override
  State<OpenTripActiveScreen> createState() => _OpenTripActiveScreenState();
}

class _OpenTripActiveScreenState extends State<OpenTripActiveScreen> {
  late final OpenTripController _controller;

  @override
  void initState() {
    super.initState();
    // Created once here (not in build), so the meter/GPS state survives
    // any rebuild of this screen for the rest of its lifetime.
    final trip = context.read<AppStateProvider>().activeTrip!;
    _controller = OpenTripController(trip: trip);
    // Real trips start the meter only from the passenger's actual "ركبت"
    // action (see OpenTripController.listenForRemoteBoarding) - a no-op for
    // the still-simulated open_trips_screen.dart browsing flow.
    _controller.listenForRemoteBoarding();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _titleFor(OpenTripStage stage) {
    switch (stage) {
      case OpenTripStage.accepted:
        return 'توجه إلى نقطة الانطلاق';
      case OpenTripStage.arrived:
        return 'وصلت لموقع الراكب';
      case OpenTripStage.onboard:
        return 'الراكب جاهز للانطلاق';
      case OpenTripStage.running:
        return 'مشوار مفتوح جارٍ الآن';
      case OpenTripStage.waiting:
        return 'المشوار متوقف مؤقتاً (انتظار)';
      case OpenTripStage.completed:
        return 'تم إنهاء المشوار';
      case OpenTripStage.cancelled:
        return 'تم إلغاء المشوار';
    }
  }

  _ActionConfig _actionFor(OpenTripStage stage) {
    switch (stage) {
      case OpenTripStage.accepted:
        return _ActionConfig(
          label: 'وصلت إلى الراكب',
          color: AppColors.primary,
          icon: Icons.sports_motorsports_rounded,
          onTap: _handleArrive,
        );
      case OpenTripStage.arrived:
        // Real trips: the passenger must press "ركبت" themselves (spec
        // section 12) - the meter starts automatically via
        // OpenTripController.listenForRemoteBoarding when they do, so this
        // stage shows a waiting state instead of a captain self-report
        // button. The legacy simulated open_trips_screen.dart flow (no real
        // backend id) keeps its original captain-taps-onboard behavior so
        // that still-existing feature keeps working unchanged.
        return _controller.isRealTrip
            ? const _ActionConfig(
                label: 'بانتظار صعود الراكب...',
                color: AppColors.secondaryText,
                icon: Icons.hourglass_top_rounded,
                onTap: null,
              )
            : _ActionConfig(
                label: 'لقد ركب الزبون',
                color: AppColors.secondary,
                icon: Icons.person_add_alt_1_rounded,
                onTap: () => _controller.markPassengerOnboard(),
              );
      case OpenTripStage.onboard:
        return _ActionConfig(
          label: 'ابدأ المشوار المفتوح',
          color: AppColors.success,
          icon: Icons.play_arrow_rounded,
          onTap: () async {
            final started = await _controller.startTrip();
            if (started && mounted) {
              context.read<AppStateProvider>().captainStartActiveTrip();
            }
          },
        );
      case OpenTripStage.running:
      case OpenTripStage.waiting:
        return _ActionConfig(
          label: 'إنهاء المشوار',
          color: AppColors.error,
          icon: Icons.flag_rounded,
          onTap: _handleCompleteTrip,
        );
      case OpenTripStage.completed:
      case OpenTripStage.cancelled:
        return const _ActionConfig(
          label: '',
          color: AppColors.secondaryText,
          icon: Icons.check,
          onTap: null,
        );
    }
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String message,
    required String confirmLabel,
    required Color confirmColor,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          content: Text(
            message,
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
            textAlign: TextAlign.center,
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('تراجع'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: confirmColor,
                    ),
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text(confirmLabel),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  void _simulateCall(String name) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text(
            'اتصال هاتفي',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          content: Text(
            'جاري الاتصال بـ $name...\n(+222 44444444)',
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
            textAlign: TextAlign.center,
          ),
          actions: [
            Center(
              child: ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                ),
                icon: const Icon(Icons.call_end_rounded),
                label: const Text('إنهاء المكالمة'),
              ),
            ),
          ],
        );
      },
    );
  }

  bool _arriving = false;

  Future<void> _handleArrive() async {
    if (_arriving) return; // Prevent repeated taps / duplicate arrive calls.
    _arriving = true;
    try {
      if (_controller.isRealTrip) {
        await RideRepository.instance.arriveTrip(_controller.trip.id);
      }
      _controller.markArrived();
      if (mounted) {
        context.read<AppStateProvider>().captainArriveAtPickup();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر تسجيل الوصول، حاول مجدداً')),
        );
      }
    } finally {
      _arriving = false;
    }
  }

  bool _completingTrip = false;

  Future<void> _handleCompleteTrip() async {
    if (_completingTrip) return; // Prevent ending the trip twice.
    final confirmed = await _showConfirmDialog(
      title: 'إنهاء المشوار',
      message:
          'هل أنت متأكد من إنهاء المشوار المفتوح؟ سيتم احتساب الأجرة النهائية وإيقاف تتبع المسافة والوقت.',
      confirmLabel: 'نعم، إنهاء المشوار',
      confirmColor: AppColors.error,
    );
    if (confirmed != true || !mounted) return;
    _completingTrip = true;

    final fare = _controller.fareBreakdown;
    final finalPosition = _controller.currentPosition;
    final distanceKm = _controller.distanceKm;
    final movingDuration = _controller.movingDuration;
    final waitingDuration = _controller.waitingDuration;

    _controller.completeTrip();

    if (_controller.isRealTrip) {
      try {
        // The server recomputes final fare/commission/net earnings from
        // `pricing_config` - it is the source of truth, never the client's
        // own live-meter estimate (spec section 23).
        final completed = await RideRepository.instance.endTrip(
          tripId: _controller.trip.id,
          finalDistanceKm: distanceKm,
        );
        if (mounted) {
          context.read<AppStateProvider>().applyBackendTripCompletion(
            completed,
          );
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تعذر إنهاء الرحلة، حاول مجدداً')),
          );
        }
        _completingTrip = false;
        return;
      }
    } else {
      context.read<AppStateProvider>().captainCompleteOpenTrip(
        distanceKm: distanceKm,
        movingDuration: movingDuration,
        waitingDuration: waitingDuration,
        fare: fare,
        finalLat: finalPosition?.latitude,
        finalLng: finalPosition?.longitude,
      );
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const OpenTripSummaryScreen()),
    );
  }

  Future<void> _handleCancelTrip() async {
    final confirmed = await _showConfirmDialog(
      title: 'إلغاء المشوار',
      message: 'هل أنت متأكد من إلغاء هذا المشوار؟ لن يتم احتساب أي أجرة.',
      confirmLabel: 'نعم، إلغاء المشوار',
      confirmColor: AppColors.error,
    );
    if (confirmed != true || !mounted) return;

    _controller.cancelTrip();
    context.read<AppStateProvider>().captainCancelActiveTrip();

    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final stage = _controller.stage;
        final action = _actionFor(stage);
        final fare = _controller.fareBreakdown;
        final trip = _controller.trip;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: Text(_titleFor(stage)),
            automaticallyImplyLeading: false,
          ),
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      RealMapWidget(
                        showRoute: false,
                        pickupLat: trip.pickupLat,
                        pickupLng: trip.pickupLng,
                        carLat: _controller.currentPosition?.latitude,
                        carLng: _controller.currentPosition?.longitude,
                        tracePolyline: _controller.tracePoints,
                      ),
                      Positioned(top: 16, right: 16, child: _mapBadge()),
                      if (stage == OpenTripStage.running ||
                          stage == OpenTripStage.waiting)
                        Positioned(
                          top: 16,
                          left: 16,
                          child: _mapFareChip(fare),
                        ),
                      if (!_controller.gpsAvailable &&
                          _controller.locationError != null)
                        Positioned(
                          bottom: 16,
                          left: 16,
                          right: 16,
                          child: _gpsWarningBanner(),
                        ),
                    ],
                  ),
                ),
                _buildBottomSheet(context, stage, action, fare, trip),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _mapBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.accent),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.all_inclusive_rounded,
            size: 14,
            color: AppColors.darkText,
          ),
          SizedBox(width: 6),
          Text(
            'مشوار مفتوح',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.darkText,
              fontFamily: 'Cairo',
            ),
          ),
        ],
      ),
    );
  }

  Widget _mapFareChip(FareBreakdown fare) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        children: [
          Text(
            FormatUtils.fare(fare.total),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: AppColors.primary,
            ),
          ),
          const Text(
            'الأجرة الحالية',
            style: TextStyle(
              fontSize: 10,
              color: AppColors.secondaryText,
              fontFamily: 'Cairo',
            ),
          ),
        ],
      ),
    );
  }

  Widget _gpsWarningBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: Row(
        children: [
          const Icon(Icons.gps_off_rounded, color: AppColors.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _controller.locationError ?? 'تعذر الوصول لإشارة GPS مؤقتاً.',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.error,
                fontFamily: 'Cairo',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSheet(
    BuildContext context,
    OpenTripStage stage,
    _ActionConfig action,
    FareBreakdown fare,
    Trip trip,
  ) {
    final isRunningOrWaiting =
        stage == OpenTripStage.running || stage == OpenTripStage.waiting;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 14)],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isRunningOrWaiting) ...[
                _buildMeterPanel(fare, stage),
                const SizedBox(height: 16),
              ] else ...[
                _buildAddressRow(trip),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: AppColors.primary,
                        size: 18,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'الوجهة غير محددة، يتم احتساب الأجرة حسب الوقت والمسافة.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppColors.primary,
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              _buildPassengerRow(context, trip),
              const SizedBox(height: 16),

              if (isRunningOrWaiting)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: OutlinedButton.icon(
                    onPressed: () => _controller.toggleWaiting(),
                    icon: Icon(
                      stage == OpenTripStage.waiting
                          ? Icons.play_circle_outline_rounded
                          : Icons.pause_circle_outline_rounded,
                    ),
                    label: Text(
                      stage == OpenTripStage.waiting
                          ? 'إنهاء الانتظار'
                          : 'بدء الانتظار',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: stage == OpenTripStage.waiting
                          ? AppColors.error
                          : AppColors.darkText,
                      side: BorderSide(
                        color: stage == OpenTripStage.waiting
                            ? AppColors.error
                            : AppColors.accent,
                      ),
                    ),
                  ),
                ),

              if (stage != OpenTripStage.completed &&
                  stage != OpenTripStage.cancelled)
                ElevatedButton(
                  onPressed: action.onTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: action.color,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(action.label),
                      const SizedBox(width: 8),
                      Icon(action.icon),
                    ],
                  ),
                ),

              if (!_controller.gpsAvailable &&
                  _controller.locationError != null) ...[
                const SizedBox(height: 12),
                _gpsWarningBanner(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMeterPanel(FareBreakdown fare, OpenTripStage stage) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withOpacity(0.15)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _meterStat(
                'مدة الرحلة',
                FormatUtils.duration(_controller.totalDuration),
                Icons.timer_outlined,
              ),
              Container(width: 1, height: 36, color: AppColors.border),
              _meterStat(
                'المسافة المقطوعة',
                FormatUtils.km(_controller.distanceKm),
                Icons.route_rounded,
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'الأجرة الحالية',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkText,
                  fontFamily: 'Cairo',
                ),
              ),
              Text(
                FormatUtils.fare(fare.total),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                  fontFamily: 'Cairo',
                ),
              ),
            ],
          ),
          if (stage == OpenTripStage.waiting) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.hourglass_top_rounded,
                    size: 14,
                    color: AppColors.warning,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'وضع الانتظار مفعّل',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.warning,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _meterStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primary, size: 18),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.darkText,
            fontFamily: 'Cairo',
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: AppColors.secondaryText,
            fontFamily: 'Cairo',
          ),
        ),
      ],
    );
  }

  Widget _buildAddressRow(Trip trip) {
    return Row(
      children: [
        const Icon(
          Icons.radio_button_checked_rounded,
          color: AppColors.success,
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'نقطة الانطلاق',
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.secondaryText,
                  fontFamily: 'Cairo',
                ),
              ),
              Text(
                trip.pickupLocation,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: AppColors.darkText,
                  fontFamily: 'Cairo',
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPassengerRow(BuildContext context, Trip trip) {
    return Row(
      children: [
        const CircleAvatar(
          radius: 20,
          backgroundColor: AppColors.primary,
          child: Icon(Icons.person, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                trip.customerName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  fontFamily: 'Cairo',
                ),
              ),
              Text(
                trip.customerPhone,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.secondaryText,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(
            Icons.chat_bubble_outline_rounded,
            color: AppColors.primary,
            size: 20,
          ),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const ChatScreen(showAppBar: true),
              ),
            );
          },
        ),
        IconButton(
          icon: const Icon(
            Icons.call_outlined,
            color: AppColors.primary,
            size: 20,
          ),
          onPressed: () => _simulateCall(trip.customerName),
        ),
        IconButton(
          icon: const Icon(
            Icons.cancel_outlined,
            color: AppColors.error,
            size: 20,
          ),
          onPressed: _handleCancelTrip,
        ),
      ],
    );
  }
}
