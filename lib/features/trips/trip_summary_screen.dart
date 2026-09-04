import 'package:flutter/material.dart';

import '../../core/constants/colors.dart';
import '../../core/services/ride_repository.dart';
import '../../core/services/saved_places_repository.dart';
import '../../models/models.dart';

/// Shown once [TripTrackingScreen] sees a trip reach [TripStatus.completed]
/// - a fare/route recap, an offer to save the pickup/destination as a
/// labeled place (see [_buildSavePlacesCard]/[SavedPlacesRepository]), then
/// a 1-5 star rating for the captain with an optional written note before
/// returning to the home screen (see [RideRepository.rateTrip]).
class TripSummaryScreen extends StatefulWidget {
  const TripSummaryScreen({super.key, required this.trip});

  final Trip trip;

  @override
  State<TripSummaryScreen> createState() => _TripSummaryScreenState();
}

class _TripSummaryScreenState extends State<TripSummaryScreen> {
  final _noteController = TextEditingController();
  int _rating = 0;
  bool _isSubmitting = false;
  String? _error;

  /// Which of 'pickup'/'destination' currently has a save-place request in
  /// flight, if any - disables just that row's chips instead of the whole
  /// card while it saves.
  String? _savingSide;

  /// label ('home'/'work'/'school') most recently saved for each side, so
  /// the matching chip can show a checkmark instead of just going quiet.
  final Map<String, String> _savedLabelBySide = {};

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _goHome() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _submitRating() async {
    if (_rating == 0) return;
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await RideRepository.instance.rateTrip(
        widget.trip.id,
        rating: _rating,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      );
      if (!mounted) return;
      _goHome();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _error = 'تعذر إرسال التقييم الآن، تحقق من الاتصال وحاول مرة أخرى.';
      });
    }
  }

  Future<void> _savePlace({
    required String side,
    required String label,
    required String address,
    required double lat,
    required double lng,
  }) async {
    setState(() => _savingSide = side);
    try {
      await SavedPlacesRepository.instance.savePlace(
        label: label,
        address: address,
        lat: lat,
        lng: lng,
      );
      if (!mounted) return;
      setState(() {
        _savingSide = null;
        _savedLabelBySide[side] = label;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _savingSide = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تعذر حفظ الموقع الآن، حاول مرة أخرى.',
            style: TextStyle(fontFamily: 'Cairo'),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.success,
                  size: 64,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'وصلت بسلام!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkText,
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'شكراً لاستخدامك الهدهد.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.secondaryText,
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 24),
              _buildTripInfoCard(trip),
              const SizedBox(height: 16),
              _buildSavePlacesCard(trip),
              const SizedBox(height: 16),
              _buildRatingCard(trip),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTripInfoCard(Trip trip) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildRouteRow(
              Icons.radio_button_checked_rounded,
              AppColors.success,
              trip.pickupLocation,
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4, horizontal: 9),
              child: SizedBox(
                height: 16,
                child: VerticalDivider(width: 2, thickness: 2),
              ),
            ),
            _buildRouteRow(
              Icons.location_on_rounded,
              AppColors.error,
              trip.isOpenTrip ? 'الوجهة النهائية' : trip.destinationLocation,
            ),
            const Divider(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStat(Icons.route_rounded, '${trip.distance.toStringAsFixed(1)} كم', 'المسافة'),
                _buildStat(Icons.payments_rounded, trip.paymentMethod, 'طريقة الدفع'),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  const Text(
                    'المبلغ الإجمالي',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11,
                      color: AppColors.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${trip.price.toStringAsFixed(0)} أوقية',
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                      color: AppColors.secondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteRow(IconData icon, Color color, String label) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildStat(IconData icon, String value, String label) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.secondaryText),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: AppColors.darkText,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 10,
                color: AppColors.secondaryText,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Offers to save the pickup and (for a normal trip with a known
  /// destination) the destination as المنزل/العمل/المدرسة - skipped
  /// entirely for an open trip's destination, which has no fixed point to
  /// save. Each side saves independently and shows its own saved-label
  /// checkmark once done.
  Widget _buildSavePlacesCard(Trip trip) {
    final hasDestination = !trip.isOpenTrip;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'احفظ هذا الموقع لمشاويرك القادمة',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: AppColors.darkText,
              ),
            ),
            const SizedBox(height: 16),
            _buildSavePlaceRow(
              side: 'pickup',
              icon: Icons.radio_button_checked_rounded,
              iconColor: AppColors.success,
              address: trip.pickupLocation,
              lat: trip.pickupLat,
              lng: trip.pickupLng,
            ),
            if (hasDestination) ...[
              const SizedBox(height: 16),
              _buildSavePlaceRow(
                side: 'destination',
                icon: Icons.location_on_rounded,
                iconColor: AppColors.error,
                address: trip.destinationLocation,
                lat: trip.destLat,
                lng: trip.destLng,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSavePlaceRow({
    required String side,
    required IconData icon,
    required Color iconColor,
    required String address,
    required double lat,
    required double lng,
  }) {
    final savedLabel = _savedLabelBySide[side];
    final isSaving = _savingSide == side;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: iconColor, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                address,
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildLabelChip(
              side: side,
              label: 'home',
              icon: Icons.home_rounded,
              text: 'المنزل',
              saved: savedLabel == 'home',
              isSaving: isSaving,
              onTap: () => _savePlace(
                side: side,
                label: 'home',
                address: address,
                lat: lat,
                lng: lng,
              ),
            ),
            const SizedBox(width: 8),
            _buildLabelChip(
              side: side,
              label: 'work',
              icon: Icons.work_rounded,
              text: 'العمل',
              saved: savedLabel == 'work',
              isSaving: isSaving,
              onTap: () => _savePlace(
                side: side,
                label: 'work',
                address: address,
                lat: lat,
                lng: lng,
              ),
            ),
            const SizedBox(width: 8),
            _buildLabelChip(
              side: side,
              label: 'school',
              icon: Icons.school_rounded,
              text: 'المدرسة',
              saved: savedLabel == 'school',
              isSaving: isSaving,
              onTap: () => _savePlace(
                side: side,
                label: 'school',
                address: address,
                lat: lat,
                lng: lng,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLabelChip({
    required String side,
    required String label,
    required IconData icon,
    required String text,
    required bool saved,
    required bool isSaving,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: OutlinedButton.icon(
        onPressed: isSaving ? null : onTap,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 8),
          backgroundColor: saved ? AppColors.accent.withOpacity(0.12) : null,
          side: BorderSide(color: saved ? AppColors.accent : AppColors.border),
          foregroundColor: saved ? AppColors.secondary : AppColors.darkText,
        ),
        icon: Icon(saved ? Icons.check_circle_rounded : icon, size: 15),
        label: Text(
          text,
          style: const TextStyle(fontFamily: 'Cairo', fontSize: 11),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildRatingCard(Trip trip) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              trip.captainName != null && trip.captainName!.isNotEmpty
                  ? 'قيّم رحلتك مع ${trip.captainName}'
                  : 'قيّم رحلتك مع الكابتن',
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: AppColors.darkText,
              ),
            ),
            const SizedBox(height: 14),
            _buildStarRow(),
            const SizedBox(height: 16),
            TextField(
              controller: _noteController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'ملاحظة (اختياري)',
                hintText: 'اكتب ملاحظتك عن الكابتن أو الرحلة...',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  color: AppColors.error,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_rating == 0 || _isSubmitting) ? null : _submitRating,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.darkText,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('إرسال التقييم'),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: TextButton(
                onPressed: _isSubmitting ? null : _goHome,
                child: const Text('تخطي'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStarRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        final starValue = index + 1;
        final filled = starValue <= _rating;
        return IconButton(
          onPressed: () => setState(() => _rating = starValue),
          icon: Icon(
            filled ? Icons.star_rounded : Icons.star_border_rounded,
            color: AppColors.accent,
            size: 34,
          ),
        );
      }),
    );
  }
}
