import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../providers/app_state_provider.dart';
import '../../core/widgets/state_widgets.dart';

class NotificationsScreen extends StatelessWidget {
  final bool showAppBar;
  const NotificationsScreen({super.key, this.showAppBar = false});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppStateProvider>(context);
    final notifications = provider.customerNotifications; // Shared notification source

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: showAppBar
          ? AppBar(
              title: const Text('الإشعارات'),
            )
          : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!showAppBar) ...[
            const SizedBox(height: 40),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.0),
              child: Text(
                'مركز الإشعارات',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.darkText, fontFamily: 'Cairo'),
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          Expanded(
            child: notifications.isEmpty
                ? const EmptyStateWidget(
                    title: 'لا توجد إشعارات جديدة',
                    message: 'سنخبرك هنا عند وجود تحديثات حول رحلاتك أو عروضك.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    itemCount: notifications.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = notifications[index];
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.notifications_active_rounded,
                                color: AppColors.primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: AppColors.darkText,
                                      fontFamily: 'Cairo',
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item.body,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.secondaryText,
                                      fontFamily: 'Cairo',
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    item.time,
                                    style: const TextStyle(
                                      fontSize: 10,
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
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
