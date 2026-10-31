// Data classes that read the JSON returned by the Git-Inside backend.

Map<String, dynamic> asMap(dynamic value) => Map<String, dynamic>.from(value as Map);

List<dynamic> asList(dynamic value) => value is List ? value : <dynamic>[];

String _str(dynamic v, [String fallback = '']) => v == null ? fallback : v.toString();

double _num(dynamic v) => v is num ? v.toDouble() : (double.tryParse('${v ?? ''}') ?? 0);

int _int(dynamic v) => v is num ? v.toInt() : (int.tryParse('${v ?? ''}') ?? 0);

bool _bool(dynamic v) => v == true || v == 1;

String? _optStr(dynamic v) => (v == null || v.toString().isEmpty) ? null : v.toString();

String _billRoom(Map<String, dynamic> j) {
  final lease = j['lease'];
  if (lease is Map && lease['room'] is Map) {
    return _str((lease['room'] as Map)['roomNumber']);
  }
  return '';
}

class AppUser {
  AppUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.status,
    this.contactNumber,
  });

  final int id;
  final String fullName;
  final String email;
  final String role;
  final String status;
  final String? contactNumber;

  bool get isLandlord => role == 'landlord';
  bool get isTenant => role == 'tenant';

  Map<String, dynamic> toJson() => {
        'id': id,
        'fullName': fullName,
        'email': email,
        'role': role,
        'status': status,
        'contactNumber': contactNumber,
      };

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: _int(j['id']),
        fullName: _str(j['fullName']),
        email: _str(j['email']),
        role: _str(j['role']),
        status: _str(j['status']),
        contactNumber: j['contactNumber'] == null ? null : _str(j['contactNumber']),
      );
}

class Room {
  Room({
    required this.id,
    required this.roomNumber,
    required this.description,
    required this.monthlyRate,
    required this.capacity,
    this.isArchived = false,
    this.occupants = 0,
    this.occupancyStatus = '',
    this.occupantNames = const <String>[],
  });

  final int id;
  final String roomNumber;
  final String description;
  final double monthlyRate;
  final int capacity;
  final bool isArchived;

  /// How many tenants have an active lease in this room (landlord rooms list).
  final int occupants;

  /// vacant, occupied, full, or archived (landlord rooms list).
  final String occupancyStatus;
  final List<String> occupantNames;

  factory Room.fromJson(Map<String, dynamic> j) => Room(
        id: _int(j['id']),
        roomNumber: _str(j['roomNumber']),
        description: _str(j['description']),
        monthlyRate: _num(j['monthlyRate']),
        capacity: _int(j['capacity']),
        isArchived: _bool(j['isArchived']),
        occupants: _int(j['occupants']),
        occupancyStatus: _str(j['occupancyStatus']),
        occupantNames: asList(j['leases'])
            .map((l) => l is Map && l['tenant'] is Map ? _str((l['tenant'] as Map)['fullName']) : '')
            .where((name) => name.isNotEmpty)
            .toList(),
      );
}

class Lease {
  Lease({
    required this.id,
    required this.startDate,
    required this.endDate,
    required this.monthlyRent,
    required this.dueDay,
    required this.room,
  });

  final int id;
  final String startDate;
  final String? endDate;
  final double monthlyRent;
  final int dueDay;
  final Room? room;

  factory Lease.fromJson(Map<String, dynamic> j) => Lease(
        id: _int(j['id']),
        startDate: _str(j['startDate']),
        endDate: j['endDate'] == null ? null : _str(j['endDate']),
        monthlyRent: _num(j['monthlyRent']),
        dueDay: _int(j['dueDay']),
        room: j['room'] is Map ? Room.fromJson(asMap(j['room'])) : null,
      );
}

/// One monthly bill (a row of the backend "payments" table).
class Bill {
  Bill({
    required this.id,
    required this.period,
    required this.dueDate,
    required this.amountDue,
    required this.amountPaid,
    required this.balance,
    required this.status,
    required this.displayStatus,
    this.method,
    this.proofPath,
    this.paidAt,
    this.remarks,
    this.roomNumber = '',
    this.tenantName = '',
  });

