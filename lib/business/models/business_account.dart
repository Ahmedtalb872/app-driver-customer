class BusinessAccount {
  final String id;
  final String businessName;
  final String businessType;
  final String status;
  final String? defaultPickupAddress;
  final double? defaultPickupLat;
  final double? defaultPickupLng;
  final String? rejectionReason;
  final DateTime? createdAt;

  const BusinessAccount({
    required this.id,
    required this.businessName,
    required this.businessType,
    required this.status,
    this.defaultPickupAddress,
    this.defaultPickupLat,
    this.defaultPickupLng,
    this.rejectionReason,
    this.createdAt,
  });

  factory BusinessAccount.fromJson(Map<String, dynamic> json) {
    return BusinessAccount(
      id: json['id'] as String,
      businessName: json['business_name'] as String? ?? '',
      businessType: json['business_type'] as String? ?? 'other',
      status: json['status'] as String? ?? 'pending',
      defaultPickupAddress: json['default_pickup_address'] as String?,
      defaultPickupLat: (json['default_pickup_lat'] as num?)?.toDouble(),
      defaultPickupLng: (json['default_pickup_lng'] as num?)?.toDouble(),
      rejectionReason: json['rejection_reason'] as String?,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.tryParse(json['created_at'] as String),
    );
  }

  bool get isApproved => status == 'approved';
  bool get isPending => status == 'pending';
  bool get isRejected => status == 'rejected';
  bool get isSuspended => status == 'suspended';

  static const typeLabels = {
    'restaurant': 'مطعم',
    'institution': 'مؤسسة',
    'other': 'أخرى',
  };

  String get typeLabel => typeLabels[businessType] ?? businessType;
}
