import 'package:flutter/material.dart';

import '../../core/admin_colors.dart';
import '../../repositories/admin_finance_repository.dart';
import '../../widgets/confirm_dialog.dart';

/// Captain-subscription cycles flagged for manual review (see
/// admin_list_subscription_disputes(),
/// 20260812000057_subscription_staged_payout.sql): an early cancellation
/// before the captain's escrowed share was fully paid out, or a
/// trusted-mode renewal neither side confirmed within 5 days. This screen
/// only surfaces them and records a resolution note - the actual wallet
/// correction is made via Finance > المحافظ والمالية (adjustWalletBalance),
/// same as every other manual money decision in this dashboard.
class SubscriptionDisputesScreen extends StatefulWidget {
  const SubscriptionDisputesScreen({super.key});

  @override
  State<SubscriptionDisputesScreen> createState() =>
      _SubscriptionDisputesScreenState();
}

class _SubscriptionDisputesScreenState
    extends State<SubscriptionDisputesScreen> {
  final _repository = AdminFinanceRepository();
  bool _loading = true;
  List<Map<String, dynamic>> _disputes = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final disputes = await _repository.loadSubscriptionDisputes();
    if (!mounted) return;
    setState(() {
      _disputes = disputes;
      _loading = false;
    });
  }

  Future<void> _dismiss(Map<String, dynamic> dispute) async {
    final notes = await showReasonDialog(
      context,
      title: 'ملاحظة الحل (إلزامية)',
      hint: 'مثال: أُعيد المبلغ لمحفظة الزبون بعد التحقق من عدم اكتمال الخدمة.',
      confirmLabel: 'تم الحل',
    );
    if (notes == null) return;
    try {
      await _repository.dismissSubscriptionDispute(
        dispute['id'] as String,
        notes,
      );
      _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'حدث خطأ، تحقق من صلاحياتك.',
            style: TextStyle(fontFamily: 'Cairo'),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'اشتراكات شهرية تحتاج مراجعة يدوية - راجع سجل المشوار/المحادثة، '
            'ثم صحّح الرصيد من "المحافظ والمالية" قبل تسجيل الحل هنا.',
            style: TextStyle(fontFamily: 'Cairo', color: AdminColors.textSecondary),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _disputes.isEmpty
                ? const Center(
                    child: Text(
                      'لا توجد حالات قيد المراجعة.',
                      style: TextStyle(fontFamily: 'Cairo'),
                    ),
                  )
                : Card(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('الزبون')),
                          DataColumn(label: Text('الكابتن')),
                          DataColumn(label: Text('السبب')),
                          DataColumn(label: Text('المبلغ المحجوز')),
                          DataColumn(label: Text('سعر الاشتراك')),
                          DataColumn(label: Text('الدورة')),
                          DataColumn(label: Text('آخر تحديث')),
                          DataColumn(label: Text('إجراءات')),
                        ],
                        rows: _disputes.map((dispute) {
                          final disputeAmount =
                              dispute['dispute_amount'] as num?;
                          final agreedPrice = dispute['agreed_price'] as num?;
                          return DataRow(
                            cells: [
                              DataCell(
                                Text(dispute['customer_name'] as String? ?? '-'),
                              ),
                              DataCell(
                                Text(dispute['captain_name'] as String? ?? '-'),
                              ),
                              DataCell(
                                SizedBox(
                                  width: 260,
                                  child: Text(
                                    dispute['dispute_reason'] as String? ?? '-',
                                    style: const TextStyle(fontFamily: 'Cairo'),
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  disputeAmount != null
                                      ? '${disputeAmount.toStringAsFixed(0)} أوقية'
                                      : '-',
                                ),
                              ),
                              DataCell(
                                Text(
                                  agreedPrice != null
                                      ? '${agreedPrice.toStringAsFixed(0)} أوقية'
                                      : '-',
                                ),
                              ),
                              DataCell(
                                Text('${dispute['cycle_count'] ?? '-'}'),
                              ),
                              DataCell(
                                Text(
                                  (dispute['updated_at'] as String? ?? '')
                                      .split('T')
                                      .first,
                                ),
                              ),
                              DataCell(
                                FilledButton(
                                  onPressed: () => _dismiss(dispute),
                                  child: const Text('تم الحل'),
                                ),
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
