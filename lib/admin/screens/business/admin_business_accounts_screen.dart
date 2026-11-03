import 'package:flutter/material.dart';

import '../../core/admin_colors.dart';
import '../../repositories/admin_business_repository.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/copyable_phone.dart';
import '../../widgets/status_badge.dart';

/// Reviews self-registered restaurant/institution accounts (the business
/// portal - see lib/business/) before they can place a single ride
/// request. Deliberately minimal next to AdminCaptainsScreen: no document
/// verification step exists for a business account, just a name/type an
/// admin eyeballs against who's actually calling to ask about it.
class AdminBusinessAccountsScreen extends StatefulWidget {
  const AdminBusinessAccountsScreen({super.key});

  @override
  State<AdminBusinessAccountsScreen> createState() =>
      _AdminBusinessAccountsScreenState();
}

class _AdminBusinessAccountsScreenState
    extends State<AdminBusinessAccountsScreen> {
  final _repository = AdminBusinessRepository();
  String? _statusFilter = 'pending';
  bool _loading = true;
  List<Map<String, dynamic>> _accounts = [];

  static const _typeLabels = {
    'restaurant': 'مطعم',
    'institution': 'مؤسسة',
    'other': 'أخرى',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final accounts = await _repository.loadBusinessAccounts(
        statusFilter: _statusFilter,
      );
      if (mounted) setState(() => _accounts = accounts);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _approve(Map<String, dynamic> account) async {
    final ok = await showConfirmDialog(
      context,
      title: 'اعتماد الحساب',
      message: 'هل تريد اعتماد "${account['business_name']}"؟',
    );
    if (!ok) return;
    await _repository.approve(account['id'] as String);
    _load();
  }

  Future<void> _reject(Map<String, dynamic> account) async {
    final reason = await showReasonDialog(context, title: 'سبب الرفض (إلزامي)');
    if (reason == null) return;
    await _repository.reject(account['id'] as String, reason);
    _load();
  }

  Future<void> _toggleSuspend(Map<String, dynamic> account) async {
    final suspended = account['status'] == 'suspended';
    final ok = await showConfirmDialog(
      context,
      title: suspended ? 'إعادة تفعيل الحساب' : 'إيقاف الحساب',
      message: 'هل أنت متأكد؟',
      destructive: !suspended,
    );
    if (!ok) return;
    await _repository.setSuspended(account['id'] as String, !suspended);
    _load();
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
                DropdownMenuItem(value: 'pending', child: Text('قيد المراجعة')),
                DropdownMenuItem(value: 'approved', child: Text('معتمد')),
                DropdownMenuItem(value: 'rejected', child: Text('مرفوض')),
                DropdownMenuItem(value: 'suspended', child: Text('موقوف')),
                DropdownMenuItem(value: null, child: Text('الكل')),
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
    if (_accounts.isEmpty) {
      return const Center(
        child: Text('لا توجد حسابات مطابقة.', style: TextStyle(fontFamily: 'Cairo')),
      );
    }
    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('الاسم')),
            DataColumn(label: Text('النوع')),
            DataColumn(label: Text('المسؤول')),
            DataColumn(label: Text('الهاتف')),
            DataColumn(label: Text('الحالة')),
            DataColumn(label: Text('إجراءات')),
          ],
          rows: _accounts.map((account) {
            final status = account['status'] as String? ?? '';
            final profile = account['profiles'] as Map<String, dynamic>?;
            return DataRow(
              cells: [
                DataCell(Text(account['business_name'] as String? ?? '-')),
                DataCell(Text(_typeLabels[account['business_type']] ?? '-')),
                DataCell(Text(profile?['full_name'] as String? ?? '-')),
                DataCell(CopyablePhone(profile?['phone'] as String?)),
                DataCell(_statusBadge(status)),
                DataCell(
                  Row(
                    children: [
                      if (status == 'pending') ...[
                        IconButton(
                          tooltip: 'اعتماد',
                          icon: const Icon(
                            Icons.check_circle_outline,
                            color: AdminColors.success,
                            size: 20,
                          ),
                          onPressed: () => _approve(account),
                        ),
                        IconButton(
                          tooltip: 'رفض',
                          icon: const Icon(
                            Icons.cancel_outlined,
                            color: AdminColors.error,
                            size: 20,
                          ),
                          onPressed: () => _reject(account),
                        ),
                      ],
                      if (status == 'approved' || status == 'suspended')
                        IconButton(
                          tooltip: status == 'suspended' ? 'إعادة تفعيل' : 'إيقاف',
                          icon: Icon(
                            status == 'suspended'
                                ? Icons.play_circle_outline
                                : Icons.block,
                            size: 20,
                            color: status == 'suspended'
                                ? AdminColors.success
                                : AdminColors.error,
                          ),
                          onPressed: () => _toggleSuspend(account),
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
      case 'approved':
        return StatusBadge.success('معتمد');
      case 'pending':
        return StatusBadge.warning('قيد المراجعة');
      case 'rejected':
        return StatusBadge.error('مرفوض');
      case 'suspended':
        return StatusBadge.error('موقوف');
      default:
        return StatusBadge.neutral(status);
    }
  }
}
