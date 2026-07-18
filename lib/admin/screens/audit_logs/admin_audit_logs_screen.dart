import 'package:flutter/material.dart';

import '../../repositories/admin_audit_repository.dart';

class AdminAuditLogsScreen extends StatefulWidget {
  const AdminAuditLogsScreen({super.key});

  @override
  State<AdminAuditLogsScreen> createState() => _AdminAuditLogsScreenState();
}

class _AdminAuditLogsScreenState extends State<AdminAuditLogsScreen> {
  final _repository = AdminAuditRepository();
  bool _loading = true;
  List<Map<String, dynamic>> _logs = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final logs = await _repository.loadLogs();
    if (!mounted) return;
    setState(() {
      _logs = logs;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_logs.isEmpty) {
      return const Center(
        child: Text(
          'لا توجد أي عمليات مسجلة بعد.',
          style: TextStyle(fontFamily: 'Cairo'),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Card(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('المسؤول')),
              DataColumn(label: Text('الدور')),
              DataColumn(label: Text('العملية')),
              DataColumn(label: Text('نوع الكيان')),
              DataColumn(label: Text('السبب')),
              DataColumn(label: Text('التاريخ')),
            ],
            rows: _logs.map((log) {
              return DataRow(
                cells: [
                  DataCell(Text(log['admin_name'] as String? ?? '-')),
                  DataCell(Text(log['admin_role'] as String? ?? '-')),
                  DataCell(Text(log['action'] as String? ?? '-')),
                  DataCell(Text(log['entity_type'] as String? ?? '-')),
                  DataCell(Text(log['reason'] as String? ?? '-')),
                  DataCell(
                    Text(
                      (log['created_at'] as String? ?? '')
                          .replaceFirst('T', ' ')
                          .split('.')
                          .first,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
