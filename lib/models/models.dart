enum VehicleType { economy, comfort, family }

enum TripStatus {
  pending,
  searching,
  accepted,
  enRoute,
  arrived,
  started,
  completed,
  cancelled,
}

/// Whether a trip has a known destination up front (normal) or the
/// destination is discovered as the ride happens, fare metered live (open).
enum TripType { normal, open }

enum TransactionType {
  charge,
  payment,
  refund,
  reward,
  withdraw,
  commission,
  transfer,
}

/// Display metadata for each ride tier a customer can request. Not tied to
/// a specific vehicle/captain - matches [VehicleType], which is what a trip
/// actually requests.
extension VehicleTypeDisplayX on VehicleType {
  String get typeArabic {
    switch (this) {
      case VehicleType.economy:
        return 'إقتصادية';
      case VehicleType.comfort:
        return 'مريحة';
      case VehicleType.family:
        return 'عائلية';
    }
  }

  String get description {
    switch (this) {
      case VehicleType.economy:
        return 'سيارة عادية من 1 إلى 4 ركاب';
      case VehicleType.comfort:
        return 'سيارة أفضل وأكثر راحة من 1 إلى 4 ركاب';
      case VehicleType.family:
        return 'سيارة أكبر من 1 إلى 6 ركاب';
    }
  }
}

class Trip {
  final String id;
  final String customerName;
  final String customerPhone;
  final String? captainName;
  final String? captainPhone;
  final String? captainAvatar;
  final String? vehiclePlate;
  final String? vehicleName;
  final String pickupLocation;
  final String destinationLocation;
  final double pickupLat;
  final double pickupLng;
  final double destLat;
  final double destLng;
  final double distance; // in km
  final int duration; // in minutes
  final double price;
  final String paymentMethod;
  TripStatus status;
  final VehicleType carType;
  final bool isOpenRide;
  final int openRideTimeout; // in seconds (30, 45, 60)
  final String date;
  final double? netEarnings;
  final double? commission;

  // Open trip (destination-unknown) fields.
  final TripType tripType;

  /// Distance/ETA from the driver to the pickup point, shown before acceptance.
  final double? driverDistanceToPickupKm;
  final int? driverEtaToPickupMinutes;

  /// Final metered fare breakdown, populated once an open trip completes.
  final double? baseFareAmount;
  final double? distanceFareAmount;
  final double? timeFareAmount;
  final double? waitingFareAmount;
  final int? movingSeconds;
  final int? waitingSeconds;
  final double? finalLat;
  final double? finalLng;

  // Real-backend fields (populated once a request is backed by a Supabase
  // `trips` row instead of dummy/simulated data). All optional/additive so
  // every existing caller that only ever built simulated Trips keeps
  // compiling unchanged.
  /// Passenger profile photo, when they uploaded one. Null shows a default
  /// avatar with the first letter of [customerName] instead - never a
  /// broken image.
  final String? customerAvatarUrl;
  final double? customerRating;
  final int? customerRatingsCount;
  final int? customerCompletedTrips;
  final bool customerVerified;

  /// Free-text note from the passenger, shown only when non-empty.
  final String? customerNote;

  /// Number of passengers requested for this trip (1-6). Defaults to 1 for
  /// every simulated/dummy Trip built before this field existed.
  final int passengerCount;

  /// Live-tracking snapshot for an in-progress Open Trip (see
  /// `update_trip_live_tracking` RPC) and the real trip-start timestamp -
  /// both needed by the passenger's live trip panel to derive elapsed time
  /// and distance from timestamps/server state rather than a purely local
  /// counter (spec section 14/15).
  final double? liveTraveledDistanceKm;
  final DateTime? startedAt;

  /// Captain's last reported GPS fix (`last_location_lat/lng`), when known.
  /// Only ever populated while an Open Trip is running (see
  /// `update_trip_live_tracking`) - null for a normal trip, since nothing
  /// pushes a captain's live position for one today.
  final double? captainLat;
  final double? captainLng;

  /// Wall-clock expiry of a broadcasting request, used to drive the
  /// incoming-ride countdown from a real timestamp instead of a plain
  /// decrementing int, so it survives rebuilds/backgrounding correctly.
  final DateTime? requestExpiresAt;

  /// True for a locally-generated demo/trial trip, never for a real
  /// Supabase-backed one - lets a caller skip real `RideRepository` calls
  /// for a request that has no backing `trips` row.
  final bool isDemoTrip;

