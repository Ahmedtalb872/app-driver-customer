import 'package:flutter/material.dart';

import '../../core/constants/colors.dart';
import '../../core/services/captain_subscription_repository.dart';
import '../../models/models.dart';
import 'subscription_chat_screen.dart';

/// Entry point for "اشتراك شهري": browse approved, online captains and
/// start a price-negotiation chat with one of them. See
/// [CaptainSubscriptionRepository]/20260812000056_captain_subscriptions.sql
/// for the full negotiate-then-pay-then-activate flow this only starts.
class CaptainsBrowseScreen extends StatefulWidget {
  const CaptainsBrowseScreen({super.key});

  @override
  State<CaptainsBrowseScreen> createState() => _CaptainsBrowseScreenState();
}

class _CaptainsBrowseScreenState extends State<CaptainsBrowseScreen> {
  final _repository = CaptainSubscriptionRepository.instance;

  bool _isLoading = true;
  String? _error;
  List<BrowsableCaptain> _captains = [];
  CaptainSubscription? _myStatus;
  String? _startingCaptainId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _repository.fetchBrowsableCaptains(),
        _repository.fetchMyStatus(),
      ]);
      if (!mounted) return;
      setState(() {
        _captains = results[0] as List<BrowsableCaptain>;
        _myStatus = results[1] as CaptainSubscription?;
      });
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = 'تعذر تحميل قائمة الكباتنة الآن. حاول مرة أخرى.',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openExistingThread() {
    final status = _myStatus;
    if (status == null) return;
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) =>
                SubscriptionChatScreen(subscriptionId: status.id),
          ),
        )
        .then((_) => _load());
  }

  Future<void> _startChat(BrowsableCaptain captain) async {
    setState(() => _startingCaptainId = captain.captainId);
    try {
      final id = await _repository.startChat(captain.captainId);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => SubscriptionChatScreen(subscriptionId: id),
        ),
      );
      if (mounted) await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تعذر بدء المحادثة الآن. حاول مرة أخرى.',
              style: TextStyle(fontFamily: 'Cairo'),
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _startingCaptainId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _myStatus;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'اشتراك شهري مع كابتن',
          style: TextStyle(fontFamily: 'Cairo'),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildErrorState()
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (status != null && status.paymentDispute)
                    _buildDisputeBanner(status),
                  if (status != null && status.isActive)
                    _buildActiveBanner(status)
                  else if (status != null && status.awaitingCustomerConfirmation)
                    _buildConfirmationPendingBanner(status)
                  else ...[
                    if (status != null && status.isNegotiating)
                      _buildNegotiatingBanner(status),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'اختر كابتناً واقترح عليه سعراً شهرياً عبر الدردشة. عند موافقته يُخصم المبلغ فوراً من رصيد محفظتك، وتصبح مشاويرك معه مجاناً لمدة 30 يوماً.',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_captains.isEmpty)
                      _buildEmptyState()
                    else
                      ..._captains.map(
                        (c) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _CaptainTile(
                            captain: c,
                            isStarting: _startingCaptainId == c.captainId,
                            onTap: _startingCaptainId == null
                                ? () => _startChat(c)
                                : null,
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Cairo'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _load, child: const Text('إعادة المحاولة')),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Text(
          'لا يوجد كباتنة متاحون حالياً. حاول لاحقاً.',
          style: TextStyle(fontFamily: 'Cairo', color: AppColors.secondaryText),
        ),
      ),
    );
  }

  Widget _buildActiveBanner(CaptainSubscription status) {
    final days = status.daysRemaining;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: _openExistingThread,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.success.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.success.withOpacity(0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.verified_rounded,
                color: AppColors.success,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'اشتراكك نشط مع ${status.captainName}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        fontFamily: 'Cairo',
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      days != null
                          ? 'باقي $days يوماً - مشاويرك معه مجانية طوال هذه المدة.'
                          : 'مشاويرك معه مجانية طوال مدة الاشتراك.',
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
        ),
      ),
    );
  }

  Widget _buildNegotiatingBanner(CaptainSubscription status) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: _openExistingThread,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.accent.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.accent.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.chat_bubble_rounded, color: AppColors.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'لديك محادثة مفتوحة مع ${status.captainName} - اضغط للمتابعة',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkText,
                  ),
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: AppColors.secondaryText,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConfirmationPendingBanner(CaptainSubscription status) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: _openExistingThread,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.accent.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.accent.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.help_outline_rounded, color: AppColors.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'هل دفعت اشتراك هذا الشهر لـ ${status.captainName}؟ اضغط للتأكيد',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkText,
                  ),
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: AppColors.secondaryText,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDisputeBanner(CaptainSubscription status) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: _openExistingThread,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.warning.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.warning.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.gpp_maybe_rounded, color: AppColors.warning),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'اشتراكك مع ${status.captainName} قيد المراجعة من فريقنا',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkText,
                  ),
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: AppColors.secondaryText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CaptainTile extends StatelessWidget {
  final BrowsableCaptain captain;
  final bool isStarting;
  final VoidCallback? onTap;

  const _CaptainTile({
    required this.captain,
    required this.isStarting,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final avatarUrl = captain.avatarUrl;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primary.withOpacity(0.1),
                backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                    ? NetworkImage(avatarUrl)
                    : null,
                child: (avatarUrl != null && avatarUrl.isNotEmpty)
                    ? null
                    : Text(
                        captain.fullName.substring(0, 1),
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      captain.fullName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        fontFamily: 'Cairo',
                        color: AppColors.darkText,
                      ),
                    ),
                    if (captain.vehicleDescription.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          captain.vehicleDescription,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontFamily: 'Cairo',
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ),
                    if (captain.rating != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              size: 14,
                              color: AppColors.secondary,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '${captain.rating!.toStringAsFixed(1)} (${captain.ratingsCount})',
                              style: const TextStyle(
                                fontSize: 11,
                                fontFamily: 'Cairo',
                                color: AppColors.secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              isStarting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(
                      Icons.chat_bubble_outline_rounded,
                      color: AppColors.primary,
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
