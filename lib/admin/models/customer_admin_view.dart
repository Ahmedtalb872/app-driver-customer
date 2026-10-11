class CustomerAdminView {
  final String id;
  final String fullName;
  final String? phone;
  final String? email;
  final String? avatarUrl;
  final String status;
  final String? adminNotes;
  final double? rating;
  final int ratingsCount;
  final int completedTripsCount;
  final bool isVerified;
  final DateTime? createdAt;

  /// Outstanding Selefli (pay-later) debt, if any - null means no debt.
  /// Not part of the `customers` row itself (lives in `selefli_debts`), so
  /// [AdminCustomersRepository.loadCustomers] fetches it in a second query
  /// and merges it in; this is just where the merged value is held.
  final double? outstandingSelefliDebt;

  const CustomerAdminView({
    required this.id,
    required this.fullName,
    this.phone,
    this.email,
    this.avatarUrl,
    required this.status,
    this.adminNotes,
    this.rating,
    this.ratingsCount = 0,
    this.completedTripsCount = 0,
    this.isVerified = false,
    this.createdAt,
    this.outstandingSelefliDebt,
  });

  factory CustomerAdminView.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    return CustomerAdminView(
      id: json['id'] as String,
      fullName: (profile?['full_name'] as String?) ?? '',
      phone: profile?['phone'] as String?,
      email: profile?['email'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      status: (json['status'] as String?) ?? 'active',
      adminNotes: json['admin_notes'] as String?,
      rating: (json['rating'] as num?)?.toDouble(),
      ratingsCount: (json['ratings_count'] as num?)?.toInt() ?? 0,
      completedTripsCount: (json['completed_trips_count'] as num?)?.toInt() ?? 0,
      isVerified: json['is_verified'] as bool? ?? false,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
    );
  }

  CustomerAdminView copyWith({double? outstandingSelefliDebt}) {
    return CustomerAdminView(
      id: id,
      fullName: fullName,
      phone: phone,
      email: email,
      avatarUrl: avatarUrl,
      status: status,
      adminNotes: adminNotes,
      rating: rating,
      ratingsCount: ratingsCount,
      completedTripsCount: completedTripsCount,
      isVerified: isVerified,
      createdAt: createdAt,
      outstandingSelefliDebt:
          outstandingSelefliDebt ?? this.outstandingSelefliDebt,
    );
  }

  bool get isActive => status == 'active';
  bool get isSuspended => status == 'suspended';
  bool get hasSelefliDebt =>
      outstandingSelefliDebt != null && outstandingSelefliDebt! > 0;
}
