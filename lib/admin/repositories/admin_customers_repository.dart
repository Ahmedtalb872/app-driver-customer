import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../models/customer_admin_view.dart';

class AdminCustomersRepository {
  SupabaseClient get _client => SupabaseConfig.client;

  /// Mirrors [AdminCaptainsRepository.loadCaptains] exactly (search across
  /// the joined profiles row, status filter, offset pagination) - the
  /// customer-side equivalent. [withDebtOnly] narrows the page to just
  /// customers currently carrying outstanding Selefli debt, for the
  /// "سلفلي" admin screen's debtor list.
  Future<List<CustomerAdminView>> loadCustomers({
    String? searchQuery,
    String? statusFilter,
    bool withDebtOnly = false,
    int limit = 25,
    int offset = 0,
  }) async {
    var query = _client.from('customers').select('*, profiles!inner(*)');

    if (statusFilter != null && statusFilter.isNotEmpty) {
      query = query.eq('status', statusFilter);
    }
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.trim();
      query = query.or(
        'full_name.ilike.%$q%,phone.ilike.%$q%',
        referencedTable: 'profiles',
      );
    }

    final rows = await query
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    final customers = List<Map<String, dynamic>>.from(
      rows,
    ).map(CustomerAdminView.fromJson).toList();

    final debts = await _loadOutstandingDebts(
      customerIds: customers.map((c) => c.id).toList(),
    );
    final withDebts = customers
        .map(
          (c) => debts.containsKey(c.id)
              ? c.copyWith(outstandingSelefliDebt: debts[c.id])
              : c,
        )
        .toList();

    return withDebtOnly
        ? withDebts.where((c) => c.hasSelefliDebt).toList()
        : withDebts;
  }

  /// `customer_id -> amount - amount_paid` for every row in `selefli_debts`
  /// with `status = 'outstanding'`, scoped to [customerIds] (or every
  /// outstanding debt when null - used by the "سلفلي" screen's standalone
  /// debtor list, which isn't paginating `customers` first).
  Future<Map<String, double>> _loadOutstandingDebts({
    List<String>? customerIds,
  }) async {
    var query = _client
        .from('selefli_debts')
        .select('customer_id, amount, amount_paid')
        .eq('status', 'outstanding');
    if (customerIds != null && customerIds.isNotEmpty) {
      query = query.inFilter('customer_id', customerIds);
    }
    final rows = await query;
    final map = <String, double>{};
    for (final row in List<Map<String, dynamic>>.from(rows)) {
      final amount = (row['amount'] as num?)?.toDouble() ?? 0;
      final paid = (row['amount_paid'] as num?)?.toDouble() ?? 0;
      map[row['customer_id'] as String] = amount - paid;
    }
    return map;
  }

  /// Every customer currently carrying outstanding Selefli debt, with their
  /// profile info - for the "سلفلي" admin screen, independent of the
  /// paginated/filterable general customers list above.
  Future<List<CustomerAdminView>> loadCustomersWithOutstandingDebt() async {
    final rows = await _client
        .from('selefli_debts')
        .select('customer_id, amount, amount_paid, customers!inner(*, profiles!inner(*))')
        .eq('status', 'outstanding')
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(rows).map((row) {
      final customer = CustomerAdminView.fromJson(
        row['customers'] as Map<String, dynamic>,
      );
      final amount = (row['amount'] as num?)?.toDouble() ?? 0;
      final paid = (row['amount_paid'] as num?)?.toDouble() ?? 0;
      return customer.copyWith(outstandingSelefliDebt: amount - paid);
    }).toList();
  }

  Future<void> updateAdminNotes(String customerId, String notes) async {
    await _client
        .from('customers')
        .update({'admin_notes': notes})
        .eq('id', customerId);
  }

  Future<void> setSuspended(
    String customerId,
    bool suspended, {
    String? reason,
  }) async {
    await _client.rpc(
      'admin_set_customer_suspension',
      params: {
        'p_customer_id': customerId,
        'p_suspended': suspended,
        'p_reason': reason,
      },
    );
  }
}
