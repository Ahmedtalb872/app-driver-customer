import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/colors.dart';
import '../../core/services/ride_repository.dart';
import '../../core/widgets/real_map_widget.dart';
import '../../models/models.dart';
import '../../providers/app_state_provider.dart';
import 'trip_summary_screen.dart';

/// Watches a single trip (see [RideRepository.watchTrip]) from the moment a
/// customer requests it through to completion or cancellation, rendering
/// the matching UI for each [TripStatus] along the way.
class TripTrackingScreen extends StatefulWidget {
  const TripTrackingScreen({super.key, required this.tripId});

  final String tripId;

  @override
  State<TripTrackingScreen> createState() => _TripTrackingScreenState();
}

class _TripTrackingScreenState extends State<TripTrackingScreen> {
  StreamSubscription<Trip?>? _sub;
  Trip? _trip;
  bool _handledTerminal = false;
  bool _isCancelling = false;

  @override
  void initState() {
    super.initState();
    _sub = RideRepository.instance.watchTrip(widget.tripId).listen(_onTrip);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _onTrip(Trip? trip) {
    if (!mounted) return;
    setState(() => _trip = trip);
    if (trip == null || _handledTerminal) return;

    context.read<AppStateProvider>().setActiveTripFromBackend(trip);

    if (trip.status == TripStatus.completed) {
      _handledTerminal = true;
      context.read<AppStateProvider>().archiveActiveTrip();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => TripSummaryScreen(trip: trip)),
        );
      });
    } else if (trip.status == TripStatus.cancelled) {
      _handledTerminal = true;
      context.read<AppStateProvider>()
        ..archiveActiveTrip()
        ..setActiveTripFromBackend(null);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تم إلغاء المشوار.',
              style: TextStyle(fontFamily: 'Cairo'),
            ),
          ),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
      });
    }
  }

  Future<void> _cancelTrip() async {
    setState(() => _isCancelling = true);
    try {
      await RideRepository.instance.cancelTrip(
        widget.tripId,
        cancelledBy: 'customer',
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تعذر إلغاء المشوار الآن، حاول مرة أخرى.',
              style: TextStyle(fontFamily: 'Cairo'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  Future<void> _callCaptain(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final trip = _trip;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: trip == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                Positioned.fill(
                  child: RealMapWidget(
                    status: trip.status,
                    showRoute: trip.status == TripStatus.started,
                    interactive: true,
                    pickupLat: trip.pickupLat,
                    pickupLng: trip.pickupLng,
                    destLat: trip.isOpenTrip ? null : trip.destLat,
                    destLng: trip.isOpenTrip ? null : trip.destLng,
                    carLat: trip.captainLat,
                    carLng: trip.captainLng,
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: _buildTopBanner(trip),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: SafeArea(top: false, child: _buildBottomCard(trip)),
                ),
              ],
            ),
    );
  }

  Widget _buildTopBanner(Trip trip) {
    final (text, color) = switch (trip.status) {
      TripStatus.searching => ('جاري البحث عن كابتن قريب منك...', AppColors.primary),
      TripStatus.accepted => ('الكابتن في الطريق إليك', AppColors.primary),
      TripStatus.enRoute => ('الكابتن في الطريق إليك', AppColors.primary),
      TripStatus.arrived => ('وصل الكابتن إلى موقعك', AppColors.success),
      TripStatus.started => ('الرحلة جارية الآن', AppColors.primary),
      _ => (trip.statusArabic, AppColors.secondaryText),
    };
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(30),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (trip.status == TripStatus.searching)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            else
              const Icon(Icons.local_taxi_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
                fontFamily: 'Cairo',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomCard(Trip trip) {
    final canCancel =
        trip.status == TripStatus.searching || trip.status == TripStatus.accepted;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 14)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (trip.captainName != null && trip.captainName!.isNotEmpty)
            _buildCaptainCard(trip)
          else
            Text(
              trip.isOpenTrip ? 'مشوار مفتوح' : trip.destinationLocation,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          const SizedBox(height: 16),
          if (canCancel)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _isCancelling ? null : _cancelTrip,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                ),
                child: _isCancelling
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('إلغاء المشوار'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCaptainCard(Trip trip) {
    return Row(
      children: [
        CircleAvatar(
          radius: 26,
          backgroundColor: AppColors.primary.withOpacity(0.1),
          child: Text(
            trip.captainName!.isNotEmpty ? trip.captainName!.substring(0, 1) : '؟',
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                trip.captainName!,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              if (trip.vehicleName != null || trip.vehiclePlate != null)
                Text(
                  [
                    trip.vehicleName,
                    trip.vehiclePlate,
                  ].where((s) => (s ?? '').isNotEmpty).join(' - '),
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11,
                    color: AppColors.secondaryText,
                  ),
                ),
            ],
          ),
        ),
        IconButton.filledTonal(
          onPressed: () => _callCaptain(trip.captainPhone),
          icon: const Icon(Icons.call_rounded),
        ),
      ],
    );
  }
}
