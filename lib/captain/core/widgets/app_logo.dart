import 'package:flutter/material.dart';

/// The الهدهد logo (transparent background) — use this everywhere the logo
/// needs to sit on top of an existing background color instead of the
/// launcher-icon version, which is opaque.
class AppLogo extends StatelessWidget {
  final double width;

  const AppLogo({super.key, this.width = 120});

  @override
  Widget build(BuildContext context) {
    return Image.asset('assets/images/logo.png', width: width);
  }
}
