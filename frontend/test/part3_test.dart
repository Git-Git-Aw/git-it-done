import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:git_inside/api/api_client.dart';
import 'package:git_inside/data/local_cache.dart';
import 'package:git_inside/data/sync_service.dart';
import 'package:git_inside/models/models.dart';
import 'package:git_inside/utils/format.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('Part 3 models', () {
    test('Room reads leases, occupants, occupancy status and tenant names', () {
      final room = Room.fromJson({
        'id': 1,
        'roomNumber': '101',
        'description': 'Near the stairs',
        'monthlyRate': '3500.00',
        'capacity': 2,
        'isArchived': false,
        'occupants': 2,
        'occupancyStatus': 'full',
        'leases': [
          {
            'id': 1,
            'tenant': {'id': 2, 'fullName': 'Ana Reyes'},
          },
          {
            'id': 2,
            'tenant': {'id': 3, 'fullName': 'Ben Cruz'},
          },
        ],
      });
      expect(room.monthlyRate, 3500.0);
      expect(room.capacity, 2);
      expect(room.occupants, 2);
      expect(room.occupancyStatus, 'full');
      expect(room.isArchived, false);
      expect(room.occupantNames, ['Ana Reyes', 'Ben Cruz']);
    });

    test('Room without leases has no tenant names', () {
      final room = Room.fromJson({
        'id': 2,
        'roomNumber': '102',
        'monthlyRate': 3000,
        'capacity': 1,
        'isArchived': 1,
      });
      expect(room.occupantNames, isEmpty);
      expect(room.occupants, 0);
      expect(room.isArchived, true);
    });

    test('TenantRecord with an active lease', () {
      final tenant = TenantRecord.fromJson({
        'id': 2,
        'fullName': 'Ana Reyes',
        'email': 'ana@gitinside.test',
        'status': 'active',
        'contactNumber': '09171234567',
        'leases': [
          {
            'id': 7,
            'startDate': '2026-09-01',
            'endDate': null,
            'monthlyRent': '3500.00',
            'dueDay': 5,
            'room': {'id': 1, 'roomNumber': '101'},
          },
        ],
      });
      expect(tenant.status, 'active');
      expect(tenant.contactNumber, '09171234567');
      final lease = tenant.lease;
      expect(lease, isNotNull);
      expect(lease!.id, 7);
      expect(lease.endDate, null);
      expect(lease.dueDay, 5);
      expect(lease.room?.roomNumber, '101');
    });

    test('TenantRecord without a lease', () {
      final tenant = TenantRecord.fromJson({
        'id': 5,
        'fullName': 'Pending Person',
        'email': 'pending@gitinside.test',
        'status': 'pending',
      });
      expect(tenant.lease, null);
      expect(tenant.contactNumber, null);
      expect(tenant.status, 'pending');
    });

    test('Inquiry reads name, number and status', () {
      final inquiry = Inquiry.fromJson({
        'id': 1,
        'name': 'Maria',
        'contactNumber': '09181112222',
        'status': 'contacted',
        'createdAt': '2026-10-20T08:00:00.000Z',
        'message': 'Is there a free room?',
      });
      expect(inquiry.name, 'Maria');
      expect(inquiry.contactNumber, '09181112222');
      expect(inquiry.status, 'contacted');
      expect(inquiry.message, 'Is there a free room?');
    });

    test('Inquiry defaults to new and has no message when it is missing', () {
      final inquiry = Inquiry.fromJson({'id': 2, 'name': 'Joel', 'contactNumber': '0917'});
      expect(inquiry.status, 'new');
      expect(inquiry.message, null);
    });

    test('DormInfo reads every public field', () {
      final info = DormInfo.fromJson({
        'dormName': 'Git-Inside Dorm',
        'address': 'Maramag',
        'contactNumber': '0917',
        'about': 'Quiet dorm',
        'houseRules': 'No loud music',
        'requirements': 'Valid ID',
      });
      expect(info.dormName, 'Git-Inside Dorm');
      expect(info.houseRules, 'No loud music');
      expect(info.requirements, 'Valid ID');
    });

    test('MonthlyReport reads totals and bill rows', () {
      final report = MonthlyReport.fromJson({
        'month': '2026-10',
        'totals': {'billed': '7000.00', 'collected': 3500, 'outstanding': '3500.00'},
        'rows': [
          {
            'id': 1,
            'period': '2026-10',
            'dueDate': '2026-10-05',
            'amountDue': 3500,
            'amountPaid': 3500,
            'balance': 0,
            'status': 'paid',
            'displayStatus': 'paid',
            'lease': {
              'room': {'roomNumber': '101'},
            },
            'tenant': {'fullName': 'Ana Reyes'},
          },
          {
            'id': 2,
            'period': '2026-10',
            'dueDate': '2026-10-05',
            'amountDue': 3500,
            'amountPaid': 0,
            'balance': 3500,
            'status': 'unpaid',
            'displayStatus': 'overdue',
            'lease': {
              'room': {'roomNumber': '102'},
            },
            'tenant': {'fullName': 'Ben Cruz'},
          },
        ],
      });
      expect(report.billed, 7000.0);
      expect(report.collected, 3500.0);
      expect(report.outstanding, 3500.0);
      expect(report.rows.length, 2);
      expect(report.rows.first.tenantName, 'Ana Reyes');
      expect(report.rows.last.displayStatus, 'overdue');
      expect(report.rows.last.roomNumber, '102');
    });

    test('AppUser survives toJson and fromJson', () {
      final user = AppUser(
        id: 3,
        fullName: 'Carla Santos',
        email: 'carla@gitinside.test',
        role: 'tenant',
        status: 'active',
        contactNumber: '0917',
      );
      final copy = AppUser.fromJson(jsonDecode(jsonEncode(user.toJson())) as Map<String, dynamic>);
      expect(copy.id, 3);
      expect(copy.fullName, 'Carla Santos');
      expect(copy.email, 'carla@gitinside.test');
      expect(copy.role, 'tenant');
      expect(copy.status, 'active');
      expect(copy.contactNumber, '0917');
      expect(copy.isTenant, true);
    });

    test('Announcement reads isArchived', () {
      final archived = Announcement.fromJson({
        'id': 1,
        'title': 'Old',
        'body': 'Text',
        'pinned': 0,
        'isArchived': true,
        'createdAt': '2026-10-01T00:00:00.000Z',
      });
      final active = Announcement.fromJson({
        'id': 2,
        'title': 'New',
        'body': 'Text',
        'pinned': true,
        'createdAt': '2026-10-02T00:00:00.000Z',
      });
      expect(archived.isArchived, true);
      expect(archived.pinned, false);
      expect(active.isArchived, false);
      expect(active.pinned, true);
    });
  });

  group('Part 3 format helpers', () {
    test('plainNumber drops a useless .0', () {
      expect(plainNumber(3500), '3500');
      expect(plainNumber(3500.5), '3500.5');
    });

    test('isPeriodText accepts only YYYY-MM', () {
      expect(isPeriodText('2026-11'), true);
      expect(isPeriodText('2026-13'), false);
      expect(isPeriodText('2026-1'), false);
      expect(isPeriodText('November'), false);
    });
  });

  group('ApiClient offline cache', () {
    late bool serverDown;
    late ApiClient api;

    setUp(() {
      serverDown = false;
      final mock = MockClient((request) async {
        if (serverDown) throw http.ClientException('connection refused');
        return http.Response(
          jsonEncode({'items': [1, 2, 3]}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      api = ApiClient(client: mock)
        ..cache = MemoryCache()
        ..cacheScope = 'u1';
    });

    test('online GET returns data and is not offline', () async {
      final data = await api.get('/api/things');
      expect(asMap(data)['items'], [1, 2, 3]);
      expect(api.offlineSince.value, null);
    });

    test('offline GET returns the saved copy and sets offlineSince', () async {
      await api.get('/api/things');
      serverDown = true;
      final data = await api.get('/api/things');
      expect(asMap(data)['items'], [1, 2, 3]);
      expect(api.offlineSince.value, isNotNull);
    });

    test('offline GET of a path that was never saved throws ApiException', () async {
      serverDown = true;
      await expectLater(() => api.get('/api/never-saved'), throwsA(isA<ApiException>()));
    });

    test('a POST while offline fails and says the change was NOT saved', () async {
      serverDown = true;
      try {
        await api.post('/api/things', body: {'a': 1});
        fail('The POST should have thrown.');
      } on ApiException catch (e) {
        expect(e.message, contains('NOT saved'));
        expect(e.statusCode, null);
      }
    });

    test('offlineSince goes back to null when the server answers again', () async {
      await api.get('/api/things');
      serverDown = true;
      await api.get('/api/things');
      expect(api.offlineSince.value, isNotNull);
      serverDown = false;
      await api.get('/api/things');
      expect(api.offlineSince.value, null);
    });

    test('saved data of another account is not returned', () async {
      await api.get('/api/things');
      api.cacheScope = 'u2';
      serverDown = true;
      await expectLater(() => api.get('/api/things'), throwsA(isA<ApiException>()));
      api.cacheScope = 'u1';
      final data = await api.get('/api/things');
      expect(asMap(data)['items'], [1, 2, 3]);
    });

    test('clearScope removes only that account\'s saved data', () async {
      final cache = api.cache!;
      await api.get('/api/things');
      api.cacheScope = 'u2';
      await api.get('/api/things');
      await cache.clearScope('u1');
      serverDown = true;
      api.cacheScope = 'u1';
      await expectLater(() => api.get('/api/things'), throwsA(isA<ApiException>()));
      api.cacheScope = 'u2';
      final data = await api.get('/api/things');
      expect(asMap(data)['items'], [1, 2, 3]);
    });
  });

  group('SyncService', () {
    test('first sync counts changes and remembers the time', () async {
      final mock = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'serverTime': '2026-10-29T08:00:00.000Z',
            'payments': [
              {'id': 1},
            ],
            'maintenance': [],
            'announcements': [],
            'notifications': [],
            'rooms': [
              {'id': 1},
            ],
            'leases': [],
            'tenants': [],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final cache = MemoryCache();
      final api = ApiClient(client: mock)
        ..cache = cache
        ..cacheScope = 'u1';
      final sync = SyncService(api, cache);
      expect(sync.lastSyncText(), 'Never');
      final result = await sync.syncNow(isLandlord: true);
      expect(result.changed, 2);
      expect(sync.lastSyncText(), isNot('Never'));
    });
  });
}
