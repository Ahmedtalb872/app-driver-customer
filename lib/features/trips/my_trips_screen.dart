import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../providers/app_state_provider.dart';
import '../../models/models.dart';

class MyTripsScreen extends StatelessWidget {
  final bool showAppBar;
  const MyTripsScreen({super.key, this.showAppBar = false});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: showAppBar
            ? AppBar(
                title: const Text('رحلاتي'),
                bottom: _buildTabBar(),
              )
            : PreferredSize(
                preferredSize: const Size.fromHeight(56),
                child: Container(
                  color: Colors.white,
                  child: SafeArea(
                    child: _buildTabBar(),
                  ),
                ),
              ),
        body: TabBarView(
          children: [
            _TripListTab(statusFilter: [TripStatus.searching, TripStatus.accepted, TripStatus.enRoute, TripStatus.arrived, TripStatus.started]),
            _TripListTab(statusFilter: [TripStatus.completed]),
            _TripListTab(statusFilter: [TripStatus.cancelled]),
          ],
        ),
      ),
    );
  }

  TabBar _buildTabBar() {
    return const TabBar(
      labelColor: AppColors.primary,
      unselectedLabelColor: AppColors.secondaryText,
      indicatorColor: AppColors.primary,
      indicatorWeight: 3,
      labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Cairo'),
      unselectedLabelStyle: TextStyle(fontWeight: FontWeight.normal, fontSize: 14, fontFamily: 'Cairo'),
      tabs: [
        Tab(text: 'الحالية'),
        Tab(text: 'المكتملة'),
        Tab(text: 'الملغاة'),
      ],
    );
  }
}

class _TripListTab extends StatelessWidget {
  final List<TripStatus> statusFilter;
  const _TripListTab({required this.statusFilter});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppStateProvider>(context);
    final isCustomer = provider.userType == UserType.customer;
    
    // Filter trips matching selected tab states
    final list = isCustomer ? provider.customerTripHistory : provider.captainTripHistory;
    final filteredTrips = list.where((t) => statusFilter.contains(t.status)).toList();

    if (filteredTrips.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.history_rounded, size: 48, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            const Text(
              'لا توجد رحلات حالياً',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.darkText, fontFamily: 'Cairo'),
            ),
            const SizedBox(height: 6),
            const Text(
              'ستظهر الرحلات هنا بمجرد القيام بها.',
              style: TextStyle(fontSize: 12, color: AppColors.secondaryText, fontFamily: 'Cairo'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredTrips.length,
      itemBuilder: (context, index) {
        final trip = filteredTrips[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top details header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      trip.date,
                      style: const TextStyle(fontSize: 12, color: AppColors.secondaryText, fontFamily: 'Cairo'),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: trip.status == TripStatus.completed
                            ? AppColors.success.withOpacity(0.1)
                            : trip.status == TripStatus.cancelled
                                ? AppColors.error.withOpacity(0.1)
                                : AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(
                        trip.statusArabic,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: trip.status == TripStatus.completed
                              ? AppColors.success
                              : trip.status == TripStatus.cancelled
                                  ? AppColors.error
                                  : AppColors.primary,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    )
                  ],
                ),
                const Divider(height: 24),
                
                // Route details
                Row(
                  children: [
                    Column(
                      children: [
                        const Icon(Icons.radio_button_checked_rounded, color: AppColors.success, size: 18),
                        Container(width: 2, height: 24, color: AppColors.border),
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
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.darkText, fontFamily: 'Cairo'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 18),
                          Text(
                            trip.destinationLocation,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.darkText, fontFamily: 'Cairo'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const Divider(height: 24),
                
                // Price & Driver details
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'التكلفة الإجمالية',
                          style: TextStyle(fontSize: 11, color: AppColors.secondaryText, fontFamily: 'Cairo'),
                        ),
                        Text(
                          '${trip.price} أوقية',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary, fontFamily: 'Cairo'),
                        ),
                      ],
                    ),
                    if (isCustomer && trip.captainName != null)
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundImage: NetworkImage(trip.captainAvatar ?? 'https://api.dicebear.com/7.x/adventurer/svg?seed=Sidi'),
                            backgroundColor: AppColors.border,
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                trip.captainName!,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.darkText, fontFamily: 'Cairo'),
                              ),
                              Text(
                                trip.vehicleName ?? 'سيارة اقتصادية',
                                style: const TextStyle(fontSize: 10, color: AppColors.secondaryText, fontFamily: 'Cairo'),
                              ),
                            ],
                          ),
                        ],
                      )
                    else if (!isCustomer)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'الزبون',
                            style: TextStyle(fontSize: 10, color: AppColors.secondaryText, fontFamily: 'Cairo'),
                          ),
                          Text(
                            trip.customerName,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.darkText, fontFamily: 'Cairo'),
                          ),
                        ],
                      )
                  ],
                ),
                
                const Divider(height: 24),
                
                // Actions
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          // Simulating reporting problem
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('تم فتح تذكرة دعم لهذه الرحلة، سنقوم بالتواصل معك.', style: TextStyle(fontFamily: 'Cairo')),
                              backgroundColor: AppColors.primary,
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 40),
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('الإبلاغ عن مشكلة', style: TextStyle(fontSize: 13)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          // Simulating details view or order again
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isCustomer ? 'جاري إعادة طلب الرحلة من جديد...' : 'عرض تفاصيل الفاتورة والعمولة.',
                                style: const TextStyle(fontFamily: 'Cairo'),
                              ),
                              backgroundColor: AppColors.primary,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 40),
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          isCustomer ? 'طلب الرحلة مجدداً' : 'عرض التفاصيل',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
