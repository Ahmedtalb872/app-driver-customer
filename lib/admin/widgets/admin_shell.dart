import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/admin_colors.dart';
import '../services/admin_session.dart';
import 'admin_sidebar.dart';
import 'admin_topbar.dart';

/// Responsive dashboard shell (section 3 / 21 of the spec):
/// - >= 1100px: fixed/collapsible sidebar always visible.
/// - 700-1100px: collapsible (icon-only) sidebar.
/// - < 700px: sidebar becomes a Drawer, opened via the topbar's menu button.
class AdminShell extends StatefulWidget {
  final String currentRoute;
  final String title;
  final Widget child;

  const AdminShell({
    super.key,
    required this.currentRoute,
    required this.title,
    required this.child,
  });

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  bool _collapsed = false;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AdminSession>();
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 700;
    final isTablet = width >= 700 && width < 1100;

    if (isMobile) {
      return Scaffold(
        key: _scaffoldKey,
        drawer: Drawer(
          backgroundColor: AdminColors.sidebarBackground,
          child: SafeArea(
            child: AdminSidebar(
              currentRoute: widget.currentRoute,
              onNavigate: (route) {
                Navigator.of(context).pop();
                _goTo(context, route);
              },
            ),
          ),
        ),
        appBar: AdminTopBar(
          title: widget.title,
          profile: session.profile,
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
          AdminSidebar(currentRoute: widget.currentRoute, collapsed: collapsed),
          Expanded(
            child: Column(
              children: [
                AdminTopBar(
                  title: widget.title,
                  profile: session.profile,
                  onToggleSidebar: () =>
                      setState(() => _collapsed = !_collapsed),
                  onLogout: () => _logout(context),
                ),
                Expanded(
                  child: Container(
                    color: AdminColors.background,
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
    await context.read<AdminSession>().signOut();
    if (context.mounted) {
      context.go('/admin/login');
    }
  }
}
