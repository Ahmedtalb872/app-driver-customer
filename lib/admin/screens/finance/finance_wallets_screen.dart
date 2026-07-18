import 'dart:async';

import 'package:flutter/material.dart';

import '../../repositories/admin_finance_repository.dart';
import '../../widgets/confirm_dialog.dart';

class FinanceWalletsScreen extends StatefulWidget {
  const FinanceWalletsScreen({super.key});

  @override
  State<FinanceWalletsScreen> createState() => _FinanceWalletsScreenState();
}

class _FinanceWalletsScreenState extends State<FinanceWalletsScreen> {
  final _repository = AdminFinanceRepository();
  final _searchController = TextEditingController();
  Timer? _debounce;
  bool _loading = true;
  List<Map<String, dynamic>> _wallets = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final wallets = await _repository.loadWallets(
      searchQuery: _searchController.text,
    );
    if (!mounted) return;
    setState(() {
      _wallets = wallets;
      _loading = false;
    });
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _load);
  }

  Future<void> _adjust(Map<String, dynamic> wallet) async {
    final amountController = TextEditingController();
    var isCredit = true;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('تعديل الرصيد'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'المبلغ'),
              ),
              const SizedBox(height: 12),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('إضافة')),
                  ButtonSegment(value: false, label: Text('خصم')),
                ],
                selected: {isCredit},
                onSelectionChanged: (s) =>
                    setDialogState(() => isCredit = s.first),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                final amount = double.tryParse(amountController.text);
                if (amount == null || amount <= 0) return;
                Navigator.pop(context, {
                  'amount': amount,
                  'isCredit': isCredit,
                });
              },
              child: const Text('متابعة'),
            ),
          ],
        ),
      ),
    );
    if (result == null) return;
    if (!mounted) return;

    final reason = await showReasonDialog(
      context,
      title: 'سبب تعديل الرصيد (إلزامي)',
    );
    if (reason == null) return;

    try {
      await _repository.adjustWalletBalance(
        wallet['user_id'] as String,
        result['amount'] as double,
        result['isCredit'] as bool,
        reason,
      );
      _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تعذر تعديل الرصيد.',
              style: TextStyle(fontFamily: 'Cairo'),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 280,
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: const InputDecoration(
                hintText: 'ابحث بالاسم أو الهاتف',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : Card(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('الاسم')),
                          DataColumn(label: Text('الهاتف')),
                          DataColumn(label: Text('الرصيد')),
                          DataColumn(label: Text('العملة')),
                          DataColumn(label: Text('إجراءات')),
                        ],
                        rows: _wallets.map((wallet) {
                          final profile =
                              wallet['profiles'] as Map<String, dynamic>?;
                          return DataRow(
                            cells: [
                              DataCell(
                                Text((profile?['full_name'] as String?) ?? '-'),
                              ),
                              DataCell(
                                Text((profile?['phone'] as String?) ?? '-'),
                              ),
                              DataCell(Text('${wallet['balance']}')),
                              DataCell(Text('${wallet['currency']}')),
                              DataCell(
                                IconButton(
                                  icon: const Icon(
                                    Icons.account_balance_wallet_outlined,
                                    size: 20,
                                  ),
                                  onPressed: () => _adjust(wallet),
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
