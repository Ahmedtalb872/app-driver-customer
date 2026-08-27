import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../constants/colors.dart';

class LoadingWidget extends StatelessWidget {
  final double height;
  const LoadingWidget({super.key, this.height = 100});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.shimmerBase,
      highlightColor: AppColors.shimmerHighlight,
      child: Container(
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }
}

class LoadingListWidget extends StatelessWidget {
  final int itemCount;
  const LoadingListWidget({super.key, this.itemCount = 3});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: itemCount,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => const LoadingWidget(height: 90),
    );
  }
}

class CustomStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const CustomStateWidget({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 64, color: AppColors.primary),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.darkText,
                fontFamily: 'Cairo',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.secondaryText,
                fontFamily: 'Cairo',
              ),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              SizedBox(
                width: 200,
                child: ElevatedButton(
                  onPressed: onAction,
                  child: Text(actionLabel!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class EmptyStateWidget extends StatelessWidget {
  final String title;
  final String message;
  const EmptyStateWidget({
    super.key,
    this.title = 'لا توجد بيانات',
    this.message = 'لا توجد عناصر لعرضها حالياً.',
  });

  @override
  Widget build(BuildContext context) {
    return CustomStateWidget(
      icon: Icons.hourglass_empty_rounded,
      title: title,
      message: message,
    );
  }
}

class ErrorStateWidget extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onRetry;
  const ErrorStateWidget({
    super.key,
    this.title = 'حدث خطأ ما',
    this.message = 'حدث خطأ أثناء تحميل البيانات، يرجى المحاولة مرة أخرى.',
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return CustomStateWidget(
      icon: Icons.error_outline_rounded,
      title: title,
      message: message,
      actionLabel: onRetry != null ? 'إعادة المحاولة' : null,
      onAction: onRetry,
    );
  }
}

class NoInternetWidget extends StatelessWidget {
  final VoidCallback? onRetry;
  const NoInternetWidget({super.key, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return CustomStateWidget(
      icon: Icons.wifi_off_rounded,
      title: 'لا يوجد اتصال بالإنترنت',
      message: 'يرجى التحقق من اتصالك بالشبكة والمحاولة مرة أخرى.',
      actionLabel: 'تحديث',
      onAction: onRetry,
    );
  }
}

class ExpiredTripWidget extends StatelessWidget {
  final VoidCallback? onAction;
  const ExpiredTripWidget({super.key, this.onAction});

  @override
  Widget build(BuildContext context) {
    return CustomStateWidget(
      icon: Icons.timer_off_outlined,
      title: 'انتهت مدة ظهور المشوار',
      message: 'لقد انتهت المدة المتاحة لقبول هذا المشوار.',
      actionLabel: 'الرجوع',
      onAction: onAction,
    );
  }
}