  final int id;
  final String period;
  final String dueDate;
  final double amountDue;
  final double amountPaid;
  final double balance;
  final String status;

  /// Same as status, but "overdue" when an unpaid bill is past its due date.
  final String displayStatus;

  final String? method;

  /// Server path of the uploaded receipt, for example "/uploads/123-abc.jpg".
  final String? proofPath;
  final String? paidAt;
  final String? remarks;
  final String roomNumber;
  final String tenantName;

  factory Bill.fromJson(Map<String, dynamic> j) => Bill(
        id: _int(j['id']),
        period: _str(j['period']),
        dueDate: _str(j['dueDate']),
        amountDue: _num(j['amountDue']),
        amountPaid: _num(j['amountPaid']),
        balance: _num(j['balance']),
        status: _str(j['status']),
        displayStatus: _str(j['displayStatus'], _str(j['status'])),
        method: _optStr(j['method']),
        proofPath: _optStr(j['proofPath']),
        paidAt: _optStr(j['paidAt']),
        remarks: _optStr(j['remarks']),
        roomNumber: _billRoom(j),
        tenantName: j['tenant'] is Map ? _str(asMap(j['tenant'])['fullName']) : '',
      );
}

class Announcement {
  Announcement({
    required this.id,
    required this.title,
    required this.body,
    required this.pinned,
    required this.createdAt,
    required this.authorName,
    this.isArchived = false,
  });

  final int id;
  final String title;
  final String body;
  final bool pinned;
  final String createdAt;
  final String authorName;
  final bool isArchived;

  factory Announcement.fromJson(Map<String, dynamic> j) => Announcement(
        id: _int(j['id']),
        title: _str(j['title']),
        body: _str(j['body']),
        pinned: _bool(j['pinned']),
        createdAt: _str(j['createdAt']),
        authorName: j['author'] is Map ? _str(asMap(j['author'])['fullName']) : '',
        isArchived: _bool(j['isArchived']),
      );
}

class AppNotification {
  AppNotification({
    required this.id,
    required this.type,
    required this.message,
    required this.isRead,
    required this.createdAt,
  });

  final int id;
  final String type;
  final String message;
  final bool isRead;
  final String createdAt;

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: _int(j['id']),
        type: _str(j['type']),
        message: _str(j['message']),
        isRead: _bool(j['isRead']),
        createdAt: _str(j['createdAt']),
      );
}

class NotificationsResult {
  NotificationsResult({required this.unread, required this.items});

  final int unread;
  final List<AppNotification> items;

  factory NotificationsResult.fromJson(Map<String, dynamic> j) => NotificationsResult(
        unread: _int(j['unread']),
        items: asList(j['items']).map((e) => AppNotification.fromJson(asMap(e))).toList(),
      );
}

class TenantDashboard {
  TenantDashboard({
    required this.balance,
    required this.nextDue,
    required this.lease,
    required this.room,
    required this.announcements,
    required this.unreadNotifications,
  });

  final double balance;
  final Bill? nextDue;
  final Lease? lease;
  final Room? room;
  final List<Announcement> announcements;
  final int unreadNotifications;

  factory TenantDashboard.fromJson(Map<String, dynamic> j) {
    final lease = j['lease'] is Map ? Lease.fromJson(asMap(j['lease'])) : null;
    return TenantDashboard(
      balance: _num(j['balance']),
      nextDue: j['nextDue'] is Map ? Bill.fromJson(asMap(j['nextDue'])) : null,
      lease: lease,
      room: j['room'] is Map ? Room.fromJson(asMap(j['room'])) : lease?.room,
      announcements: asList(j['announcements']).map((e) => Announcement.fromJson(asMap(e))).toList(),
      unreadNotifications: _int(j['unreadNotifications']),
    );
  }
}

class MaintenanceBrief {
  MaintenanceBrief({
    required this.id,
    required this.roomNumber,
    required this.category,
    required this.urgency,
    required this.status,
    required this.description,
    required this.createdAt,
  });

  final int id;
  final String roomNumber;
  final String category;
  final String urgency;
  final String status;
  final String description;
  final String createdAt;

