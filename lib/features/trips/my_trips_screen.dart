import 'package:flutter/material.dart';

import '../../core/constants/colors.dart';
import '../../core/services/ride_repository.dart';
import '../../models/models.dart';

class MyTripsScreen extends StatefulWidget {
  final bool showAppBar;
  const MyTripsScreen({super.key, this.showAppBar = false});

  @override
  State<MyTripsScreen> createState() => _MyTripsScreenState();
}

class _MyTripsScreenState extends State<MyTripsScreen> {
  late Future<List<Trip>> _tripsFuture;

  @override
  void initState() {
    super.initState();
    _tripsFuture = RideRepository.instance.fetchCustomerTrips();
  }

  Future<void> _refresh() async {
    setState(() {
      _tripsFuture = RideRepository.instance.fetchCustomerTrips();
    });
    await _tripsFuture;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: widget.showAppBar
            ? AppBar(title: const Text('رحلاتي'), bottom: _buildTabBar())
            : PreferredSize(
                preferredSize: const Size.fromHeight(56),
                child: Container(
                  color: Colors.white,
                  child: SafeArea(child: _buildTabBar()),
                ),
              ),
        body: FutureBuilder<List<Trip>>(
          future: _tripsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _buildError();
            }
            final trips = snapshot.data ?? [];
            return TabBarView(
              children: [
                _TripListTab(
                  trips: trips,
                  statusFilter: const [
                    TripStatus.searching,
                    TripStatus.accepted,
                    TripStatus.enRoute,
                    TripStatus.arrived,
                    TripStatus.started,
                  ],
                  onRefresh: _refresh,
                ),
                _TripListTab(
                  trips: trips,
                  statusFilter: const [TripStatus.completed],
                  onRefresh: _refresh,
                ),
                _TripListTab(
                  trips: trips,
                  statusFilter: const [TripStatus.cancelled],
                  onRefresh: _refresh,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'تعذر تحميل رحلاتك الآن.',
              style: TextStyle(fontFamily: 'Cairo', color: AppColors.secondaryText),
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _refresh, child: const Text('إعادة المحاولة')),
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
      labelStyle: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 14,
        fontFamily: 'Cairo',
      ),
      unselectedLabelStyle: TextStyle(
        fontWeight: FontWeight.normal,
        fontSize: 14,
        fontFamily: 'Cairo',
      ),
      tabs: [
        Tab(text: 'الحالية'),
        Tab(text: 'المكتملة'),
        Tab(text: 'الملغاة'),
      ],
    );
  }
}

class _TripListTab extends StatelessWidget {
  final List<Trip> trips;
  final List<TripStatus> statusFilter;
  final Future<void> Function() onRefresh;
  const _TripListTab({
    required this.trips,
    required this.statusFilter,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final filteredTrips = trips.where((t) => statusFilter.contains(t.status)).toList();

    if (filteredTrips.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          children: [
            const SizedBox(height: 80),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.history_rounded,
                      size: 48,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'لا توجد رحلات حالياً',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkText,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'ستظهر رحلاتك هنا بمجرد طلبها.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.secondaryText,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        trip.date,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.secondaryText,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
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
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      Column(
                        children: [
                          const Icon(
                            Icons.radio_button_checked_rounded,
                            color: AppColors.success,
                            size: 18,
                          ),
                          Container(width: 2, height: 24, color: AppColors.border),
                          const Icon(
                            Icons.location_on_rounded,
                            color: AppColors.error,
                            size: 18,
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              trip.pickupLocation,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppColors.darkText,
                                fontFamily: 'Cairo',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 18),
                            Text(
                              trip.isOpenTrip ? 'مشوار مفتوح' : trip.destinationLocation,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppColors.darkText,
                                fontFamily: 'Cairo',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'التكلفة الإجمالية',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.secondaryText,
                              fontFamily: 'Cairo',
                            ),
                          ),
                          Text(
                            '${trip.price} أوقية',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                              fontFamily: 'Cairo',
                            ),
                          ),
                        ],
                      ),
                      if (trip.captainName != null && trip.captainName!.isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'الكابتن',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.secondaryText,
                                fontFamily: 'Cairo',
                              ),
                            ),
                            Text(
                              trip.captainName!,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.darkText,
                                fontFamily: 'Cairo',
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  if (trip.status == TripStatus.completed) ...[
                    const Divider(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'تم فتح تذكرة دعم لهذه الرحلة، سنقوم بالتواصل معك.',
                                style: TextStyle(fontFamily: 'Cairo'),
                              ),
                              backgroundColor: AppColors.primary,
                            ),
                          );
                        },
                        child: const Text(
                          'الإبلاغ عن مشكلة',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