  /// 'ride' (default, passenger trip) or 'delivery' (parcel courier job -
  /// see `20260801000046_delivery_service.sql`). For a delivery,
  /// [recipientName]/[recipientPhone]/[packageDescription] are populated
  /// instead of describing the passenger, and [carType] is meaningless
  /// (always priced/broadcast as a motorcycle job server-side).
  final String serviceType;
  final String? recipientName;
  final String? recipientPhone;
  final String? packageDescription;

  Trip({
    required this.id,
    required this.customerName,
    required this.customerPhone,
    this.captainName,
    this.captainPhone,
    this.captainAvatar,
    this.vehiclePlate,
    this.vehicleName,
    required this.pickupLocation,
    required this.destinationLocation,
    required this.pickupLat,
    required this.pickupLng,
    required this.destLat,
    required this.destLng,
    required this.distance,
    required this.duration,
    required this.price,
    required this.paymentMethod,
    required this.status,
    required this.carType,
    required this.isOpenRide,
    required this.openRideTimeout,
    required this.date,
    this.netEarnings,
    this.commission,
    this.tripType = TripType.normal,
    this.driverDistanceToPickupKm,
    this.driverEtaToPickupMinutes,
    this.baseFareAmount,
    this.distanceFareAmount,
    this.timeFareAmount,
    this.waitingFareAmount,
    this.movingSeconds,
    this.waitingSeconds,
    this.finalLat,
    this.finalLng,
    this.customerAvatarUrl,
    this.customerRating,
    this.customerRatingsCount,
    this.customerCompletedTrips,
    this.customerVerified = false,
    this.customerNote,
    this.passengerCount = 1,
    this.liveTraveledDistanceKm,
    this.startedAt,
    this.requestExpiresAt,
    this.isDemoTrip = false,
    this.captainLat,
    this.captainLng,
    this.serviceType = 'ride',
    this.recipientName,
    this.recipientPhone,
    this.packageDescription,
  });

  bool get isOpenTrip => tripType == TripType.open;

  bool get isDelivery => serviceType == 'delivery';

  /// Builds a display [Trip] from a real `public.trips` row (optionally
  /// joined with `customers`/`profiles` passenger info), as returned by
  /// [RideRepository]. Keeps every existing screen that already renders a
  /// [Trip] working unchanged for real, backend-backed requests.
  factory Trip.fromTripRow(
    Map<String, dynamic> row, {
    Map<String, dynamic>? customerProfile,
    Map<String, dynamic>? captainProfile,
  }) {
    final tripTypeValue = row['trip_type'] as String? ?? 'normal';
    final hasDestination =
        row['destination_lat'] != null && row['destination_lng'] != null;
    final pickupLat = (row['pickup_lat'] as num?)?.toDouble() ?? 0.0;
    final pickupLng = (row['pickup_lng'] as num?)?.toDouble() ?? 0.0;
    final destLat = (row['destination_lat'] as num?)?.toDouble() ?? pickupLat;
    final destLng = (row['destination_lng'] as num?)?.toDouble() ?? pickupLng;
    final expiresAtValue = row['expires_at'] as String?;
    final vehicleTypeValue = (row['vehicle_type'] as String?) ?? 'economy';

    final vehicleBrand = captainProfile?['vehicle_brand'] as String?;
    final vehicleModel = captainProfile?['vehicle_model'] as String?;
    final vehicleName = (vehicleBrand != null || vehicleModel != null)
        ? [
            vehicleBrand,
            vehicleModel,
          ].where((s) => (s ?? '').isNotEmpty).join(' ')
        : null;
    final startedAtValue = row['started_at'] as String?;

    return Trip(
      id: row['id'] as String,
      customerName:
          (customerProfile?['full_name'] as String?)?.trim().isNotEmpty == true
          ? customerProfile!['full_name'] as String
          : 'راكب',
      customerPhone: (customerProfile?['phone'] as String?) ?? '',
      captainName: captainProfile?['full_name'] as String?,
      captainPhone: captainProfile?['phone'] as String?,
      captainAvatar: captainProfile?['avatar_url'] as String?,
      vehicleName: (vehicleName ?? '').isEmpty ? null : vehicleName,
      vehiclePlate: captainProfile?['vehicle_plate'] as String?,
      pickupLocation: row['pickup_address'] as String? ?? '',
      destinationLocation: hasDestination
          ? (row['destination_address'] as String? ?? '')
          : 'مشوار مفتوح',
      pickupLat: pickupLat,
      pickupLng: pickupLng,
      destLat: destLat,
      destLng: destLng,
      distance: (row['distance_km'] as num?)?.toDouble() ?? 0.0,
      duration: (row['estimated_duration_minutes'] as num?)?.toInt() ?? 0,
      price:
          (row['final_price'] as num?)?.toDouble() ??
          (row['estimated_price'] as num?)?.toDouble() ??
          0.0,
      paymentMethod: (row['payment_method'] as String?) == 'wallet'
          ? 'المحفظة'
          : 'نقداً',
      status: _tripStatusFromDb(row['status'] as String?),
      carType: _vehicleTypeFromDb(vehicleTypeValue),
      isOpenRide: tripTypeValue == 'open',
      openRideTimeout: 45,
      date:
          (row['requested_at'] as String?) ?? DateTime.now().toIso8601String(),
      tripType: tripTypeValue == 'open' ? TripType.open : TripType.normal,
      netEarnings: (row['captain_net_earnings'] as num?)?.toDouble(),
      commission: (row['commission_amount'] as num?)?.toDouble(),
      customerNote: (row['customer_note'] as String?)?.trim().isEmpty == true
          ? null
          : row['customer_note'] as String?,
      passengerCount: (row['passenger_count'] as num?)?.toInt() ?? 1,
      liveTraveledDistanceKm: (row['traveled_distance_km'] as num?)?.toDouble(),
      startedAt: startedAtValue != null
          ? DateTime.parse(startedAtValue).toLocal()
          : null,
      requestExpiresAt: expiresAtValue != null
          ? DateTime.parse(expiresAtValue).toLocal()
          : null,
      captainLat: (row['last_location_lat'] as num?)?.toDouble(),
      captainLng: (row['last_location_lng'] as num?)?.toDouble(),
      customerAvatarUrl: customerProfile?['avatar_url'] as String?,
      customerRating: (customerProfile?['rating'] as num?)?.toDouble(),
      customerRatingsCount: (customerProfile?['ratings_count'] as num?)
          ?.toInt(),
      customerCompletedTrips:
          (customerProfile?['completed_trips_count'] as num?)?.toInt(),
      customerVerified: customerProfile?['is_verified'] as bool? ?? false,
      serviceType: (row['service_type'] as String?) ?? 'ride',
      recipientName: row['recipient_name'] as String?,
      recipientPhone: row['recipient_phone'] as String?,
      packageDescription: row['package_description'] as String?,
    );
  }

