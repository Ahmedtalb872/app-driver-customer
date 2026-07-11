
enum UserType { customer, captain }

enum VehicleType { economy, comfort, family }

enum TripStatus {
  pending,
  searching,
  accepted,
  enRoute,
  arrived,
  started,
  completed,
  cancelled
}

enum TransactionType {
  charge,
  payment,
  refund,
  reward,
  withdraw,
  commission,
  transfer
}

class AppUser {
  final String id;
  final String name;
  final String phone;
  final double rating;
  final int tripsCount;
  final UserType type;
  final String avatar;

  AppUser({
    required this.id,
    required this.name,
    required this.phone,
    required this.rating,
    required this.tripsCount,
    required this.type,
    required this.avatar,
  });
}

class Vehicle {
  final String brand;
  final String model;
  final int year;
  final String color;
  final String plate;
  final int seats;
  final VehicleType type;

  Vehicle({
    required this.brand,
    required this.model,
    required this.year,
    required this.color,
    required this.plate,
    required this.seats,
    required this.type,
  });

  String get typeArabic {
    switch (type) {
      case VehicleType.economy:
        return 'إقتصادية';
      case VehicleType.comfort:
        return 'مريحة';
      case VehicleType.family:
        return 'عائلية';
    }
  }

  String get description {
    switch (type) {
      case VehicleType.economy:
        return 'سيارة عادية من 1 إلى 4 ركاب';
      case VehicleType.comfort:
        return 'سيارة أفضل وأكثر راحة من 1 إلى 4 ركاب';
      case VehicleType.family:
        return 'سيارة أكبر من 1 إلى 6 ركاب';
    }
  }
}

class CaptainDetails {
  final AppUser user;
  final Vehicle vehicle;
  final double acceptanceRate;
  final double cancellationRate;
  final Map<String, String> documentsStatus; // e.g. {'national_id': 'accepted'}

  CaptainDetails({
    required this.user,
    required this.vehicle,
    required this.acceptanceRate,
    required this.cancellationRate,
    required this.documentsStatus,
  });
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
  });

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

class NotificationModel {
  final String id;
  final String title;
  final String body;
  final String time;
  final bool isRead;

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.time,
    this.isRead = false,
  });
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
