import 'package:flutter/material.dart';

import '../../../features/destinations/data/models/district.dart';
import '../../../features/destinations/data/models/neighborhood.dart';
import '../../../features/destinations/data/repositories/districts_repository.dart';
import '../../../features/destinations/data/repositories/neighborhoods_repository.dart';
import '../../core/admin_colors.dart';
import '../../widgets/status_badge.dart';

/// Reuses the Phase 2 [DistrictsRepository]/[NeighborhoodsRepository]
/// admin* methods directly - no new backend for locations, exactly as the
/// spec requires ("do not rebuild or duplicate Phase 2 tables").
class DistrictsNeighborhoodsScreen extends StatefulWidget {
  const DistrictsNeighborhoodsScreen({super.key});

  @override
  State<DistrictsNeighborhoodsScreen> createState() =>
      _DistrictsNeighborhoodsScreenState();
}

class _DistrictsNeighborhoodsScreenState
    extends State<DistrictsNeighborhoodsScreen>
    with SingleTickerProviderStateMixin {
  final _districtsRepo = DistrictsRepository();
  final _neighborhoodsRepo = NeighborhoodsRepository();
  late final TabController _tabController;

  bool _loading = true;
  List<District> _districts = [];
  List<Neighborhood> _neighborhoods = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      _districtsRepo.adminListAllDistricts(),
      _neighborhoodsRepo.adminListAllNeighborhoods(),
    ]);
    if (!mounted) return;
    setState(() {
      _districts = results[0] as List<District>;
      _neighborhoods = results[1] as List<Neighborhood>;
      _loading = false;
    });
  }

  Future<void> _addOrEditDistrict({District? existing}) async {
    final nameArController = TextEditingController(
      text: existing?.nameAr ?? '',
    );
    final nameFrController = TextEditingController(
      text: existing?.nameFr ?? '',
    );
    final codeController = TextEditingController(text: existing?.code ?? '');
    final latController = TextEditingController(
      text: existing?.latitude?.toString() ?? '',
    );
    final lngController = TextEditingController(
      text: existing?.longitude?.toString() ?? '',
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? 'إضافة مقاطعة' : 'تعديل المقاطعة'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameArController,
                decoration: const InputDecoration(labelText: 'الاسم بالعربية'),
              ),
              TextField(
                controller: nameFrController,
                decoration: const InputDecoration(labelText: 'الاسم بالفرنسية'),
              ),
              if (existing == null)
                TextField(
                  controller: codeController,
                  decoration: const InputDecoration(
                    labelText: 'الرمز (بالإنجليزية)',
                  ),
                ),
              TextField(
                controller: latController,
                decoration: const InputDecoration(labelText: 'خط العرض'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: lngController,
                decoration: const InputDecoration(labelText: 'خط الطول'),
                keyboardType: TextInputType.number,
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
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    if (existing == null) {
      await _districtsRepo.adminAddDistrict(
        nameAr: nameArController.text.trim(),
        nameFr: nameFrController.text.trim().isEmpty
            ? null
            : nameFrController.text.trim(),
        code: codeController.text.trim(),
        latitude: double.tryParse(latController.text),
        longitude: double.tryParse(lngController.text),
      );
    } else {
      await _districtsRepo.adminUpdateDistrict(
        existing.id,
        nameAr: nameArController.text.trim(),
        nameFr: nameFrController.text.trim(),
        latitude: double.tryParse(latController.text),
        longitude: double.tryParse(lngController.text),
      );
    }
    _load();
  }

  Future<void> _toggleDistrictActive(District district) async {
    if (district.isActive) {
      await _districtsRepo.adminDeactivateDistrict(district.id);
    } else {
      await _districtsRepo.adminActivateDistrict(district.id);
    }
    _load();
  }

  Future<void> _addOrEditNeighborhood({Neighborhood? existing}) async {
    final nameArController = TextEditingController(
      text: existing?.nameAr ?? '',
    );
    final nameFrController = TextEditingController(
      text: existing?.nameFr ?? '',
    );
    String? selectedDistrictId =
        existing?.districtId ??
        (_districts.isNotEmpty ? _districts.first.id : null);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'إضافة حي' : 'تعديل الحي'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedDistrictId,
                  decoration: const InputDecoration(labelText: 'المقاطعة'),
                  items: _districts
                      .map(
                        (d) => DropdownMenuItem(
                          value: d.id,
                          child: Text(d.nameAr),
                        ),
                      )
                      .toList(),
                  onChanged: (v) =>
                      setDialogState(() => selectedDistrictId = v),
                ),
                TextField(
                  controller: nameArController,
                  decoration: const InputDecoration(
                    labelText: 'الاسم بالعربية',
                  ),
                ),
                TextField(
                  controller: nameFrController,
                  decoration: const InputDecoration(
                    labelText: 'الاسم بالفرنسية',
                  ),
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
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || selectedDistrictId == null) return;

    if (existing == null) {
      await _neighborhoodsRepo.adminAddNeighborhood(
        districtId: selectedDistrictId!,
        nameAr: nameArController.text.trim(),
        nameFr: nameFrController.text.trim().isEmpty
            ? null
            : nameFrController.text.trim(),
      );
    } else {
      await _neighborhoodsRepo.adminUpdateNeighborhood(
        existing.id,
        nameAr: nameArController.text.trim(),
        nameFr: nameFrController.text.trim(),
      );
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: AdminColors.surface,
          child: TabBar(
            controller: _tabController,
            labelColor: AdminColors.primary,
            tabs: const [
              Tab(text: 'المقاطعات'),
              Tab(text: 'الأحياء'),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabController,
                  children: [_buildDistrictsTab(), _buildNeighborhoodsTab()],
                ),
        ),
      ],
    );
  }

  Widget _buildDistrictsTab() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton.icon(
              onPressed: () => _addOrEditDistrict(),
              icon: const Icon(Icons.add),
              label: const Text('إضافة مقاطعة'),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('الاسم')),
                    DataColumn(label: Text('الرمز')),
                    DataColumn(label: Text('الحالة')),
                    DataColumn(label: Text('إجراءات')),
                  ],
                  rows: _districts.map((d) {
                    return DataRow(
                      cells: [
                        DataCell(Text(d.nameAr)),
                        DataCell(Text(d.code)),
                        DataCell(
                          d.isActive
                              ? StatusBadge.success('مفعّل')
                              : StatusBadge.neutral('معطّل'),
                        ),
                        DataCell(
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 20),
                                onPressed: () =>
                                    _addOrEditDistrict(existing: d),
                              ),
                              IconButton(
                                icon: Icon(
                                  d.isActive
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  size: 20,
                                ),
                                onPressed: () => _toggleDistrictActive(d),
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
          ),
        ],
      ),
    );
  }

  Widget _buildNeighborhoodsTab() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton.icon(
              onPressed: () => _addOrEditNeighborhood(),
              icon: const Icon(Icons.add),
              label: const Text('إضافة حي'),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('الاسم')),
                    DataColumn(label: Text('المقاطعة')),
                    DataColumn(label: Text('إجراءات')),
                  ],
                  rows: _neighborhoods.map((n) {
                    final districtName = _districts
                        .where((d) => d.id == n.districtId)
                        .map((d) => d.nameAr)
                        .cast<String?>()
                        .firstWhere((_) => true, orElse: () => '-');
                    return DataRow(
                      cells: [
                        DataCell(Text(n.nameAr)),
                        DataCell(Text(districtName ?? '-')),
                        DataCell(
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 20),
                            onPressed: () =>
                                _addOrEditNeighborhood(existing: n),
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
