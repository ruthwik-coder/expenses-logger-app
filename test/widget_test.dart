import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:expenses_logger_app/main.dart';

void main() {
  testWidgets('Home screen renders quick buttons and total', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const App());
    await tester.pumpAndSettle();

    expect(find.text('Expense Log 🪵'), findsOneWidget);
    expect(find.text('Metro'), findsOneWidget);
    expect(find.text('Bus'), findsOneWidget);
    expect(find.text('Auto'), findsOneWidget);
    expect(find.text('Other Expense'), findsOneWidget);
    expect(find.text('TAP BUTTON TO LOG'), findsOneWidget);
  });
}