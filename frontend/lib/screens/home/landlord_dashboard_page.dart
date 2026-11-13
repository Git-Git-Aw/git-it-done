import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../api/api_client.dart';
import '../../app_services.dart';
import '../../config.dart';
import '../../models/models.dart';
import '../../theme.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';

/// The landlord's overview of one month: money, rooms, payments, and repairs.
class LandlordDashboardPage extends StatefulWidget {
  const LandlordDashboardPage({super.key});

  @override
  State<LandlordDashboardPage> createState() => _LandlordDashboardPageState();
}

class _LandlordDashboardPageState extends State<LandlordDashboardPage> {
  late String _period = periodOf(DateTime.now());

  /// Goes up on every refresh, so the room map loads its lists again.
  int _mapVersion = 0;

  Future<LandlordSummary> _load() async {
    final data = await AppServices.api.get(
      '/api/dashboard/landlord',
      query: {'period': _period},
    );
    return LandlordSummary.fromJson(asMap(data));
  }

  Future<void> _showSummary() {
    return showDialog<void>(
      context: context,
      builder: (_) => _SummaryDialog(period: _period),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AsyncView<LandlordSummary>(
      key: ValueKey<String>(_period),
      load: _load,
      builder: (context, s, refresh) {
        return PageList(
          title: 'Dashboard',
          onRefresh: () async {
            setState(() => _mapVersion++);
            await refresh();
          },
          children: [
            MonthBar(
              period: _period,
              onChanged: (value) => setState(() => _period = value),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _showSummary,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Generate AI summary'),
              ),
            ),
            const SizedBox(height: 12),
            HeroCard(
              label: 'Total collections',
              value: peso(s.totalCollections),
              footnote: 'Received for ${monthLabel(s.period)}',
              icon: Icons.payments_outlined,
            ),
            _KpiGrid(
              phoneColumns: 1,
              wideColumns: 3,
              tiles: [
                _KpiTile(
                  label: 'Outstanding balance',
                  icon: Icons.account_balance_wallet_outlined,
                  value: peso(s.outstandingBalance),
                  color: s.outstandingBalance > 0 ? Colors.red.shade700 : null,
                  footnote: 'All unpaid bills so far',
                ),
                _KpiTile(
                  label: 'Occupancy rate',
                  icon: Icons.meeting_room_outlined,
                  value: '${s.occupancyRate}%',
                  footnote: '${s.occupiedRooms} of ${s.totalRooms} rooms occupied, ${s.vacantRooms} vacant',
                ),
                _KpiTile(
                  label: 'Open maintenance',
                  icon: Icons.build_outlined,
                  value: '${s.openMaintenance}',
                  color: s.openMaintenance > 0 ? Colors.orange.shade800 : null,
                  footnote: s.roomsNeedingMaintenance.isEmpty
                      ? 'No rooms need maintenance'
                      : 'Rooms: ${s.roomsNeedingMaintenance.join(', ')}',
                ),
              ],
            ),
            const SizedBox(height: 16),
            _RoomMap(period: _period, version: _mapVersion),
            _SectionHeading('Tenant payments for ${monthLabel(s.period)}'),
            _KpiGrid(
              phoneColumns: 2,
              wideColumns: 4,
              tiles: [
                _KpiTile(
                  label: 'Paid',
                  icon: Icons.check_circle_outline,
                  value: '${s.paid}',
                  color: Colors.green.shade700,
                ),
                _KpiTile(
                  label: 'Awaiting confirmation',
                  icon: Icons.hourglass_top,
                  value: '${s.pendingConfirmation}',
                  color: Colors.blue.shade700,
                  footnote: 'Proof uploaded, needs your check',
                ),
                _KpiTile(
                  label: 'Unpaid',
                  icon: Icons.receipt_long_outlined,
                  value: '${s.unpaid}',
                  color: Colors.orange.shade800,
                ),
                _KpiTile(
                  label: 'Overdue',
                  icon: Icons.warning_amber_rounded,
                  value: '${s.overdue}',
                  color: s.overdue > 0 ? Colors.red.shade700 : null,
                  footnote: 'Past the due date',
                ),
              ],
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: 'Open maintenance reports',
              child: s.recentReports.isEmpty
                  ? const Text('No open reports. Everything is fixed.')
                  : Column(
                      children: [
                        for (var i = 0; i < s.recentReports.length; i++) ...[
                          if (i > 0) const Divider(height: 1),
                          _ReportTile(s.recentReports[i]),
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

/// A small heading with the same gradient bar that SectionCard uses.
class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 5,
            height: 20,
            decoration: BoxDecoration(
              gradient: brandGradient,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700, color: inkDark),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lays number tiles in rows with the same height in every row.
/// [phoneColumns] is used under 600 px wide, [wideColumns] from 600 px.
class _KpiGrid extends StatelessWidget {
  const _KpiGrid({
    required this.tiles,
    required this.phoneColumns,
    required this.wideColumns,
  });

  final List<Widget> tiles;
  final int phoneColumns;
  final int wideColumns;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        var columns = constraints.maxWidth >= 600 ? wideColumns : phoneColumns;
        if (columns > tiles.length) columns = tiles.length;
        if (columns < 1) columns = 1;
        final rows = <Widget>[];
        for (var start = 0; start < tiles.length; start += columns) {
          final end = start + columns > tiles.length ? tiles.length : start + columns;
          final chunk = tiles.sublist(start, end);
          if (columns == 1) {
            rows.add(chunk.first);
          } else {
            rows.add(
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < columns; i++) ...[
                      if (i > 0) const SizedBox(width: 12),
                      Expanded(
                        child: i < chunk.length ? chunk[i] : const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }
          if (end < tiles.length) rows.add(const SizedBox(height: 12));
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: rows,
        );
      },
    );
  }
}

/// One number with a label. No LayoutBuilder inside, so equal row heights work.
class _KpiTile extends StatelessWidget {
  const _KpiTile({
    required this.label,
    required this.value,
    required this.icon,
    this.color,
    this.footnote,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? color;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? brandDeep;
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: inkSoft,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: color ?? inkDark,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (footnote != null) ...[
            const SizedBox(height: 4),
            Text(
              footnote!,
              style: theme.textTheme.bodySmall?.copyWith(color: inkSoft),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Room map
// ---------------------------------------------------------------------------

/// What a room cell shows. The order is from most urgent to least urgent, and
/// the first five are the states of a bill.
enum _CellState { overdue, unpaid, awaiting, other, paid, noBill, vacant }

_CellState _billState(String status) {
  switch (status) {
    case 'overdue':
      return _CellState.overdue;
    case 'unpaid':
      return _CellState.unpaid;
    case 'pending_confirmation':
      return _CellState.awaiting;
    case 'paid':
      return _CellState.paid;
    default:
      return _CellState.other;
  }
}

Color _cellColor(_CellState state) {
  switch (state) {
    case _CellState.overdue:
      return Colors.red.shade700;
    case _CellState.unpaid:
      return Colors.orange.shade800;
    case _CellState.awaiting:
      return Colors.blue.shade700;
    case _CellState.other:
      return Colors.teal.shade700;
    case _CellState.paid:
      return Colors.green.shade700;
    case _CellState.noBill:
      return brandPurple;
    case _CellState.vacant:
      return Colors.grey.shade600;
  }
}

String _cellLabel(_CellState state) {
  switch (state) {
    case _CellState.overdue:
      return 'Overdue';
    case _CellState.unpaid:
      return 'Unpaid';
    case _CellState.awaiting:
      return 'Awaiting confirmation';
    case _CellState.other:
      return 'Other status';
    case _CellState.paid:
      return 'Paid';
    case _CellState.noBill:
      return 'No bill yet';
    case _CellState.vacant:
      return 'Vacant';
  }
}

String _cellShortLabel(_CellState state) {
  switch (state) {
    case _CellState.overdue:
      return 'Overdue';
    case _CellState.unpaid:
      return 'Unpaid';
    case _CellState.awaiting:
      return 'Awaiting';
    case _CellState.other:
      return 'Other';
    case _CellState.paid:
      return 'Paid';
    case _CellState.noBill:
      return 'No bill';
    case _CellState.vacant:
      return 'Vacant';
  }
}

IconData _cellIcon(_CellState state) {
  switch (state) {
    case _CellState.overdue:
      return Icons.warning_amber_rounded;
    case _CellState.unpaid:
      return Icons.receipt_long_outlined;
    case _CellState.awaiting:
      return Icons.hourglass_top;
    case _CellState.other:
      return Icons.info_outline;
    case _CellState.paid:
      return Icons.check_circle;
    case _CellState.noBill:
      return Icons.remove_circle_outline;
    case _CellState.vacant:
      return Icons.meeting_room_outlined;
  }
}

/// One room with this month's bills for it and the state it is shown in.
class _RoomCell {
  _RoomCell(this.room, this.bills, this.state);

  final Room room;
  final List<Bill> bills;
  final _CellState state;
}

/// Vacant when nobody has an active lease in the room. Otherwise the most
/// urgent state among the bills of the month, or "no bill yet" without bills.
_CellState _stateFor(Room room, List<Bill> bills) {
  if (room.occupants == 0) return _CellState.vacant;
  if (bills.isEmpty) return _CellState.noBill;
  var worst = _billState(bills.first.displayStatus);
  for (final bill in bills) {
    final state = _billState(bill.displayStatus);
    if (state.index < worst.index) worst = state;
  }
  return worst;
}

/// A grid of every room, coloured by this month's payment status.
/// It loads the same two lists that the offline sync already saves
/// (GET /api/rooms with archived=true, and GET /api/payments with period).
class _RoomMap extends StatefulWidget {
  const _RoomMap({required this.period, required this.version});

  final String period;

  /// Changes when the dashboard is refreshed.
  final int version;

  @override
  State<_RoomMap> createState() => _RoomMapState();
}

class _RoomMapState extends State<_RoomMap> with AutomaticKeepAliveClientMixin<_RoomMap> {
  List<Room>? _rooms;
  List<Bill>? _bills;
  Object? _error;
  int _loadId = 0;

  /// Keeps the loaded map while it is scrolled out of view, so it does not
  /// load again each time the landlord scrolls back to it.
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _RoomMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.period != widget.period || oldWidget.version != widget.version) {
      _load();
    }
  }

  Future<void> _load() async {
    final id = ++_loadId;
    try {
      final roomData = await AppServices.api.get('/api/rooms', query: {'archived': 'true'});
      final billData = await AppServices.api.get('/api/payments', query: {'period': widget.period});
      if (!mounted || id != _loadId) return;
      setState(() {
        _rooms = asList(roomData)
            .map((e) => Room.fromJson(asMap(e)))
            .where((room) => !room.isArchived)
            .toList();
        _bills = asList(billData).map((e) => Bill.fromJson(asMap(e))).toList();
        _error = null;
      });
    } catch (e) {
      if (!mounted || id != _loadId) return;
      setState(() => _error = e);
    }
  }

  void _retry() {
    setState(() {
      _error = null;
      _rooms = null;
      _bills = null;
    });
    _load();
  }

  List<_RoomCell> _cells(List<Room> rooms, List<Bill> bills) {
    final byRoom = <String, List<Bill>>{};
    for (final bill in bills) {
      byRoom.putIfAbsent(bill.roomNumber, () => <Bill>[]).add(bill);
    }
    return [
      for (final room in rooms)
        _RoomCell(
          room,
          byRoom[room.roomNumber] ?? <Bill>[],
          _stateFor(room, byRoom[room.roomNumber] ?? <Bill>[]),
        ),
    ];
  }

  void _showCell(_RoomCell cell) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      constraints: const BoxConstraints(maxWidth: 560),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(radiusL)),
      ),
      builder: (_) => _RoomDetails(cell: cell, period: widget.period),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final title = 'Room map: ${monthLabel(widget.period)}';
    final error = _error;
    final rooms = _rooms;
    final bills = _bills;
    if (error != null) {
      return SectionCard(
        title: title,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Could not load the room map. ${errorText(error)}'),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _retry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      );
    }
    if (rooms == null || bills == null) {
      return SectionCard(
        title: title,
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    if (rooms.isEmpty) {
      return SectionCard(
        title: title,
        child: const EmptyState(
          icon: Icons.meeting_room_outlined,
          message: 'No rooms yet. Add rooms on the Rooms page.',
        ),
      );
    }
    final cells = _cells(rooms, bills);
    final counts = <_CellState, int>{};
    for (final cell in cells) {
      counts[cell.state] = (counts[cell.state] ?? 0) + 1;
    }
    final theme = Theme.of(context);
    final hint = theme.textTheme.bodySmall?.copyWith(color: inkSoft);
    return SectionCard(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tap a room to see its tenants and bills.', style: hint),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final state in _CellState.values)
                if (state != _CellState.other || (counts[state] ?? 0) > 0)
                  _StatePill(state: state, count: counts[state] ?? 0),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = 10.0;
              var columns = ((constraints.maxWidth + gap) / (92 + gap)).floor();
              if (columns < 2) columns = 2;
              final tileWidth =
                  ((constraints.maxWidth - gap * (columns - 1)) / columns).floorToDouble();
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final cell in cells)
                    _RoomTile(
                      cell: cell,
                      width: tileWidth,
                      onTap: () => _showCell(cell),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          Text(
            'A room with two tenants shows its most urgent bill: overdue, then unpaid, '
            'then awaiting confirmation, then paid. Vacant means nobody has an active '
            'lease in the room. No bill yet means the room has a tenant but no bill '
            'for this month.',
            style: hint,
          ),
        ],
      ),
    );
  }
}

/// A small coloured label for a room state, with an optional count.
class _StatePill extends StatelessWidget {
  const _StatePill({required this.state, this.count});

  final _CellState state;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final color = _cellColor(state);
    final label = _cellLabel(state);
    final text = count == null ? label : '$label $count';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                color: color,
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

/// One room in the map. The colour, the icon and the word all show the state,
/// so the map does not depend on colour alone.
class _RoomTile extends StatelessWidget {
  const _RoomTile({required this.cell, required this.width, required this.onTap});

  final _RoomCell cell;
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final room = cell.room;
    final color = _cellColor(cell.state);
    final isVacant = cell.state == _CellState.vacant;
    return SizedBox(
      width: width,
      child: Tooltip(
        message:
            'Room ${room.roomNumber}: ${_cellLabel(cell.state)}, ${room.occupants} of ${room.capacity} tenants',
        child: Material(
          color: color.withValues(alpha: isVacant ? 0.08 : 0.14),
          borderRadius: BorderRadius.circular(radiusM),
          child: InkWell(
            borderRadius: BorderRadius.circular(radiusM),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radiusM),
                border: Border.all(color: color.withValues(alpha: 0.45)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(_cellIcon(cell.state), size: 18, color: color),
                      const Spacer(),
                      Text(
                        '${room.occupants}/${room.capacity}',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      room.roomNumber,
                      style: const TextStyle(
                        color: inkDark,
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _cellShortLabel(cell.state),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The bottom sheet that opens when a room in the map is tapped.
class _RoomDetails extends StatelessWidget {
  const _RoomDetails({required this.cell, required this.period});

  final _RoomCell cell;
  final String period;

  @override
  Widget build(BuildContext context) {
    final room = cell.room;
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: lineSoft,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Room ${room.roomNumber}',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: inkDark,
                    ),
                  ),
                ),
                _StatePill(state: cell.state),
              ],
            ),
            const SizedBox(height: 12),
            InfoRow('Monthly rate', peso(room.monthlyRate)),
            InfoRow('Occupancy', '${room.occupants} of ${room.capacity}'),
            InfoRow(
              'Tenants',
              room.occupantNames.isEmpty ? 'None' : room.occupantNames.join(', '),
            ),
            if (room.description.isNotEmpty) InfoRow('About', room.description),
            const SizedBox(height: 14),
            Text(
              'Bills for ${monthLabel(period)}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: inkDark,
              ),
            ),
            const SizedBox(height: 8),
            if (cell.bills.isEmpty)
              Text(
                cell.state == _CellState.noBill
                    ? 'No bills for this room in ${monthLabel(period)}. Use Generate bills on the Payments page if they are not created yet.'
                    : 'No bills for this room in ${monthLabel(period)}.',
              )
            else
              for (final bill in cell.bills) _BillBox(bill),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BillBox extends StatelessWidget {
  const _BillBox(this.bill);

  final Bill bill;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radiusM),
        border: Border.all(color: lineSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  bill.tenantName.isEmpty ? 'Tenant' : bill.tenantName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              StatusChip(bill.displayStatus),
            ],
          ),
          const SizedBox(height: 6),
          InfoRow('Due date', formatDate(bill.dueDate)),
          InfoRow('Amount due', peso(bill.amountDue)),
          InfoRow('Paid so far', peso(bill.amountPaid)),
          InfoRow('Balance', peso(bill.balance)),
        ],
      ),
    );
  }
}

class _ReportTile extends StatelessWidget {
  const _ReportTile(this.report);

  final MaintenanceBrief report;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Room ${report.roomNumber}: ${titleCase(report.category)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              StatusChip(report.status),
            ],
          ),
          const SizedBox(height: 4),
          Text(report.description, maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StatusChip(report.urgency, label: '${titleCase(report.urgency)} urgency'),
              Text(formatDate(report.createdAt), style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}

/// Asks the AI Dorm Manager for the monthly summary and shows the answer.
class _SummaryDialog extends StatefulWidget {
  const _SummaryDialog({required this.period});

  final String period;

  @override
  State<_SummaryDialog> createState() => _SummaryDialogState();
}

class _SummaryDialogState extends State<_SummaryDialog> {
  String? _text;
  String? _error;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    try {
      final data = await AppServices.api.post(
        '/api/chat/summary',
        body: {'period': widget.period},
        changesData: false,
        timeout: AppConfig.aiRequestTimeout,
      );
      final reply = ChatReply.fromJson(asMap(data));
      if (!mounted) return;
      setState(() => _text = plainText(reply.reply));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Something went wrong. Please try again.');
    }
  }

  Future<void> _copy() async {
    final text = _text;
    if (text == null) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) showSnack(context, 'Summary copied.');
  }

  @override
  Widget build(BuildContext context) {
    final text = _text;
    final error = _error;
    Widget content;
    if (error != null) {
      content = Text(error, style: TextStyle(color: Theme.of(context).colorScheme.error));
    } else if (text == null) {
      content = const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    } else {
      content = SingleChildScrollView(child: SelectableText(text));
    }
    return AlertDialog(
      title: Text('AI summary: ${monthLabel(widget.period)}'),
      content: SizedBox(width: 480, child: content),
      actions: [
        if (text != null)
          TextButton.icon(
            onPressed: _copy,
            icon: const Icon(Icons.copy),
            label: const Text('Copy'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
