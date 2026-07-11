import '../models/models.dart';

class LocationItem {
  final String name;
  final String description;
  final double lat;
  final double lng;

  LocationItem({
    required this.name,
    required this.description,
    required this.lat,
    required this.lng,
  });
}

class DummyData {
  static final List<LocationItem> nouakchottLocations = [
    LocationItem(name: 'سوق العاصمة', description: 'وسط المدينة، نواكشوط', lat: 18.0878, lng: -15.9789),
    LocationItem(name: 'المطار الدولي (أم التونسي)', description: 'طريق نواذيبو، نواكشوط', lat: 18.3117, lng: -15.9678),
    LocationItem(name: 'مجمع البيت', description: 'تفرغ زينة، نواكشوط', lat: 18.1025, lng: -15.9754),
    LocationItem(name: 'تفرغ زينة', description: 'الحي السكني الراقي، نواكشوط', lat: 18.1065, lng: -15.9664),
    LocationItem(name: 'لكصر', description: 'المقاطعة القديمة، نواكشوط', lat: 18.0982, lng: -15.9592),
    LocationItem(name: 'عرفات', description: 'المنطقة الجنوبية، نواكشوط', lat: 18.0435, lng: -15.9521),
    LocationItem(name: 'تيارت', description: 'المنطقة الشمالية، نواكشوط', lat: 18.1255, lng: -15.9288),
    LocationItem(name: 'الرياض', description: 'طريق روصو، نواكشوط', lat: 18.0125, lng: -15.9688),
    LocationItem(name: 'دار النعيم', description: 'شمال شرق المدينة، نواكشوط', lat: 18.1098, lng: -15.9087),
  ];

  static final AppUser dummyCustomer = AppUser(
    id: 'cust_1',
    name: 'أحمد سالم ولد محمد',
    phone: '+22244444444',
    rating: 4.8,
    tripsCount: 37,
    type: UserType.customer,
    avatar: 'https://api.dicebear.com/7.x/adventurer/svg?seed=Ahmed',
  );

  static final CaptainDetails dummyCaptain = CaptainDetails(
    user: AppUser(
      id: 'cap_1',
      name: 'سيد محمد ولد بونا',
      phone: '+22233333333',
      rating: 4.9,
      tripsCount: 152,
      type: UserType.captain,
      avatar: 'https://api.dicebear.com/7.x/adventurer/svg?seed=Sidi',
    ),
    vehicle: Vehicle(
      brand: 'تويوتا',
      model: 'كورولا',
      year: 2018,
      color: 'رمادي ميتاليك',
      plate: '4567 AA 00',
      seats: 4,
      type: VehicleType.economy,
    ),
    acceptanceRate: 94.0,
    cancellationRate: 2.5,
    documentsStatus: {
      'personal_photo': 'accepted',
      'national_id': 'accepted',
      'driver_license': 'accepted',
      'car_card': 'accepted',
      'car_photo': 'accepted',
      'car_insurance': 'accepted',
    },
  );

  static final List<Trip> dummyCustomerTrips = [
    Trip(
      id: 'trip_101',
      customerName: 'أحمد سالم ولد محمد',
      customerPhone: '+22244444444',
      captainName: 'سيد محمد ولد بونا',
      captainPhone: '+22233333333',
      captainAvatar: 'https://api.dicebear.com/7.x/adventurer/svg?seed=Sidi',
      vehicleName: 'تويوتا كورولا 2018',
      vehiclePlate: '4567 AA 00',
      pickupLocation: 'تفرغ زينة (مجمع البيت)',
      destinationLocation: 'سوق العاصمة',
      pickupLat: 18.1025,
      pickupLng: -15.9754,
      destLat: 18.0878,
      destLng: -15.9789,
      distance: 3.2,
      duration: 12,
      price: 150.0,
      paymentMethod: 'نقداً',
      status: TripStatus.completed,
      carType: VehicleType.economy,
      isOpenRide: false,
      openRideTimeout: 45,
      date: '2026-07-09 18:30',
    ),
    Trip(
      id: 'trip_102',
      customerName: 'أحمد سالم ولد محمد',
      customerPhone: '+22244444444',
      captainName: 'عثمان ولد أحمد',
      captainPhone: '+22232222222',
      captainAvatar: 'https://api.dicebear.com/7.x/adventurer/svg?seed=Ousmane',
      vehicleName: 'هيونداي إلنترا 2020',
      vehiclePlate: '9988 AB 00',
      pickupLocation: 'لكصر',
      destinationLocation: 'المطار الدولي (أم التونسي)',
      pickupLat: 18.0982,
      pickupLng: -15.9592,
      destLat: 18.3117,
      destLng: -15.9678,
      distance: 24.5,
      duration: 35,
      price: 800.0,
      paymentMethod: 'Bankily',
      status: TripStatus.completed,
      carType: VehicleType.comfort,
      isOpenRide: true,
      openRideTimeout: 60,
      date: '2026-07-08 10:15',
    ),
    Trip(
      id: 'trip_103',
      customerName: 'أحمد سالم ولد محمد',
      customerPhone: '+22244444444',
      pickupLocation: 'عرفات (كارفور الداية)',
      destinationLocation: 'مجمع البيت',
      pickupLat: 18.0435,
      pickupLng: -15.9521,
      destLat: 18.1025,
      destLng: -15.9754,
      distance: 7.8,
      duration: 22,
      price: 250.0,
      paymentMethod: 'المحفظة',
      status: TripStatus.cancelled,
      carType: VehicleType.economy,
      isOpenRide: false,
      openRideTimeout: 45,
      date: '2026-07-07 14:20',
    ),
  ];

