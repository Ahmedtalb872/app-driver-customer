import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/constants/colors.dart';

/// Large animated countdown ring driven by a real wall-clock [expiresAt]
/// timestamp rather than a plain decrementing integer, so it stays correct
/// across widget rebuilds and after the app returns from the background -
/// every tick recomputes the remaining time from `expiresAt - now()`
/// instead of accumulating drift.
class RideCountdownRing extends StatefulWidget {
  final DateTime expiresAt;
  final VoidCallback onExpired;
  final double size;

  const RideCountdownRing({
    super.key,
    required this.expiresAt,
    required this.onExpired,
    this.size = 96,
  });

  @override
  State<RideCountdownRing> createState() => _RideCountdownRingState();
}

class _RideCountdownRingState extends State<RideCountdownRing> {
  Timer? _timer;
  late final Duration _total;
  Duration _remaining = Duration.zero;
  bool _expiredFired = false;

  @override
  void initState() {
    super.initState();
    final total = widget.expiresAt.difference(DateTime.now());
    _total = total > Duration.zero ? total : const Duration(seconds: 1);
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (!mounted) return;
    final remaining = widget.expiresAt.difference(DateTime.now());
    setState(() {
      _remaining = remaining.isNegative ? Duration.zero : remaining;
    });
    if (_remaining == Duration.zero && !_expiredFired) {
      _expiredFired = true;
      _timer?.cancel();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onExpired();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalMs = _total.inMilliseconds;
    final progress = totalMs <= 0
        ? 0.0
        : (_remaining.inMilliseconds / totalMs).clamp(0.0, 1.0);
    final seconds = _remaining.inSeconds;
    final mm = (seconds ~/ 60).toString().padLeft(2, '0');
    final ss = (seconds % 60).toString().padLeft(2, '0');
    final urgent = seconds <= 10;
    final ringColor = urgent ? AppColors.error : AppColors.primary;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: progress, end: progress),
              duration: const Duration(milliseconds: 300),
              builder: (context, value, _) => CircularProgressIndicator(
                value: value,
                strokeWidth: 6,
                backgroundColor: AppColors.border,
                valueColor: AlwaysStoppedAnimation<Color>(ringColor),
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$mm:$ss',
                style: TextStyle(
                  fontSize: widget.size * 0.2,
                  fontWeight: FontWeight.bold,
                  color: urgent ? AppColors.error : AppColors.darkText,
                  fontFamily: 'Cairo',
                ),
              ),
              Text(
                'ثانية',
                style: TextStyle(
                  fontSize: widget.size * 0.08,
                  color: AppColors.secondaryText,
                  fontFamily: 'Cairo',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
