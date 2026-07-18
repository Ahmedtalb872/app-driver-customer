import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/admin_colors.dart';
import '../../repositories/admin_users_repository.dart';
import '../../services/admin_session.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/status_badge.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _repository = AdminUsersRepository();
  bool _loading = true;
  List<Map<String, dynamic>> _admins = [];

  static const _roleLabels = {
    'super_admin': 'مدير عام',
    'operations_admin': 'مدير عمليات',
    'finance_admin': 'مدير مالي',
    'support_admin': 'مدير دعم',
    'content_admin': 'مدير محتوى',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final admins = await _repository.loadAdmins();
    if (!mounted) return;
    setState(() {
      _admins = admins;
      _loading = false;
    });
  }

  Future<void> _addAdmin() async {
    final phoneController = TextEditingController();
    final nameController = TextEditingController();
    var role = 'support_admin';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('إضافة مسؤول'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'يجب أن يمتلك المستخدم حساباً مسجلاً بالفعل (عبر تطبيق الجوال) '
                  'قبل ترقيته إلى صلاحية إدارية.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AdminColors.textSecondary,
                    fontFamily: 'Cairo',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(
                    labelText: 'رقم هاتف الحساب',
                  ),
                ),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'الاسم الكامل'),
                ),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  decoration: const InputDecoration(labelText: 'الدور'),
                  items: _roleLabels.entries
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setDialogState(() => role = v ?? role),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('ترقية إلى مسؤول'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;

    try {
      final profile = await _repository.findProfileByPhone(
        phoneController.text.trim(),
      );
      if (profile == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'لا يوجد مستخدم مسجل بهذا الرقم.',
                style: TextStyle(fontFamily: 'Cairo'),
              ),
            ),
          );
        }
        return;
      }
      await _repository.promoteToAdmin(
        targetUserId: profile['id'] as String,
        adminRole: role,
        fullName: nameController.text.trim().isEmpty
            ? null
            : nameController.text.trim(),
      );
      _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تعذر إضافة المسؤول، تحقق من صلاحياتك.',
              style: TextStyle(fontFamily: 'Cairo'),
            ),
          ),
        );
      }
    }
  }

  Future<void> _toggleActive(Map<String, dynamic> admin) async {
    final isActive = admin['is_active'] as bool? ?? true;
    final ok = await showConfirmDialog(
      context,
      title: isActive ? 'تعطيل المسؤول' : 'تفعيل المسؤول',
      message: 'هل أنت متأكد؟',
      destructive: isActive,
    );
    if (!ok) return;
    try {
      await _repository.setActive(admin['id'] as String, !isActive);
      _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تعذر تنفيذ الإجراء.',
              style: TextStyle(fontFamily: 'Cairo'),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AdminSession>();
    final isSuperAdmin = session.profile?.isSuperAdmin ?? false;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isSuperAdmin)
            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton.icon(
                onPressed: _addAdmin,
                icon: const Icon(Icons.add),
                label: const Text('إضافة مسؤول'),
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
                          DataColumn(label: Text('الدور')),
                          DataColumn(label: Text('الحالة')),
                          DataColumn(label: Text('إجراءات')),
                        ],
                        rows: _admins.map((admin) {
                          final profile =
                              admin['profiles'] as Map<String, dynamic>?;
                          final isActive = admin['is_active'] as bool? ?? true;
                          final isSelf = admin['id'] == session.profile?.id;
                          return DataRow(
                            cells: [
                              DataCell(
                                Text(
                                  (admin['full_name'] as String?) ??
                                      (profile?['full_name'] as String?) ??
                                      '-',
                                ),
                              ),
                              DataCell(
                                Text((profile?['phone'] as String?) ?? '-'),
                              ),
                              DataCell(
                                Text(
                                  _roleLabels[admin['admin_role']] ??
                                      '${admin['admin_role']}',
                                ),
                              ),
                              DataCell(
                                isActive
                                    ? StatusBadge.success('مفعّل')
                                    : StatusBadge.error('معطّل'),
                              ),
                              DataCell(
                                isSuperAdmin && !isSelf
                                    ? IconButton(
                                        icon: Icon(
                                          isActive
                                              ? Icons.block
                                              : Icons.check_circle_outline,
                                          size: 20,
                                          color: isActive
                                              ? AdminColors.error
                                              : AdminColors.success,
                                        ),
                                        onPressed: () => _toggleActive(admin),
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