  static TripStatus _tripStatusFromDb(String? value) {
    switch (value) {
      case 'searching':
        return TripStatus.searching;
      case 'accepted':
        return TripStatus.accepted;
      case 'arrived':
        return TripStatus.arrived;
      case 'boarded':
      case 'in_progress':
        return TripStatus.started;
      case 'completed':
        return TripStatus.completed;
      case 'cancelled':
        return TripStatus.cancelled;
      case 'expired':
        return TripStatus.pending;
      default:
        return TripStatus.searching;
    }
  }

  static VehicleType _vehicleTypeFromDb(String value) {
    switch (value) {
      case 'comfort':
        return VehicleType.comfort;
      case 'family':
        return VehicleType.family;
      default:
        return VehicleType.economy;
    }
  }

  Trip copyWith({
    String? id,
    String? customerName,
    String? customerPhone,
    String? captainName,
    String? captainPhone,
    String? captainAvatar,
    String? vehiclePlate,
    String? vehicleName,
    String? pickupLocation,
    String? destinationLocation,
    double? pickupLat,
    double? pickupLng,
    double? destLat,
    double? destLng,
    double? distance,
    int? duration,
    double? price,
    String? paymentMethod,
    TripStatus? status,
    VehicleType? carType,
    bool? isOpenRide,
    int? openRideTimeout,
    String? date,
    double? netEarnings,
    double? commission,
    TripType? tripType,
    double? driverDistanceToPickupKm,
    int? driverEtaToPickupMinutes,
    double? baseFareAmount,
    double? distanceFareAmount,
    double? timeFareAmount,
    double? waitingFareAmount,
    int? movingSeconds,
    int? waitingSeconds,
    double? finalLat,
    double? finalLng,
    String? customerAvatarUrl,
    double? customerRating,
    int? customerRatingsCount,
    int? customerCompletedTrips,
    bool? customerVerified,
    String? customerNote,
    int? passengerCount,
    double? liveTraveledDistanceKm,
    DateTime? startedAt,
    DateTime? requestExpiresAt,
    bool? isDemoTrip,
    double? captainLat,
    double? captainLng,
  }) {
    return Trip(
      id: id ?? this.id,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      captainName: captainName ?? this.captainName,
      captainPhone: captainPhone ?? this.captainPhone,
      captainAvatar: captainAvatar ?? this.captainAvatar,
      vehiclePlate: vehiclePlate ?? this.vehiclePlate,
      vehicleName: vehicleName ?? this.vehicleName,
      pickupLocation: pickupLocation ?? this.pickupLocation,
      destinationLocation: destinationLocation ?? this.destinationLocation,
      pickupLat: pickupLat ?? this.pickupLat,
      pickupLng: pickupLng ?? this.pickupLng,
      destLat: destLat ?? this.destLat,
      destLng: destLng ?? this.destLng,
      distance: distance ?? this.distance,
      duration: duration ?? this.duration,
      price: price ?? this.price,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      status: status ?? this.status,
      carType: carType ?? this.carType,
      isOpenRide: isOpenRide ?? this.isOpenRide,
      openRideTimeout: openRideTimeout ?? this.openRideTimeout,
      date: date ?? this.date,
      netEarnings: netEarnings ?? this.netEarnings,
      commission: commission ?? this.commission,
      tripType: tripType ?? this.tripType,
      driverDistanceToPickupKm:
          driverDistanceToPickupKm ?? this.driverDistanceToPickupKm,
      driverEtaToPickupMinutes:
          driverEtaToPickupMinutes ?? this.driverEtaToPickupMinutes,
      baseFareAmount: baseFareAmount ?? this.baseFareAmount,
      distanceFareAmount: distanceFareAmount ?? this.distanceFareAmount,
      timeFareAmount: timeFareAmount ?? this.timeFareAmount,
      waitingFareAmount: waitingFareAmount ?? this.waitingFareAmount,
      movingSeconds: movingSeconds ?? this.movingSeconds,
      waitingSeconds: waitingSeconds ?? this.waitingSeconds,
      finalLat: finalLat ?? this.finalLat,
      finalLng: finalLng ?? this.finalLng,
      customerAvatarUrl: customerAvatarUrl ?? this.customerAvatarUrl,
      customerRating: customerRating ?? this.customerRating,
      customerRatingsCount: customerRatingsCount ?? this.customerRatingsCount,
      customerCompletedTrips:
          customerCompletedTrips ?? this.customerCompletedTrips,
      customerVerified: customerVerified ?? this.customerVerified,
      customerNote: customerNote ?? this.customerNote,
      passengerCount: passengerCount ?? this.passengerCount,
      liveTraveledDistanceKm:
          liveTraveledDistanceKm ?? this.liveTraveledDistanceKm,
      startedAt: startedAt ?? this.startedAt,
      requestExpiresAt: requestExpiresAt ?? this.requestExpiresAt,
      isDemoTrip: isDemoTrip ?? this.isDemoTrip,
      captainLat: captainLat ?? this.captainLat,
      captainLng: captainLng ?? this.captainLng,
    );
  }

