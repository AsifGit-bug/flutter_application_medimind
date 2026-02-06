import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_medimind/pages/auth/welcome_page.dart';

void main() {
  testWidgets('Welcome page smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MaterialApp(home: WelcomePage()));

    // Verify that the welcome screen shows the app name.
    expect(find.text('MediMind'), findsOneWidget);
    expect(find.text('Welcome To'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
    expect(find.text('Register'), findsOneWidget);
  });
}
