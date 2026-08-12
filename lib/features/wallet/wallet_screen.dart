import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/services/selefli_repository.dart';
import '../../core/services/wallet_repository.dart';
import '../../models/models.dart';
import '../../providers/app_state_provider.dart';
import 'payment/payment_gateway_screen.dart';
import 'payment/payment_provider_config.dart';

class WalletScreen extends StatefulWidget {
  final bool showAppBar;
  const WalletScreen({super.key, this.showAppBar = false});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final _amountController = TextEditingController();
  bool _isLoading = true;
  SelefliStatus? _selefliStatus;

  @override
  void initState() {
    super.initState();
    _loadWallet();
    _loadSelefliStatus();
  }

  Future<void> _loadWallet() async {
    setState(() => _isLoading = true);
    try {
      final balance = await WalletRepository.instance.fetchBalance();
      final transactions = await WalletRepository.instance.fetchTransactions();
      if (!mounted) return;
      context.read<AppStateProvider>().setWallet(
        balance: balance,
        transactions: transactions,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadSelefliStatus() async {
    try {
      final status = await SelefliRepository.instance.fetchStatus();
      if (mounted) setState(() => _selefliStatus = status);
    } catch (_) {
      // Best effort - the Selefli card just stays hidden if this fails.
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _showRechargeMethodSheet() {
    _amountController.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'شحن رصيد المحفظة',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'المبلغ (أوقية)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo',
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: 'أدخل المبلغ، مثال: 500',
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'اختر وسيلة الدفع',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo',
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...PaymentProviders.all.map(
                    (p) => _buildProviderTile(sheetContext, p),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildProviderTile(
    BuildContext sheetContext,
    PaymentProviderConfig p,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openPaymentGateway(sheetContext, p),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: p.primaryColor.withOpacity(0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: p.primaryColor.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: p.primaryColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(p.logoIcon, color: p.onPrimaryColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  p.displayName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    fontFamily: 'Cairo',
                    color: AppColors.darkText,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_left_rounded,
                color: AppColors.secondaryText,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openPaymentGateway(BuildContext sheetContext, PaymentProviderConfig p) {
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'الرجاء إدخال مبلغ صحيح أولاً.',
            style: TextStyle(fontFamily: 'Cairo'),
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    Navigator.of(sheetContext).pop();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            PaymentGatewayScreen(provider: p, initialAmount: amount),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppStateProvider>(context);
    final selefliCard = _buildSelefliCard();

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
            const SizedBox(height: 24),

            // "سلفلي" eligibility / outstanding-debt status, when known.
            if (selefliCard != null) selefliCard,

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
    final balance = provider.walletBalance;
    return Card(
      color: AppColors.accent,
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
            _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : Text(
                    '$balance أوقية',
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
                onPressed: _showRechargeMethodSheet,
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

  /// `null` while the status is still loading/unknown (the card just stays
  /// hidden) - once loaded, shows exactly one of: outstanding debt (must be
  /// paid off before Selefli can be used again), current eligibility cap,
  /// or how many more completed trips unlock the first tier.
  Widget? _buildSelefliCard() {
    final status = _selefliStatus;
    if (status == null) return null;

    if (status.hasOutstandingDebt) {
      return _selefliCardShell(
        icon: Icons.account_balance_wallet_rounded,
        color: AppColors.error,
        title: 'دين سلفلي مستحق',
        body:
            '${status.outstandingAmount.toStringAsFixed(0)} أوقية - سيُخصم '
            'تلقائياً من رصيدك عند الشحن، ولا يمكنك استخدام سلفلي مجدداً '
            'حتى تسديده بالكامل.',
      );
    }

    if (status.isEligible) {
      return _selefliCardShell(
        icon: Icons.bolt_rounded,
        color: AppColors.primary,
        title: 'خدمة سلفلي متاحة',
        body:
            'يمكنك طلب مشوار بدون رصيد حتى '
            '${status.cap!.toStringAsFixed(0)} أوقية، تُخصم تلقائياً من '
            'محفظتك لاحقاً.',
      );
    }

    final remaining = 11 - status.completedTripsCount;
    if (remaining <= 0) return null;
    return _selefliCardShell(
      icon: Icons.lock_clock_rounded,
      color: AppColors.secondary,
      title: 'اقترب من سلفلي',
      body:
          'أكمل $remaining مشوار إضافي لتصبح مؤهلاً لخدمة سلفلي '
          '(السفر بدون رصيد).',
    );
  }

  Widget _selefliCardShell({
    required IconData icon,
    required Color color,
    required String title,
    required String body,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    fontFamily: 'Cairo',
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(
                    fontSize: 12,
                    fontFamily: 'Cairo',
                    color: AppColors.darkText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsList(AppStateProvider provider) {
    final transactions = provider.walletTransactions;

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