  String get carTypeNameArabic {
    switch (carType) {
      case VehicleType.economy:
        return 'إقتصادية';
      case VehicleType.comfort:
        return 'مريحة';
      case VehicleType.family:
        return 'عائلية';
    }
  }

  String get statusArabic {
    switch (status) {
      case TripStatus.pending:
        return 'قيد الانتظار';
      case TripStatus.searching:
        return 'جاري البحث عن كابتن';
      case TripStatus.accepted:
        return 'تم قبول الطلب';
      case TripStatus.enRoute:
        return 'الكابتن في الطريق';
      case TripStatus.arrived:
        return 'وصل الكابتن';
      case TripStatus.started:
        return 'رحلة جارية';
      case TripStatus.completed:
        return 'مكتملة';
      case TripStatus.cancelled:
        return 'ملغاة';
    }
  }
}

class Message {
  final String id;
  final String senderId;
  final String senderName;
  final String content;
  final String time;
  final bool isLocation;
  final double? latitude;
  final double? longitude;
  final bool isMe;

  Message({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.time,
    this.isLocation = false,
    this.latitude,
    this.longitude,
    required this.isMe,
  });
}

/// The 10 document slots a captain uploads, matching the `document_type`
/// CHECK constraint on `public.captain_documents`
/// (20260717000034_captain_documents.sql). All but [additionalDocument] are
/// mandatory - see [CaptainDocument.mandatoryTypes].
enum DocumentType {
  profilePhoto,
  nationalIdFront,
  nationalIdBack,
  drivingLicenseFront,
  drivingLicenseBack,
  vehicleRegistrationFront,
  vehicleRegistrationBack,
  vehiclePhoto,
  vehicleInsurance,
  additionalDocument,
}

