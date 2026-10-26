import 'package:flutter_test/flutter_test.dart';
import 'package:git_inside/models/models.dart';
import 'package:git_inside/utils/format.dart';

void main() {
  test('Bill reads the proof and the room from a tenant payment', () {
    final bill = Bill.fromJson({
      'id': 4,
      'period': '2026-10',
      'dueDate': '2026-10-05',
      'amountDue': 3500,
      'amountPaid': 0,
      'balance': 3500,
      'status': 'pending_confirmation',
      'displayStatus': 'pending_confirmation',
      'method': 'GCash',
      'proofPath': '/uploads/1700000000000-abc123.jpg',
      'paidAt': null,
      'remarks': null,
      'lease': {
        'id': 1,
        'room': {'id': 1, 'roomNumber': '101'},
      },
      'tenant': {'id': 2, 'fullName': 'Ana Reyes'},
    });
    expect(bill.status, 'pending_confirmation');
    expect(bill.method, 'GCash');
    expect(bill.proofPath, '/uploads/1700000000000-abc123.jpg');
    expect(bill.paidAt, null);
    expect(bill.remarks, null);
    expect(bill.roomNumber, '101');
    expect(bill.tenantName, 'Ana Reyes');
  });

  test('Bill still works when optional parts are missing', () {
    final bill = Bill.fromJson({
      'id': 5,
      'period': '2026-11',
      'dueDate': '2026-11-05',
      'amountDue': 3500,
      'amountPaid': 0,
      'balance': 3500,
      'status': 'unpaid',
    });
    expect(bill.displayStatus, 'unpaid');
    expect(bill.proofPath, null);
    expect(bill.roomNumber, '');
    expect(bill.tenantName, '');
  });

  test('MaintenanceReport reads a tenant report', () {
    final report = MaintenanceReport.fromJson({
      'id': 7,
      'category': 'plumbing',
      'urgency': 'high',
      'status': 'In Progress',
      'description': 'The faucet is leaking.',
      'photoPath': '/uploads/1700000000001-def456.png',
      'remarks': 'Plumber coming tomorrow',
      'assignedTo': 'Mang Tonyo',
      'resolvedAt': null,
      'createdAt': '2026-10-02T01:00:00.000Z',
      'room': {'id': 1, 'roomNumber': '101'},
      'tenant': {'id': 2, 'fullName': 'Ana Reyes', 'contactNumber': '0917'},
    });
    expect(report.roomNumber, '101');
    expect(report.tenantName, 'Ana Reyes');
    expect(report.urgency, 'high');
    expect(report.photoPath, '/uploads/1700000000001-def456.png');
    expect(report.assignedTo, 'Mang Tonyo');
    expect(report.resolvedAt, null);
  });

  test('ChatReply reads the reply and the proposed actions', () {
    final reply = ChatReply.fromJson({
      'role': 'tenant',
      'reply': 'Please review and confirm.',
      'pendingActions': [
        {
          'id': '3f9a6c1e-0000-4000-8000-000000000001',
          'tool': 'submit_maintenance_report',
          'summary': 'Submit a plumbing report (high urgency): faucet is leaking',
          'expiresAt': '2026-10-26T10:00:00.000Z',
        },
      ],
    });
    expect(reply.reply, 'Please review and confirm.');
    expect(reply.pendingActions.length, 1);
    expect(reply.pendingActions.single.tool, 'submit_maintenance_report');
  });

  test('ChatReply works with no proposed actions', () {
    final reply = ChatReply.fromJson({'role': 'visitor', 'reply': 'Hello!'});
    expect(reply.pendingActions, isEmpty);
  });

  test('ActionOutcome reads the confirm result', () {
    final outcome = ActionOutcome.fromJson({
      'status': 'executed',
      'message': 'Report #7 submitted.',
      'result': {'reportId': 7},
    });
    expect(outcome.status, 'executed');
    expect(outcome.message, 'Report #7 submitted.');
  });

  test('plainText removes simple Markdown marks', () {
    expect(plainText('**Hello** there'), 'Hello there');
    expect(plainText('## Summary\n- one\n* two'), 'Summary\n\u2022 one\n\u2022 two');
    expect(plainText('Plain text stays.'), 'Plain text stays.');
  });
}
