import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayhunter_mobile/app/wayhunter_app.dart';

void main() {
  testWidgets('home can select a module and updates the second tab', (
    tester,
  ) async {
    await tester.pumpWidget(const WayhunterApp());
    expect(find.text('Choose a module'), findsOneWidget);
    await tester.tap(find.text('Location Hunter').first);
    await tester.pumpAndSettle();
    expect(find.text('Add New Place'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });
}