extension DocumentTypeX on DocumentType {
  /// The exact string stored in `captain_documents.document_type` - keep in
  /// sync with the migration's CHECK constraint.
  String get dbValue {
    switch (this) {
      case DocumentType.profilePhoto:
        return 'profile_photo';
      case DocumentType.nationalIdFront:
        return 'national_id_front';
      case DocumentType.nationalIdBack:
        return 'national_id_back';
      case DocumentType.drivingLicenseFront:
        return 'driving_license_front';
      case DocumentType.drivingLicenseBack:
        return 'driving_license_back';
      case DocumentType.vehicleRegistrationFront:
        return 'vehicle_registration_front';
      case DocumentType.vehicleRegistrationBack:
        return 'vehicle_registration_back';
      case DocumentType.vehiclePhoto:
        return 'vehicle_photo';
      case DocumentType.vehicleInsurance:
        return 'vehicle_insurance';
      case DocumentType.additionalDocument:
        return 'additional_document';
    }
  }

  static DocumentType fromDb(String value) {
    return DocumentType.values.firstWhere(
      (t) => t.dbValue == value,
      orElse: () => DocumentType.additionalDocument,
    );
  }

  String get labelArabic {
    switch (this) {
      case DocumentType.profilePhoto:
        return 'الصورة الشخصية';
      case DocumentType.nationalIdFront:
        return 'بطاقة الهوية الوطنية (الوجه الأمامي)';
      case DocumentType.nationalIdBack:
        return 'بطاقة الهوية الوطنية (الوجه الخلفي)';
      case DocumentType.drivingLicenseFront:
        return 'رخصة السياقة (الوجه الأمامي)';
      case DocumentType.drivingLicenseBack:
        return 'رخصة السياقة (الوجه الخلفي)';
      case DocumentType.vehicleRegistrationFront:
        return 'البطاقة الرمادية (الوجه الأمامي)';
      case DocumentType.vehicleRegistrationBack:
        return 'البطاقة الرمادية (الوجه الخلفي)';
      case DocumentType.vehiclePhoto:
        return 'صورة السيارة';
      case DocumentType.vehicleInsurance:
        return 'تأمين السيارة';
      case DocumentType.additionalDocument:
        return 'مستند إضافي (اختياري)';
    }
  }

  /// Every type except [additionalDocument] is mandatory - see
  /// [CaptainDocument.mandatoryTypes], which this must stay consistent with.
  bool get isMandatory => this != DocumentType.additionalDocument;

  /// Whether the real-world document this slot represents typically carries
  /// an expiry date - drives whether the upload UI asks for one. Purely a
  /// UX hint; the database column accepts a value (or null) for any type.
  bool get typicallyHasExpiry {
    switch (this) {
      case DocumentType.nationalIdFront:
      case DocumentType.nationalIdBack:
      case DocumentType.drivingLicenseFront:
      case DocumentType.drivingLicenseBack:
      case DocumentType.vehicleRegistrationFront:
      case DocumentType.vehicleRegistrationBack:
      case DocumentType.vehicleInsurance:
        return true;
      case DocumentType.profilePhoto:
      case DocumentType.vehiclePhoto:
      case DocumentType.additionalDocument:
        return false;
    }
  }
}

enum DocumentStatus { pending, approved, rejected, expired }

extension DocumentStatusX on DocumentStatus {
  String get dbValue {
    switch (this) {
      case DocumentStatus.pending:
        return 'pending';
      case DocumentStatus.approved:
        return 'approved';
      case DocumentStatus.rejected:
        return 'rejected';
      case DocumentStatus.expired:
        return 'expired';
    }
  }

  static DocumentStatus fromDb(String value) {
    switch (value) {
      case 'approved':
        return DocumentStatus.approved;
      case 'rejected':
        return DocumentStatus.rejected;
      case 'expired':
        return DocumentStatus.expired;
      case 'pending':
      default:
        return DocumentStatus.pending;
    }
  }

  String get labelArabic {
    switch (this) {
      case DocumentStatus.pending:
        return 'قيد المراجعة';
      case DocumentStatus.approved:
        return 'مقبول';
      case DocumentStatus.rejected:
        return 'مرفوض';
      case DocumentStatus.expired:
        return 'منتهي الصلاحية';
    }
  }
}

/// One uploaded document row, mirroring `public.captain_documents`
/// (20260717000034_captain_documents.sql). Built from a real Supabase row
/// via [CaptainDocument.fromRow], following the same `.fromXRow` convention
/// [Trip.fromTripRow] already established for real-backend models.
class CaptainDocument {
  final String id;
  final String captainId;
  final DocumentType documentType;
  final String filePath;
  final String fileName;
  final String mimeType;
  final int fileSize;
  final DateTime uploadedAt;
  final DateTime? expiresAt;
  final DocumentStatus status;
  final String? rejectionReason;
  final String? reviewedBy;
  final DateTime? reviewedAt;

