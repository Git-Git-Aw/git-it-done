import 'package:flutter/material.dart';

import '../../app_services.dart';
import '../../models/models.dart';
import '../../theme.dart';
import '../chat/chat_screens.dart';
import '../maintenance/tenant_maintenance_page.dart';
import '../payments/tenant_payments_page.dart';
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
/// (web and desktop) and a bottom bar on phones. On a phone with many tabs,
/// the first four stay in the bar and the rest are under "More".
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

  bool get _hasMore => _items.length > 5;
  int get _primaryCount => _hasMore ? 4 : _items.length;

  List<_NavItem> _buildItems() {
    final user = widget.user;
    final dashboard = _NavItem(
      label: 'Dashboard',
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
      builder: () => user.isLandlord
          ? const LandlordDashboardPage()
          : TenantDashboardPage(user: user),
    );
    final aiManager = _NavItem(
      label: 'AI Manager',
      icon: Icons.smart_toy_outlined,
      selectedIcon: Icons.smart_toy,
      builder: () => ChatPage(user: user),
    );
    final announcements = _NavItem(
      label: 'Announcements',
      icon: Icons.campaign_outlined,
      selectedIcon: Icons.campaign,
      builder: () => AnnouncementsPage(user: user),
    );
    final notifications = _NavItem(
      label: 'Notifications',
      icon: Icons.notifications_outlined,
      selectedIcon: Icons.notifications,
      showsUnread: true,
      builder: () => const NotificationsPage(),
    );
    final profile = _NavItem(
      label: 'Profile',
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
      builder: () => ProfilePage(user: user),
    );

    if (user.isLandlord) {
      return [dashboard, aiManager, announcements, notifications, profile];
    }
    return [
      dashboard,
      _NavItem(
        label: 'Payments',
        icon: Icons.payments_outlined,
        selectedIcon: Icons.payments,
        builder: () => const TenantPaymentsPage(),
      ),
      _NavItem(
        label: 'Maintenance',
        icon: Icons.build_outlined,
        selectedIcon: Icons.build,
        builder: () => const TenantMaintenancePage(),
      ),
      aiManager,
      announcements,
      notifications,
      profile,
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

  Future<void> _openMore() async {
    final chosen = await showModalBottomSheet<int>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = _primaryCount; i < _items.length; i++)
              ListTile(
                leading: _iconFor(_items[i], selected: i == _index),
                title: Text(_items[i].label),
                selected: i == _index,
                onTap: () => Navigator.of(sheetContext).pop(i),
              ),
          ],
        ),
      ),
    );
    if (chosen != null && mounted) _select(chosen);
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

  /// The "More" icon shows a dot when a hidden tab has unread notifications.
  Widget _moreIcon() {
    const icon = Icon(Icons.more_horiz);
    final hiddenHasUnread =
        _items.skip(_primaryCount).any((item) => item.showsUnread);
    if (!hiddenHasUnread) return icon;
    return ValueListenableBuilder<int>(
      valueListenable: AppServices.unreadCount,
      builder: (context, count, _) => Badge(
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
      final barIndex = _index < _primaryCount ? _index : _primaryCount;
      return Scaffold(
        appBar: _buildAppBar(false),
        body: page,
        bottomNavigationBar: NavigationBar(
          selectedIndex: barIndex,
          onDestinationSelected: (i) {
            if (i < _primaryCount) {
              _select(i);
            } else {
              _openMore();
            }
          },
          destinations: [
            for (var i = 0; i < _primaryCount; i++)
              NavigationDestination(
                icon: _iconFor(_items[i], selected: false),
                selectedIcon: _iconFor(_items[i], selected: true),
                label: _items[i].label,
              ),
            if (_hasMore)
              NavigationDestination(
                icon: _moreIcon(),
                label: 'More',
              ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: _buildAppBar(true),
      body: Row(
        children: [
          // The side menu scrolls when the window is short.
          LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: NavigationRail(
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
                ),
              ),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: page),
        ],
      ),
    );
  }
}
