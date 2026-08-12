import 'package:flutter_test/flutter_test.dart';
import 'package:flow_money/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const BudgetApp());
    expect(find.text('FlowMoney'), findsOneWidget);
  });
}
