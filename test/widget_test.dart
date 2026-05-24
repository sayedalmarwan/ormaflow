import 'package:flutter_test/flutter_test.dart';

import 'package:orma_flow/main.dart';

void main() {
  testWidgets('App basic smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const OrmaFlowApp());

    // Verify that the title "Ormaflow" is displayed in the AppBar.
    expect(find.text('Ormaflow'), findsOneWidget);

    // Verify that the hero card with "Tasks for Today" is shown.
    expect(find.text('Tasks for Today'), findsOneWidget);
  });
}
