import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/admin_colors.dart';
import '../../models/finance_report_row.dart';
import '../../repositories/admin_finance_reports_repository.dart';
import '../../utils/csv_downloader.dart';
import '../../utils/report_printer.dart';
import '../../widgets/stat_card.dart';

/// "المالية" - daily and monthly recharge reports, printable as PDF.
///
/// Every bucket in the selected range is listed even when nothing was
/// recharged that day, so a printed report reads as a continuous ledger
/// with no unexplained gaps.
class FinanceReportsScreen extends StatefulWidget {
  const FinanceReportsScreen({super.key});

  @override
  State<FinanceReportsScreen> createState() => _FinanceReportsScreenState();
}

class _FinanceReportsScreenState extends State<FinanceReportsScreen> {
  static const List<String> _arabicMonths = [
    'يناير',
    'فبراير',
    'مارس',
    'أبريل',
    'مايو',
    'يونيو',
    'يوليو',
    'أغسطس',
    'سبتمبر',
    'أكتوبر',
    'نوفمبر',
    'ديسمبر',
  ];

  // DateTime.weekday is 1=Monday .. 7=Sunday.
  static const List<String> _arabicWeekdays = [
    'الاثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
    'السبت',
    'الأحد',
  ];

  final _repository = AdminFinanceReportsRepository();

  // Latin digits on purpose: these numbers get pasted into bank forms and
  // spreadsheets, where Arabic-Indic digits are a nuisance.
  final _money = NumberFormat('#,##0', 'en');
  final _isoDate = DateFormat('yyyy-MM-dd');