  factory MaintenanceBrief.fromJson(Map<String, dynamic> j) => MaintenanceBrief(
        id: _int(j['id']),
        roomNumber: j['room'] is Map ? _str(asMap(j['room'])['roomNumber']) : '',
        category: _str(j['category']),
        urgency: _str(j['urgency']),
        status: _str(j['status']),
        description: _str(j['description']),
        createdAt: _str(j['createdAt']),
      );
}

class LandlordSummary {
  LandlordSummary({
    required this.period,
    required this.totalCollections,
    required this.outstandingBalance,
    required this.occupancyRate,
    required this.occupiedRooms,
    required this.vacantRooms,
    required this.totalRooms,
    required this.paid,
    required this.pendingConfirmation,
    required this.unpaid,
    required this.overdue,
    required this.openMaintenance,
    required this.roomsNeedingMaintenance,
    required this.recentReports,
  });

  final String period;
  final double totalCollections;
  final double outstandingBalance;
  final int occupancyRate;
  final int occupiedRooms;
  final int vacantRooms;
  final int totalRooms;
  final int paid;
  final int pendingConfirmation;
  final int unpaid;
  final int overdue;
  final int openMaintenance;
  final List<String> roomsNeedingMaintenance;
  final List<MaintenanceBrief> recentReports;

  factory LandlordSummary.fromJson(Map<String, dynamic> j) {
    final occupancy = asMap(j['occupancy'] ?? <String, dynamic>{});
    final byPayment = asMap(j['tenantsByPayment'] ?? <String, dynamic>{});
    final maintenance = asMap(j['maintenance'] ?? <String, dynamic>{});
    return LandlordSummary(
      period: _str(j['period']),
      totalCollections: _num(j['totalCollections']),
      outstandingBalance: _num(j['outstandingBalance']),
      occupancyRate: _int(occupancy['rate']),
      occupiedRooms: _int(occupancy['occupiedRooms']),
      vacantRooms: _int(occupancy['vacantRooms']),
      totalRooms: _int(occupancy['totalRooms']),
      paid: _int(byPayment['paid']),
      pendingConfirmation: _int(byPayment['pendingConfirmation']),
      unpaid: _int(byPayment['unpaid']),
      overdue: _int(byPayment['overdue']),
      openMaintenance: _int(maintenance['openCount']),
      roomsNeedingMaintenance: asList(maintenance['roomsNeedingMaintenance'])
          .map((e) => _str(asMap(e)['roomNumber']))
          .toList(),
      recentReports: asList(maintenance['recent'])
          .map((e) => MaintenanceBrief.fromJson(asMap(e)))
          .toList(),
    );
  }
}

/// A full maintenance report (the dashboard only needs [MaintenanceBrief]).
class MaintenanceReport {
  MaintenanceReport({
    required this.id,
    required this.roomNumber,
    required this.tenantName,
    required this.category,
    required this.urgency,
    required this.status,
    required this.description,
    required this.createdAt,
    this.photoPath,
    this.remarks,
    this.assignedTo,
    this.resolvedAt,
  });

  final int id;
  final String roomNumber;
  final String tenantName;
  final String category;
  final String urgency;
  final String status;
  final String description;
  final String createdAt;
  final String? photoPath;
  final String? remarks;
  final String? assignedTo;
  final String? resolvedAt;

  factory MaintenanceReport.fromJson(Map<String, dynamic> j) => MaintenanceReport(
        id: _int(j['id']),
        roomNumber: j['room'] is Map ? _str(asMap(j['room'])['roomNumber']) : '',
        tenantName: j['tenant'] is Map ? _str(asMap(j['tenant'])['fullName']) : '',
        category: _str(j['category'], 'other'),
        urgency: _str(j['urgency'], 'medium'),
        status: _str(j['status'], 'Pending'),
        description: _str(j['description']),
        createdAt: _str(j['createdAt']),
        photoPath: _optStr(j['photoPath']),
        remarks: _optStr(j['remarks']),
        assignedTo: _optStr(j['assignedTo']),
        resolvedAt: _optStr(j['resolvedAt']),
      );
}

/// A change the AI proposed. Nothing happens until the user confirms it.
class PendingAction {
  PendingAction({
    required this.id,
    required this.tool,
    required this.summary,
    required this.expiresAt,
  });

