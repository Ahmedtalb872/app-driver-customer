import 'package:flutter/material.dart';

/// Global navigator key so services that live outside the widget tree (like
/// `SessionGuardService`, which reacts to a Realtime event, not user input)
/// can redirect the user - e.g. forcing a sign-out back to the login screen -
/// without needing a [BuildContext] of their own.
class AppNavigator {
  AppNavigator._();

  static final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();
}
