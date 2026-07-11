import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../providers/app_state_provider.dart';
import '../../models/models.dart';
import '../../core/widgets/real_map_widget.dart';
import '../trips/my_trips_screen.dart';
import '../wallet/wallet_screen.dart';
import '../profile/profile_screen.dart';
import 'open_trips_screen.dart';
import 'captain_active_trip_screen.dart';
import '../onboarding/user_type_selection_screen.dart';
import '../../dummy_data/dummy_data.dart';

class CaptainHomeScreen extends StatefulWidget {
  const CaptainHomeScreen({super.key});

  @override
  State<CaptainHomeScreen> createState() => _CaptainHomeScreenState();
}

class _CaptainHomeScreenState extends State<CaptainHomeScreen> {
  int _currentIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppStateProvider>(context);

    // List of screens for bottom navigation
    final List<Widget> screens = [
      _buildDashboardView(provider),
      const OpenTripsScreen(showAppBar: false),
      const MyTripsScreen(showAppBar: false),
      const WalletScreen(showAppBar: false),
      const ProfileScreen(showAppBar: false),
    ];

    // Auto navigate to active trip screen if captain has accepted a trip
    if (provider.activeTrip != null && 
        (provider.activeTrip!.status == TripStatus.accepted || 
         provider.activeTrip!.status == TripStatus.enRoute || 
         provider.activeTrip!.status == TripStatus.arrived || 
         provider.activeTrip!.status == TripStatus.started)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const CaptainActiveTripScreen()),
        );
      });
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      drawer: _buildDrawer(provider),
      bottomNavigationBar: _buildBottomNavigationBar(),
      body: screens[_currentIndex],
    );
  }

  Widget _buildDashboardView(AppStateProvider provider) {
    return Stack(
      children: [
        // High fidelity map viewport
        Positioned.fill(
          child: RealMapWidget(
            showRoute: false,
            // Dim map if captain is offline
            interactive: provider.isCaptainOnline,
          ),
        ),
        
        // Darkened overlay for offline state
        if (!provider.isCaptainOnline)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.35),
            ),
          ),
          
        // Custom Header Bar
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.only(top: 50, left: 16, right: 16, bottom: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(provider.isCaptainOnline ? 0.4 : 0.6),
                  Colors.transparent,
                ],
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Hamburger drawer icon
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3))],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.menu_rounded, color: AppColors.darkText),
                    onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                  ),
                ),
                
                // Online/Offline status switch badge
                GestureDetector(
                  onTap: () => provider.toggleCaptainOnline(),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: provider.isCaptainOnline ? AppColors.success : AppColors.error,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2))],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          provider.isCaptainOnline ? 'متصل (متاح)' : 'غير متصل (مغلق)',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Blank spacer or notification placeholder
                const SizedBox(width: 48),
              ],
            ),
          ),
        ),
        
        // Status indicator banner
        Positioned(
          top: 110,
          left: 20,
          right: 20,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
            ),
            child: Row(
              children: [
                Icon(
                  provider.isCaptainOnline ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                  color: provider.isCaptainOnline ? AppColors.success : AppColors.error,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    provider.isCaptainOnline
                        ? 'أنت متاح لاستقبال المشاوير وبث الطلبات القريبة.'
                        : 'قم بتفعيل زر الاتصال بالأعلى لبدء استقبال المشاوير.',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.darkText, fontFamily: 'Cairo'),
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // Captain Stats overview card (Float at bottom)
        Positioned(
          bottom: 24,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.darkText.withOpacity(0.12),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'ملخص أرباح اليوم ككابتن',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.darkText, fontFamily: 'Cairo'),
                    ),
                    Text(
                      '${provider.captainTodayEarnings} أوقية',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary, fontFamily: 'Cairo'),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatCol('المشاوير اليومية', '${provider.captainTripHistory.length} رحلات'),
                    Container(width: 1, height: 28, color: AppColors.border),
                    _buildStatCol('التقييم العام', '4.9 ⭐'),
                    Container(width: 1, height: 28, color: AppColors.border),
                    _buildStatCol('رصيد المحفظة', '${provider.captainWalletBalance} و.م'),
                  ],
                ),
              ],
            ),
          ),
        ),
        
        // Incoming Trip Request overlay dialog (Full screen popup when new request arrives)
        if (provider.incomingRequest != null)
          _buildIncomingRequestOverlay(provider),
      ],
    );
  }

  Widget _buildStatCol(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.secondaryText, fontFamily: 'Cairo')),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.darkText, fontFamily: 'Cairo')),
      ],
    );
  }

  Widget _buildIncomingRequestOverlay(AppStateProvider provider) {
    final trip = provider.incomingRequest!;
    
    return Positioned.fill(
      child: Container(
        color: Colors.black87, // Translucent dark backdrop
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 20)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Text(
                        'مشوار ركاب جديد!',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ),
                  ),
                  const Divider(height: 32),
                  
                  // Pickup & Destination
                  Row(
                    children: [
                      Column(
                        children: [
                          const Icon(Icons.radio_button_checked_rounded, color: AppColors.success, size: 18),
                          Container(width: 1.5, height: 24, color: AppColors.border),
                          const Icon(Icons.location_on_rounded, color: AppColors.error, size: 18),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              trip.pickupLocation,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.darkText, fontFamily: 'Cairo'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 20),
                            Text(
                              trip.destinationLocation,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.darkText, fontFamily: 'Cairo'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                  
                  // Details Row (fare, distance)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildSummaryItem('الأرباح المقدرة', '${trip.price} أوقية'),
                      Container(width: 1, height: 24, color: AppColors.border),
                      _buildSummaryItem('مسافة المشوار', '${trip.distance} كم'),
                      Container(width: 1, height: 24, color: AppColors.border),
                      _buildSummaryItem('المدة المتوقعة', '${trip.duration} دقيقة'),
                    ],
                  ),
                  const Divider(height: 32),
                  
                  // Ticking Countdown
                  Center(
                    child: Column(
                      children: [
                        const Text(
                          'الوقت المتبقي لقبول المشوار:',
                          style: TextStyle(fontSize: 11, color: AppColors.secondaryText, fontFamily: 'Cairo'),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '00:${provider.countdownSeconds.toString().padLeft(2, '0')}',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  
                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => provider.ignoreIncomingRequest(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.secondaryText,
                            side: const BorderSide(color: AppColors.border),
                          ),
                          child: const Text('تجاهل الطلب'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            provider.acceptIncomingRequest();
                            // Navigation to Active Trip screen occurs automatically via state listener
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                          child: const Text('قبول المشوار'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.secondaryText, fontFamily: 'Cairo')),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.darkText, fontFamily: 'Cairo')),
      ],
    );
  }

  Widget _buildDrawer(AppStateProvider provider) {
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(
              color: AppColors.primary,
            ),
            currentAccountPicture: CircleAvatar(
              backgroundImage: NetworkImage(DummyData.dummyCaptain.user.avatar),
              backgroundColor: Colors.white,
            ),
            accountName: Text(
              provider.captainName,
              style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16),
            ),
            accountEmail: Text(
              provider.captainPhone,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          
          ListTile(
            leading: const Icon(Icons.dashboard_rounded, color: AppColors.primary),
            title: const Text('لوحة التحكم', style: TextStyle(fontFamily: 'Cairo')),
            onTap: () {
              Navigator.of(context).pop();
              setState(() {
                _currentIndex = 0;
              });
            },
          ),
          ListTile(
            leading: const Icon(Icons.explore_rounded, color: AppColors.primary),
            title: const Text('المشاوير المفتوحة للجميع', style: TextStyle(fontFamily: 'Cairo')),
            onTap: () {
              Navigator.of(context).pop();
              setState(() {
                _currentIndex = 1; // Open trips tab
              });
            },
          ),
          ListTile(
            leading: const Icon(Icons.wallet_rounded, color: AppColors.primary),
            title: const Text('الأرباح والمحفظة', style: TextStyle(fontFamily: 'Cairo')),
            onTap: () {
              Navigator.of(context).pop();
              setState(() {
                _currentIndex = 3; // Wallet tab
              });
            },
          ),
          ListTile(
            leading: const Icon(Icons.history_rounded, color: AppColors.primary),
            title: const Text('سجل رحلات كابتن', style: TextStyle(fontFamily: 'Cairo')),
            onTap: () {
              Navigator.of(context).pop();
              setState(() {
                _currentIndex = 2; // Trips tab
              });
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: AppColors.error),
            title: const Text('تسجيل الخروج', style: TextStyle(fontFamily: 'Cairo', color: AppColors.error)),
            onTap: () {
              Navigator.of(context).pop();
              provider.logout();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const UserTypeSelectionScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.secondaryText,
      selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 11),
      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontFamily: 'Cairo', fontSize: 11),
      onTap: (index) {
        setState(() {
          _currentIndex = index;
        });
      },
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard_rounded),
          label: 'الرئيسية',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.explore_rounded),
          label: 'المفتوحة',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.history_rounded),
          label: 'الرحلات',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.wallet_rounded),
          label: 'المحفظة',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_rounded),
          label: 'الحساب',
        ),
      ],
    );
  }
}