  bool _monthly = false;
  bool _loading = true;
  String? _error;
  late DateTime _from;
  late DateTime _to;
  List<FinanceReportRow> _rows = const [];
  FinanceReportTotals _totals = FinanceReportTotals.empty;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _from = DateTime(now.year, now.month, 1);
    _to = DateTime(now.year, now.month, now.day);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await _repository.loadReport(
        from: _from,
        to: _to,
        monthly: _monthly,
      );
      final totals = await _repository.loadTotals(from: _from, to: _to);
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _totals = totals;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _readableError(error);
      });
    }
  }

  String _readableError(Object error) {
    final text = error.toString();
    if (text.contains('RANGE_TOO_LARGE')) {
      return 'المدة المختارة طويلة جداً، اختر مدة أقصر.';
    }
    if (text.contains('INVALID_RANGE')) {
      return 'تواريخ غير صحيحة.';
    }
    if (text.contains('finance_admin')) {
      return 'ليس لديك صلاحية الاطلاع على التقارير المالية.';
    }
    return 'تعذّر تحميل التقرير، حاول مرة أخرى.';
  }

  void _applyRange(DateTime from, DateTime to, {bool? monthly}) {
    setState(() {
      _from = DateTime(from.year, from.month, from.day);
      _to = DateTime(to.year, to.month, to.day);
      if (monthly != null) _monthly = monthly;
    });
    _load();
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: DateTimeRange(start: _from, end: _to),
      helpText: 'اختر المدة',
      saveText: 'تطبيق',
    );
    if (picked == null) return;
    _applyRange(picked.start, picked.end);
  }

  // ---------------------------------------------------------------- labels

  String _bucketLabel(DateTime bucket) {
    if (_monthly) {
      return '${_arabicMonths[bucket.month - 1]} ${bucket.year}';
    }
    return '${_arabicWeekdays[bucket.weekday - 1]} '
        '${_isoDate.format(bucket)}';
  }

  String get _rangeLabel =>
      'من ${_isoDate.format(_from)} إلى ${_isoDate.format(_to)}';

  // ---------------------------------------------------------------- export

  static String _esc(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');

  void _exportPdf() {
    final buffer = StringBuffer()
      ..writeln('<header>')
      ..writeln('<h1>الهدهد — التقرير المالي '
          '(${_monthly ? 'شهري' : 'يومي'})</h1>')
      ..writeln('<p class="meta">${_esc(_rangeLabel)} — '
          'أُصدر في ${_isoDate.format(DateTime.now())}</p>')
      ..writeln('</header>')
      ..writeln('<div class="cards">')
      ..writeln(_htmlCard('${_totals.captainsCount}', 'كباتن قاموا بالشحن'))
      ..writeln(_htmlCard(_money.format(_totals.captainsAmount),
          'مجموع شحن الكباتن (أوقية)'))
      ..writeln(_htmlCard('${_totals.requestsCount}', 'عدد عمليات الشحن'))
      ..writeln(_htmlCard(
          _money.format(_totals.totalAmount), 'الإجمالي المشحون (أوقية)'))
      ..writeln('</div>')
      ..writeln('<table>')
      ..writeln('<thead><tr>'
          '<th>${_monthly ? 'الشهر' : 'اليوم'}</th>'
          '<th>عدد الكباتن</th>'
          '<th>مبلغ الكباتن</th>'
          '<th>عدد الزبائن</th>'
          '<th>مبلغ الزبائن</th>'
          '<th>عمليات الشحن</th>'
          '<th>الإجمالي</th>'
          '</tr></thead>')
      ..writeln('<tbody>');

    for (final row in _rows) {
      buffer.writeln(
        '<tr${row.isEmpty ? ' class="empty"' : ''}>'
        '<td>${_esc(_bucketLabel(row.bucket))}</td>'
        '<td>${row.captainsCount}</td>'
        '<td>${_money.format(row.captainsAmount)}</td>'
        '<td>${row.customersCount}</td>'
        '<td>${_money.format(row.customersAmount)}</td>'
        '<td>${row.requestsCount}</td>'
        '<td>${_money.format(row.totalAmount)}</td>'
        '</tr>',
      );
    }

    buffer
      ..writeln('</tbody>')
      ..writeln('<tfoot><tr>'
          '<td>الإجمالي</td>'
          '<td>${_totals.captainsCount}</td>'
          '<td>${_money.format(_totals.captainsAmount)}</td>'
          '<td>${_totals.customersCount}</td>'
          '<td>${_money.format(_totals.customersAmount)}</td>'
          '<td>${_totals.requestsCount}</td>'
          '<td>${_money.format(_totals.totalAmount)}</td>'
          '</tr></tfoot>')
      ..writeln('</table>')
      ..writeln('<footer>'
          'عدد الكباتن والزبائن في صف الإجمالي هو عدد الأشخاص المختلفين '
          'خلال كامل المدة، لذلك لا يساوي بالضرورة مجموع الأعمدة أعلاه '
          '(من شحن في أكثر من يوم يُحسب مرة واحدة).'
          '</footer>');

    printReportHtml('التقرير المالي - الهدهد', buffer.toString());
  }

  static String _htmlCard(String value, String label) =>
      '<div class="card"><div class="v">$value</div>'
      '<div class="l">$label</div></div>';

  void _exportCsv() {
    final buffer = StringBuffer()
      // UTF-8 BOM so Excel opens the Arabic headers correctly.
      ..write('﻿')
      ..writeln(
        [
          _monthly ? 'الشهر' : 'اليوم',
          'عدد الكباتن',
          'مبلغ الكباتن',
          'عدد الزبائن',
          'مبلغ الزبائن',
          'عمليات الشحن',
          'الإجمالي',
        ].join(','),
      );
    for (final row in _rows) {
      buffer.writeln(
        [
          _monthly
              ? '${row.bucket.year}-'
                    '${row.bucket.month.toString().padLeft(2, '0')}'
              : _isoDate.format(row.bucket),
          row.captainsCount,
          row.captainsAmount.toStringAsFixed(2),
          row.customersCount,
          row.customersAmount.toStringAsFixed(2),
          row.requestsCount,
          row.totalAmount.toStringAsFixed(2),
        ].join(','),
      );
    }
    downloadCsv(
      'hudhud_finance_${_monthly ? 'monthly' : 'daily'}_'
      '${_isoDate.format(_from)}_${_isoDate.format(_to)}.csv',
      buffer.toString(),
    );
  }

  // ------------------------------------------------------------------ ui

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildToolbar(),
          const SizedBox(height: 14),
          _buildPresets(),
          const SizedBox(height: 16),
          if (_error != null)
            _buildError()
          else ...[
            _buildTotals(),
            const SizedBox(height: 16),
            Expanded(child: _buildTable()),
          ],
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(
              value: false,
              label: Text('تقرير يومي'),
              icon: Icon(Icons.today_rounded),
            ),
            ButtonSegment(
              value: true,
              label: Text('تقرير شهري'),
              icon: Icon(Icons.calendar_month_rounded),
            ),
          ],
          selected: {_monthly},
          onSelectionChanged: (selection) {
            setState(() => _monthly = selection.first);
            _load();
          },
        ),
        OutlinedButton.icon(
          onPressed: _pickRange,
          icon: const Icon(Icons.date_range_rounded),
          label: Text(_rangeLabel),
        ),
        IconButton(
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'تحديث',
        ),
        FilledButton.icon(
          onPressed: _loading || _rows.isEmpty ? null : _exportPdf,
          icon: const Icon(Icons.picture_as_pdf_rounded),
          label: const Text('تصدير PDF'),
        ),
        OutlinedButton.icon(
          onPressed: _loading || _rows.isEmpty ? null : _exportCsv,
          icon: const Icon(Icons.table_view_rounded),
          label: const Text('تصدير Excel/CSV'),
        ),
      ],
    );
  }

  Widget _buildPresets() {
    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month, 1);
    final lastMonth = DateTime(now.year, now.month - 1, 1);
    final presets = <String, VoidCallback>{
      'هذا الشهر': () => _applyRange(thisMonth, now, monthly: false),
      'الشهر الماضي': () => _applyRange(
        lastMonth,
        thisMonth.subtract(const Duration(days: 1)),
        monthly: false,
      ),
      'آخر ٣٠ يوماً': () =>
          _applyRange(now.subtract(const Duration(days: 29)), now,
              monthly: false),
      'هذه السنة (شهرياً)': () =>
          _applyRange(DateTime(now.year, 1, 1), now, monthly: true),
      'آخر ١٢ شهراً': () => _applyRange(
        DateTime(now.year, now.month - 11, 1),
        now,
        monthly: true,
      ),
    };
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final entry in presets.entries)
          ActionChip(label: Text(entry.key), onPressed: entry.value),
      ],
    );
  }

  Widget _buildError() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 42,
              color: AdminColors.error,
            ),
            const SizedBox(height: 10),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Cairo'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(onPressed: _load, child: const Text('إعادة المحاولة')),
          ],
        ),
      ),
    );
  }

  Widget _buildTotals() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 1100
            ? 4
            : constraints.maxWidth > 640
            ? 2
            : 1;
        final cards = [
          StatCard(
            label: 'كباتن قاموا بالشحن',
            value: '${_totals.captainsCount}',
            icon: Icons.local_taxi_rounded,
            color: AdminColors.secondary,
          ),
          StatCard(
            label: 'مجموع شحن الكباتن (أوقية)',
            value: _money.format(_totals.captainsAmount),
            icon: Icons.account_balance_wallet_rounded,
            color: AdminColors.success,
          ),
          StatCard(
            label: 'عدد عمليات الشحن',
            value: '${_totals.requestsCount}',
            icon: Icons.receipt_long_rounded,
            color: AdminColors.accent,
          ),
          StatCard(
            label: 'الإجمالي المشحون (أوقية)',
            value: _money.format(_totals.totalAmount),
            icon: Icons.payments_rounded,
            color: AdminColors.primary,
          ),
        ];
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 3.1,
          children: cards,
        );
      },
    );
  }

  Widget _buildTable() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_rows.isEmpty) {
      return const Center(
        child: Text(
          'لا توجد بيانات في هذه المدة.',
          style: TextStyle(fontFamily: 'Cairo'),
        ),
      );
    }
    return Card(
      child: SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: [
              DataColumn(label: Text(_monthly ? 'الشهر' : 'اليوم')),
              const DataColumn(label: Text('عدد الكباتن')),
              const DataColumn(label: Text('مبلغ الكباتن')),
              const DataColumn(label: Text('عدد الزبائن')),
              const DataColumn(label: Text('مبلغ الزبائن')),
              const DataColumn(label: Text('عمليات الشحن')),
              const DataColumn(label: Text('الإجمالي')),
            ],
            rows: [
              for (final row in _rows)
                DataRow(
                  color: row.isEmpty
                      ? WidgetStatePropertyAll(
                          AdminColors.textSecondary.withValues(alpha: 0.05),
                        )
                      : null,
                  cells: [
                    DataCell(Text(_bucketLabel(row.bucket))),
                    DataCell(Text('${row.captainsCount}')),
                    DataCell(Text(_money.format(row.captainsAmount))),
                    DataCell(Text('${row.customersCount}')),
                    DataCell(Text(_money.format(row.customersAmount))),
                    DataCell(Text('${row.requestsCount}')),
                    DataCell(
                      Text(
                        _money.format(row.totalAmount),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
