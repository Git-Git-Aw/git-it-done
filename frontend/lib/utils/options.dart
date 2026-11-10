import 'package:flutter/material.dart';

/// Values the backend accepts for maintenance reports.
const List<String> maintenanceCategories = [
  'plumbing',
  'electrical',
  'furniture',
  'appliance',
  'cleaning',
  'other',
];

const List<String> urgencyLevels = ['low', 'medium', 'high'];

const List<String> maintenanceStatuses = ['Pending', 'In Progress', 'Resolved'];

/// How a tenant paid (payments are recorded manually, with a receipt photo).
const List<String> paymentMethods = ['Cash', 'GCash', 'Maya', 'Bank transfer', 'Other'];

/// A simple icon for each way of paying (the real brand logos are not used).
IconData paymentMethodIcon(String method) {
  switch (method) {
    case 'Cash':
      return Icons.payments_outlined;
    case 'GCash':
    case 'Maya':
      return Icons.phone_android_outlined;
    case 'Bank transfer':
      return Icons.account_balance_outlined;
    default:
      return Icons.more_horiz;
  }
}

IconData categoryIcon(String category) {
  switch (category) {
    case 'plumbing':
      return Icons.water_drop_outlined;
    case 'electrical':
      return Icons.bolt_outlined;
    case 'furniture':
      return Icons.chair_outlined;
    case 'appliance':
      return Icons.kitchen_outlined;
    case 'cleaning':
      return Icons.cleaning_services_outlined;
    default:
      return Icons.build_outlined;
  }
}

