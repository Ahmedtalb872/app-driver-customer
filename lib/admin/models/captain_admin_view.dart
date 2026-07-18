class CaptainAdminView {
  final String id;
  final String fullName;
  final String? phone;
  final String? email;
  final String status;
  final String? rejectionReason;
  final String? adminNotes;
  final String? city;
  final String? address;
  final bool isOnline;
  final String? vehicleType;
  final String? vehicleBrand;
  final String? vehicleModel;
  final int? vehicleYear;
  final String? vehicleColor;
  final String? vehiclePlate;
  final int? vehicleSeats;
  final double walletBalance;
  final DateTime? createdAt;
  final DateTime? dateOfBirth;

  const CaptainAdminView({
    required this.id,
    required this.fullName,
    this.phone,
    this.email,
    required this.status,
    this.rejectionReason,
    this.adminNotes,
    this.city,
    this.address,
    this.isOnline = false,
    this.vehicleType,
    this.vehicleBrand,
    this.vehicleModel,
    this.vehicleYear,
    this.vehicleColor,
    this.vehiclePlate,
    this.vehicleSeats,
    this.walletBalance = 0,
    this.createdAt,
    this.dateOfBirth,
  });

  factory CaptainAdminView.fromJson(
    Map<String, dynamic> json, {
    double walletBalance = 0,
  }) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    return CaptainAdminView(
      id: json['id'] as String,
      fullName: (profile?['full_name'] as String?) ?? '',
      phone: profile?['phone'] as String?,
      email: profile?['email'] as String?,
      status: (json['status'] as String?) ?? 'pending',
      rejectionReason: json['rejection_reason'] as String?,
      adminNotes: json['admin_notes'] as String?,
      city: json['city'] as String?,
      address: json['address'] as String?,
      isOnline: json['is_online'] as bool? ?? false,
      vehicleType: json['vehicle_type'] as String?,
      vehicleBrand: json['vehicle_brand'] as String?,
      vehicleModel: json['vehicle_model'] as String?,
      vehicleYear: (json['vehicle_year'] as num?)?.toInt(),
      vehicleColor: json['vehicle_color'] as String?,
      vehiclePlate: json['vehicle_plate'] as String?,
      vehicleSeats: (json['vehicle_seats'] as num?)?.toInt(),
      walletBalance: walletBalance,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      dateOfBirth: json['date_of_birth'] == null
          ? null
          : DateTime.parse(json['date_of_birth'] as String),
    );
  }

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
  bool get isSuspended => status == 'suspended';
}
