import 'package:flutter/material.dart';

import '../../core/admin_colors.dart';
import '../../repositories/admin_trips_repository.dart';
import '../../utils/csv_downloader.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/status_badge.dart';
import 'trip_detail_panel.dart';

class AdminTripsScreen extends StatefulWidget {
  const AdminTripsScreen({super.key});

  @override
  State<AdminTripsScreen> createState() => _AdminTripsScreenState();
}

class _AdminTripsScreenState extends State<AdminTripsScreen> {
  final _repository = AdminTripsRepository();
  static const _pageSize = 25;
  int _offset = 0;
  String? _statusFilter;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _trips = [];

  static const _statusLabels = {
    'searching': 'قيد البحث',
    'accepted': 'مقبولة',
    'arrived': 'وصل الكابتن',
    'in_progress': 'جارية',
    'completed': 'مكتملة',
    'cancelled': 'ملغاة',
  };

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
      final trips = await _repository.loadTrips(
        statusFilter: _statusFilter,
        limit: _pageSize,
        offset: _offset,
      );
      setState(() => _trips = trips);
    } catch (e) {
      setState(() => _error = 'تعذر تحميل الرحلات.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openDetails(Map<String, dynamic> trip) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TripDetailPanel(trip: trip, onChanged: _load),
    );
  }

  Future<void> _cancelTrip(Map<String, dynamic> trip) async {
    final reason = await showReasonDialog(
      context,
      title: 'سبب إلغاء الرحلة (إلزامي)',
    );
    if (reason == null) return;
    try {
      await _repository.cancel(trip['id'] as String, reason);
      _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تعذر إلغاء الرحلة.',
              style: TextStyle(fontFamily: 'Cairo'),
            ),
          ),
        );
      }
    }
  }

  void _exportCsv() {
    downloadCsv('trips_export.csv', _repository.toCsv(_trips));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 200,
                child: DropdownButtonFormField<String?>(
                  initialValue: _statusFilter,
                  decoration: const InputDecoration(labelText: 'الحالة'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('الكل')),
                    ..._statusLabels.entries.map(
                      (e) =>
                          DropdownMenuItem(value: e.key, child: Text(e.value)),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() => _statusFilter = value);
                    _offset = 0;
                    _load();
                  },
                ),
              ),
              OutlinedButton.icon(
                onPressed: _trips.isEmpty ? null : _exportCsv,
                icon: const Icon(Icons.download_rounded),
                label: const Text('تصدير CSV'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(child: _buildContent()),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                onPressed: _offset == 0
                    ? null
                    : () {
                        setState(
                          () =>
                              _offset = (_offset - _pageSize).clamp(0, 1 << 30),
                        );
                        _load();
                      },
                icon: const Icon(Icons.chevron_right_rounded),
              ),
              Text(
                'من ${_offset + 1}',
                style: const TextStyle(fontFamily: 'Cairo'),
              ),
              IconButton(
                onPressed: _trips.length < _pageSize
                    ? null
                    : () {
                        setState(() => _offset += _pageSize);
                        _load();
                      },
                icon: const Icon(Icons.chevron_left_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(fontFamily: 'Cairo')),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _load,
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      );
    }
    if (_trips.isEmpty) {
      return const Center(
        child: Text(
          'لا توجد رحلات مسجلة بعد.',
          style: TextStyle(fontFamily: 'Cairo'),
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
            DataColumn(label: Text('من')),
            DataColumn(label: Text('إلى')),
            DataColumn(label: Text('السعر')),
            DataColumn(label: Text('التاريخ')),
            DataColumn(label: Text('إجراءات')),
          ],
          rows: _trips.map((trip) {
            final status = trip['status'] as String? ?? '';
            final canCancel = status != 'completed' && status != 'cancelled';
            return DataRow(
              cells: [
                DataCell(
                  Text((trip['id'] as String).substring(0, 8)),
                  onTap: () => _openDetails(trip),
                ),
                DataCell(_statusBadge(status)),
                DataCell(Text(trip['pickup_address'] as String? ?? '-')),
                DataCell(Text(trip['destination_address'] as String? ?? '-')),
                DataCell(
                  Text(
                    '${trip['final_price'] ?? trip['estimated_price'] ?? '-'}',
                  ),
                ),
                DataCell(
                  Text(
                    (trip['requested_at'] as String? ?? '').split('T').first,
                  ),
                ),
                DataCell(
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.visibility_outlined, size: 20),
                        onPressed: () => _openDetails(trip),
                      ),
                      if (canCancel)
                        IconButton(
                          icon: const Icon(
                            Icons.cancel_outlined,
                            size: 20,
                            color: AdminColors.error,
                          ),
                          onPressed: () => _cancelTrip(trip),
                        ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    switch (status) {
      case 'completed':
        return StatusBadge.success(_statusLabels[status]!);
      case 'cancelled':
        return StatusBadge.error(_statusLabels[status]!);
      case 'searching':
      case 'accepted':
      case 'arrived':
      case 'in_progress':
        return StatusBadge.warning(_statusLabels[status]!);
      default:
        return StatusBadge.neutral(status);
    }
  }
}
