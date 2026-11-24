import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayhunter_mobile/app/wayhunter_module.dart';
import 'package:wayhunter_mobile/core/theme/wayhunter_theme.dart';
import 'package:wayhunter_mobile/core/widgets/wayhunter_surface.dart';
import 'package:wayhunter_mobile/features/home/presentation/views/home_screen.dart';

void main() {
  for (final (size, contentWidth) in [
    (const Size(320, 568), 280.0),
    (const Size(1280, 800), 560.0),
  ]) {
    testWidgets('Home renders module cards at ${size.width.toInt()} px', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final selections = <ModuleId>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: WayhunterTheme.light,
          home: Scaffold(body: HomeScreen(onSelectModule: selections.add)),
        ),
      );
      await tester.pumpAndSettle();

      final panel = find.byType(WayhunterSurfaceCard).first;
      expect(tester.getSize(panel).width, contentWidth);
      expect(tester.getCenter(panel).dx, size.width / 2);

      for (final module in ModuleId.values) {
        final tile = find.widgetWithText(ListTile, module.title);
        expect(tile, findsOneWidget);
        await tester.ensureVisible(tile);
        await tester.pumpAndSettle();
        expect(tile.hitTestable(), findsOneWidget);
        await tester.tap(tile);
        await tester.pumpAndSettle();
      }

      expect(selections, ModuleId.values);
      expect(tester.takeException(), isNull);
    });
  }
}