  final String id;
  final String tool;
  final String summary;
  final String expiresAt;

  factory PendingAction.fromJson(Map<String, dynamic> j) => PendingAction(
        id: _str(j['id']),
        tool: _str(j['tool']),
        summary: _str(j['summary']),
        expiresAt: _str(j['expiresAt']),
      );
}

/// The answer from POST /api/chat.
class ChatReply {
  ChatReply({required this.reply, required this.pendingActions});

  final String reply;
  final List<PendingAction> pendingActions;

  factory ChatReply.fromJson(Map<String, dynamic> j) => ChatReply(
        reply: _str(j['reply']),
        pendingActions:
            asList(j['pendingActions']).map((e) => PendingAction.fromJson(asMap(e))).toList(),
      );
}

/// The answer from confirming or cancelling a proposed action.
class ActionOutcome {
  ActionOutcome({required this.status, required this.message});

  /// "executed" or "cancelled".
  final String status;
  final String message;

  factory ActionOutcome.fromJson(Map<String, dynamic> j) => ActionOutcome(
        status: _str(j['status']),
        message: _str(j['message']),
      );
}

/// A tenant account as the landlord sees it (with the active lease, if any).
class TenantRecord {
  TenantRecord({
    required this.id,
    required this.fullName,
    required this.email,
    required this.status,
    this.contactNumber,
    this.lease,
  });

  final int id;
  final String fullName;
  final String email;

  /// pending (waiting for approval), active, or archived.
  final String status;
  final String? contactNumber;
  final Lease? lease;

  factory TenantRecord.fromJson(Map<String, dynamic> j) {
    final leases = asList(j['leases']);
    return TenantRecord(
      id: _int(j['id']),
      fullName: _str(j['fullName']),
      email: _str(j['email']),
      status: _str(j['status']),
      contactNumber: _optStr(j['contactNumber']),
      lease: leases.isEmpty ? null : Lease.fromJson(asMap(leases.first)),
    );
  }
}

/// A message left by a visitor through the AI chatbox.
class Inquiry {
  Inquiry({
    required this.id,
    required this.name,
    required this.contactNumber,
    required this.status,
    required this.createdAt,
    this.message,
  });

  final int id;
  final String name;
  final String contactNumber;

  /// new or contacted.
  final String status;
  final String createdAt;
  final String? message;

  factory Inquiry.fromJson(Map<String, dynamic> j) => Inquiry(
        id: _int(j['id']),
        name: _str(j['name']),
        contactNumber: _str(j['contactNumber']),
        status: _str(j['status'], 'new'),
        createdAt: _str(j['createdAt']),
        message: _optStr(j['message']),
      );
}

/// The public information about the dormitory (the visitor chat reads it too).
class DormInfo {
  DormInfo({
    required this.dormName,
    required this.address,
    required this.contactNumber,
    required this.about,
    required this.houseRules,
    required this.requirements,
  });

  final String dormName;
  final String address;
  final String contactNumber;
  final String about;
  final String houseRules;
  final String requirements;

  factory DormInfo.fromJson(Map<String, dynamic> j) => DormInfo(
        dormName: _str(j['dormName']),
        address: _str(j['address']),
        contactNumber: _str(j['contactNumber']),
        about: _str(j['about']),
        houseRules: _str(j['houseRules']),
        requirements: _str(j['requirements']),
      );
}

/// GET /api/reports/monthly (json): totals and one row per bill.
class MonthlyReport {
  MonthlyReport({
    required this.month,
    required this.billed,
    required this.collected,
    required this.outstanding,
    required this.rows,
  });

  final String month;
  final double billed;
  final double collected;
  final double outstanding;
  final List<Bill> rows;

  factory MonthlyReport.fromJson(Map<String, dynamic> j) {
    final totals = asMap(j['totals'] ?? <String, dynamic>{});
    return MonthlyReport(
      month: _str(j['month']),
      billed: _num(totals['billed']),
      collected: _num(totals['collected']),
      outstanding: _num(totals['outstanding']),
      rows: asList(j['rows']).map((e) => Bill.fromJson(asMap(e))).toList(),
    );
  }
}
