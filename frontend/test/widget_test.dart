import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:git_inside/widgets/common.dart';

void main() {
  testWidgets('StatusChip shows a readable label', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: StatusChip('pending_confirmation')),
      ),
    );
    expect(find.text('Awaiting confirmation'), findsOneWidget);
  });

  testWidgets('EmptyState shows its message', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EmptyState(icon: Icons.inbox, message: 'Nothing here yet.'),
        ),
      ),
    );
    expect(find.text('Nothing here yet.'), findsOneWidget);
  });
}
