import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/admin_colors.dart';
import '../../models/customer_admin_view.dart';
import '../../repositories/admin_customers_repository.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/status_badge.dart';

/// General registered-customers list (name/phone/rating/trip count/Selefli
/// debt) - the customer-side counterpart of [AdminCaptainsScreen], same
/// search+filter+pagination shape.
class AdminCustomersScreen extends StatefulWidget {
  const AdminCustomersScreen({super.key});

  @override
  State<AdminCustomersScreen> createState() => _AdminCustomersScreenState();
}

class _AdminCustomersScreenState extends State<AdminCustomersScreen> {
  final _repository = AdminCustomersRepository();
  final _searchController = TextEditingController();
  Timer? _debounce;

  static const _pageSize = 25;
  int _offset = 0;
  String? _statusFilter;
  bool _loading = true;
  String? _error;
  List<CustomerAdminView> _customers = [];

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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await _repository.loadCustomers(
        searchQuery: _searchController.text,
        statusFilter: _statusFilter,
        limit: _pageSize,
        offset: _offset,
      );
      setState(() => _customers = results);
    } catch (e) {
      setState(() => _error = 'تعذر تحميل قائمة الزبناء.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _offset = 0;
      _load();
    });
  }

  Future<void> _toggleSuspend(CustomerAdminView customer) async {
    if (customer.isSuspended) {
      final ok = await showConfirmDialog(
        context,
        title: 'إعادة تفعيل الزبون',
        message: 'هل تريد إعادة تفعيل ${customer.fullName}؟',
      );
      if (!ok) return;
      await _repository.setSuspended(customer.id, false);
    } else {
      final reason = await showReasonDialog(
        context,
        title: 'سبب الإيقاف (إلزامي)',
      );
      if (reason == null) return;
      await _repository.setSuspended(customer.id, true, reason: reason);
    }
    _load();
  }

  Future<void> _editNotes(CustomerAdminView customer) async {
    final controller = TextEditingController(text: customer.adminNotes ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('ملاحظات إدارية - ${customer.fullName}'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(hintText: 'أضف ملاحظة...'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (saved != true) return;
    await _repository.updateAdminNotes(customer.id, controller.text.trim());
    _load();
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
            children: [
              SizedBox(
                width: 260,
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: const InputDecoration(
                    hintText: 'ابحث بالاسم أو رقم الهاتف',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
              ),
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<String?>(
                  initialValue: _statusFilter,
                  decoration: const InputDecoration(labelText: 'الحالة'),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('الكل')),
                    DropdownMenuItem(value: 'active', child: Text('نشط')),
                    DropdownMenuItem(value: 'suspended', child: Text('موقوف')),
                  ],
                  onChanged: (value) {
                    setState(() => _statusFilter = value);
                    _offset = 0;
                    _load();
                  },
                ),
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
                onPressed: _customers.length < _pageSize
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
    if (_customers.isEmpty) {
      return const Center(
        child: Text(
          'لا يوجد زبناء مطابقون.',
          style: TextStyle(fontFamily: 'Cairo'),
        ),
      );
    }

    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('#')),
              DataColumn(label: Text('')),
              DataColumn(label: Text('الاسم')),
              DataColumn(label: Text('الهاتف')),
              DataColumn(label: Text('الحالة')),
              DataColumn(label: Text('التقييم')),
              DataColumn(label: Text('عدد المشاوير')),
              DataColumn(label: Text('دين سلفلي')),
              DataColumn(label: Text('إجراءات')),
            ],
            rows: _customers.asMap().entries.map((entry) {
              final index = entry.key;
              final customer = entry.value;
              return DataRow(
                cells: [
                  DataCell(Text('${_offset + index + 1}')),
                  DataCell(_CustomerAvatar(customer: customer)),
                  DataCell(
                    Text(customer.fullName.isEmpty ? '-' : customer.fullName),
                  ),
                  DataCell(Text(customer.phone ?? '-')),
                  DataCell(
                    customer.isSuspended
                        ? StatusBadge.error('موقوف')
                        : StatusBadge.success('نشط'),
                  ),
                  DataCell(
                    Text(
                      customer.rating == null
                          ? '-'
                          : '${customer.rating!.toStringAsFixed(1)} (${customer.ratingsCount})',
                    ),
                  ),
                  DataCell(Text('${customer.completedTripsCount}')),
                  DataCell(
                    customer.hasSelefliDebt
                        ? StatusBadge.error(
                            '${customer.outstandingSelefliDebt!.toStringAsFixed(0)} أوقية',
                          )
                        : StatusBadge.neutral('لا يوجد'),
                  ),
                  DataCell(
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'ملاحظات إدارية',
                          icon: const Icon(Icons.edit_note_rounded, size: 20),
                          onPressed: () => _editNotes(customer),
                        ),
                        IconButton(
                          tooltip: customer.isSuspended ? 'إعادة تفعيل' : 'إيقاف',
                          icon: Icon(
                            customer.isSuspended
                                ? Icons.play_circle_outline
                                : Icons.block,
                            size: 20,
                            color: customer.isSuspended
                                ? AdminColors.success
                                : AdminColors.error,
                          ),
                          onPressed: () => _toggleSuspend(customer),
                        ),
                      ],
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

class _CustomerAvatar extends StatelessWidget {
  const _CustomerAvatar({required this.customer});

  final CustomerAdminView customer;

  @override
  Widget build(BuildContext context) {
    final url = customer.avatarUrl;
    return CircleAvatar(
      radius: 18,
      backgroundColor: AdminColors.primary.withValues(alpha: 0.1),
      backgroundImage: (url == null || url.isEmpty) ? null : NetworkImage(url),
      child: (url == null || url.isEmpty)
          ? Icon(Icons.person_outline, size: 18, color: AdminColors.primary)
          : null,
    );
  }
}
