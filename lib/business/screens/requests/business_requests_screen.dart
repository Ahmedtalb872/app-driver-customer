import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/ride_repository.dart';
import '../../../models/models.dart';
import '../../core/business_colors.dart';

class BusinessRequestsScreen extends StatefulWidget {
  const BusinessRequestsScreen({super.key});

  @override
  State<BusinessRequestsScreen> createState() =>
      _BusinessRequestsScreenState();
}

class _BusinessRequestsScreenState extends State<BusinessRequestsScreen> {
  bool _loading = true;
  List<Trip> _trips = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final trips = await RideRepository.instance.fetchCustomerTrips();
      if (mounted) setState(() => _trips = trips);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _cancel(Trip trip) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إلغاء الطلب'),
        content: const Text('هل أنت متأكد من إلغاء هذا الطلب؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('تراجع'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: BusinessColors.error),
            child: const Text('إلغاء الطلب'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await RideRepository.instance.cancelTrip(trip.id, cancelledBy: 'customer');
      _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر إلغاء الطلب.')),
        );
      }
    }
  }

  bool _canCancel(Trip trip) =>
      trip.status == TripStatus.pending || trip.status == TripStatus.searching;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'طلباتي',
                style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18),
              ),
              Row(
                children: [
                  IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () => context.go('/business/new-request'),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('طلب جديد'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_trips.isEmpty) {
      return const Center(
        child: Text('لا توجد طلبات بعد.', style: TextStyle(fontFamily: 'Cairo')),
      );
    }
    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('النوع')),
            DataColumn(label: Text('من')),
            DataColumn(label: Text('إلى')),
            DataColumn(label: Text('المستلم')),
            DataColumn(label: Text('الحالة')),
            DataColumn(label: Text('الكابتن')),
            DataColumn(label: Text('التاريخ')),
            DataColumn(label: Text('')),
          ],
          rows: _trips.map((trip) {
            return DataRow(
              cells: [
                DataCell(Text(trip.isDelivery ? 'توصيل' : 'مشوار')),
                DataCell(Text(trip.pickupLocation, overflow: TextOverflow.ellipsis)),
                DataCell(Text(trip.destinationLocation, overflow: TextOverflow.ellipsis)),
                DataCell(Text(trip.recipientName ?? '-')),
                DataCell(_statusBadge(trip.status)),
                DataCell(Text(trip.captainName ?? '-')),
                DataCell(Text(trip.date)),
                DataCell(
                  _canCancel(trip)
                      ? IconButton(
                          tooltip: 'إلغاء',
                          icon: const Icon(Icons.cancel_outlined, size: 20, color: BusinessColors.error),
                          onPressed: () => _cancel(trip),
                        )
                      : const SizedBox(),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _statusBadge(TripStatus status) {
    final (label, color) = switch (status) {
      TripStatus.completed => ('مكتملة', BusinessColors.success),
      TripStatus.cancelled => ('ملغاة', BusinessColors.error),
      TripStatus.pending || TripStatus.searching => ('قيد البحث عن كابتن', BusinessColors.warning),
      _ => ('جارية', BusinessColors.primary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}