  const CaptainDocument({
    required this.id,
    required this.captainId,
    required this.documentType,
    required this.filePath,
    required this.fileName,
    required this.mimeType,
    required this.fileSize,
    required this.uploadedAt,
    this.expiresAt,
    required this.status,
    this.rejectionReason,
    this.reviewedBy,
    this.reviewedAt,
  });

  factory CaptainDocument.fromRow(Map<String, dynamic> row) {
    final expiresAtValue = row['expires_at'] as String?;
    final reviewedAtValue = row['reviewed_at'] as String?;
    return CaptainDocument(
      id: row['id'] as String,
      captainId: row['captain_id'] as String,
      documentType: DocumentTypeX.fromDb(row['document_type'] as String),
      filePath: row['file_path'] as String,
      fileName: row['file_name'] as String,
      mimeType: row['mime_type'] as String,
      fileSize: (row['file_size'] as num).toInt(),
      uploadedAt: DateTime.parse(row['uploaded_at'] as String).toLocal(),
      expiresAt: expiresAtValue != null
          ? DateTime.parse(expiresAtValue).toLocal()
          : null,
      status: DocumentStatusX.fromDb(row['status'] as String),
      rejectionReason: row['rejection_reason'] as String?,
      reviewedBy: row['reviewed_by'] as String?,
      reviewedAt: reviewedAtValue != null
          ? DateTime.parse(reviewedAtValue).toLocal()
          : null,
    );
  }

  /// No cron/scheduled job exists anywhere in this project (see
  /// `expire_trip`'s client-triggered-best-effort pattern) to flip a past-
  /// due row's stored `status` to 'expired', so this is computed for
  /// display instead - shown as an overlay regardless of the stored status.
  bool get isEffectivelyExpired =>
      expiresAt != null && expiresAt!.isBefore(DateTime.now());

  static const List<DocumentType> mandatoryTypes = [
    DocumentType.profilePhoto,
    DocumentType.nationalIdFront,
    DocumentType.nationalIdBack,
    DocumentType.drivingLicenseFront,
    DocumentType.drivingLicenseBack,
    DocumentType.vehicleRegistrationFront,
    DocumentType.vehicleRegistrationBack,
    DocumentType.vehiclePhoto,
    DocumentType.vehicleInsurance,
  ];

  static const List<DocumentType> allTypes = [
    ...mandatoryTypes,
    DocumentType.additionalDocument,
  ];
}

class WalletTransaction {
  final String id;
  final double amount;
  final TransactionType type;
  final String title;
  final String date;
  final bool isCredit;

  WalletTransaction({
    required this.id,
    required this.amount,
    required this.type,
    required this.title,
    required this.date,
    required this.isCredit,
  });

  String get typeArabic {
    switch (type) {
      case TransactionType.charge:
        return 'شحن رصيد';
      case TransactionType.payment:
        return 'دفع رحلة';
      case TransactionType.refund:
        return 'استرجاع مبلغ';
      case TransactionType.reward:
        return 'مكافأة';
      case TransactionType.withdraw:
        return 'سحب أرباح';
      case TransactionType.commission:
        return 'خصم عمولة';
      case TransactionType.transfer:
        return 'تحويل رصيد';
    }
  }
}

/// A customer's eligibility for "سلفلي" (Selefli) - ride now, pay later up
/// to a cap that rises with loyalty (see customer_selefli_status,
/// 20260812000055_selefli_credit.sql). [cap] is null until
/// [completedTripsCount] passes the first tier's threshold; even once
/// eligible, a new Selefli ride can't be requested while
/// [outstandingAmount] is still owed on a previous one.
class SelefliStatus {
  const SelefliStatus({
    required this.cap,
    required this.outstandingAmount,
    required this.completedTripsCount,
  });

  final double? cap;
  final double outstandingAmount;
  final int completedTripsCount;

  bool get isEligible => cap != null;
  bool get hasOutstandingDebt => outstandingAmount > 0;

  /// True only when a new Selefli ride could actually be requested right
  /// now - eligible for a tier AND no debt left over from a previous one.
  bool get canRequestNow => isEligible && !hasOutstandingDebt;

  factory SelefliStatus.fromJson(Map<String, dynamic> json) {
    return SelefliStatus(
      cap: (json['cap'] as num?)?.toDouble(),
      outstandingAmount: (json['outstanding_amount'] as num?)?.toDouble() ?? 0,
      completedTripsCount: (json['completed_trips_count'] as num?)?.toInt() ?? 0,
    );
  }
}

