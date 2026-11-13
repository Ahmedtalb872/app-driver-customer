/// One bucket (a calendar day, or a month) of approved wallet recharges,
/// as returned by the `admin_finance_recharge_report` RPC in
/// 20260821000082_admin_finance_reports.sql.
class FinanceReportRow {
  const FinanceReportRow({
    required this.bucket,
    required this.captainsCount,
    required this.captainsAmount,
    required this.customersCount,
    required this.customersAmount,
    required this.requestsCount,
    required this.totalAmount,
  });

  /// Day, or the first day of the month for a monthly report.
  final DateTime bucket;

  /// Distinct captains who had a recharge approved in this bucket.
  final int captainsCount;
  final double captainsAmount;

  final int customersCount;
  final double customersAmount;

  /// Approved recharge requests in this bucket, all roles.
  final int requestsCount;
  final double totalAmount;

  bool get isEmpty => requestsCount == 0;

  static double _num(Object? value) =>
      value == null ? 0 : (value as num).toDouble();

  static int _int(Object? value) => value == null ? 0 : (value as num).toInt();

  factory FinanceReportRow.fromMap(Map<String, dynamic> map) {
    return FinanceReportRow(
      bucket: DateTime.parse(map['bucket'] as String),
      captainsCount: _int(map['captains_count']),
      captainsAmount: _num(map['captains_amount']),
      customersCount: _int(map['customers_count']),
      customersAmount: _num(map['customers_amount']),
      requestsCount: _int(map['requests_count']),
      totalAmount: _num(map['total_amount']),
    );
  }
}

/// Range-wide totals from `admin_finance_recharge_totals`. Not derivable
/// by summing [FinanceReportRow]s: a captain who recharged on three days
/// is three rows there but one distinct captain here.
class FinanceReportTotals {
  const FinanceReportTotals({
    required this.captainsCount,
    required this.captainsAmount,
    required this.customersCount,
    required this.customersAmount,
    required this.requestsCount,
    required this.totalAmount,
  });

  final int captainsCount;
  final double captainsAmount;
  final int customersCount;
  final double customersAmount;
  final int requestsCount;
  final double totalAmount;

  static const empty = FinanceReportTotals(
    captainsCount: 0,
    captainsAmount: 0,
    customersCount: 0,
    customersAmount: 0,
    requestsCount: 0,
    totalAmount: 0,
  );

  factory FinanceReportTotals.fromMap(Map<String, dynamic> map) {
    return FinanceReportTotals(
      captainsCount: FinanceReportRow._int(map['captains_count']),
      captainsAmount: FinanceReportRow._num(map['captains_amount']),
      customersCount: FinanceReportRow._int(map['customers_count']),
      customersAmount: FinanceReportRow._num(map['customers_amount']),
      requestsCount: FinanceReportRow._int(map['requests_count']),
      totalAmount: FinanceReportRow._num(map['total_amount']),
    );
  }
}
