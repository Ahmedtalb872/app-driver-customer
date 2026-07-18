import 'package:flutter/material.dart';

import '../../../features/wallet/payment/payment_provider_config.dart';
import '../../core/admin_colors.dart';

/// Read-only reference view of the payment providers the mobile wallet
/// screen is configured with (lib/features/wallet/payment/payment_provider_config.dart).
/// There is no `payment_methods` table yet, so there is nothing to toggle
/// live from here - this screen exists so an admin can see current merchant
/// configuration without opening the mobile codebase.
class PaymentMethodsScreen extends StatelessWidget {
  const PaymentMethodsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AdminColors.accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AdminColors.accent.withValues(alpha: 0.3),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, color: AdminColors.accent),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'هذه القائمة مرجعية للاطلاع فقط: مصدرها إعدادات المزوّدين '
                    'الثابتة في تطبيق الهاتف. تفعيل/تعطيل مزوّد مباشرة من هنا '
                    'يتطلب جدول payment_methods في قاعدة البيانات، وهو غير '
                    'موجود بعد.',
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth > 900
                  ? 3
                  : constraints.maxWidth > 600
                  ? 2
                  : 1;
              return GridView.count(
                crossAxisCount: columns,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.7,
                children: PaymentProviders.all
                    .map((provider) => _ProviderCard(provider: provider))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ProviderCard extends StatelessWidget {
  final PaymentProviderConfig provider;

  const _ProviderCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: provider.primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(provider.logoIcon, color: provider.primaryColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    provider.displayName,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AdminColors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'مُفعّل',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AdminColors.success,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              provider.legalName,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                color: AdminColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${provider.accountLabel}: ${provider.merchantAccountNumber}',
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 12),
            ),
            Text(
              'معرّف التاجر: ${provider.merchantId}',
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                color: AdminColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