/// An approved, currently-online captain as shown on the "browse captains
/// to subscribe with" screen (see browsable_captains(),
/// 20260812000056_captain_subscriptions.sql). Deliberately carries no phone
/// number - that only becomes visible once a real relationship exists (a
/// trip or a subscription with this captain).
class BrowsableCaptain {
  const BrowsableCaptain({
    required this.captainId,
    required this.fullName,
    this.avatarUrl,
    this.vehicleBrand,
    this.vehicleModel,
    this.vehicleColor,
    this.rating,
    required this.ratingsCount,
  });

  final String captainId;
  final String fullName;
  final String? avatarUrl;
  final String? vehicleBrand;
  final String? vehicleModel;
  final String? vehicleColor;
  final double? rating;
  final int ratingsCount;

  String get vehicleDescription {
    final parts = [
      vehicleBrand,
      vehicleModel,
      vehicleColor,
    ].where((p) => p != null && p.trim().isNotEmpty).toList();
    return parts.isEmpty ? '' : parts.join(' - ');
  }

  factory BrowsableCaptain.fromJson(Map<String, dynamic> json) {
    final name = json['full_name'] as String?;
    return BrowsableCaptain(
      captainId: json['captain_id'] as String,
      fullName: name == null || name.trim().isEmpty ? 'كابتن' : name,
      avatarUrl: json['avatar_url'] as String?,
      vehicleBrand: json['vehicle_brand'] as String?,
      vehicleModel: json['vehicle_model'] as String?,
      vehicleColor: json['vehicle_color'] as String?,
      rating: (json['rating'] as num?)?.toDouble(),
      ratingsCount: (json['ratings_count'] as num?)?.toInt() ?? 0,
    );
  }
}

enum SubscriptionStatus { negotiating, active, rejected, cancelled }

/// Who a renewal cycle's payment moves through (see
/// 20260812000057_subscription_staged_payout.sql): 'escrow' is the default
/// - the app charges the customer's wallet and stages the captain's payout
/// over the month; 'trusted' is opt-in from the customer's second month
/// onward - the customer pays the captain directly (cash) and both sides
/// just confirm it happened, the app only pulling its flat commission from
/// the captain's wallet once both have.
enum SubscriptionRenewalMode { escrow, trusted }

/// A monthly ride-with-this-captain arrangement (see
/// customer_subscription_status(),
/// 20260812000057_subscription_staged_payout.sql): negotiated via
/// free-text chat, then paid in full and activated the moment the captain
/// accepts an offer. Always the customer's single most-relevant thread
/// (the active one if there is one, else the newest still-open
/// negotiation, else a cancelled-but-disputed one still awaiting admin
/// review) - never a full history.
class CaptainSubscription {
  const CaptainSubscription({
    required this.id,
    required this.captainId,
    required this.captainName,
    this.captainAvatarUrl,
    this.captainPhone,
    this.vehicleBrand,
    this.vehicleModel,
    this.vehicleColor,
    required this.status,
    this.proposedPrice,
    this.proposedBy,
    this.agreedPrice,
    this.startedAt,
    this.expiresAt,
    this.payoutStatus,
    this.renewalMode = SubscriptionRenewalMode.escrow,
    this.cycleCount = 1,
    this.renewalWindowOpenedAt,
    this.customerConfirmedRenewalAt,
    this.captainConfirmedRenewalAt,
    this.paymentDispute = false,
    this.disputeReason,
  });

  final String id;
  final String captainId;
  final String captainName;
  final String? captainAvatarUrl;
  final String? captainPhone;
  final String? vehicleBrand;
  final String? vehicleModel;
  final String? vehicleColor;
  final SubscriptionStatus status;
  final double? proposedPrice;
  final String? proposedBy;
  final double? agreedPrice;
  final DateTime? startedAt;
  final DateTime? expiresAt;

  /// Only meaningful once [status] has been active at least once - null
  /// while still negotiating. 'pending_first_half'/'pending_second_half'/
  /// 'fully_paid_out' track the current cycle's escrow release, regardless
  /// of [renewalMode] (a cycle already in escrow finishes in escrow even if
  /// the customer switches to trusted mode for the *next* cycle).
  final String? payoutStatus;
  final SubscriptionRenewalMode renewalMode;
  final int cycleCount;
  final DateTime? renewalWindowOpenedAt;
  final DateTime? customerConfirmedRenewalAt;
  final DateTime? captainConfirmedRenewalAt;
  final bool paymentDispute;
  final String? disputeReason;

  bool get isActive {
    final expiry = expiresAt;
    return status == SubscriptionStatus.active &&
        expiry != null &&
        expiry.isAfter(DateTime.now());
  }

