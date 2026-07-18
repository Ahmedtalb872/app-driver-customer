import 'package:flutter/material.dart';

import '../../core/admin_colors.dart';
import '../../repositories/admin_finance_repository.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/status_badge.dart';

class RechargeRequestsScreen extends StatefulWidget {
  const RechargeRequestsScreen({super.key});

  @override
  State<RechargeRequestsScreen> createState() => _RechargeRequestsScreenState();
}

class _RechargeRequestsScreenState extends State<RechargeRequestsScreen> {
  final _repository = AdminFinanceRepository();
  String? _statusFilter = 'pending';
  bool _loading = true;
  List<Map<String, dynamic>> _requests = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final requests = await _repository.loadRechargeRequests(
      statusFilter: _statusFilter,
    );
    if (!mounted) return;
    setState(() {
      _requests = requests;
      _loading = false;
    });
  }

  Future<void> _approve(Map<String, dynamic> request) async {
    final ok = await showConfirmDialog(
      context,
      title: 'الموافقة على طلب الشحن',
      message: 'هل تريد الموافقة على شحن ${request['amount']}؟',
    );
    if (!ok) return;
    try {
      await _repository.approveRecharge(request['id'] as String);
      _load();
    } catch (_) {
      _showError();
    }
  }

  Future<void> _reject(Map<String, dynamic> request) async {
    final reason = await showReasonDialog(context, title: 'سبب الرفض (إلزامي)');
    if (reason == null) return;
    try {
      await _repository.rejectRecharge(request['id'] as String, reason);
      _load();
    } catch (_) {
      _showError();
    }
  }

  void _showError() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'حدث خطأ، تحقق من صلاحياتك.',
          style: TextStyle(fontFamily: 'Cairo'),
        ),
      ),
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
                DropdownMenuItem(value: 'pending', child: Text('قيد الانتظار')),
                DropdownMenuItem(value: 'approved', child: Text('موافق عليه')),
                DropdownMenuItem(value: 'rejected', child: Text('مرفوض')),
                DropdownMenuItem(value: null, child: Text('الكل')),
              ],
              onChanged: (value) {
                setState(() => _statusFilter = value);
                _load();
              },
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _requests.isEmpty
                ? const Center(
                    child: Text(
                      'لا توجد طلبات.',
                      style: TextStyle(fontFamily: 'Cairo'),
                    ),
                  )
                : Card(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('المبلغ')),
                          DataColumn(label: Text('طريقة الدفع')),
                          DataColumn(label: Text('الحالة')),
                          DataColumn(label: Text('التاريخ')),
                          DataColumn(label: Text('إجراءات')),
                        ],
                        rows: _requests.map((request) {
                          final status = request['status'] as String? ?? '';
                          return DataRow(
                            cells: [
                              DataCell(Text('${request['amount']}')),
                              DataCell(
                                Text(
                                  request['payment_method'] as String? ?? '-',
                                ),
                              ),
                              DataCell(
                                status == 'approved'
                                    ? StatusBadge.success('موافق عليه')
                                    : status == 'rejected'
                                    ? StatusBadge.error('مرفوض')
                                    : StatusBadge.warning('قيد الانتظار'),
                              ),
                              DataCell(
                                Text(
                                  (request['created_at'] as String? ?? '')
                                      .split('T')
                                      .first,
                                ),
                              ),
                              DataCell(
                                status == 'pending'
                                    ? Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(
                                              Icons.check_circle_outline,
                                              color: AdminColors.success,
                                              size: 20,
                                            ),
                                            onPressed: () => _approve(request),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.cancel_outlined,
                                              color: AdminColors.error,
                                              size: 20,
                                            ),
                                            onPressed: () => _reject(request),
                                          ),
                                        ],
                                      )
                                    : const SizedBox(),
                              ),
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
