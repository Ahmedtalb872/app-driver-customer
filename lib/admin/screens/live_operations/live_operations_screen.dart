import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/admin_colors.dart';
import '../../models/captain_admin_view.dart';
import '../../repositories/admin_captains_repository.dart';
import '../../repositories/admin_trips_repository.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/status_badge.dart';
import '../trips/trip_detail_panel.dart';

/// Live monitoring view: currently active trips and online captains, backed
/// by Supabase Realtime (see `AdminTripsRepository.watchActiveTrips` /
/// `AdminCaptainsRepository.watchOnlineCaptains`) instead of polling. Built
/// entirely on the existing `trips`/`captains` tables - no new schema.
/// There is no live captain-location column yet, so this is a live *list*
/// view rather than a live map.
class LiveOperationsScreen extends StatefulWidget {
  const LiveOperationsScreen({super.key});

  @override
  State<LiveOperationsScreen> createState() => _LiveOperationsScreenState();
}

class _LiveOperationsScreenState extends State<LiveOperationsScreen> {
  final _tripsRepository = AdminTripsRepository();
  final _captainsRepository = AdminCaptainsRepository();

  static const _statusLabels = {
    'searching': 'قيد البحث',
    'accepted': 'مقبولة',
    'arrived': 'وصل الكابتن',
    'in_progress': 'جارية',
  };

  StreamSubscription<List<Map<String, dynamic>>>? _tripsSub;
  StreamSubscription<List<CaptainAdminView>>? _captainsSub;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _activeTrips = [];
  List<CaptainAdminView> _onlineCaptains = [];
  DateTime? _lastUpdated;

