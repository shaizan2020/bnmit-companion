// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bnmit_companion/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: BNMITCompanionApp(),
      ),
    );

    // Verify that the app is created.
    expect(find.byType(BNMITCompanionApp), findsOneWidget);

    // Pump the timer to let the 2-second splash delay complete
    await tester.pump(const Duration(seconds: 3));
    // Pump again to allow GoRouter to perform the navigation and render the next screen
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  });
}
