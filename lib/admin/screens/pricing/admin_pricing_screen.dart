import 'package:flutter/material.dart';

import '../../core/admin_colors.dart';
import '../../repositories/admin_pricing_repository.dart';
import '../../widgets/confirm_dialog.dart';

class AdminPricingScreen extends StatefulWidget {
  const AdminPricingScreen({super.key});

  @override
  State<AdminPricingScreen> createState() => _AdminPricingScreenState();
}

class _AdminPricingScreenState extends State<AdminPricingScreen> {
  final _repository = AdminPricingRepository();
  bool _loading = true;
  List<Map<String, dynamic>> _configs = [];

  static const _vehicleLabels = {
    'economy': 'إقتصادية',
    'comfort': 'مريحة',
    'family': 'عائلية',
    'motorcycle': 'دراجة نارية (توصيل)',
  };
  static const _fields = [
    ('base_fare', 'الأجرة الأساسية'),
    ('price_per_km', 'السعر لكل كيلومتر'),
    ('price_per_minute', 'السعر لكل دقيقة'),
    ('minimum_fare', 'الحد الأدنى للأجرة'),
    ('waiting_fee_per_minute', 'رسوم الانتظار لكل دقيقة'),
    ('cancellation_fee', 'رسوم الإلغاء'),
    ('commission_percentage', 'نسبة عمولة المنصة (%)'),
    ('surge_multiplier', 'معامل التسعير المرتفع'),
    ('open_trip_base_fare', 'أجرة بداية المشوار المفتوح'),
    ('open_trip_base_distance_km', 'مسافة بداية المشوار المفتوح (كم)'),
    ('open_trip_base_minutes', 'مدة بداية المشوار المفتوح (دقيقة)'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final configs = await _repository.loadAll();
    if (!mounted) return;
    setState(() {
      _configs = configs;
      _loading = false;
    });
  }

  Future<void> _edit(Map<String, dynamic> config) async {
    final controllers = {
      for (final field in _fields)
        field.$1: TextEditingController(text: '${config[field.$1]}'),
    };

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'تعديل تسعير ${_vehicleLabels[config['vehicle_type']] ?? config['vehicle_type']}',
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _fields
                .map(
                  (field) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: TextField(
                      controller: controllers[field.$1],
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(labelText: field.$2),
                    ),
                  ),
                )
                .toList(),
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
    if (!mounted) return;

    final ok = await showConfirmDialog(
      context,
      title: 'تأكيد تغيير التسعير',
      message:
          'سيتم تطبيق هذه التغييرات فوراً على حسابات الأجرة الجديدة. هل تريد المتابعة؟',
    );
    if (!ok) return;

    final payload = {
      for (final field in _fields)
        field.$1:
            double.tryParse(controllers[field.$1]!.text) ?? config[field.$1],
    };

    await _repository.update(config['id'] as String, config, payload);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Padding(
      padding: const EdgeInsets.all(20),
      child: ListView(
        children: _configs.map((config) {
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _vehicleLabels[config['vehicle_type']] ??
                            '${config['vehicle_type']}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _edit(config),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('تعديل'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'آخر تحديث: ${(config['updated_at'] as String? ?? '').split('T').first}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AdminColors.textSecondary,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  const Divider(height: 24),
                  Wrap(
                    spacing: 24,
                    runSpacing: 12,
                    children: _fields
                        .map(
                          (field) => SizedBox(
                            width: 160,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  field.$2,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AdminColors.textSecondary,
                                    fontFamily: 'Cairo',
                                  ),
                                ),
                                Text(
                                  '${config[field.$1]}',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Cairo',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
