import 'package:flutter_test/flutter_test.dart';
import 'package:git_inside/utils/format.dart';

void main() {
  group('peso', () {
    test('formats whole amounts', () {
      expect(peso(3500), '\u20b13,500.00');
    });
    test('formats large amounts with decimals', () {
      expect(peso(1234567.5), '\u20b11,234,567.50');
    });
    test('formats negative amounts', () {
      expect(peso(-50), '-\u20b150.00');
    });
    test('formats zero', () {
      expect(peso(0), '\u20b10.00');
    });
  });

  group('dates', () {
    test('formatDate reads a plain date', () {
      expect(formatDate('2026-10-05'), 'Oct 5, 2026');
    });
    test('formatDate shows a dash when empty', () {
      expect(formatDate(null), '-');
      expect(formatDate(''), '-');
    });
    test('formatDate returns unreadable text unchanged', () {
      expect(formatDate('not a date'), 'not a date');
    });
    test('formatDateTime shows 12-hour time', () {
      expect(formatDateTime('2026-10-05T15:07:00'), 'Oct 5, 2026 3:07 PM');
      expect(formatDateTime('2026-10-05T00:05:00'), 'Oct 5, 2026 12:05 AM');
      expect(formatDateTime(null), '-');
    });
    test('monthLabel', () {
      expect(monthLabel('2026-11'), 'November 2026');
      expect(monthLabel('bad'), 'bad');
      expect(monthLabel('2026-13'), '2026-13');
    });
    test('periodOf pads the month', () {
      expect(periodOf(DateTime(2026, 3, 9)), '2026-03');
      expect(periodOf(DateTime(2026, 12, 31)), '2026-12');
    });
  });

  group('text helpers', () {
    test('titleCase', () {
      expect(titleCase('in_progress'), 'In Progress');
      expect(titleCase('plumbing'), 'Plumbing');
      expect(titleCase(null), '-');
    });
    test('statusLabel', () {
      expect(statusLabel('pending_confirmation'), 'Awaiting confirmation');
      expect(statusLabel('overdue'), 'Overdue');
    });
    test('firstName', () {
      expect(firstName('Ana Reyes'), 'Ana');
      expect(firstName('  Ben  '), 'Ben');
    });
    test('isValidEmail', () {
      expect(isValidEmail('ana@gitinside.test'), true);
      expect(isValidEmail(' ana@gitinside.test '), true);
      expect(isValidEmail('ana@'), false);
      expect(isValidEmail('ana gitinside.test'), false);
      expect(isValidEmail(''), false);
    });
  });
}
