import 'package:flutter/material.dart';

import '../../models/customer_admin_view.dart';
import '../../repositories/admin_customers_repository.dart';
import '../../repositories/admin_settings_repository.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/status_badge.dart';

/// Dedicated "سلفلي" section - previously just a couple of fields buried
/// inside the general settings screen. Two parts: the eligibility controls
/// (the promo on/off switch that was already there, plus the normal-tier
/// thresholds/caps that used to be hardcoded in selefli_credit_cap(), see
/// 20261003000110_selefli_configurable_tiers.sql) and a live list of every
/// customer currently carrying outstanding Selefli debt.
class AdminSelefliScreen extends StatefulWidget {
  const AdminSelefliScreen({super.key});

  @override
  State<AdminSelefliScreen> createState() => _AdminSelefliScreenState();
}

class _AdminSelefliScreenState extends State<AdminSelefliScreen> {
  final _settingsRepository = AdminSettingsRepository();
  final _customersRepository = AdminCustomersRepository();

  bool _loading = true;
  Map<String, dynamic> _settings = {};
  List<CustomerAdminView> _debtors = [];

  bool _promoEnabled = false;
  late final TextEditingController _promoCapController;
  late final TextEditingController _tier1MinTripsController;
  late final TextEditingController _tier1CapController;
  late final TextEditingController _tier2MinTripsController;
  late final TextEditingController _tier2CapController;

  @override
  void initState() {
    super.initState();
    _promoCapController = TextEditingController();
    _tier1MinTripsController = TextEditingController();
    _tier1CapController = TextEditingController();
    _tier2MinTripsController = TextEditingController();
    _tier2CapController = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _promoCapController.dispose();
    _tier1MinTripsController.dispose();
    _tier1CapController.dispose();
    _tier2MinTripsController.dispose();
    _tier2CapController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      _settingsRepository.load(),
      _customersRepository.loadCustomersWithOutstandingDebt(),
    ]);
    if (!mounted) return;
    final settings = results[0] as Map<String, dynamic>;
    setState(() {
      _settings = settings;
      _debtors = results[1] as List<CustomerAdminView>;
      _promoEnabled = settings['selefli_promo_enabled'] as bool? ?? false;
      _promoCapController.text =
          (settings['selefli_promo_cap'] as num?)?.toString() ?? '100';
      _tier1MinTripsController.text =
          (settings['selefli_tier1_min_trips'] as num?)?.toString() ?? '10';
      _tier1CapController.text =
          (settings['selefli_tier1_cap'] as num?)?.toString() ?? '100';
      _tier2MinTripsController.text =
          (settings['selefli_tier2_min_trips'] as num?)?.toString() ?? '30';
      _tier2CapController.text =
          (settings['selefli_tier2_cap'] as num?)?.toString() ?? '200';
      _loading = false;
    });
  }

  Future<void> _save() async {
    final ok = await showConfirmDialog(
      context,
      title: 'حفظ إعدادات سلفلي',
      message: 'هل تريد حفظ التغييرات على شروط أهلية سلفلي؟',
    );
    if (!ok) return;

    final payload = {
      'selefli_promo_enabled': _promoEnabled,
      'selefli_promo_cap':
          double.tryParse(_promoCapController.text.trim()) ?? 100,
      'selefli_tier1_min_trips':
          int.tryParse(_tier1MinTripsController.text.trim()) ?? 10,
      'selefli_tier1_cap':
          double.tryParse(_tier1CapController.text.trim()) ?? 100,
      'selefli_tier2_min_trips':
          int.tryParse(_tier2MinTripsController.text.trim()) ?? 30,
      'selefli_tier2_cap':
          double.tryParse(_tier2CapController.text.trim()) ?? 200,
    };
    await _settingsRepository.update(_settings, payload);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تم حفظ إعدادات سلفلي بنجاح',
            style: TextStyle(fontFamily: 'Cairo'),
          ),
        ),
      );
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Padding(
      padding: const EdgeInsets.all(20),
      child: ListView(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'شروط الأهلية العادية',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'تُطبَّق تلقائياً حسب عدد مشاوير الزبون المكتملة، طالما '
                    'العرض الترويجي أدناه غير مفعّل.',
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _tier1MinTripsController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'المستوى الأول: بعد كم مشوار',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _tier1CapController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'الحد الأقصى (أوقية)',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _tier2MinTripsController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'المستوى الثاني: بعد كم مشوار',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _tier2CapController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'الحد الأقصى (أوقية)',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                  SwitchListTile(
                    title: const Text(
                      'عرض ترويجي: سلفلي للجميع',
                      style: TextStyle(fontFamily: 'Cairo'),
                    ),
                    subtitle: const Text(
                      'عند التفعيل، يصبح كل زبون مؤهلاً لسلفلي فوراً بغض '
                      'النظر عن عدد مشاويره - تحفيز لتنزيل التطبيق. أوقفه '
                      'لإعادة العمل بالمستويين أعلاه حسب عدد المشاوير '
                      'المكتملة.',
                      style: TextStyle(fontFamily: 'Cairo', fontSize: 12),
                    ),
                    isThreeLine: true,
                    value: _promoEnabled,
                    onChanged: (v) => setState(() => _promoEnabled = v),
                  ),
                  if (_promoEnabled) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: _promoCapController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'الحد الأقصى لكل زبون أثناء العرض (أوقية)',
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ElevatedButton(
                      onPressed: _save,
                      child: const Text('حفظ الإعدادات'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'الزبناء ذوو دين سلفلي مستحق (${_debtors.length})',
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 12),
          if (_debtors.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'لا يوجد زبناء عليهم دين سلفلي مستحق حالياً.',
                  style: TextStyle(fontFamily: 'Cairo'),
                ),
              ),
            )
          else
            Card(
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('الاسم')),
                      DataColumn(label: Text('الهاتف')),
                      DataColumn(label: Text('عدد المشاوير')),
                      DataColumn(label: Text('الدين المستحق')),
                    ],
                    rows: _debtors
                        .map(
                          (c) => DataRow(
                            cells: [
                              DataCell(Text(c.fullName.isEmpty ? '-' : c.fullName)),
                              DataCell(Text(c.phone ?? '-')),
                              DataCell(Text('${c.completedTripsCount}')),
                              DataCell(
                                StatusBadge.error(
                                  '${c.outstandingSelefliDebt!.toStringAsFixed(0)} أوقية',
                                ),
                              ),
                            ],
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
