import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/business_colors.dart';
import '../core/business_theme.dart';
import '../services/business_session.dart';
import 'business_sidebar.dart';
import 'business_topbar.dart';

/// Responsive shell for every signed-in business portal screen - same
/// breakpoints/behavior as `AdminShell`, [BusinessColors] styled.
class BusinessShell extends StatefulWidget {
  final String currentRoute;
  final String title;
  final Widget child;

  const BusinessShell({
    super.key,
    required this.currentRoute,
    required this.title,
    required this.child,
  });

  @override
  State<BusinessShell> createState() => _BusinessShellState();
}

class _BusinessShellState extends State<BusinessShell> {
  bool _collapsed = false;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return Theme(data: BusinessTheme.theme, child: _buildScaffold(context));
  }

  Widget _buildScaffold(BuildContext context) {
    final session = context.watch<BusinessSession>();
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 700;
    final isTablet = width >= 700 && width < 1100;

    if (isMobile) {
      return Scaffold(
        key: _scaffoldKey,
        drawer: Drawer(
          backgroundColor: BusinessColors.sidebarBackground,
          child: SafeArea(
            child: BusinessSidebar(
              currentRoute: widget.currentRoute,
              onNavigate: (route) {
                Navigator.of(context).pop();
                _goTo(context, route);
              },
            ),
          ),
        ),
        appBar: BusinessTopBar(
          title: widget.title,
          account: session.account,
          onToggleSidebar: () => _scaffoldKey.currentState?.openDrawer(),
          onLogout: () => _logout(context),
        ),
        body: widget.child,
      );
    }

    final collapsed = _collapsed || isTablet;

    return Scaffold(
      body: Row(
        children: [
          BusinessSidebar(currentRoute: widget.currentRoute, collapsed: collapsed),
          Expanded(
            child: Column(
              children: [
                BusinessTopBar(
                  title: widget.title,
                  account: session.account,
                  onToggleSidebar: () =>
                      setState(() => _collapsed = !_collapsed),
                  onLogout: () => _logout(context),
                ),
                Expanded(
                  child: Container(
                    color: BusinessColors.background,
                    child: widget.child,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _goTo(BuildContext context, String route) {
    context.go(route);
  }

  Future<void> _logout(BuildContext context) async {
    await context.read<BusinessSession>().signOut();
    if (context.mounted) {
      context.go('/business/login');
    }
  }
}
