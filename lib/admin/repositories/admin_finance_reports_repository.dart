import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../models/finance_report_row.dart';

/// Reads the daily/monthly recharge reports backing the "المالية" section.
/// Both RPCs are security-definer and gated on
/// `has_admin_role('finance_admin')`, so a non-finance admin gets a
/// Postgres exception rather than an empty list.
class AdminFinanceReportsRepository {
  SupabaseClient get _client => SupabaseConfig.client;

  static String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  Future<List<FinanceReportRow>> loadReport({
    required DateTime from,
    required DateTime to,
    required bool monthly,
  }) async {
    final rows = await _client.rpc(
      'admin_finance_recharge_report',
      params: {
        'p_from': _date(from),
        'p_to': _date(to),
        'p_granularity': monthly ? 'month' : 'day',
      },
    );
    return List<Map<String, dynamic>>.from(rows as List)
        .map(FinanceReportRow.fromMap)
        .toList();
  }

  Future<FinanceReportTotals> loadTotals({
    required DateTime from,
    required DateTime to,
  }) async {
    final rows = await _client.rpc(
      'admin_finance_recharge_totals',
      params: {'p_from': _date(from), 'p_to': _date(to)},
    );
    final list = List<Map<String, dynamic>>.from(rows as List);
    if (list.isEmpty) return FinanceReportTotals.empty;
    return FinanceReportTotals.fromMap(list.first);
  }
}
