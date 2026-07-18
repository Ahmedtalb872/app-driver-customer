import 'package:flutter/material.dart';

import '../core/admin_colors.dart';
import '../models/captain_admin_view.dart';
import '../repositories/admin_captains_repository.dart';
import '../repositories/admin_trips_repository.dart';

/// Lets an operator pick an approved, currently-online captain to assign (or
/// reassign) to a trip. Captains already busy on another active trip are
/// excluded, except the trip's current captain (if any), who is always
/// shown so the admin can see who currently holds it. Returns the chosen
/// captain id, or null if dismissed.
Future<String?> showCaptainPickerDialog(
  BuildContext context, {
  String? currentCaptainId,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) =>
        _CaptainPickerDialog(currentCaptainId: currentCaptainId),
  );
}

class _CaptainPickerDialog extends StatefulWidget {
  final String? currentCaptainId;

  const _CaptainPickerDialog({this.currentCaptainId});

  @override
  State<_CaptainPickerDialog> createState() => _CaptainPickerDialogState();
}

class _CaptainPickerDialogState extends State<_CaptainPickerDialog> {
  final _captainsRepository = AdminCaptainsRepository();
  final _tripsRepository = AdminTripsRepository();
  final _searchController = TextEditingController();

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
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _captainsRepository.loadCaptains(
          statusFilter: 'approved',
          onlineFilter: true,
          limit: 200,
        ),
        _tripsRepository.loadBusyCaptainIds(),
      ]);
      final candidates = results[0] as List<CaptainAdminView>;
      final busyIds = results[1] as Set<String>;
      setState(() {
        _captains = candidates
            .where(
              (c) => !busyIds.contains(c.id) || c.id == widget.currentCaptainId,
            )
            .toList();
      });
    } catch (_) {
      setState(() => _error = 'تعذر تحميل قائمة الكباتن المتاحين.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = query.isEmpty
        ? _captains
        : _captains
              .where(
                (c) =>
                    c.fullName.toLowerCase().contains(query) ||
                    (c.phone ?? '').toLowerCase().contains(query),
              )
              .toList();

    return AlertDialog(
      title: const Text(
        'اختر كابتن للتعيين',
        style: TextStyle(fontFamily: 'Cairo'),
      ),
      content: SizedBox(
        width: 380,
        height: 420,
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'بحث بالاسم أو الهاتف...',
                isDense: true,
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(child: _buildList(filtered)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
      ],
    );
  }

  Widget _buildList(List<CaptainAdminView> captains) {
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
    if (captains.isEmpty) {
      return const Center(
        child: Text(
          'لا يوجد كباتن متاحون للتعيين حالياً.',
          style: TextStyle(fontFamily: 'Cairo'),
        ),
      );
    }
    return ListView.separated(
      itemCount: captains.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final captain = captains[index];
        final isCurrent = captain.id == widget.currentCaptainId;
        return ListTile(
          title: Text(
            captain.fullName,
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
          subtitle: Text(
            '${captain.phone ?? '-'} • ${captain.vehicleType ?? '-'}',
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
          trailing: isCurrent
              ? const Text(
                  'الكابتن الحالي',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: AdminColors.textSecondary,
                    fontSize: 11,
                  ),
                )
              : null,
          onTap: () => Navigator.of(context).pop(captain.id),
        );
      },
    );
  }
}
