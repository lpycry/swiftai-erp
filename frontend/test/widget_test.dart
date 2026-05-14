import 'package:flutter_test/flutter_test.dart';

import 'package:swiftai_erp/app.dart';

void main() {
  testWidgets('App renders login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const SwiftAIERPApp());

    // Verify login screen is shown by default
    expect(find.text('SwiftAI ERP'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });
}
