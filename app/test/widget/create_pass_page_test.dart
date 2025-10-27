import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../lib/features/pass/create_pass_page.dart';
import '../../lib/core/providers/nfc_provider.dart';
import '../../lib/core/nfc/nfc_service.dart';

void main() {
  group('CreatePassPage Widget Tests', () {
    late NFCProvider mockNfcProvider;
    
    setUp(() {
      mockNfcProvider = NFCProvider();
      
      // Mock the method channel for NFC
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.nfcpass.app/nfc'),
        (MethodCall methodCall) async {
          switch (methodCall.method) {
            case 'isNFCSupported':
              return true;
            case 'isNFCEnabled':
              return true;
            case 'startScan':
              return true;
            case 'stopScan':
              return null;
            default:
              return null;
          }
        },
      );
      
      // Mock the event channel for NFC events
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockStreamHandler(
        const EventChannel('com.nfcpass.app/nfc_events'),
        MockNFCStreamHandler(),
      );
    });
    
    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.nfcpass.app/nfc'),
        null,
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockStreamHandler(
        const EventChannel('com.nfcpass.app/nfc_events'),
        null,
      );
    });
    
    Widget createTestWidget() {
      return MaterialApp(
        home: Scaffold(
          body: CreatePassPage(),
        ),
      );
    }
    
    testWidgets('should display create pass form', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();
      
      // Check if main form elements are present
      expect(find.text('Create New Pass'), findsOneWidget);
      expect(find.byType(TextFormField), findsWidgets); // Multiple form fields
      expect(find.text('UID'), findsOneWidget);
      expect(find.text('Pass Type'), findsOneWidget);
      expect(find.text('Category'), findsOneWidget);
      expect(find.text('People Allowed'), findsOneWidget);
    });
    
    testWidgets('should have NFC scan button in UID field', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();
      
      // Find the UID text field
      final uidField = find.widgetWithText(TextFormField, 'UID');
      expect(uidField, findsOneWidget);
      
      // Check for NFC icon button
      expect(find.byIcon(Icons.nfc), findsOneWidget);
    });
    
    testWidgets('should show NFC scan dialog when scan button tapped', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();
      
      // Tap the NFC scan button
      await tester.tap(find.byIcon(Icons.nfc));
      await tester.pumpAndSettle();
      
      // Check if scan dialog appears
      expect(find.text('Scanning for NFC Tag'), findsOneWidget);
      expect(find.text('Hold your device near an NFC tag to scan its UID.'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });
    
    testWidgets('should close scan dialog when cancel tapped', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();
      
      // Open scan dialog
      await tester.tap(find.byIcon(Icons.nfc));
      await tester.pumpAndSettle();
      
      // Tap cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      
      // Dialog should be closed
      expect(find.text('Scanning for NFC Tag'), findsNothing);
    });
    
    testWidgets('should validate required fields', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();
      
      // Try to submit without filling required fields
      final createButton = find.text('Create Pass');
      expect(createButton, findsOneWidget);
      
      await tester.tap(createButton);
      await tester.pumpAndSettle();
      
      // Should show validation errors
      expect(find.text('Please enter a UID'), findsOneWidget);
    });
    
    testWidgets('should fill UID field when valid UID entered', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();
      
      // Find and fill the UID field
      final uidField = find.widgetWithText(TextFormField, 'UID');
      await tester.enterText(uidField, 'ABC123DEF456');
      await tester.pumpAndSettle();
      
      // Verify the text was entered
      expect(find.text('ABC123DEF456'), findsOneWidget);
    });
    
    testWidgets('should validate UID format', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();
      
      // Enter invalid UID (too short)
      final uidField = find.widgetWithText(TextFormField, 'UID');
      await tester.enterText(uidField, '123');
      
      // Fill other required fields
      final categoryField = find.widgetWithText(TextFormField, 'Category');
      await tester.enterText(categoryField, 'VIP');
      
      // Try to submit
      await tester.tap(find.text('Create Pass'));
      await tester.pumpAndSettle();
      
      // Should show UID validation error
      expect(find.textContaining('UID must be'), findsOneWidget);
    });
    
    testWidgets('should select pass type from dropdown', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();
      
      // Find and tap the pass type dropdown
      final passTypeDropdown = find.byType(DropdownButtonFormField<String>).first;
      await tester.tap(passTypeDropdown);
      await tester.pumpAndSettle();
      
      // Select 'seasonal' option
      await tester.tap(find.text('seasonal').last);
      await tester.pumpAndSettle();
      
      // Verify selection
      expect(find.text('seasonal'), findsOneWidget);
    });
    
    testWidgets('should validate people allowed field', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();
      
      // Find people allowed field and enter invalid value
      final peopleField = find.widgetWithText(TextFormField, 'People Allowed');
      await tester.enterText(peopleField, '0');
      
      // Fill required fields
      final uidField = find.widgetWithText(TextFormField, 'UID');
      await tester.enterText(uidField, 'ABC123DEF456');
      
      final categoryField = find.widgetWithText(TextFormField, 'Category');
      await tester.enterText(categoryField, 'VIP');
      
      // Try to submit
      await tester.tap(find.text('Create Pass'));
      await tester.pumpAndSettle();
      
      // Should show validation error
      expect(find.textContaining('must be at least 1'), findsOneWidget);
    });
    
    testWidgets('should show success message on valid form submission', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();
      
      // Fill all required fields with valid data
      final uidField = find.widgetWithText(TextFormField, 'UID');
      await tester.enterText(uidField, 'ABC123DEF456');
      
      final categoryField = find.widgetWithText(TextFormField, 'Category');
      await tester.enterText(categoryField, 'VIP');
      
      final peopleField = find.widgetWithText(TextFormField, 'People Allowed');
      await tester.enterText(peopleField, '2');
      
      // Submit the form
      await tester.tap(find.text('Create Pass'));
      await tester.pumpAndSettle();
      
      // Should show loading state first
      expect(find.text('Creating Pass...'), findsOneWidget);
    });
    
    testWidgets('should disable form during submission', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();
      
      // Fill required fields
      final uidField = find.widgetWithText(TextFormField, 'UID');
      await tester.enterText(uidField, 'ABC123DEF456');
      
      final categoryField = find.widgetWithText(TextFormField, 'Category');
      await tester.enterText(categoryField, 'VIP');
      
      // Submit the form
      await tester.tap(find.text('Create Pass'));
      await tester.pump(); // Don't settle to catch loading state
      
      // Form should be disabled during submission
      final createButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Creating Pass...'),
      );
      expect(createButton.onPressed, isNull);
    });
    
    testWidgets('should show NFC not supported message', (WidgetTester tester) async {
      // Mock NFC not supported
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.nfcpass.app/nfc'),
        (MethodCall methodCall) async {
          if (methodCall.method == 'isNFCSupported') {
            return false;
          }
          return true;
        },
      );
      
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();
      
      // Try to scan NFC
      await tester.tap(find.byIcon(Icons.nfc));
      await tester.pumpAndSettle();
      
      // Should show error message
      expect(find.textContaining('NFC is not supported'), findsOneWidget);
    });
  });
}

class MockNFCStreamHandler implements MockStreamHandler {
  @override
  void onCancel(Object? arguments) {
    // Mock implementation
  }
  
  @override
  void onListen(Object? arguments, MockStreamHandlerEventSink events) {
    // Mock implementation - simulate NFC events
    Future.delayed(const Duration(milliseconds: 100), () {
      // Simulate tag discovered event
      events.success({
        'type': 'tag_discovered',
        'data': {
          'uid': 'ABC123DEF456',
          'techList': ['NfcA'],
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        }
      });
    });
  }
}