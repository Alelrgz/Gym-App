import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_app/main.dart';

void main() {
  testWidgets('App renders login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: GymApp()));
    await tester.pumpAndSettle();

    // Should show the login screen with "Accedi" button
    expect(find.text('Accedi'), findsWidgets);
  });
}
