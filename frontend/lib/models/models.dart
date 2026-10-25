// Data classes that read the JSON returned by the Git-Inside backend.

Map<String, dynamic> asMap(dynamic value) => Map<String, dynamic>.from(value as Map);

List<dynamic> asList(dynamic value) => value is List ? value : <dynamic>[];

String _str(dynamic v, [String fallback = '']) => v == null ? fallback : v.toString();

double _num(dynamic v) => v is num ? v.toDouble() : (double.tryParse('${v ?? ''}') ?? 0);

int _int(dynamic v) => v is num ? v.toInt() : (int.tryParse('${v ?? ''}') ?? 0);

bool _bool(dynamic v) => v == true || v == 1;

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
  });

  final int id;
  final String roomNumber;
  final String description;
  final double monthlyRate;
  final int capacity;

  factory Room.fromJson(Map<String, dynamic> j) => Room(
        id: _int(j['id']),
        roomNumber: _str(j['roomNumber']),
        description: _str(j['description']),
        monthlyRate: _num(j['monthlyRate']),
        capacity: _int(j['capacity']),
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

  factory Bill.fromJson(Map<String, dynamic> j) => Bill(
        id: _int(j['id']),
        period: _str(j['period']),
        dueDate: _str(j['dueDate']),
        amountDue: _num(j['amountDue']),
        amountPaid: _num(j['amountPaid']),
        balance: _num(j['balance']),
        status: _str(j['status']),
        displayStatus: _str(j['displayStatus'], _str(j['status'])),
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
  });

  final int id;
  final String title;
  final String body;
  final bool pinned;
  final String createdAt;
  final String authorName;

  factory Announcement.fromJson(Map<String, dynamic> j) => Announcement(
        id: _int(j['id']),
        title: _str(j['title']),
        body: _str(j['body']),
        pinned: _bool(j['pinned']),
        createdAt: _str(j['createdAt']),
        authorName: j['author'] is Map ? _str(asMap(j['author'])['fullName']) : '',
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
