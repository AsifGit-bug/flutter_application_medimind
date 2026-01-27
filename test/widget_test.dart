import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_medimind/pages/auth/splash_page.dart';

void main() {
  testWidgets('Splash screen smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MaterialApp(home: SplashPage()));

    // Verify that the splash screen shows the app name.
    expect(find.text('MediMind'), findsOneWidget);
    expect(find.byIcon(Icons.medical_services_rounded), findsOneWidget);
  });
}