  @override
  void initState() {
    super.initState();
    _tripsSub = _tripsRepository.watchActiveTrips().listen(
      (trips) {
        if (!mounted) return;
        setState(() {
          _activeTrips = trips;
          _loading = false;
          _error = null;
          _lastUpdated = DateTime.now();
        });
      },
      onError: (_) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'تعذر تحميل بيانات العمليات المباشرة.';
        });
      },
    );
    _captainsSub = _captainsRepository.watchOnlineCaptains(limit: 50).listen((
      captains,
    ) {
      if (!mounted) return;
      setState(() {
        _onlineCaptains = captains;
        _lastUpdated = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    _tripsSub?.cancel();
    _captainsSub?.cancel();
    super.dispose();
  }

  /// Immediate re-fetch for the manual refresh button and after an action
  /// taken from [TripDetailPanel] (assign/cancel/notes) - the Realtime
  /// subscriptions above will also pick up the same change shortly after,
  /// this just avoids waiting on that round-trip for the UI to update.
  Future<void> _manualRefresh() async {
    try {
      final results = await Future.wait([
        _tripsRepository.loadActiveTrips(),
        _captainsRepository.loadCaptains(onlineFilter: true, limit: 50),
      ]);
      if (!mounted) return;
      setState(() {
        _activeTrips = results[0] as List<Map<String, dynamic>>;
        _onlineCaptains = results[1] as List<CaptainAdminView>;
        _lastUpdated = DateTime.now();
        _error = null;
      });
    } catch (_) {
      // The Realtime subscriptions above will recover; ignore a transient
      // manual-refresh failure rather than surfacing a duplicate error.
    }
  }

  Future<void> _openDetails(Map<String, dynamic> trip) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          TripDetailPanel(trip: trip, onChanged: _manualRefresh),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null && _activeTrips.isEmpty && _onlineCaptains.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(fontFamily: 'Cairo')),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _manualRefresh,
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      );
    }

    final searching = _activeTrips
        .where((t) => t['status'] == 'searching')
        .length;
    final onTrip = _activeTrips
        .where(
          (t) =>
              t['status'] == 'accepted' ||
              t['status'] == 'arrived' ||
              t['status'] == 'in_progress',
        )
        .length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _liveDot(),
              const SizedBox(width: 8),
              const Text(
                'مباشر - تحديث فوري عبر Supabase Realtime',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  color: AdminColors.textSecondary,
                ),
              ),
              const Spacer(),
              if (_lastUpdated != null)
                Text(
                  'آخر تحديث: ${_lastUpdated!.hour.toString().padLeft(2, '0')}:${_lastUpdated!.minute.toString().padLeft(2, '0')}:${_lastUpdated!.second.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    color: AdminColors.textSecondary,
                  ),
                ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _manualRefresh,
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'تحديث الآن',
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth > 900
                  ? 4
                  : constraints.maxWidth > 600
                  ? 2
                  : 1;
              final cards = [
                StatCard(
                  label: 'رحلات قيد البحث عن كابتن',
                  value: '$searching',
                  icon: Icons.search_rounded,
                  color: AdminColors.warning,
                ),
                StatCard(
                  label: 'رحلات جارية',
                  value: '$onTrip',
                  icon: Icons.local_taxi_rounded,
                  color: AdminColors.primary,
                ),
                StatCard(
                  label: 'إجمالي الرحلات النشطة',
                  value: '${_activeTrips.length}',
                  icon: Icons.bolt_rounded,
                  color: AdminColors.secondary,
                ),
                StatCard(
                  label: 'كباتن متصلون الآن',
                  value: '${_onlineCaptains.length}',
                  icon: Icons.wifi_tethering_rounded,
                  color: AdminColors.success,
                ),
              ];
              return GridView.count(
                crossAxisCount: columns,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 2.6,
                children: cards,
              );
            },
          ),
          const SizedBox(height: 24),
          const Text(
            'الرحلات النشطة الآن',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AdminColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _buildActiveTripsTable(),
          const SizedBox(height: 24),
          const Text(
            'الكباتن المتصلون الآن',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AdminColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _buildOnlineCaptainsList(),
        ],
      ),
    );
  }

  Widget _liveDot() {
    return Container(
      width: 10,
      height: 10,
      decoration: const BoxDecoration(
        color: AdminColors.success,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildActiveTripsTable() {
    if (_activeTrips.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: Text(
              'لا توجد رحلات نشطة حالياً.',
              style: TextStyle(fontFamily: 'Cairo'),
            ),
          ),
        ),
      );
    }

    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('رقم الرحلة')),
            DataColumn(label: Text('الحالة')),
            DataColumn(label: Text('الزبون')),
            DataColumn(label: Text('الكابتن')),
            DataColumn(label: Text('من')),
            DataColumn(label: Text('إلى')),
            DataColumn(label: Text('وقت الطلب')),
          ],
          rows: _activeTrips.map((trip) {
            final status = trip['status'] as String? ?? '';
            final customer =
                trip['customers']?['profiles'] as Map<String, dynamic>?;
            final captain =
                trip['captains']?['profiles'] as Map<String, dynamic>?;
            final requestedAt = trip['requested_at'] as String?;
            return DataRow(
              onSelectChanged: (_) => _openDetails(trip),
              cells: [
                DataCell(Text((trip['id'] as String).substring(0, 8))),
                DataCell(StatusBadge.warning(_statusLabels[status] ?? status)),
                DataCell(Text(customer?['full_name'] as String? ?? '-')),
                DataCell(
                  Text(captain?['full_name'] as String? ?? 'بدون كابتن'),
                ),
                DataCell(Text(trip['pickup_address'] as String? ?? '-')),
                DataCell(Text(trip['destination_address'] as String? ?? '-')),
                DataCell(
                  Text(
                    requestedAt == null
                        ? '-'
                        : requestedAt.split('T').last.substring(0, 5),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildOnlineCaptainsList() {
    if (_onlineCaptains.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: Text(
              'لا يوجد كباتن متصلون حالياً.',
              style: TextStyle(fontFamily: 'Cairo'),
            ),
          ),
        ),
      );
    }

    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('الاسم')),
            DataColumn(label: Text('الهاتف')),
            DataColumn(label: Text('نوع المركبة')),
            DataColumn(label: Text('الحالة')),
          ],
          rows: _onlineCaptains.map((captain) {
            return DataRow(
              cells: [
                DataCell(Text(captain.fullName)),
                DataCell(Text(captain.phone ?? '-')),
                DataCell(Text(captain.vehicleType ?? '-')),
                DataCell(StatusBadge.success('متصل')),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
