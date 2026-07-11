import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../providers/app_state_provider.dart';
import '../trips/my_trips_screen.dart';
import '../wallet/wallet_screen.dart';
import '../support/chat_screen.dart';
import '../profile/profile_screen.dart';
import '../../core/widgets/real_map_widget.dart';
import 'location_selection_screen.dart';
import '../notifications/notifications_screen.dart';
import '../onboarding/user_type_selection_screen.dart';
import '../../dummy_data/dummy_data.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  int _currentIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppStateProvider>(context);

    // List of screens for bottom navigation
    final List<Widget> screens = [
      _buildHomeMapView(provider),
      const MyTripsScreen(showAppBar: false),
      const WalletScreen(showAppBar: false),
      const ChatScreen(showAppBar: false),
      const ProfileScreen(showAppBar: false),
    ];

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      drawer: _buildDrawer(provider),
      bottomNavigationBar: _buildBottomNavigationBar(),
      body: screens[_currentIndex],
    );
  }

  Widget _buildHomeMapView(AppStateProvider provider) {
    return Stack(
      children: [
        // High fidelity map viewport
        const Positioned.fill(
          child: RealMapWidget(
            showRoute: false,
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
                  Colors.black.withOpacity(0.4),
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
                
                // Brand name
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3))],
                  ),
                  child: const Text(
                    'الهدهد',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ),
                
                // Notifications icon with badge
                Stack(
                  children: [
                    Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3))],
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.notifications_outlined, color: AppColors.darkText),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (context) => const NotificationsScreen(showAppBar: true)),
                          );
                        },
                      ),
                    ),
                    if (provider.customerNotifications.isNotEmpty)
                      Positioned(
                        right: 2,
                        top: 2,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: AppColors.error,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${provider.customerNotifications.length}',
                            style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        
        // Location Search Bottom Sheet
        Positioned(
          bottom: 16,
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
                const Text(
                  'أهلاً بك، أين تريد الذهاب؟',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkText,
                    fontFamily: 'Cairo',
                  ),
                ),
                const SizedBox(height: 14),
                
                // Clickable search bar
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const LocationSelectionScreen()),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.search_rounded, color: AppColors.primary, size: 22),
                        SizedBox(width: 12),
                        Text(
                          'ابحث عن وجهتك الحالية...',
                          style: TextStyle(color: AppColors.secondaryText, fontSize: 13, fontFamily: 'Cairo'),
                        ),
                        Spacer(),
                        Icon(Icons.tune_rounded, color: AppColors.secondaryText, size: 18),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                
                // Saved Locations
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSavedPlaceBtn('المنزل', Icons.home_filled),
                    _buildSavedPlaceBtn('العمل', Icons.work_rounded),
                    _buildSavedPlaceBtn('المطار', Icons.local_airport_rounded),
                    _buildSavedPlaceBtn('المزيد', Icons.bookmark_added_rounded),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSavedPlaceBtn(String label, IconData icon) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const LocationSelectionScreen()),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.darkText, fontFamily: 'Cairo', fontWeight: FontWeight.bold),
          ),
        ],
      ),
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
              backgroundImage: NetworkImage(DummyData.dummyCustomer.avatar),
              backgroundColor: Colors.white,
            ),
            accountName: Text(
              provider.customerName,
              style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16),
            ),
            accountEmail: Text(
              provider.customerPhone,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          
          ListTile(
            leading: const Icon(Icons.wallet_rounded, color: AppColors.primary),
            title: const Text('المحفظة', style: TextStyle(fontFamily: 'Cairo')),
            onTap: () {
              Navigator.of(context).pop();
              setState(() {
                _currentIndex = 2; // Wallet tab
              });
            },
          ),
          ListTile(
            leading: const Icon(Icons.history_rounded, color: AppColors.primary),
            title: const Text('مشاويري السابقة', style: TextStyle(fontFamily: 'Cairo')),
            onTap: () {
              Navigator.of(context).pop();
              setState(() {
                _currentIndex = 1; // Trips tab
              });
            },
          ),
          ListTile(
            leading: const Icon(Icons.support_agent_rounded, color: AppColors.primary),
            title: const Text('الدعم والمساعدة', style: TextStyle(fontFamily: 'Cairo')),
            onTap: () {
              Navigator.of(context).pop();
              setState(() {
                _currentIndex = 4; // Account/Profile tab
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
          icon: Icon(Icons.home_filled),
          label: 'الرئيسية',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.history_rounded),
          label: 'رحلاتي',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.wallet_rounded),
          label: 'المحفظة',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.forum_outlined),
          label: 'الرسائل',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_rounded),
          label: 'الحساب',
        ),
      ],
    );
  }
}
