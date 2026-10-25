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
