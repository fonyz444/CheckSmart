import 'package:flutter_test/flutter_test.dart';
import 'package:checksmart/src/app.dart';

void main() {
  testWidgets('Dashboard screen renders', (WidgetTester tester) async {
    await tester.pumpWidget(const CheckSmartApp());
    expect(find.text('CheckSmart'), findsOneWidget);
  });
}