  bool get isNegotiating => status == SubscriptionStatus.negotiating;

  int? get daysRemaining {
    final expiry = expiresAt;
    if (expiry == null || !isActive) return null;
    return expiry.difference(DateTime.now()).inDays;
  }

  /// The "موثوق" toggle only becomes available once the current escrow
  /// cycle has fully paid out - i.e. from the customer's second month
  /// onward, matching the product decision that the first month always
  /// goes through the safety-net staged payout.
  bool get canOptIntoTrusted =>
      isActive &&
      renewalMode == SubscriptionRenewalMode.escrow &&
      payoutStatus == 'fully_paid_out';

  bool get canOptIntoEscrow =>
      isActive && renewalMode == SubscriptionRenewalMode.trusted;

  /// True once this cycle has expired in trusted mode and the app is
  /// waiting on the customer to confirm they paid the captain directly.
  bool get awaitingCustomerConfirmation =>
      status == SubscriptionStatus.active &&
      renewalMode == SubscriptionRenewalMode.trusted &&
      renewalWindowOpenedAt != null &&
      customerConfirmedRenewalAt == null;

  factory CaptainSubscription.fromJson(Map<String, dynamic> json) {
    final name = json['captain_name'] as String?;
    return CaptainSubscription(
      id: json['id'] as String,
      captainId: json['captain_id'] as String,
      captainName: name == null || name.trim().isEmpty ? 'كابتن' : name,
      captainAvatarUrl: json['captain_avatar_url'] as String?,
      captainPhone: json['captain_phone'] as String?,
      vehicleBrand: json['vehicle_brand'] as String?,
      vehicleModel: json['vehicle_model'] as String?,
      vehicleColor: json['vehicle_color'] as String?,
      status: _statusFromString(json['status'] as String?),
      proposedPrice: (json['proposed_price'] as num?)?.toDouble(),
      proposedBy: json['proposed_by'] as String?,
      agreedPrice: (json['agreed_price'] as num?)?.toDouble(),
      startedAt: json['started_at'] == null
          ? null
          : DateTime.parse(json['started_at'] as String).toLocal(),
      expiresAt: json['expires_at'] == null
          ? null
          : DateTime.parse(json['expires_at'] as String).toLocal(),
      payoutStatus: json['payout_status'] as String?,
      renewalMode: (json['renewal_mode'] as String?) == 'trusted'
          ? SubscriptionRenewalMode.trusted
          : SubscriptionRenewalMode.escrow,
      cycleCount: (json['cycle_count'] as num?)?.toInt() ?? 1,
      renewalWindowOpenedAt: json['renewal_window_opened_at'] == null
          ? null
          : DateTime.parse(
              json['renewal_window_opened_at'] as String,
            ).toLocal(),
      customerConfirmedRenewalAt: json['customer_confirmed_renewal_at'] == null
          ? null
          : DateTime.parse(
              json['customer_confirmed_renewal_at'] as String,
            ).toLocal(),
      captainConfirmedRenewalAt: json['captain_confirmed_renewal_at'] == null
          ? null
          : DateTime.parse(
              json['captain_confirmed_renewal_at'] as String,
            ).toLocal(),
      paymentDispute: json['payment_dispute'] as bool? ?? false,
      disputeReason: json['dispute_reason'] as String?,
    );
  }

  static SubscriptionStatus _statusFromString(String? value) {
    switch (value) {
      case 'active':
        return SubscriptionStatus.active;
      case 'rejected':
        return SubscriptionStatus.rejected;
      case 'cancelled':
        return SubscriptionStatus.cancelled;
      case 'negotiating':
      default:
        return SubscriptionStatus.negotiating;
    }
  }
}

/// One chat bubble in a subscription negotiation thread (see
/// captain_subscription_messages, 20260812000056_captain_subscriptions.sql).
class SubscriptionMessage {
  const SubscriptionMessage({
    required this.id,
    required this.subscriptionId,
    required this.senderId,
    required this.senderRole,
    required this.body,
    this.offerAmount,
    required this.createdAt,
  });

  final String id;
  final String subscriptionId;
  final String senderId;
  final String senderRole;
  final String body;
  final double? offerAmount;
  final DateTime createdAt;

  bool get isOffer => offerAmount != null;

  factory SubscriptionMessage.fromJson(Map<String, dynamic> json) {
    return SubscriptionMessage(
      id: json['id'] as String,
      subscriptionId: json['subscription_id'] as String,
      senderId: json['sender_id'] as String,
      senderRole: json['sender_role'] as String,
      body: json['body'] as String,
      offerAmount: (json['offer_amount'] as num?)?.toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }
}
