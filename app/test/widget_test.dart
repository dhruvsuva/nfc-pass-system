// This is a basic Flutter widget test for the NFC Pass App.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/app.dart';

void main() {
  testWidgets('NFC Pass App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const NFCPassApp());

    // Verify that the splash screen is shown initially.
    expect(find.text('NFC Pass Manager'), findsOneWidget);
    expect(find.text('Initializing...'), findsOneWidget);
  });
}
