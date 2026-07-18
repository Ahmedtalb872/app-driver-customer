import 'package:flutter/material.dart';

import '../../features/destinations/data/models/district.dart';
import '../../features/destinations/data/models/place.dart';
import '../../features/destinations/data/models/place_category.dart';
import '../../features/destinations/data/repositories/categories_repository.dart';
import '../../features/destinations/data/repositories/districts_repository.dart';
import '../../features/destinations/data/repositories/places_repository.dart';
import '../core/admin_colors.dart';

class PickedDestination {
  final String address;
  final double latitude;
  final double longitude;

  const PickedDestination({
    required this.address,
    required this.latitude,
    required this.longitude,
  });
}

/// Reuses the existing Phase-2 destinations system (districts -> categories
/// -> registered places) so an operator can pick a known place instead of
/// typing a free-text address. Returns null if the operator picked "منزل أو
/// موقع غير مسجل" (or dismissed the sheet) - in that case the caller's
/// existing free-text-address + map-tap flow is the right path, unchanged.
Future<PickedDestination?> showDestinationPickerSheet(BuildContext context) {
  return showModalBottomSheet<PickedDestination>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const _DestinationPickerSheet(),
  );
}

enum _Step { district, category, place }

class _DestinationPickerSheet extends StatefulWidget {
  const _DestinationPickerSheet();

  @override
  State<_DestinationPickerSheet> createState() =>
      _DestinationPickerSheetState();
}

class _DestinationPickerSheetState extends State<_DestinationPickerSheet> {
  final _districtsRepository = DistrictsRepository();
  final _categoriesRepository = CategoriesRepository();
  final _placesRepository = PlacesRepository();

  _Step _step = _Step.district;
  bool _loading = true;
  String? _error;

  List<District> _districts = [];
  List<PlaceCategory> _categories = [];
  List<Place> _places = [];

  District? _selectedDistrict;
  PlaceCategory? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _loadDistricts();
  }

  Future<void> _loadDistricts() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final districts = await _districtsRepository.loadActiveDistricts();
      setState(() => _districts = districts);
    } catch (_) {
      setState(() => _error = 'تعذر تحميل قائمة المقاطعات.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _selectDistrict(District district) async {
    setState(() {
      _selectedDistrict = district;
      _step = _Step.category;
      _loading = true;
      _error = null;
    });
    try {
      final categories = await _categoriesRepository
          .loadCategoriesWithPlaceCounts(district.id);
      setState(() => _categories = categories);
    } catch (_) {
      setState(() => _error = 'تعذر تحميل التصنيفات.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _selectCategory(PlaceCategory category) async {
    setState(() {
      _selectedCategory = category;
      _step = _Step.place;
      _loading = true;
      _error = null;
    });
    try {
      final places = await _placesRepository.loadByDistrictAndCategory(
        districtId: _selectedDistrict!.id,
        categoryId: category.id,
      );
      setState(() => _places = places);
    } catch (_) {
      setState(() => _error = 'تعذر تحميل الأماكن.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _goBack() {
    setState(() {
      if (_step == _Step.place) {
        _step = _Step.category;
      } else if (_step == _Step.category) {
        _step = _Step.district;
        _selectedDistrict = null;
      }
    });
  }

  void _retry() {
    if (_step == _Step.district) {
      _loadDistricts();
    } else if (_step == _Step.category) {
      _selectDistrict(_selectedDistrict!);
    } else {
      _selectCategory(_selectedCategory!);
    }
  }

  void _pickPlace(Place place) {
    Navigator.of(context).pop(
      PickedDestination(
        address: place.displayAddress ?? place.displayName,
        latitude: place.latitude,
        longitude: place.longitude,
      ),
    );
  }

  void _pickUnregistered() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AdminColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    if (_step != _Step.district)
                      IconButton(
                        onPressed: _goBack,
                        icon: const Icon(Icons.arrow_forward_rounded),
                      ),
                    Expanded(
                      child: Text(
                        _titleForStep(),
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(child: _buildBody(scrollController)),
            ],
          ),
        );
      },
    );
  }

  String _titleForStep() {
    switch (_step) {
      case _Step.district:
        return 'اختر المقاطعة';
      case _Step.category:
        return 'اختر التصنيف - ${_selectedDistrict?.nameAr ?? ''}';
      case _Step.place:
        return 'اختر المكان - ${_selectedCategory?.nameAr ?? ''}';
    }
  }

  Widget _buildBody(ScrollController scrollController) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(fontFamily: 'Cairo')),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _retry,
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      );
    }

    switch (_step) {
      case _Step.district:
        return ListView.separated(
          controller: scrollController,
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: _districts.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final district = _districts[index];
            return ListTile(
              title: Text(
                district.nameAr,
                style: const TextStyle(fontFamily: 'Cairo'),
              ),
              trailing: const Icon(Icons.chevron_left_rounded),
              onTap: () => _selectDistrict(district),
            );
          },
        );
      case _Step.category:
        return ListView.separated(
          controller: scrollController,
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: _categories.length + 1,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            if (index == _categories.length) {
              return ListTile(
                leading: const Icon(Icons.home_outlined),
                title: const Text(
                  'منزل أو موقع غير مسجل',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: const Text(
                  'استخدم العنوان النصي والخريطة يدوياً',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 11),
                ),
                onTap: _pickUnregistered,
              );
            }
            final category = _categories[index];
            return ListTile(
              title: Text(
                category.nameAr,
                style: const TextStyle(fontFamily: 'Cairo'),
              ),
              subtitle: Text(
                '${category.placeCount} مكان مسجل',
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 11),
              ),
              enabled: category.placeCount > 0,
              trailing: const Icon(Icons.chevron_left_rounded),
              onTap: () => _selectCategory(category),
            );
          },
        );
      case _Step.place:
        if (_places.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'لا توجد أماكن مسجلة في هذا التصنيف.',
                  style: TextStyle(fontFamily: 'Cairo'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _pickUnregistered,
                  child: const Text(
                    'استخدام منزل أو موقع غير مسجل',
                    style: TextStyle(fontFamily: 'Cairo'),
                  ),
                ),
              ],
            ),
          );
        }
        return ListView.separated(
          controller: scrollController,
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: _places.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final place = _places[index];
            return ListTile(
              title: Text(
                place.displayName,
                style: const TextStyle(fontFamily: 'Cairo'),
              ),
              subtitle: Text(
                place.displayAddress ?? '-',
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 11),
              ),
              onTap: () => _pickPlace(place),
            );
          },
        );
    }
  }
}
