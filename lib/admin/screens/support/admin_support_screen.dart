import 'package:flutter/material.dart';

import '../../../models/models.dart';
import '../../core/admin_colors.dart';
import '../../repositories/admin_support_repository.dart';
import '../../widgets/status_badge.dart';
import 'admin_support_ticket_panel.dart';

class AdminSupportScreen extends StatefulWidget {
  const AdminSupportScreen({super.key});

  @override
  State<AdminSupportScreen> createState() => _AdminSupportScreenState();
}

class _AdminSupportScreenState extends State<AdminSupportScreen> {
  final _repository = AdminSupportRepository();
  String? _statusFilter;
  bool _loading = true;
  List<SupportTicket> _tickets = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final tickets = await _repository.loadTickets(statusFilter: _statusFilter);
    if (!mounted) return;
    setState(() {
      _tickets = tickets;
      _loading = false;
    });
  }

  Future<void> _openTicket(SupportTicket ticket) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          AdminSupportTicketPanel(ticket: ticket, onChanged: _load),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 200,
            child: DropdownButtonFormField<String?>(
              initialValue: _statusFilter,
              decoration: const InputDecoration(labelText: 'الحالة'),
              items: const [
                DropdownMenuItem(value: null, child: Text('الكل')),
                DropdownMenuItem(value: 'open', child: Text('مفتوحة')),
                DropdownMenuItem(value: 'in_progress', child: Text('قيد المعالجة')),
                DropdownMenuItem(value: 'resolved', child: Text('محلولة')),
                DropdownMenuItem(value: 'closed', child: Text('مغلقة')),
              ],
              onChanged: (value) {
                setState(() => _statusFilter = value);
                _load();
              },
            ),
          ),
          const SizedBox(height: 16),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_tickets.isEmpty) {
      return const Center(
        child: Text(
          'لا توجد محادثات دعم مطابقة.',
          style: TextStyle(fontFamily: 'Cairo'),
        ),
      );
    }

    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('المستخدم')),
            DataColumn(label: Text('النوع')),
            DataColumn(label: Text('الهاتف')),
            DataColumn(label: Text('الحالة')),
            DataColumn(label: Text('آخر تحديث')),
          ],
          rows: _tickets.map((ticket) {
            return DataRow(
              onSelectChanged: (_) => _openTicket(ticket),
              cells: [
                DataCell(
                  Text(
                    ticket.userFullName?.isNotEmpty == true
                        ? ticket.userFullName!
                        : '-',
                  ),
                ),
                DataCell(_roleBadge(ticket)),
                DataCell(Text(ticket.userPhone ?? '-')),
                DataCell(_statusBadge(ticket)),
                DataCell(Text(_formatDate(ticket.updatedAt))),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Widget _roleBadge(SupportTicket ticket) {
    switch (ticket.userRole) {
      case 'captain':
        return StatusBadge(label: 'كابتن', color: AdminColors.primary);
      case 'customer':
        return StatusBadge(label: 'زبون', color: AdminColors.secondary);
      default:
        return StatusBadge.neutral('-');
    }
  }

  Widget _statusBadge(SupportTicket ticket) {
    switch (ticket.status) {
      case 'open':
        return StatusBadge.warning('مفتوحة');
      case 'in_progress':
        return StatusBadge.success('قيد المعالجة');
      case 'resolved':
        return StatusBadge.neutral('محلولة');
      case 'closed':
        return StatusBadge.neutral('مغلقة');
      default:
        return StatusBadge.neutral(ticket.status);
    }
  }
}
