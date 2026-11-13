import 'package:flutter/material.dart';

import '../../app_services.dart';
import '../../models/models.dart';
import '../../theme.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';

/// What a tenant sees first: balance, key card, next payment, and news.
class TenantDashboardPage extends StatelessWidget {
  const TenantDashboardPage({super.key, required this.user});

  final AppUser user;

  Future<TenantDashboard> _load() async {
    final data = await AppServices.api.get('/api/dashboard/tenant');
    return TenantDashboard.fromJson(asMap(data));
  }

  @override
  Widget build(BuildContext context) {
    return AsyncView<TenantDashboard>(
      load: _load,
      builder: (context, dash, refresh) {
        final due = dash.nextDue;
        final lease = dash.lease;
        final room = dash.room;
        return PageList(
          title: 'Hi, ${firstName(user.fullName)}',
          onRefresh: refresh,
          children: [
            HeroCard(
              label: 'Current balance',
              value: peso(dash.balance),
              footnote: dash.balance > 0
                  ? 'Total of your unpaid bills'
                  : 'You are all paid up',
              icon: dash.balance > 0
                  ? Icons.account_balance_wallet_outlined
                  : Icons.check_circle_outline,
            ),
            if (lease != null && room != null)
              _KeyCard(
                name: user.fullName,
                room: room,
                lease: lease,
                due: due,
              )
            else ...[
              MetricCard(
                label: 'Next due date',
                icon: Icons.event_outlined,
                value: due == null ? 'None' : formatDate(due.dueDate),
                footnote: due == null
                    ? 'No bills waiting'
                    : '${monthLabel(due.period)} bill: ${peso(due.balance)}',
              ),
              const SizedBox(height: 12),
            ],
            SectionCard(
              title: 'Next payment',
              child: due == null
                  ? const Text('You have no bills waiting. New bills appear here each month.')
                  : Column(
                      children: [
                        InfoRow('Bill for', monthLabel(due.period)),
                        InfoRow('Due date', formatDate(due.dueDate)),
                        InfoRow('Amount due', peso(due.amountDue)),
                        InfoRow('Paid so far', peso(due.amountPaid)),
                        InfoRow('Balance', peso(due.balance)),
                        InfoRow('Status', '', child: StatusChip(due.displayStatus)),
                      ],
                    ),
            ),
            SectionCard(
              title: 'My room and lease',
              child: lease == null || room == null
                  ? const Text('You have no active lease yet. The landlord will assign your room.')
                  : Column(
                      children: [
                        InfoRow('Room', room.roomNumber),
                        if (room.description.isNotEmpty) InfoRow('About the room', room.description),
                        InfoRow('Monthly rent', peso(lease.monthlyRent)),
                        InfoRow('Due day', 'Day ${lease.dueDay} of each month'),
                        InfoRow('Lease starts', formatDate(lease.startDate)),
                        InfoRow(
                          'Lease ends',
                          lease.endDate == null ? 'No end date' : formatDate(lease.endDate),
                        ),
                      ],
                    ),
            ),
            if (dash.unreadNotifications > 0)
              SectionCard(
                child: Row(
                  children: [
                    const Icon(Icons.notifications_active_outlined),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        dash.unreadNotifications == 1
                            ? 'You have 1 unread notification. Open the Notifications tab.'
                            : 'You have ${dash.unreadNotifications} unread notifications. Open the Notifications tab.',
                      ),
                    ),
                  ],
                ),
              ),
            SectionCard(
              title: 'Latest announcements',
              child: dash.announcements.isEmpty
                  ? const Text('No announcements yet.')
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < dash.announcements.length; i++) ...[
                          if (i > 0) const Divider(height: 24),
                          _AnnouncementSummary(dash.announcements[i]),
                        ],
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }
}

/// Whole days from today to the due date (negative when the date has passed).
/// Uses the same date reading as [formatDate], so the countdown always matches
/// the date shown on screen.
int? _daysUntil(String dueDate) {
  final parsed = DateTime.tryParse(dueDate);
  if (parsed == null) return null;
  final date = dueDate.length > 10 ? parsed.toLocal() : parsed;
  final now = DateTime.now();
  return DateTime.utc(date.year, date.month, date.day)
      .difference(DateTime.utc(now.year, now.month, now.day))
      .inDays;
}

String _countdownText(int days) {
  if (days > 1) return 'Due in $days days';
  if (days == 1) return 'Due in 1 day';
  if (days == 0) return 'Due today';
  final daysLate = -days;
  return daysLate == 1 ? 'Overdue by 1 day' : 'Overdue by $daysLate days';
}

/// The tenant's room shown like a dorm key card.
class _KeyCard extends StatelessWidget {
  const _KeyCard({
    required this.name,
    required this.room,
    required this.lease,
    required this.due,
  });

  final String name;
  final Room room;
  final Lease lease;
  final Bill? due;

  @override
  Widget build(BuildContext context) {
    final bill = due;
    final days = bill == null ? null : _daysUntil(bill.dueDate);
    final isPaid = bill != null && bill.displayStatus == 'paid';
    final isLate = days != null && days < 0 && !isPaid;
    final isAwaiting = bill != null && bill.displayStatus == 'pending_confirmation';
    final pills = <Widget>[
      if (isPaid) const _KeyPill(icon: Icons.check_circle_outline, text: 'Paid'),
      if (days != null && !isPaid)
        _KeyPill(
          icon: isLate ? Icons.warning_amber_rounded : Icons.schedule,
          text: _countdownText(days),
          color: isLate ? Colors.red.shade700 : null,
        ),
      if (isAwaiting)
        const _KeyPill(icon: Icons.hourglass_top, text: 'Awaiting confirmation'),
    ];
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: brandGradient,
        borderRadius: BorderRadius.circular(radiusL),
        boxShadow: softShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radiusL),
        child: Stack(
          children: [
            Positioned(
              right: -40,
              top: -50,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.10),
                ),
              ),
            ),
            Positioned(
              left: -30,
              bottom: -60,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      LogoTile(size: 34),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Git-Inside',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'KEY CARD',
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          letterSpacing: 1.6,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'ROOM',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      letterSpacing: 2,
                    ),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      room.roomNumber,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 48,
                        height: 1.15,
                      ),
                    ),
                  ),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(height: 1, color: Colors.white.withValues(alpha: 0.25)),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 28,
                    runSpacing: 14,
                    children: [
                      _KeyField('Monthly rent', peso(lease.monthlyRent)),
                      _KeyField('Due day', 'Day ${lease.dueDay}'),
                      _KeyField(
                        'Next due date',
                        bill == null ? 'None' : formatDate(bill.dueDate),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    bill == null
                        ? 'No bills waiting'
                        : '${monthLabel(bill.period)} bill: ${peso(bill.balance)}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  if (pills.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(spacing: 8, runSpacing: 8, children: pills),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KeyField extends StatelessWidget {
  const _KeyField(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}

class _KeyPill extends StatelessWidget {
  const _KeyPill({required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;

  /// Background colour. A soft white is used when this is null.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color ?? Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnnouncementSummary extends StatelessWidget {
  const _AnnouncementSummary(this.item);

  final Announcement item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (item.pinned) ...[
              const Icon(Icons.push_pin, size: 16),
              const SizedBox(width: 4),
            ],
            Expanded(
              child: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(item.body, maxLines: 3, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        Text(formatDate(item.createdAt), style: theme.textTheme.bodySmall),
      ],
    );
  }
}
