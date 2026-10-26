import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qr_code_generator/main.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> openApp(WidgetTester tester) async {
    await tester.pumpWidget(const QRGeneratorApp());
    await tester.pumpAndSettle();
  }

  testWidgets('1. QR Generator screen displays correctly', (tester) async {
    await openApp(tester);

    expect(find.text('QR Generator'), findsOneWidget);
    expect(find.text('Create Your QR Code'), findsOneWidget);
    expect(find.text('Generate QR Code'), findsOneWidget);
    expect(find.text('Your content'), findsOneWidget);
  });

  testWidgets('2. Input hint and introductory text are visible',
      (tester) async {
    await openApp(tester);

    expect(
      find.text('Turn text or a website into a QR code.'),
      findsOneWidget,
    );
    expect(find.text('Enter text or https://example.com'), findsOneWidget);
  });

  testWidgets('3. Empty input displays validation message', (tester) async {
    await openApp(tester);

    await tester.tap(find.text('Generate QR Code'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter text or a URL.'), findsOneWidget);
  });

  testWidgets('4. Whitespace-only input is rejected', (tester) async {
    await openApp(tester);

    await tester.enterText(find.byType(TextField), '     ');
    await tester.tap(find.text('Generate QR Code'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter text or a URL.'), findsOneWidget);
    expect(find.text('Your QR Code'), findsNothing);
  });

  testWidgets('5. Valid text generates a QR code', (tester) async {
    await openApp(tester);

    await tester.enterText(find.byType(TextField), 'Hello QR Generator');
    await tester.tap(find.text('Generate QR Code'));
    await tester.pumpAndSettle();

    expect(find.text('Your QR Code'), findsOneWidget);
    expect(find.text('Hello QR Generator'), findsNWidgets(2));
    expect(find.text('Copy Text'), findsOneWidget);
  });

  testWidgets('6. Leading and trailing spaces are trimmed', (tester) async {
    await openApp(tester);

    await tester.enterText(find.byType(TextField), '  Hello QR  ');
    await tester.tap(find.text('Generate QR Code'));
    await tester.pumpAndSettle();

    expect(find.text('Your QR Code'), findsOneWidget);
    expect(find.text('Hello QR'), findsOneWidget);
  });

  testWidgets('7. Valid HTTPS URL generates a QR code', (tester) async {
    await openApp(tester);

    await tester.enterText(
      find.byType(TextField),
      'https://example.com',
    );
    await tester.tap(find.text('Generate QR Code'));
    await tester.pumpAndSettle();

    expect(find.text('Your QR Code'), findsOneWidget);
    expect(find.text('https://example.com'), findsNWidgets(2));
  });

  testWidgets('8. Invalid HTTP URL displays validation message',
      (tester) async {
    await openApp(tester);

    await tester.enterText(find.byType(TextField), 'https://');
    await tester.tap(find.text('Generate QR Code'));
    await tester.pumpAndSettle();

    expect(
      find.text('Please enter a valid HTTP or HTTPS URL.'),
      findsOneWidget,
    );
    expect(find.text('Your QR Code'), findsNothing);
  });

  testWidgets('9. Editing input clears the validation message',
      (tester) async {
    await openApp(tester);

    await tester.tap(find.text('Generate QR Code'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter text or a URL.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Valid text');
    await tester.pumpAndSettle();

    expect(find.text('Please enter text or a URL.'), findsNothing);
  });

  testWidgets('10. Clear button resets input and generated QR code',
      (tester) async {
    await openApp(tester);

    await tester.enterText(find.byType(TextField), 'Clear me');
    await tester.tap(find.text('Generate QR Code'));
    await tester.pumpAndSettle();

    expect(find.text('Your QR Code'), findsOneWidget);

    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();

    expect(find.text('Your QR Code'), findsNothing);
    expect(find.text('Clear me'), findsNothing);
    expect(find.text('Your content'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty);
  });

  testWidgets('11. Generated content appears in recent history',
      (tester) async {
    await openApp(tester);

    await tester.enterText(find.byType(TextField), 'History item');
    await tester.tap(find.text('Generate QR Code'));
    await tester.pumpAndSettle();

    await tester.drag(
      find.byType(ListView).first,
      const Offset(0, -1000),
    );
    await tester.pumpAndSettle();

    expect(find.text('Recent QR History'), findsOneWidget);
    expect(find.byType(ListTile), findsOneWidget);
    expect(find.text('History item'), findsNWidgets(2));
  });
  testWidgets('12. Tapping a history item restores its QR code',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'qr_history': ['https://example.com'],
    });

    await openApp(tester);
    await tester.drag(find.byType(ListView).first, const Offset(0, -1000));
    await tester.pumpAndSettle();

    expect(find.text('Recent QR History'), findsOneWidget);

    await tester.tap(find.byType(ListTile).first);
    await tester.pumpAndSettle();

    expect(find.text('Your QR Code'), findsOneWidget);
    expect(find.text('https://example.com'), findsNWidgets(2));
  });

  testWidgets('13. Remove button deletes an item from history',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'qr_history': ['Remove this item'],
    });

    await openApp(tester);
    await tester.drag(find.byType(ListView).first, const Offset(0, -1000));
    await tester.pumpAndSettle();

    expect(find.byType(ListTile), findsOneWidget);

    await tester.tap(find.byTooltip('Remove from history'));
    await tester.pumpAndSettle();

    expect(find.byType(ListTile), findsNothing);
    expect(find.text('Recent QR History'), findsNothing);
  });

  testWidgets('14. Clear history removes all saved history items',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'qr_history': ['First item', 'Second item'],
    });

    await openApp(tester);
    await tester.drag(find.byType(ListView).first, const Offset(0, -1000));
    await tester.pumpAndSettle();

    expect(find.byType(ListTile), findsNWidgets(2));

    await tester.tap(find.text('Clear history'));
    await tester.pumpAndSettle();

    expect(find.byType(ListTile), findsNothing);
    expect(find.text('Recent QR History'), findsNothing);
  });

  testWidgets('15. Repeated generation does not duplicate history entries',
      (tester) async {
    await openApp(tester);

    await tester.enterText(find.byType(TextField), 'Repeated item');
    await tester.tap(find.text('Generate QR Code'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Repeated item');
    await tester.tap(find.text('Generate QR Code'));
    await tester.pumpAndSettle();

    await tester.drag(
      find.byType(ListView).first,
      const Offset(0, -1000),
    );
    await tester.pumpAndSettle();

    expect(find.text('Recent QR History'), findsOneWidget);
    expect(find.byType(ListTile), findsOneWidget);
    expect(find.text('Repeated item'), findsNWidgets(2));
  });
}














