import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/admin_colors.dart';
import '../../models/dashboard_stats.dart';
import '../../repositories/admin_dashboard_repository.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/status_badge.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _repository = AdminDashboardRepository();
  final _currency = NumberFormat.decimalPattern('ar');

  bool _loading = true;
  String? _error;
  DashboardStats _stats = const DashboardStats();
  List<Map<String, dynamic>> _tripsPerDay = [];
  List<Map<String, dynamic>> _recentTrips = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _repository.loadStats(),
        _repository.loadTripsPerDay(),
        _repository.loadRecentTrips(),
      ]);
      setState(() {
        _stats = results[0] as DashboardStats;
        _tripsPerDay = results[1] as List<Map<String, dynamic>>;
        _recentTrips = results[2] as List<Map<String, dynamic>>;
      });
    } catch (e) {
      setState(() => _error = 'تعذر تحميل الإحصائيات، حاول مجدداً.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(fontFamily: 'Cairo')),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _load,
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth > 1100
                    ? 5
                    : constraints.maxWidth > 800
                    ? 3
                    : constraints.maxWidth > 500
                    ? 2
                    : 1;
                final cards = [
                  StatCard(
                    label: 'إجمالي الكباتن',
                    value: '${_stats.totalCaptains}',
                    icon: Icons.local_taxi_rounded,
                    color: AdminColors.secondary,
                  ),
                  StatCard(
                    label: 'كباتن معتمدون',
                    value: '${_stats.approvedCaptains}',
                    icon: Icons.verified_rounded,
                    color: AdminColors.success,
                  ),
                  StatCard(
                    label: 'كباتن قيد المراجعة',
                    value: '${_stats.pendingCaptains}',
                    icon: Icons.hourglass_top_rounded,
                    color: AdminColors.warning,
                  ),
                  StatCard(
                    label: 'كباتن متصلون الآن',
                    value: '${_stats.onlineCaptains}',
                    icon: Icons.wifi_tethering_rounded,
                    color: AdminColors.accent,
                  ),
                  StatCard(
                    label: 'إجمالي الرحلات',
                    value: '${_stats.totalTrips}',
                    icon: Icons.route_rounded,
                    color: AdminColors.primary,
                  ),
                  StatCard(
                    label: 'رحلات نشطة',
                    value: '${_stats.activeTrips}',
                    icon: Icons.directions_car_rounded,
                    color: AdminColors.secondary,
                  ),
                  StatCard(
                    label: 'رحلات مكتملة',
                    value: '${_stats.completedTrips}',
                    icon: Icons.check_circle_rounded,
                    color: AdminColors.success,
                  ),
                  StatCard(
                    label: 'رحلات ملغاة',
                    value: '${_stats.cancelledTrips}',
                    icon: Icons.cancel_rounded,
                    color: AdminColors.error,
                  ),
                  StatCard(
                    label: 'رحلات اليوم',
                    value: '${_stats.tripsToday}',
                    icon: Icons.today_rounded,
                    color: AdminColors.primary,
                  ),
                  StatCard(
                    label: 'كباتن جدد اليوم',
                    value: '${_stats.newCaptainsToday}',
                    icon: Icons.person_add_alt_1_rounded,
                    color: AdminColors.secondary,
                  ),
                  StatCard(
                    label: 'إيرادات المنصة',
                    value: _currency.format(_stats.platformRevenue),
                    icon: Icons.trending_up_rounded,
                    color: AdminColors.success,
                  ),
                  StatCard(
                    label: 'أرباح الكباتن',
                    value: _currency.format(_stats.captainEarnings),
                    icon: Icons.savings_rounded,
                    color: AdminColors.accent,
                  ),
                  StatCard(
                    label: 'العمولة المحصلة',
                    value: _currency.format(_stats.commissionCollected),
                    icon: Icons.account_balance_rounded,
                    color: AdminColors.primary,
                  ),
                  StatCard(
                    label: 'طلبات شحن معلقة',
                    value: '${_stats.pendingRechargeRequests}',
                    icon: Icons.add_card_rounded,
                    color: AdminColors.warning,
                  ),
                  StatCard(
                    label: 'طلبات سحب معلقة',
                    value: '${_stats.pendingWithdrawalRequests}',
                    icon: Icons.outbond_rounded,
                    color: AdminColors.warning,
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
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 900;
                final tripsChart = _buildTripsChart();
                final statusChart = _buildStatusDistributionChart();
                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 2, child: tripsChart),
                      const SizedBox(width: 16),
                      Expanded(child: statusChart),
                    ],
                  );
                }
                return Column(
                  children: [
                    tripsChart,
                    const SizedBox(height: 16),
                    statusChart,
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            _buildRecentTrips(),
          ],
        ),
      ),
    );
  }

  Widget _buildTripsChart() {
    final spots = <FlSpot>[
      for (var i = 0; i < _tripsPerDay.length; i++)
        FlSpot(i.toDouble(), (_tripsPerDay[i]['count'] as int).toDouble()),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'الرحلات خلال آخر 7 أيام',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontFamily: 'Cairo',
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: spots.isEmpty
                  ? const Center(
                      child: Text(
                        'لا توجد بيانات رحلات بعد',
                        style: TextStyle(
                          color: AdminColors.textSecondary,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    )
                  : LineChart(
                      LineChartData(
                        gridData: const FlGridData(show: false),
                        titlesData: const FlTitlesData(
                          topTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: spots,
                            isCurved: true,
                            color: AdminColors.primary,
                            barWidth: 3,
                            dotData: const FlDotData(show: true),
                            belowBarData: BarAreaData(
                              show: true,
                              color: AdminColors.primary.withValues(
                                alpha: 0.08,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusDistributionChart() {
    final sections = [
      PieChartSectionData(
        value: _stats.completedTrips.toDouble(),
        color: AdminColors.success,
        title: 'مكتملة',
        radius: 50,
        titleStyle: const TextStyle(fontSize: 10, color: Colors.white),
      ),
      PieChartSectionData(
        value: _stats.activeTrips.toDouble(),
        color: AdminColors.secondary,
        title: 'نشطة',
        radius: 50,
        titleStyle: const TextStyle(fontSize: 10, color: Colors.white),
      ),
      PieChartSectionData(
        value: _stats.cancelledTrips.toDouble(),
        color: AdminColors.error,
        title: 'ملغاة',
        radius: 50,
        titleStyle: const TextStyle(fontSize: 10, color: Colors.white),
      ),
    ].where((s) => s.value > 0).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'توزيع حالات الرحلات',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontFamily: 'Cairo',
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: sections.isEmpty
                  ? const Center(
                      child: Text(
                        'لا توجد بيانات رحلات بعد',
                        style: TextStyle(
                          color: AdminColors.textSecondary,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    )
                  : PieChart(
                      PieChartData(
                        sections: sections,
                        sectionsSpace: 2,
                        centerSpaceRadius: 30,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentTrips() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'أحدث الرحلات',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontFamily: 'Cairo',
              ),
            ),
            const SizedBox(height: 12),
            if (_recentTrips.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'لا توجد رحلات مسجلة بعد.',
                  style: TextStyle(
                    color: AdminColors.textSecondary,
                    fontFamily: 'Cairo',
                  ),
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('رقم الرحلة')),
                    DataColumn(label: Text('الحالة')),
                    DataColumn(label: Text('من')),
                    DataColumn(label: Text('إلى')),
                    DataColumn(label: Text('السعر')),
                  ],
                  rows: _recentTrips.map((trip) {
                    return DataRow(
                      cells: [
                        DataCell(Text((trip['id'] as String).substring(0, 8))),
                        DataCell(
                          StatusBadge.neutral(trip['status'] as String? ?? ''),
                        ),
                        DataCell(Text(trip['pickup_address'] as String? ?? '')),
                        DataCell(
                          Text(trip['destination_address'] as String? ?? '-'),
                        ),
                        DataCell(
                          Text(
                            '${trip['final_price'] ?? trip['estimated_price'] ?? '-'}',
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
