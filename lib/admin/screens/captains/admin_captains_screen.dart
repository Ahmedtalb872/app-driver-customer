import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/admin_colors.dart';
import '../../models/captain_admin_view.dart';
import '../../repositories/admin_captains_repository.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/status_badge.dart';
import 'captain_detail_panel.dart';

class AdminCaptainsScreen extends StatefulWidget {
  const AdminCaptainsScreen({super.key});

  @override
  State<AdminCaptainsScreen> createState() => _AdminCaptainsScreenState();
}

class _AdminCaptainsScreenState extends State<AdminCaptainsScreen> {
  final _repository = AdminCaptainsRepository();
  final _searchController = TextEditingController();
  Timer? _debounce;

  static const _pageSize = 25;
  int _offset = 0;
  String? _statusFilter;
  bool? _onlineFilter;
  bool _loading = true;
  String? _error;
  List<CaptainAdminView> _captains = [];

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
      final results = await _repository.loadCaptains(
        searchQuery: _searchController.text,
        statusFilter: _statusFilter,
        onlineFilter: _onlineFilter,
        limit: _pageSize,
        offset: _offset,
      );
      setState(() => _captains = results);
    } catch (e) {
      setState(() => _error = 'تعذر تحميل قائمة الكباتن.');
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

  Future<void> _openDetails(CaptainAdminView captain) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          CaptainDetailPanel(captain: captain, onChanged: _load),
    );
  }

  Future<void> _approve(CaptainAdminView captain) async {
    final ok = await showConfirmDialog(
      context,
      title: 'اعتماد الكابتن',
      message: 'هل تريد اعتماد ${captain.fullName}؟',
    );
    if (!ok) return;
    try {
      await _repository.approve(captain.id);
      _load();
    } on CaptainDocumentsIncompleteException {
      _showError(
        'لا يمكن اعتماد الكابتن قبل اعتماد جميع المستندات الإلزامية (٩ مستندات) - '
        'راجع تبويب المستندات من صفحة تفاصيل الكابتن.',
      );
    } catch (_) {
      _showError();
    }
  }

  Future<void> _reject(CaptainAdminView captain) async {
    final reason = await showReasonDialog(context, title: 'سبب الرفض (إلزامي)');
    if (reason == null) return;
    try {
      await _repository.reject(captain.id, reason);
      _load();
    } catch (_) {
      _showError();
    }
  }

  Future<void> _toggleSuspend(CaptainAdminView captain) async {
    if (captain.isSuspended) {
      final ok = await showConfirmDialog(
        context,
        title: 'إعادة تفعيل الكابتن',
        message: 'هل تريد إعادة تفعيل ${captain.fullName}؟',
      );
      if (!ok) return;
      await _repository.setSuspended(captain.id, false);
    } else {
      final reason = await showReasonDialog(
        context,
        title: 'سبب الإيقاف (إلزامي)',
      );
      if (reason == null) return;
      await _repository.setSuspended(captain.id, true, reason: reason);
    }
    _load();
  }

  void _showError([String? message]) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message ?? 'حدث خطأ، تحقق من صلاحياتك وحاول مجدداً.',
          style: const TextStyle(fontFamily: 'Cairo'),
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
                    DropdownMenuItem(
                      value: 'pending',
                      child: Text('قيد المراجعة'),
                    ),
                    DropdownMenuItem(value: 'approved', child: Text('معتمد')),
                    DropdownMenuItem(value: 'rejected', child: Text('مرفوض')),
                    DropdownMenuItem(value: 'suspended', child: Text('موقوف')),
                  ],
                  onChanged: (value) {
                    setState(() => _statusFilter = value);
                    _offset = 0;
                    _load();
                  },
                ),
              ),
              SizedBox(
                width: 160,
                child: DropdownButtonFormField<bool?>(
                  initialValue: _onlineFilter,
                  decoration: const InputDecoration(labelText: 'الاتصال'),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('الكل')),
                    DropdownMenuItem(value: true, child: Text('متصل')),
                    DropdownMenuItem(value: false, child: Text('غير متصل')),
                  ],
                  onChanged: (value) {
                    setState(() => _onlineFilter = value);
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
                onPressed: _captains.length < _pageSize
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
    if (_captains.isEmpty) {
      return const Center(
        child: Text(
          'لا يوجد كباتن مطابقون.',
          style: TextStyle(fontFamily: 'Cairo'),
        ),
      );
    }

    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('الاسم')),
            DataColumn(label: Text('الهاتف')),
            DataColumn(label: Text('الحالة')),
            DataColumn(label: Text('الاتصال')),
            DataColumn(label: Text('السيارة')),
            DataColumn(label: Text('الرصيد')),
            DataColumn(label: Text('إجراءات')),
          ],
          rows: _captains.map((captain) {
            return DataRow(
              cells: [
                DataCell(
                  Text(captain.fullName.isEmpty ? '-' : captain.fullName),
                  onTap: () => _openDetails(captain),
                ),
                DataCell(Text(captain.phone ?? '-')),
                DataCell(_statusBadge(captain)),
                DataCell(
                  captain.isOnline
                      ? StatusBadge.success('متصل')
                      : StatusBadge.neutral('غير متصل'),
                ),
                DataCell(Text(captain.vehicleModel ?? '-')),
                DataCell(Text(captain.walletBalance.toStringAsFixed(0))),
                DataCell(
                  Row(
                    children: [
                      if (captain.isPending) ...[
                        IconButton(
                          tooltip: 'اعتماد',
                          icon: const Icon(
                            Icons.check_circle_outline,
                            color: AdminColors.success,
                            size: 20,
                          ),
                          onPressed: () => _approve(captain),
                        ),
                        IconButton(
                          tooltip: 'رفض',
                          icon: const Icon(
                            Icons.cancel_outlined,
                            color: AdminColors.error,
                            size: 20,
                          ),
                          onPressed: () => _reject(captain),
                        ),
                      ],
                      if (captain.isApproved || captain.isSuspended)
                        IconButton(
                          tooltip: captain.isSuspended
                              ? 'إعادة تفعيل'
                              : 'إيقاف',
                          icon: Icon(
                            captain.isSuspended
                                ? Icons.play_circle_outline
                                : Icons.block,
                            size: 20,
                            color: captain.isSuspended
                                ? AdminColors.success
                                : AdminColors.error,
                          ),
                          onPressed: () => _toggleSuspend(captain),
                        ),
                      IconButton(
                        tooltip: 'التفاصيل',
                        icon: const Icon(Icons.visibility_outlined, size: 20),
                        onPressed: () => _openDetails(captain),
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

  Widget _statusBadge(CaptainAdminView captain) {
    switch (captain.status) {
      case 'approved':
        return StatusBadge.success('معتمد');
      case 'pending':
        return StatusBadge.warning('قيد المراجعة');
      case 'rejected':
        return StatusBadge.error('مرفوض');
      case 'suspended':
        return StatusBadge.error('موقوف');
      default:
        return StatusBadge.neutral(captain.status);
    }
  }
}
