import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/business_colors.dart';

/// The only way from the public business pages into the real staff admin
/// dashboard (`/admin/login`) - deliberately small, unlabeled and low
/// contrast so a random visitor registering their restaurant never notices
/// it, while staff who already know it's there can still find it. Must be
/// placed somewhere on every screen a first-time, signed-out visitor can
/// land on (register and login) - see business_router.dart's redirect,
/// which now sends a signed-out visitor to /business/register by default
/// instead of a login form.
class HiddenAdminKey extends StatelessWidget {
  const HiddenAdminKey({super.key});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: IconButton(
          iconSize: 16,
          color: BusinessColors.border,
          splashRadius: 16,
          onPressed: () => context.go('/admin/login'),
          icon: const Icon(Icons.key_rounded),
        ),
      ),
    );
  }
}
