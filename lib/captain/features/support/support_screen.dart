import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../../core/services/phone_caller.dart';
import '../../core/services/whatsapp_support.dart';

class SupportScreen extends StatelessWidget {
  final bool showAppBar;
  const SupportScreen({super.key, this.showAppBar = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: showAppBar ? AppBar(title: const Text('الدعم والمساعدة')) : null,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!showAppBar) ...[
              const SizedBox(height: 20),
              const Text(
                'المساعدة والدعم',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkText,
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Fast Contact Options Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'تواصل معنا مباشرة',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkText,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'فريق دعم الهدهد متاح على مدار الساعة لمساعدتك في أي استفسار.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.secondaryText,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        _buildContactChannel(
                          context,
                          icon: Icons.chat_bubble_outline_rounded,
                          label: 'محادثة مباشرة',
                          color: AppColors.primary,
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'جاري بدء محادثة دعم جديدة...',
                                  style: TextStyle(fontFamily: 'Cairo'),
                                ),
                                backgroundColor: AppColors.primary,
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 12),
                        _buildContactChannel(
                          context,
                          icon: Icons.call_outlined,
                          label: 'اتصال هاتفي',
                          color: AppColors.success,
                          onTap: () =>
                              PhoneCaller.call('+${WhatsAppSupport.supportPhone}'),
                        ),
                        const SizedBox(width: 12),
                        _buildContactChannel(
                          context,
                          icon: Icons.alternate_email_rounded,
                          label: 'بريد إلكتروني',
                          color: AppColors.secondaryText,
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'تم نسخ البريد الإلكتروني للدعم support@alhudhud.mr',
                                  style: TextStyle(fontFamily: 'Cairo'),
                                ),
                                backgroundColor: AppColors.darkText,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),

            // FAQ Header
            const Text(
              'الأسئلة الشائعة والمساعدة',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.darkText,
                fontFamily: 'Cairo',
              ),
            ),
            const SizedBox(height: 12),

            // FAQ Accordion List
            _buildFAQItem(
              'الحساب والتسجيل كعميل أو كابتن',
              'يمكنك إنشاء حساب بسهولة عبر التطبيق باختيار نوع الحساب "زبون" أو "كابتن". يتطلب حساب الكابتن رفع وثائق تشمل الهوية والرخصة والبطاقة الرمادية للمراجعة قبل التفعيل.',
            ),
            _buildFAQItem(
              'كيفية احتساب أسعار الرحلات',
              'يتم تحديد سعر الرحلة بناءً على المسافة المقطوعة والزمن المتوقع ومستوى الطلب ونوع فئة السيارة المطلوبة (اقتصادية، مريحة، عائلية). السعر يظهر كاملاً للزبون قبل تأكيد الطلب.',
            ),
            _buildFAQItem(
              'ما هو المشوار المفتوح؟',
              'هي خاصية تتيح للزبون طرح مشواره للكباتن القريبين مباشرة دون تخصيص كابتن محدد، حيث يتمكن أول كابتن متاح من قبوله. يمكنك ضبط مدة بقاء المشوار (30، 45، أو 60 ثانية).',
            ),
            _buildFAQItem(
              'فقدان الأغراض الشخصية في السيارة',
              'في حال نسيان غرض في السيارة، يرجى التواصل معنا مباشرة من خلال زر "اتصال هاتفي" المتاح بالدعم وتزويدنا برقم الرحلة المفقودة لنقوم بالتنسيق الفوري مع الكابتن.',
            ),
            _buildFAQItem(
              'طرق الدفع المتوفرة بالتطبيق',
              'يدعم الهدهد الدفع النقدي المباشر، والدفع بواسطة المحفظة الداخلية، بالإضافة لخدمات الدفع الوطنية مثل Bankily و Masrvi و Sedad بشكل سلس.',
            ),
            _buildFAQItem(
              'شروط الأمان والسلامة في الرحلة',
              'نحرص على تفعيل ميزات سلامة متقدمة مثل مشاركة مسار الرحلة الجارية مع عائلتك وزر الطوارئ SOS السريع للإبلاغ المباشر في حالات الطوارئ أثناء سير المشوار.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactChannel(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.15)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  fontFamily: 'Cairo',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFAQItem(String title, String answer) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        shape: const Border(),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.darkText,
            fontFamily: 'Cairo',
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
            child: Text(
              answer,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.secondaryText,
                fontFamily: 'Cairo',
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
