import 'package:flutter_test/flutter_test.dart';
import 'package:git_inside/models/models.dart';

void main() {
  test('AppUser reads the login response', () {
    final user = AppUser.fromJson({
      'id': 2,
      'fullName': 'Ana Reyes',
      'email': 'ana@gitinside.test',
      'role': 'tenant',
      'status': 'active',
      'contactNumber': null,
    });
    expect(user.isTenant, true);
    expect(user.isLandlord, false);
    expect(user.contactNumber, null);
  });

  test('TenantDashboard reads the backend JSON', () {
    final room = {
      'id': 1,
      'roomNumber': '101',
      'description': 'Single room',
      'monthlyRate': 3500,
      'capacity': 1,
    };
    final dash = TenantDashboard.fromJson({
      'balance': 3500,
      'lease': {
        'id': 1,
        'startDate': '2026-09-01',
        'endDate': null,
        'monthlyRent': 3500,
        'dueDay': 5,
        'room': room,
      },
      'room': room,
      'nextDue': {
        'id': 9,
        'period': '2026-10',
        'dueDate': '2026-10-05',
        'amountDue': 3500,
        'amountPaid': 0,
        'balance': 3500,
        'status': 'unpaid',
        'displayStatus': 'overdue',
      },
      'announcements': [
        {
          'id': 1,
          'title': 'Water interruption',
          'body': 'No water on Saturday morning.',
          'pinned': true,
          'createdAt': '2026-10-01T00:00:00.000Z',
          'author': {'id': 1, 'fullName': 'Landlord'},
        },
      ],
      'unreadNotifications': 2,
    });
    expect(dash.balance, 3500);
    expect(dash.room!.roomNumber, '101');
    expect(dash.lease!.dueDay, 5);
    expect(dash.lease!.endDate, null);
    expect(dash.nextDue!.displayStatus, 'overdue');
    expect(dash.announcements.single.pinned, true);
    expect(dash.announcements.single.authorName, 'Landlord');
    expect(dash.unreadNotifications, 2);
  });

  test('TenantDashboard works when there is no lease or bill', () {
    final dash = TenantDashboard.fromJson({
      'balance': 0,
      'lease': null,
      'room': null,
      'nextDue': null,
      'announcements': [],
      'unreadNotifications': 0,
    });
    expect(dash.lease, null);
    expect(dash.room, null);
    expect(dash.nextDue, null);
    expect(dash.announcements, isEmpty);
  });

  test('LandlordSummary reads the backend JSON', () {
    final summary = LandlordSummary.fromJson({
      'period': '2026-10',
      'totalCollections': 3500,
      'outstandingBalance': 7000,
      'occupancy': {
        'rate': 75,
        'occupiedSlots': 3,
        'totalCapacity': 4,
        'totalRooms': 4,
        'occupiedRooms': 3,
        'vacantRooms': 1,
      },
      'tenantsByPayment': {'paid': 1, 'pendingConfirmation': 0, 'unpaid': 1, 'overdue': 1},
      'maintenance': {
        'openCount': 1,
        'roomsNeedingMaintenance': [
          {'id': 2, 'roomNumber': '102'},
        ],
        'recent': [
          {
            'id': 5,
            'category': 'plumbing',
            'urgency': 'high',
            'status': 'Pending',
            'description': 'Leaking faucet',
            'createdAt': '2026-10-02T01:00:00.000Z',
            'room': {'id': 2, 'roomNumber': '102'},
          },
        ],
      },
    });
    expect(summary.occupancyRate, 75);
    expect(summary.vacantRooms, 1);
    expect(summary.overdue, 1);
    expect(summary.totalCollections, 3500);
    expect(summary.roomsNeedingMaintenance, ['102']);
    expect(summary.recentReports.first.roomNumber, '102');
    expect(summary.recentReports.first.urgency, 'high');
  });

  test('NotificationsResult reads unread count and items', () {
    final result = NotificationsResult.fromJson({
      'unread': 1,
      'items': [
        {
          'id': 3,
          'type': 'due_reminder',
          'message': 'Your payment for 2026-10 is due on 2026-10-05.',
          'isRead': false,
          'createdAt': '2026-10-02T01:00:00.000Z',
        },
        {
          'id': 2,
          'type': 'announcement',
          'message': 'New announcement: Water interruption',
          'isRead': true,
          'createdAt': '2026-10-01T01:00:00.000Z',
        },
      ],
    });
    expect(result.unread, 1);
    expect(result.items.length, 2);
    expect(result.items.first.isRead, false);
    expect(result.items.last.isRead, true);
  });
}
