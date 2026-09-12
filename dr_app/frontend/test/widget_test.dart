import 'package:flutter_test/flutter_test.dart';
import 'package:drishti/main.dart';

void main() {
  testWidgets('Drishti app loads the shell navigation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const DrishtiApp());

    expect(find.text('DRISHTI'), findsOneWidget);
    expect(find.text('Patients'), findsOneWidget);
    expect(find.text('Dashboard'), findsWidgets);
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
