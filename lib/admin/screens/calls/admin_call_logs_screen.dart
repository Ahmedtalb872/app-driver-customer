import 'package:flutter/material.dart';

import '../../repositories/admin_call_logs_repository.dart';

const _roleLabels = {
  'customer': 'زبون',
  'captain': 'كابتن',
  'admin': 'إدارة',
};

const _outcomeLabels = {
  'ringing': 'جارية...',
  'answered': 'تم الرد',
  'missed': 'لم يُرد',
  'declined': 'مرفوضة',
  'failed': 'فشلت',
};

const _outcomeColors = {
  'answered': Color(0xFF2E7D32),
  'missed': Color(0xFFB71C1C),
  'declined': Color(0xFFB71C1C),
  'failed': Color(0xFF9E9E9E),
  'ringing': Color(0xFF9E9E9E),
};

class AdminCallLogsScreen extends StatefulWidget {
  const AdminCallLogsScreen({super.key});

  @override
  State<AdminCallLogsScreen> createState() => _AdminCallLogsScreenState();
}

class _AdminCallLogsScreenState extends State<AdminCallLogsScreen> {
  final _repository = AdminCallLogsRepository();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _logs = [];

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
      final logs = await _repository.loadLogs();
      if (!mounted) return;
      setState(() {
        _logs = logs;
        _loading = false;
      });
    } catch (e) {
      // Without this, a query failure (most likely: the call_logs table/
      // migration 20261008000114_call_logs.sql hasn't been run on this
      // project yet) left _loading stuck true forever - a silent spinner
      // with no way to tell what went wrong. The raw exception is shown
      // (not a generic message) so a screenshot of this screen is enough
      // to diagnose it, same reasoning as RequestRideScreen's own
      // _friendlyErrorFor fallback.
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  /// Same fallback chain as TripDetailPanel._customerLabel - a registered
  /// name, then the guest phone a dispatch operator typed in, then a
  /// plain dash rather than nothing at all.
  String _customerLabel(Map<String, dynamic> log) {
    final trip = log['trips'] as Map<String, dynamic>?;
    final name =
        (trip?['customers'] as Map?)?['profiles']?['full_name'] as String?;
    if (name != null && name.trim().isNotEmpty) return name;
    final guestPhone = trip?['guest_customer_phone'] as String?;
    if (guestPhone != null && guestPhone.trim().isNotEmpty) return guestPhone;
    return '-';
  }

  String _formatDuration(Map<String, dynamic> log) {
    final seconds = (log['duration_seconds'] as num?)?.toInt();
    if (seconds == null) return '-';
    final minutes = seconds ~/ 60;
    final remaining = seconds % 60;
    return '$minutes:${remaining.toString().padLeft(2, '0')}';
  }

  String _formatTime(Map<String, dynamic> log) {
    final raw = log['started_at'] as String?;
    if (raw == null) return '-';
    return raw.replaceFirst('T', ' ').split('.').first;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'تحديث',
            ),
          ),
          const SizedBox(height: 8),
          if (_error != null)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'تعذر تحميل سجل المكالمات.',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 11),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: _load,
                        child: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: _logs.isEmpty
                  ? const Center(
                      child: Text(
                        'لا توجد أي مكالمات مسجّلة بعد.',
                        style: TextStyle(fontFamily: 'Cairo'),
                      ),
                    )
                  : Card(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('الوقت')),
                          DataColumn(label: Text('الزبون')),
                          DataColumn(label: Text('من')),
                          DataColumn(label: Text('إلى')),
                          DataColumn(label: Text('الحالة')),
                          DataColumn(label: Text('المدة')),
                        ],
                        rows: _logs.map((log) {
                          final outcome = log['outcome'] as String? ?? 'ringing';
                          return DataRow(
                            cells: [
                              DataCell(Text(_formatTime(log))),
                              DataCell(Text(_customerLabel(log))),
                              DataCell(
                                Text(
                                  _roleLabels[log['caller_role']] ??
                                      log['caller_role'] as String? ??
                                      '-',
                                ),
                              ),
                              DataCell(
                                Text(
                                  _roleLabels[log['callee_role']] ??
                                      log['callee_role'] as String? ??
                                      '-',
                                ),
                              ),
                              DataCell(
                                Text(
                                  _outcomeLabels[outcome] ?? outcome,
                                  style: TextStyle(
                                    color: _outcomeColors[outcome],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              DataCell(Text(_formatDuration(log))),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
