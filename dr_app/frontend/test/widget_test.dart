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
}
