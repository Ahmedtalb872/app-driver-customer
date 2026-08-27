import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../providers/app_state_provider.dart';

/// Shown briefly right after a trip completes: just a thank-you message,
/// no financial breakdown or button - it clears the active trip and
/// returns to the dashboard on its own after a few seconds.
class CaptainTripSummaryScreen extends StatefulWidget {
  const CaptainTripSummaryScreen({super.key});

  @override
  State<CaptainTripSummaryScreen> createState() =>
      _CaptainTripSummaryScreenState();
}

class _CaptainTripSummaryScreenState extends State<CaptainTripSummaryScreen> {
  Timer? _autoReturnTimer;

  @override
  void initState() {
    super.initState();
    _autoReturnTimer = Timer(const Duration(seconds: 3), _returnHome);
  }

  @override
  void dispose() {
    _autoReturnTimer?.cancel();
    super.dispose();
  }

  void _returnHome() {
    if (!mounted) return;
    Provider.of<AppStateProvider>(
      context,
      listen: false,
    ).confirmCaptainSummary();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: AppColors.primaryDark,
                    size: 64,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'عمل رائع يا كابتن!',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkText,
                    fontFamily: 'Cairo',
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'فخورين بك، شريك الهدهد',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDark,
                    fontFamily: 'Cairo',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
