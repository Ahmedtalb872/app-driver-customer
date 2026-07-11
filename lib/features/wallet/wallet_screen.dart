import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../providers/app_state_provider.dart';
import '../../models/models.dart';

class WalletScreen extends StatefulWidget {
  final bool showAppBar;
  const WalletScreen({super.key, this.showAppBar = false});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final _amountController = TextEditingController();
  String _selectedMethod = 'Bankily';

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _showRechargeDialog() {
    _amountController.clear();
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
              title: const Text(
                'شحن رصيد المحفظة',
                style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'المبلغ (أوقية)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        hintText: 'أدخل المبلغ، مثال: 500',
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'وسيلة الدفع الإلكتروني',
                      style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Column(
                      children: ['Bankily', 'Masrvi', 'Sedad', 'بطاقة مصرفية'].map((method) {
                        return RadioListTile<String>(
                          value: method,
                          groupValue: _selectedMethod,
                          activeColor: AppColors.primary,
                          title: Text(method, style: const TextStyle(fontFamily: 'Cairo', fontSize: 14)),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() {
                                _selectedMethod = val;
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final amount = double.tryParse(_amountController.text) ?? 0.0;
                    if (amount > 0) {
                      Provider.of<AppStateProvider>(context, listen: false)
                          .rechargeWallet(amount, _selectedMethod);
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('تمت إضافة $amount أوقية لمحفظتك بنجاح عبر $_selectedMethod.', style: const TextStyle(fontFamily: 'Cairo')),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    }
                  },
                  child: const Text('تأكيد الشحن'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showWithdrawDialog() {
    _amountController.clear();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: const Text(
            'سحب الأرباح إلى Bankily',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'المبلغ المراد سحبه (أوقية)',
                style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 13),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: 'أدخل المبلغ، مثال: 300',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                final amount = double.tryParse(_amountController.text) ?? 0.0;
                final provider = Provider.of<AppStateProvider>(context, listen: false);
                if (amount > 0 && amount <= provider.captainWalletBalance) {
                  provider.withdrawCaptainEarnings(amount);
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('تم تقديم طلب سحب بقيمة $amount أوقية إلى حسابك بنجاح.', style: const TextStyle(fontFamily: 'Cairo')),
                      backgroundColor: AppColors.success,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('رصيد المحفظة غير كافٍ لإتمام عملية السحب.', style: TextStyle(fontFamily: 'Cairo')),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              },
              child: const Text('تأكيد السحب'),
            ),
          ],
        );
      },
    );
  }

  void _showTransferDialog() {
    _amountController.clear();
    final phoneController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: const Text(
            'تحويل رصيد',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'رقم هاتف المستلم',
                style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 13),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  hintText: 'أدخل رقم الهاتف، مثال: 36000000',
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'المبلغ المراد تحويله (أوقية)',
                style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 13),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: 'أدخل المبلغ، مثال: 500',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                final amount = double.tryParse(_amountController.text) ?? 0.0;
                final phone = phoneController.text;
                final provider = Provider.of<AppStateProvider>(context, listen: false);
                if (amount > 0 && amount <= provider.customerWalletBalance && phone.isNotEmpty) {
                  provider.transferBalance(amount, phone);
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('تم تحويل $amount أوقية إلى $phone بنجاح.', style: const TextStyle(fontFamily: 'Cairo')),
                      backgroundColor: AppColors.success,
                    ),
                  );
                } else if (amount > provider.customerWalletBalance) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('رصيد المحفظة غير كافٍ لإتمام عملية التحويل.', style: TextStyle(fontFamily: 'Cairo')),
                      backgroundColor: AppColors.error,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('الرجاء إدخال بيانات صحيحة.', style: TextStyle(fontFamily: 'Cairo')),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              },
              child: const Text('تأكيد التحويل'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppStateProvider>(context);
    final isCustomer = provider.userType == UserType.customer;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text('المحفظة والأرباح'),
            )
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
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.darkText, fontFamily: 'Cairo'),
              ),
              const SizedBox(height: 16),
            ],

            // Main Balance Card
            _buildBalanceCard(provider, isCustomer),
            const SizedBox(height: 24),

            // Additional stats for Captain
            if (!isCustomer) ...[
              _buildCaptainStatsRow(provider),
              const SizedBox(height: 24),
            ],

            // Transactions Header
            const Text(
              'سجل العمليات الأخير',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.darkText, fontFamily: 'Cairo'),
            ),
            const SizedBox(height: 12),

            // Transactions List
            _buildTransactionsList(provider, isCustomer),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard(AppStateProvider provider, bool isCustomer) {
    double balance = isCustomer ? provider.customerWalletBalance : provider.captainWalletBalance;
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
              style: TextStyle(color: Colors.white70, fontSize: 14, fontFamily: 'Cairo'),
            ),
            const SizedBox(height: 6),
            Text(
              '$balance أوقية',
              style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                if (isCustomer) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _showRechargeDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primary,
                      ),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('شحن رصيد'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _showTransferDialog,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white70),
                      ),
                      icon: const Icon(Icons.send_rounded),
                      label: const Text('تحويل'),
                    ),
                  ),
                ] else ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _showWithdrawDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primary,
                      ),
                      icon: const Icon(Icons.account_balance_wallet_rounded),
                      label: const Text('سحب الأرباح'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _showRechargeDialog,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white70),
                      ),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('شحن المحفظة'),
                    ),
                  ),
                ],
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildCaptainStatsRow(AppStateProvider provider) {
    return Row(
      children: [
        _buildStatBox('أرباح اليوم', '${provider.captainTodayEarnings} أوقية', Icons.today),
        const SizedBox(width: 12),
        _buildStatBox('عدد الرحلات', '${provider.captainTripsCount} رحلة', Icons.check_circle_outline),
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
              style: const TextStyle(fontSize: 11, color: AppColors.secondaryText, fontFamily: 'Cairo'),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.darkText, fontFamily: 'Cairo'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionsList(AppStateProvider provider, bool isCustomer) {
    final transactions = isCustomer ? provider.customerTransactions : provider.captainTransactions;

    if (transactions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40.0),
          child: Column(
            children: const [
              Icon(Icons.receipt_long_rounded, color: AppColors.secondaryText, size: 40),
              SizedBox(height: 8),
              Text('لا توجد عمليات سابقة', style: TextStyle(fontFamily: 'Cairo', color: AppColors.secondaryText)),
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
                  tx.isCredit ? Icons.add_circle_outline : Icons.remove_circle_outline,
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
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.darkText, fontFamily: 'Cairo'),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tx.date,
                      style: const TextStyle(fontSize: 10, color: AppColors.secondaryText, fontFamily: 'Cairo'),
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
