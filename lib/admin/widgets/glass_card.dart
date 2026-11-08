import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/admin_colors.dart';

/// A frosted, translucent panel - [BackdropFilter] blur plus a low-opacity
/// white fill over whatever sits behind it ([AmbientGlowBackground]'s glow
/// blobs, normally), bordered in [AdminColors.border]. The "glass" half of
/// this dashboard's glass/dark aesthetic; wrap it in [HoverLift] for the
/// other half (the reference design's cards lift slightly on hover).
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = 20,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: AdminColors.surface.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: AdminColors.border),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Lifts [child] a few pixels and brightens its shadow on mouse hover (web/
/// desktop only - a no-op tap target on touch, same as the reference design
/// which only animates on `whileHover`). Wrap any card-like widget in this
/// to get the dashboard's signature "glass-card hover" motion without
/// duplicating the animation logic at every call site.
class HoverLift extends StatefulWidget {
  final Widget child;
  final double liftPx;

  const HoverLift({super.key, required this.child, this.liftPx = 6});

  @override
  State<HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<HoverLift> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(
          0,
          _hovering ? -widget.liftPx : 0,
          0,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: _hovering
              ? [
                  BoxShadow(
                    color: AdminColors.primary.withValues(alpha: 0.28),
                    blurRadius: 28,
                    spreadRadius: -4,
                    offset: const Offset(0, 14),
                  ),
                ]
              : const [],
        ),
        child: widget.child,
      ),
    );
  }
}

/// Soft, blurred color blobs behind the dashboard content - the glow a
/// glass card needs to actually look like glass. Placed once, behind
/// [AdminShell]'s content area, so every admin screen gets it for free
/// instead of each screen having to add its own background.
class AmbientGlowBackground extends StatelessWidget {
  const AmbientGlowBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -120,
            right: -80,
            child: _blob(AdminColors.primary, 320),
          ),
          Positioned(
            bottom: -140,
            left: -100,
            child: _blob(AdminColors.secondary, 360),
          ),
          Positioned(
            top: 240,
            left: -60,
            child: _blob(AdminColors.teal, 220),
          ),
        ],
      ),
    );
  }

  // The radial gradient's own fade to transparent already reads as a soft
  // glow with no hard edge - no BackdropFilter needed on the blob itself,
  // only on GlassCard (which blurs whatever sits *behind* it, these blobs
  // included).
  Widget _blob(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0)],
        ),
      ),
    );
  }
}
