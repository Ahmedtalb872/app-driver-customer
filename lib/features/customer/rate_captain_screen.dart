import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../providers/app_state_provider.dart';


class RateCaptainScreen extends StatefulWidget {
  const RateCaptainScreen({super.key});

  @override
  State<RateCaptainScreen> createState() => _RateCaptainScreenState();
}

class _RateCaptainScreenState extends State<RateCaptainScreen> {
  int _starsRating = 5;
  final _commentController = TextEditingController();
  double _tipAmount = 0.0; // 0, 50, 100, 200

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _handleSubmit(AppStateProvider provider) {
    provider.submitRating(_starsRating.toDouble(), _commentController.text, _tipAmount);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('شكراً لتقييمك! تم إرسال ملاحظاتك بنجاح.', style: TextStyle(fontFamily: 'Cairo')),
        backgroundColor: AppColors.success,
      ),
    );
    
    // Return to Customer Home Screen
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppStateProvider>(context);
    final trip = provider.customerTripHistory.isNotEmpty 
        ? provider.customerTripHistory.first 
        : null;

    final driverName = trip?.captainName ?? 'سيد محمد ولد بونا';
    final driverAvatar = trip?.captainAvatar ?? 'https://api.dicebear.com/7.x/adventurer/svg?seed=Sidi';
    final vehicleDetails = trip?.vehicleName ?? 'تويوتا كورولا 2018';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('تقييم الكابتن'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 10),
              
              // Driver Card Header
              CircleAvatar(
                radius: 40,
                backgroundImage: NetworkImage(driverAvatar),
                backgroundColor: Colors.white,
              ),
              const SizedBox(height: 12),
              Text(
                driverName,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.darkText, fontFamily: 'Cairo'),
              ),
              Text(
                vehicleDetails,
                style: const TextStyle(fontSize: 12, color: AppColors.secondaryText, fontFamily: 'Cairo'),
              ),
              const SizedBox(height: 28),
              
              // Stars interactive selector
              const Text(
                'كيف كانت تجربتك مع هذا الكابتن؟',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Cairo', color: AppColors.darkText),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  int starVal = index + 1;
                  return IconButton(
                    icon: Icon(
                      starVal <= _starsRating ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: AppColors.accent,
                      size: 40,
                    ),
                    onPressed: () {
                      setState(() {
                        _starsRating = starVal;
                      });
                    },
                  );
                }),
              ),
              const SizedBox(height: 28),
              
              // Tips selector row
              const Text(
                'إضافة إكرامية اختيارية للكابتن (أوقية)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Cairo', color: AppColors.darkText),
              ),
              const SizedBox(height: 12),
              Row(
                children: [0.0, 50.0, 100.0, 200.0].map((tip) {
                  bool isSel = _tipAmount == tip;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _tipAmount = tip;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isSel ? AppColors.primary : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSel ? AppColors.primary : AppColors.border,
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            tip == 0.0 ? 'بدون' : '$tip و.م',
                            style: TextStyle(
                              color: isSel ? Colors.white : AppColors.darkText,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              fontFamily: 'Cairo',
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 28),
              
              // Comment input
              const Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'أضف تعليقاً إضافياً (اختياري)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Cairo', color: AppColors.darkText),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _commentController,
                maxLines: 3,
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(
                  hintText: 'اكتب ملاحظاتك هنا لمساعدة الكابتن على تحسين خدماته...',
                ),
              ),
              const SizedBox(height: 36),
              
              // Action buttons
              ElevatedButton(
                onPressed: () => _handleSubmit(provider),
                child: const Text('إرسال التقييم'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  provider.submitRating(0, '', 0);
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                style: TextButton.styleFrom(foregroundColor: AppColors.secondaryText),
                child: const Text('تخطي التقييم'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
