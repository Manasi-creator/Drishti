import 'package:flutter_test/flutter_test.dart';
import 'package:drishti/main.dart';
import 'package:drishti/screens/screening/new_screening_screen.dart';

void main() {
  testWidgets('Drishti app loads the shell navigation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const DrishtiApp());

    expect(find.text('DRISHTI'), findsOneWidget);
    expect(find.text('Patients'), findsOneWidget);
    expect(find.text('Dashboard'), findsWidgets);
  });

  testWidgets('New Screening action is available from the dashboard', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const DrishtiApp());

    expect(find.text('New Screening'), findsWidgets);
  });

  test('String-backed booleans from the backend are normalized safely', () {
    expect(parseBooleanFlag(true), isTrue);
    expect(parseBooleanFlag('true'), isTrue);
    expect(parseBooleanFlag('TRUE'), isTrue);
    expect(parseBooleanFlag('1'), isTrue);
    expect(parseBooleanFlag('false'), isFalse);
    expect(parseBooleanFlag('0'), isFalse);
    expect(parseBooleanFlag(null), isFalse);
  });

  testWidgets('Settings screen opens and shows sections', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const DrishtiApp());

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsWidgets);
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Screening Preferences'), findsOneWidget);
    expect(find.text('Report Preferences'), findsOneWidget);
  });
}
