import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/supabase/auth_exception.dart';
import '../../core/supabase/wallet_repository.dart';
import '../../providers/app_state_provider.dart';
import 'wallet_recharge_options_screen.dart';

const double _kGiftRedeemThreshold = 10;

class WalletScreen extends StatefulWidget {
  final bool showAppBar;
  const WalletScreen({super.key, this.showAppBar = false});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final _walletRepository = WalletRepository();
  double? _giftBalance;
  bool _isRedeemingGift = false;

  @override
  void initState() {
    super.initState();
    _loadGiftBalance();
  }

  Future<void> _loadGiftBalance() async {
    try {
      final balance = await _walletRepository.getGiftBalance();
      if (mounted) setState(() => _giftBalance = balance);
    } on AppAuthException {
      // Leave the gift card in its loading state rather than showing a
      // scary error for what's a nice-to-have bonus balance.
    }
  }

  Future<void> _redeemGiftCredits() async {
    setState(() => _isRedeemingGift = true);
    try {
      final amount = await _walletRepository.redeemGiftCredits();
      if (!mounted) return;
      Provider.of<AppStateProvider>(
        context,
        listen: false,
      ).creditWalletFromGiftRedemption(amount);
      await _loadGiftBalance();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم تحويل ${amount.toStringAsFixed(0)} أوقية من مكافأتي إلى رصيدك.',
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } on AppAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message, style: const TextStyle(fontFamily: 'Cairo')),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isRedeemingGift = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppStateProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: widget.showAppBar
          ? AppBar(title: const Text('المحفظة والأرباح'))
          : null,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!widget.showAppBar) ...[
              const SizedBox(height: 20),
              const Text(
                'المحفظة الرقمية',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkText,
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Main Balance Card
            _buildBalanceCard(provider),
            const SizedBox(height: 16),

            _buildGiftWalletCard(),
            const SizedBox(height: 24),

            _buildCaptainStatsRow(provider),
            const SizedBox(height: 24),

            // Transactions Header
            const Text(
              'سجل العمليات الأخير',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.darkText,
                fontFamily: 'Cairo',
              ),
            ),
            const SizedBox(height: 12),

            // Transactions List
            _buildTransactionsList(provider),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard(AppStateProvider provider) {
    return Card(
      color: AppColors.primary,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'الرصيد الحالي المتوفر',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontFamily: 'Cairo',
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${provider.captainWalletBalance} أوقية',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                fontFamily: 'Cairo',
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const WalletRechargeOptionsScreen(),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white70),
                ),
                icon: const Icon(Icons.add_rounded),
                label: const Text('شحن المحفظة'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGiftWalletCard() {
    final balance = _giftBalance;
    final canRedeem = balance != null && balance >= _kGiftRedeemThreshold;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.card_giftcard_rounded, color: AppColors.primary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'مكافأتي',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkText,
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
              Text(
                balance == null
                    ? '...'
                    : '${balance.toStringAsFixed(0)} أوقية',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                  fontFamily: 'Cairo',
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'تكسب أوقية واحدة عن كل رحلة تُكملها، تصلح لمدة 6 أشهر من '
            'تاريخ كسبها. عند وصول رصيدك إلى 10 أوقية أو أكثر يمكنك تحويله '
            'إلى رصيدك الرئيسي.',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.secondaryText,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: canRedeem && !_isRedeemingGift
                  ? _redeemGiftCredits
                  : null,
              child: _isRedeemingGift
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('تحويل إلى المحفظة الرئيسية'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCaptainStatsRow(AppStateProvider provider) {
    return Row(
      children: [
        _buildStatBox(
          'أرباح اليوم',
          '${provider.captainTodayEarnings} أوقية',
          Icons.today,
        ),
        const SizedBox(width: 12),
        _buildStatBox(
          'عدد الرحلات',
          '${provider.captainTripsCount} رحلة',
          Icons.check_circle_outline,
        ),
      ],
    );
  }

  Widget _buildStatBox(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.primary, size: 24),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.secondaryText,
                fontFamily: 'Cairo',
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.darkText,
                fontFamily: 'Cairo',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionsList(AppStateProvider provider) {
    final transactions = provider.captainTransactions;

    if (transactions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40.0),
          child: Column(
            children: const [
              Icon(
                Icons.receipt_long_rounded,
                color: AppColors.secondaryText,
                size: 40,
              ),
              SizedBox(height: 8),
              Text(
                'لا توجد عمليات سابقة',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  color: AppColors.secondaryText,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: transactions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final tx = transactions[index];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: tx.isCredit
                      ? AppColors.success.withOpacity(0.1)
                      : AppColors.error.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  tx.isCredit
                      ? Icons.add_circle_outline
                      : Icons.remove_circle_outline,
                  color: tx.isCredit ? AppColors.success : AppColors.error,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppColors.darkText,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tx.date,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.secondaryText,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${tx.isCredit ? "+" : "-"}${tx.amount} و.م',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: tx.isCredit ? AppColors.success : AppColors.error,
                  fontFamily: 'Cairo',
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
