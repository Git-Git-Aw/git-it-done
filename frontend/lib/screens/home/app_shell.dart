import 'package:flutter/material.dart';

import '../../app_services.dart';
import '../../models/models.dart';
import '../../theme.dart';
import 'announcements_page.dart';
import 'landlord_dashboard_page.dart';
import 'notifications_page.dart';
import 'profile_page.dart';
import 'tenant_dashboard_page.dart';

/// One tab of the signed-in app.
class _NavItem {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.builder,
    this.showsUnread = false,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget Function() builder;

  /// True for the Notifications tab: it shows the unread badge.
  final bool showsUnread;
}

/// The frame around every signed-in page: a side menu on wide screens
/// (web and desktop) and a bottom bar on phones.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.user});

  final AppUser user;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  /// Goes up on every tab tap, so the page is rebuilt and loads fresh data.
  int _visit = 0;

  late final List<_NavItem> _items = _buildItems();

  List<_NavItem> _buildItems() {
    final user = widget.user;
    return [
      _NavItem(
        label: 'Dashboard',
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard,
        builder: () => user.isLandlord
            ? const LandlordDashboardPage()
            : TenantDashboardPage(user: user),
      ),
      _NavItem(
        label: 'Announcements',
        icon: Icons.campaign_outlined,
        selectedIcon: Icons.campaign,
        builder: () => AnnouncementsPage(user: user),
      ),
      _NavItem(
        label: 'Notifications',
        icon: Icons.notifications_outlined,
        selectedIcon: Icons.notifications,
        showsUnread: true,
        builder: () => const NotificationsPage(),
      ),
      _NavItem(
        label: 'Profile',
        icon: Icons.person_outline,
        selectedIcon: Icons.person,
        builder: () => ProfilePage(user: user),
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
    AppServices.refreshUnread();
  }

  void _select(int index) {
    setState(() {
      _index = index;
      _visit++;
    });
    // The Notifications page updates the badge by itself.
    if (!_items[index].showsUnread) {
      AppServices.refreshUnread();
    }
  }

  Widget _iconFor(_NavItem item, {required bool selected}) {
    final icon = Icon(selected ? item.selectedIcon : item.icon);
    if (!item.showsUnread) return icon;
    return ValueListenableBuilder<int>(
      valueListenable: AppServices.unreadCount,
      builder: (context, count, _) => Badge.count(
        count: count,
        isLabelVisible: count > 0,
        child: icon,
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool wide) {
    final user = widget.user;
    final role = user.isLandlord ? 'Landlord' : 'Tenant';
    return AppBar(
      foregroundColor: Colors.white,
      backgroundColor: Colors.transparent,
      scrolledUnderElevation: 0,
      flexibleSpace: const DecoratedBox(
        decoration: BoxDecoration(gradient: brandGradient),
      ),
      title: Row(
        children: [
          Image.asset('assets/logo.png', height: 30),
          const SizedBox(width: 10),
          const Text('Git-Inside'),
        ],
      ),
      actions: [
        if (wide)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                '$role: ${user.fullName}',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 800;
    final extended = width >= 1100;

    final page = KeyedSubtree(
      key: ValueKey<String>('page-$_index-$_visit'),
      child: _items[_index].builder(),
    );

    if (!wide) {
      return Scaffold(
        appBar: _buildAppBar(false),
        body: page,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _select,
          destinations: [
            for (final item in _items)
              NavigationDestination(
                icon: _iconFor(item, selected: false),
                selectedIcon: _iconFor(item, selected: true),
                label: item.label,
              ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: _buildAppBar(true),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _index,
            onDestinationSelected: _select,
            extended: extended,
            labelType: extended ? null : NavigationRailLabelType.all,
            destinations: [
              for (final item in _items)
                NavigationRailDestination(
                  icon: _iconFor(item, selected: false),
                  selectedIcon: _iconFor(item, selected: true),
                  label: Text(item.label),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: page),
        ],
      ),
    );
  }
}