  static final List<Trip> dummyCaptainTrips = [
    Trip(
      id: 'trip_201',
      customerName: 'فاطمة منت اعل',
      customerPhone: '+22245555555',
      captainName: 'سيد محمد ولد بونا',
      captainPhone: '+22233333333',
      pickupLocation: 'تيارت',
      destinationLocation: 'سوق العاصمة',
      pickupLat: 18.1255,
      pickupLng: -15.9288,
      destLat: 18.0878,
      destLng: -15.9789,
      distance: 6.5,
      duration: 18,
      price: 200.0,
      paymentMethod: 'Masrvi',
      status: TripStatus.completed,
      carType: VehicleType.economy,
      isOpenRide: false,
      openRideTimeout: 45,
      date: '2026-07-10 12:30',
      netEarnings: 170.0,
      commission: 30.0,
    ),
    Trip(
      id: 'trip_202',
      customerName: 'النان ولد المختار',
      customerPhone: '+22246666666',
      captainName: 'سيد محمد ولد بونا',
      captainPhone: '+22233333333',
      pickupLocation: 'تفرغ زينة',
      destinationLocation: 'دار النعيم',
      pickupLat: 18.1065,
      pickupLng: -15.9664,
      destLat: 18.1098,
      destLng: -15.9087,
      distance: 8.9,
      duration: 25,
      price: 300.0,
      paymentMethod: 'نقداً',
      status: TripStatus.completed,
      carType: VehicleType.economy,
      isOpenRide: true,
      openRideTimeout: 30,
      date: '2026-07-10 09:15',
      netEarnings: 255.0,
      commission: 45.0,
    ),
  ];

  static final List<WalletTransaction> dummyCustomerTransactions = [
    WalletTransaction(
      id: 'tx_1',
      amount: 1000.0,
      type: TransactionType.charge,
      title: 'شحن رصيد بواسطة Bankily',
      date: '2026-07-10 11:00',
      isCredit: true,
    ),
    WalletTransaction(
      id: 'tx_2',
      amount: 250.0,
      type: TransactionType.payment,
      title: 'دفع قيمة رحلة #trip_103',
      date: '2026-07-07 14:40',
      isCredit: false,
    ),
    WalletTransaction(
      id: 'tx_3',
      amount: 250.0,
      type: TransactionType.refund,
      title: 'استرجاع قيمة رحلة ملغاة #trip_103',
      date: '2026-07-07 15:00',
      isCredit: true,
    ),
    WalletTransaction(
      id: 'tx_4',
      amount: 50.0,
      type: TransactionType.reward,
      title: 'هدية التسجيل في التطبيق',
      date: '2026-07-05 08:00',
      isCredit: true,
    ),
  ];

  static final List<WalletTransaction> dummyCaptainTransactions = [
    WalletTransaction(
      id: 'tx_201',
      amount: 170.0,
      type: TransactionType.charge,
      title: 'أرباح رحلة #trip_201',
      date: '2026-07-10 12:48',
      isCredit: true,
    ),
    WalletTransaction(
      id: 'tx_202',
      amount: 30.0,
      type: TransactionType.commission,
      title: 'عمولة تطبيق الهدهد لرحلة #trip_201',
      date: '2026-07-10 12:48',
      isCredit: false,
    ),
    WalletTransaction(
      id: 'tx_203',
      amount: 500.0,
      type: TransactionType.withdraw,
      title: 'سحب رصيد إلى حساب Bankily',
      date: '2026-07-09 20:00',
      isCredit: false,
    ),
    WalletTransaction(
      id: 'tx_204',
      amount: 100.0,
      type: TransactionType.reward,
      title: 'مكافأة الكابتن المتميز الأسبوعية',
      date: '2026-07-06 00:00',
      isCredit: true,
    ),
  ];

  static final List<NotificationModel> dummyCustomerNotifications = [
    NotificationModel(
      id: 'notif_1',
      title: 'مرحباً بك في الهدهد!',
      body: 'يسعدنا انضمامك إلينا. رحلتك الأولى آمنة ومريحة.',
      time: 'منذ يومين',
    ),
    NotificationModel(
      id: 'notif_2',
      title: 'تم شحن المحفظة بنجاح',
      body: 'لقد تم إضافة 1000 أوقية لرصيدك بنجاح عبر Bankily.',
      time: 'منذ 6 ساعات',
    ),
    NotificationModel(
      id: 'notif_3',
      title: 'عرض خاص للرحلات',
      body: 'احصل على خصم 10% على رحلتك القادمة داخل نواكشوط.',
      time: 'منذ ساعة',
    ),
  ];

  static final List<Message> dummyMessages = [
    Message(
      id: 'msg_1',
      senderId: 'cap_1',
      senderName: 'سيد محمد ولد بونا',
      content: 'السلام عليكم، أنا في الطريق إليك.',
      time: '12:32 م',
      isMe: false,
    ),
    Message(
      id: 'msg_2',
      senderId: 'cust_1',
      senderName: 'أحمد سالم ولد محمد',
      content: 'وعليكم السلام، ممتاز أنا في انتظارك عند البوابة.',
      time: '12:33 م',
      isMe: true,
    ),
    Message(
      id: 'msg_3',
      senderId: 'cap_1',
      senderName: 'سيد محمد ولد بونا',
      content: 'لقد وصلت للموقع تقريباً.',
      time: '12:38 م',
      isMe: false,
    ),
  ];
}
