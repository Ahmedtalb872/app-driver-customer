import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/supabase/auth_exception.dart';
import '../../core/supabase/auth_repository.dart';
import '../../core/services/whatsapp_support.dart';
import '../../providers/app_state_provider.dart';
import '../captain/captain_home_screen.dart';
import '../profile/captain_edit_info_screen.dart';
import 'permissions_screen.dart';
import 'splash_screen.dart';

/// Shown after registration (and on every login) while a captain's account
/// is not yet approved by an admin. There is deliberately no way to skip
/// past this screen into the app - only a status refresh, editing info
/// (personal/vehicle/documents, all in one place), a WhatsApp contact
/// button for delays, and logout. Approval/rejection happens from the
/// admin panel, which flips `captains.status` and (on rejection) fills
/// `captains.rejection_reason` with the reason shown here.
class PendingReviewScreen extends StatefulWidget {
  final String? uploadWarning;
  const PendingReviewScreen({super.key, this.uploadWarning});

  @override
  State<PendingReviewScreen> createState() => _PendingReviewScreenState();
}

class _PendingReviewScreenState extends State<PendingReviewScreen> {
  final _authRepository = AuthRepository();
  bool _isChecking = false;
  bool _isRejected = false;
  String? _rejectionReason;

  @override
  void initState() {
    super.initState();
    _checkStatus(silent: true);
    if (widget.uploadWarning != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.uploadWarning!,
              style: const TextStyle(fontFamily: 'Cairo'),
            ),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 5),
          ),
        );
      });
    }
  }

  Future<void> _checkStatus({bool silent = false}) async {
    setState(() => _isChecking = true);
    try {
      final userId = _authRepository.currentUser?.id;
      if (userId == null) return;
      final captain = await _authRepository.getCaptain(userId);
      final status = captain['status'] as String?;
      final approved = status == 'approved';

      if (!mounted) return;
      if (approved) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) =>
                const PermissionsScreen(destination: CaptainHomeScreen()),
          ),
          (route) => false,
        );
        return;
      }

      setState(() {
        _isRejected = status == 'rejected';
        _rejectionReason = _isRejected
            ? captain['rejection_reason'] as String?
            : null;
      });
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isRejected
                  ? 'طلبك مرفوض حاليًا، راجع ملاحظة الإدارة أدناه.'
                  : 'لا يزال طلبك قيد المراجعة، حاول مرة أخرى لاحقًا.',
              style: const TextStyle(fontFamily: 'Cairo'),
            ),
          ),
        );
      }
    } on AppAuthException catch (e) {
      if (!mounted || silent) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message, style: const TextStyle(fontFamily: 'Cairo')),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  Future<void> _logout() async {
    await _authRepository.signOut();
    if (!mounted) return;
    Provider.of<AppStateProvider>(context, listen: false).logout();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const SplashScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: (_isRejected ? AppColors.error : AppColors.warning)
                      .withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isRejected
                      ? Icons.error_outline_rounded
                      : Icons.hourglass_top_rounded,
                  color: _isRejected ? AppColors.error : AppColors.warning,
                  size: 72,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                _isRejected ? 'طلبك مرفوض حاليًا' : 'جاري تأكد من حسابك',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkText,
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _isRejected
                    ? 'راجع ملاحظة الإدارة أدناه، صحّح المشكلة، ثم اطلب تحديث الحالة.'
                    : 'فريقنا يراجع بياناتك ومستنداتك الآن. ستتمكن من الدخول للتطبيق فور تفعيل حسابك من الإدارة.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.secondaryText,
                  fontFamily: 'Cairo',
                ),
              ),
              if (!_isRejected) ...[
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    'نرحب بك كابتن بيننا! أنت على بعد خطوة من الانضمام لأسرة الهدهد، أكمل ملفك معنا وترقب التفعيل.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDark,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ),
              ],
              if (_isRejected &&
                  _rejectionReason != null &&
                  _rejectionReason!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.error.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ملاحظة الإدارة',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: AppColors.error,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _rejectionReason!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.darkText,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: _isChecking ? null : _checkStatus,
                icon: _isChecking
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.refresh_rounded),
                label: const Text('تحديث الحالة'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const CaptainEditInfoScreen(),
                    ),
                  );
                  _checkStatus(silent: true);
                },
                icon: const Icon(Icons.edit_rounded),
                label: const Text('تعديل المعلومات والمستندات'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => WhatsAppSupport.contactSupport(
                  message: 'السلام عليكم، تأخر تفعيل حساب الكابتن الخاص بي.',
                ),
                icon: const Icon(Icons.chat_rounded),
                label: const Text('تأخر التفعيل؟ تواصل معنا على واتساب'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _logout,
                child: const Text('تسجيل الخروج'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
