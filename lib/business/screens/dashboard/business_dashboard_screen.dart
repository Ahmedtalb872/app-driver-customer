import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/services/ride_repository.dart';
import '../../../models/models.dart';
import '../../core/business_colors.dart';
import '../../services/business_session.dart';

class BusinessDashboardScreen extends StatefulWidget {
  const BusinessDashboardScreen({super.key});

  @override
  State<BusinessDashboardScreen> createState() =>
      _BusinessDashboardScreenState();
}

class _BusinessDashboardScreenState extends State<BusinessDashboardScreen> {
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

  bool _isActive(Trip t) => !(t.status == TripStatus.completed ||
      t.status == TripStatus.cancelled);

  @override
  Widget build(BuildContext context) {
    final account = context.watch<BusinessSession>().account;
    final total = _trips.length;
    final active = _trips.where(_isActive).length;
    final completed =
        _trips.where((t) => t.status == TripStatus.completed).length;
    final cancelled =
        _trips.where((t) => t.status == TripStatus.cancelled).length;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'أهلاً، ${account?.businessName ?? ''}',
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                                color: BusinessColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'هذا ملخص طلبات المشاوير والتوصيل الخاصة بك',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 12,
                                color: BusinessColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: () => context.go('/business/new-request'),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('طلب مشوار جديد'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final cards = [
                        _StatCard(
                          label: 'إجمالي الطلبات',
                          value: '$total',
                          icon: Icons.route_rounded,
                        ),
                        _StatCard(
                          label: 'قيد التنفيذ',
                          value: '$active',
                          icon: Icons.pending_actions_rounded,
                          color: BusinessColors.warning,
                        ),
                        _StatCard(
                          label: 'مكتملة',
                          value: '$completed',
                          icon: Icons.check_circle_rounded,
                          color: BusinessColors.success,
                        ),
                        _StatCard(
                          label: 'ملغاة',
                          value: '$cancelled',
                          icon: Icons.cancel_rounded,
                          color: BusinessColors.error,
                        ),
                      ];
                      final isWide = constraints.maxWidth > 760;
                      if (isWide) {
                        return Row(
                          children: [
                            for (final c in cards) ...[
                              Expanded(child: c),
                              if (c != cards.last) const SizedBox(width: 16),
                            ],
                          ],
                        );
                      }
                      return Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: cards
                            .map((c) => SizedBox(width: 220, child: c))
                            .toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'آخر الطلبات',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: BusinessColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_trips.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          'لا توجد طلبات بعد - اضغط "طلب مشوار جديد" لبدء أول طلب.',
                          style: TextStyle(fontFamily: 'Cairo'),
                        ),
                      ),
                    )
                  else
                    Card(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('النوع')),
                            DataColumn(label: Text('من')),
                            DataColumn(label: Text('إلى')),
                            DataColumn(label: Text('الحالة')),
                            DataColumn(label: Text('التاريخ')),
                          ],
                          rows: _trips.take(5).map((trip) {
                            return DataRow(
                              cells: [
                                DataCell(Text(trip.isDelivery ? 'توصيل' : 'مشوار')),
                                DataCell(Text(trip.pickupLocation)),
                                DataCell(Text(trip.destinationLocation)),
                                DataCell(_statusBadge(trip.status)),
                                DataCell(Text(trip.date)),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _statusBadge(TripStatus status) {
    final (label, color) = switch (status) {
      TripStatus.completed => ('مكتملة', BusinessColors.success),
      TripStatus.cancelled => ('ملغاة', BusinessColors.error),
      TripStatus.pending || TripStatus.searching => ('قيد البحث', BusinessColors.warning),
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

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.color = BusinessColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    color: BusinessColors.textSecondary,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: color),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.bold,
                fontSize: 26,
                color: BusinessColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
