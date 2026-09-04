import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/nouakchott_bounds.dart';
import '../../../core/services/geocoding_service.dart';
import '../../../core/widgets/real_map_widget.dart';
import '../../../features/destinations/data/models/district.dart';
import '../../../features/destinations/data/models/place.dart';
import '../../../features/destinations/data/models/place_category.dart';
import '../../../features/destinations/data/repositories/categories_repository.dart';
import '../../../features/destinations/data/repositories/districts_repository.dart';
import '../../../features/destinations/data/repositories/places_repository.dart';
import '../../../features/destinations/presentation/widgets/category_icon.dart';
import '../../core/admin_colors.dart';
import '../../widgets/status_badge.dart';

/// Reuses the Phase 2 [PlacesRepository]/[CategoriesRepository] admin*
/// methods directly - same rule as districts/neighborhoods.
class PlacesCategoriesScreen extends StatefulWidget {
  const PlacesCategoriesScreen({super.key});

  @override
  State<PlacesCategoriesScreen> createState() => _PlacesCategoriesScreenState();
}

class _PlacesCategoriesScreenState extends State<PlacesCategoriesScreen>
    with SingleTickerProviderStateMixin {
  final _placesRepo = PlacesRepository();
  final _categoriesRepo = CategoriesRepository();
  final _districtsRepo = DistrictsRepository();
  late final TabController _tabController;
  final _searchController = TextEditingController();

  bool _loading = true;
  List<Place> _places = [];
  List<PlaceCategory> _categories = [];
  List<District> _districts = [];
  String? _districtFilter;
  String? _categoryFilter;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      _placesRepo.adminSearchPlaces(
        query: _searchController.text,
        districtId: _districtFilter,
        categoryId: _categoryFilter,
      ),
      _categoriesRepo.adminListAllCategories(),
      _districtsRepo.adminListAllDistricts(),
    ]);
    if (!mounted) return;
    setState(() {
      _places = results[0] as List<Place>;
      _categories = results[1] as List<PlaceCategory>;
      _districts = results[2] as List<District>;
      _loading = false;
    });
  }

  Future<void> _addOrEditPlace({Place? existing}) async {
    final nameArController = TextEditingController(
      text: existing?.nameAr ?? '',
    );
    final nameFrController = TextEditingController(
      text: existing?.nameFr ?? '',
    );
    final addressArController = TextEditingController(
      text: existing?.addressAr ?? '',
    );
    final latController = TextEditingController(
      text: existing?.latitude.toString() ?? '',
    );
    final lngController = TextEditingController(
      text: existing?.longitude.toString() ?? '',
    );
    String? districtId =
        existing?.districtId ??
        (_districts.isNotEmpty ? _districts.first.id : null);
    String? categoryId =
        existing?.categoryId ??
        (_categories.isNotEmpty ? _categories.first.id : null);
    var isPopular = existing?.isPopular ?? false;
    LatLng? pickedPoint = existing != null
        ? LatLng(existing.latitude, existing.longitude)
        : null;
    var isGeocoding = false;
    String? boundsError;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> handlePick(LatLng point) async {
            setDialogState(() {
              pickedPoint = point;
              latController.text = point.latitude.toStringAsFixed(6);
              lngController.text = point.longitude.toStringAsFixed(6);
              boundsError = isWithinNouakchott(point.latitude, point.longitude)
                  ? null
                  : 'هذه النقطة خارج نطاق أنواكشوط - اختر نقطة داخل المدينة.';
            });
            if (addressArController.text.trim().isNotEmpty) return;
            setDialogState(() => isGeocoding = true);
            final address = await GeocodingService.instance.reverseGeocode(
              point.latitude,
              point.longitude,
            );
            if (address != null) addressArController.text = address;
            setDialogState(() => isGeocoding = false);
          }

          return AlertDialog(
            title: Text(existing == null ? 'إضافة مكان' : 'تعديل المكان'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: districtId,
                    decoration: const InputDecoration(labelText: 'المقاطعة'),
                    items: _districts
                        .map(
                          (d) => DropdownMenuItem(
                            value: d.id,
                            child: Text(d.nameAr),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setDialogState(() => districtId = v),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: categoryId,
                    decoration: const InputDecoration(labelText: 'الفئة'),
                    items: _categories
                        .map(
                          (c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(c.nameAr),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setDialogState(() => categoryId = v),
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
                  TextField(
                    controller: addressArController,
                    decoration: const InputDecoration(labelText: 'العنوان'),
                  ),
                  const SizedBox(height: 12),
                  const Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'اضغط على الخريطة لتحديد الموقع، أو عدّل الإحداثيات يدوياً بالأسفل',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      height: 260,
                      child: RealMapWidget(
                        interactive: true,
                        destLat: pickedPoint?.latitude,
                        destLng: pickedPoint?.longitude,
                        destDraggable: true,
                        onMapTap: handlePick,
                        onDestDragged: handlePick,
                      ),
                    ),
                  ),
                  if (isGeocoding)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'جارٍ تحديد العنوان...',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: latController,
                    decoration: const InputDecoration(labelText: 'خط العرض'),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setDialogState(() => boundsError = null),
                  ),
                  TextField(
                    controller: lngController,
                    decoration: const InputDecoration(labelText: 'خط الطول'),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setDialogState(() => boundsError = null),
                  ),
                  if (boundsError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        boundsError!,
                        style: const TextStyle(
                          color: AdminColors.error,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  CheckboxListTile(
                    value: isPopular,
                    title: const Text('مكان شائع'),
                    onChanged: (v) =>
                        setDialogState(() => isPopular = v ?? false),
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
                onPressed: () {
                  final lat = double.tryParse(latController.text);
                  final lng = double.tryParse(lngController.text);
                  if (lat == null || lng == null) {
                    setDialogState(
                      () => boundsError = 'أدخل إحداثيات صحيحة أو اختر نقطة من الخريطة.',
                    );
                    return;
                  }
                  if (!isWithinNouakchott(lat, lng)) {
                    setDialogState(
                      () => boundsError =
                          'هذه النقطة خارج نطاق أنواكشوط - اختر نقطة داخل المدينة.',
                    );
                    return;
                  }
                  Navigator.pop(context, true);
                },
                child: const Text('حفظ'),
              ),
            ],
          );
        },
      ),
    );
    if (confirmed != true || districtId == null || categoryId == null) return;

    final lat = double.tryParse(latController.text);
    final lng = double.tryParse(lngController.text);
    if (lat == null || lng == null) return;

    if (existing == null) {
      await _placesRepo.adminAddOfficialPlace(
        districtId: districtId!,
        categoryId: categoryId!,
        nameAr: nameArController.text.trim(),
        nameFr: nameFrController.text.trim().isEmpty
            ? null
            : nameFrController.text.trim(),
        addressAr: addressArController.text.trim(),
        latitude: lat,
        longitude: lng,
        isPopular: isPopular,
      );
    } else {
      await _placesRepo.adminUpdateOfficialPlace(
        existing.id,
        nameAr: nameArController.text.trim(),
        nameFr: nameFrController.text.trim(),
        addressAr: addressArController.text.trim(),
        latitude: lat,
        longitude: lng,
        isPopular: isPopular,
        categoryId: categoryId,
      );
    }
    _load();
  }

  Future<void> _togglePlaceActive(Place place) async {
    if (place.isActive) {
      await _placesRepo.adminDeactivatePlace(place.id);
    } else {
      await _placesRepo.adminActivatePlace(place.id);
    }
    _load();
  }

  Future<void> _verifyPlace(Place place) async {
    await _placesRepo.adminVerifyPlace(place.id);
    _load();
  }

  Future<void> _addOrEditCategory({PlaceCategory? existing}) async {
    final codeController = TextEditingController(text: existing?.code ?? '');
    final nameArController = TextEditingController(
      text: existing?.nameAr ?? '',
    );
    final nameFrController = TextEditingController(
      text: existing?.nameFr ?? '',
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? 'إضافة فئة' : 'تعديل الفئة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (existing == null)
              TextField(
                controller: codeController,
                decoration: const InputDecoration(
                  labelText: 'الرمز (بالإنجليزية)',
                ),
              ),
            TextField(
              controller: nameArController,
              decoration: const InputDecoration(labelText: 'الاسم بالعربية'),
            ),
            TextField(
              controller: nameFrController,
              decoration: const InputDecoration(labelText: 'الاسم بالفرنسية'),
            ),
          ],
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
      await _categoriesRepo.adminAddCategory(
        code: codeController.text.trim(),
        nameAr: nameArController.text.trim(),
        nameFr: nameFrController.text.trim().isEmpty
            ? null
            : nameFrController.text.trim(),
      );
    } else {
      await _categoriesRepo.adminUpdateCategory(
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
              Tab(text: 'الأماكن'),
              Tab(text: 'التصنيفات'),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabController,
                  children: [_buildPlacesTab(), _buildCategoriesTab()],
                ),
        ),
      ],
    );
  }

  Widget _buildPlacesTab() {
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
                width: 240,
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'ابحث بالاسم',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                  onSubmitted: (_) => _load(),
                ),
              ),
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<String?>(
                  initialValue: _districtFilter,
                  decoration: const InputDecoration(labelText: 'المقاطعة'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('الكل')),
                    ..._districts.map(
                      (d) =>
                          DropdownMenuItem(value: d.id, child: Text(d.nameAr)),
                    ),
                  ],
                  onChanged: (v) {
                    setState(() => _districtFilter = v);
                    _load();
                  },
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _addOrEditPlace(),
                icon: const Icon(Icons.add),
                label: const Text('إضافة مكان'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('الاسم')),
                    DataColumn(label: Text('الحالة')),
                    DataColumn(label: Text('شائع')),
                    DataColumn(label: Text('موثّق')),
                    DataColumn(label: Text('إجراءات')),
                  ],
                  rows: _places.map((place) {
                    return DataRow(
                      cells: [
                        DataCell(Text(place.displayName)),
                        DataCell(
                          place.isActive
                              ? StatusBadge.success('مفعّل')
                              : StatusBadge.neutral('معطّل'),
                        ),
                        DataCell(
                          place.isPopular
                              ? const Icon(
                                  Icons.star,
                                  color: AdminColors.accent,
                                  size: 18,
                                )
                              : const SizedBox(),
                        ),
                        DataCell(
                          place.isVerified
                              ? const Icon(
                                  Icons.verified,
                                  color: AdminColors.success,
                                  size: 18,
                                )
                              : const SizedBox(),
                        ),
                        DataCell(
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 20),
                                onPressed: () =>
                                    _addOrEditPlace(existing: place),
                              ),
                              if (!place.isVerified)
                                IconButton(
                                  icon: const Icon(
                                    Icons.verified_outlined,
                                    size: 20,
                                  ),
                                  onPressed: () => _verifyPlace(place),
                                ),
                              IconButton(
                                icon: Icon(
                                  place.isActive
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  size: 20,
                                ),
                                onPressed: () => _togglePlaceActive(place),
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

  Widget _buildCategoriesTab() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton.icon(
              onPressed: () => _addOrEditCategory(),
              icon: const Icon(Icons.add),
              label: const Text('إضافة فئة'),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 200,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.1,
              ),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                return Card(
                  child: InkWell(
                    onTap: () => _addOrEditCategory(existing: category),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            iconForCategory(category.iconName),
                            color: AdminColors.primary,
                            size: 28,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            category.nameAr,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
