import 'package:flutter/material.dart';

/// Describes one payment provider's branding and merchant details.
/// The payment page itself never hardcodes a provider — it only reads
/// from this config, so adding a new provider (or swapping merchant
/// details) never requires touching the UI.
class PaymentProviderConfig {
  final String id;
  final String displayName;
  final String legalName;
  final Color primaryColor;
  final Color onPrimaryColor;
  final IconData logoIcon;
  final String merchantId;
  final String merchantName;
  final String merchantAccountNumber;
  final String accountLabel;
  final int phoneDigits;
  final int pinDigits;

  const PaymentProviderConfig({
    required this.id,
    required this.displayName,
    required this.legalName,
    required this.primaryColor,
    required this.onPrimaryColor,
    required this.logoIcon,
    required this.merchantId,
    required this.merchantName,
    required this.merchantAccountNumber,
    required this.accountLabel,
    this.phoneDigits = 8,
    this.pinDigits = 4,
  });
}

class PaymentProviders {
  const PaymentProviders._();

  static const bankily = PaymentProviderConfig(
    id: 'bankily',
    displayName: 'Bankily',
    legalName: 'بنكيلي للدفع الإلكتروني',
    primaryColor: Color(0xFF0072CE),
    onPrimaryColor: Colors.white,
    logoIcon: Icons.account_balance_wallet_rounded,
    merchantId: 'MER-458213',
    merchantName: 'شركة الهدهد للنقل الذكي',
    merchantAccountNumber: '22244490001',
    accountLabel: 'رقم حساب بنكيلي التجاري',
  );

  static const masrvi = PaymentProviderConfig(
    id: 'masrvi',
    displayName: 'Masrvi',
    legalName: 'مصرفي للدفع الإلكتروني',
    primaryColor: Color(0xFF00A651),
    onPrimaryColor: Colors.white,
    logoIcon: Icons.credit_score_rounded,
    merchantId: 'MER-773190',
    merchantName: 'شركة الهدهد للنقل الذكي',
    merchantAccountNumber: '22233390002',
    accountLabel: 'رقم حساب مصرفي التجاري',
  );

  static const sedad = PaymentProviderConfig(
    id: 'sedad',
    displayName: 'Sedad',
    legalName: 'سداد للدفع الإلكتروني',
    primaryColor: Color(0xFFE4572E),
    onPrimaryColor: Colors.white,
    logoIcon: Icons.qr_code_scanner_rounded,
    merchantId: 'MER-621047',
    merchantName: 'شركة الهدهد للنقل الذكي',
    merchantAccountNumber: '22255590003',
    accountLabel: 'رقم حساب سداد التجاري',
  );

  static const bankCard = PaymentProviderConfig(
    id: 'card',
    displayName: 'بطاقة مصرفية',
    legalName: 'الدفع بالبطاقة المصرفية',
    primaryColor: Color(0xFF6B4EFF),
    onPrimaryColor: Colors.white,
    logoIcon: Icons.credit_card_rounded,
    merchantId: 'MER-990045',
    merchantName: 'شركة الهدهد للنقل الذكي',
    merchantAccountNumber: '22200090004',
    accountLabel: 'رقم الحساب التجاري',
  );

  static const List<PaymentProviderConfig> all = [
    bankily,
    masrvi,
    sedad,
    bankCard,
  ];
}
