import 'package:filamentmanager_mobile_app/app_controller.dart';
import 'package:filamentmanager_mobile_app/data/memory_printer_repository.dart';
import 'package:filamentmanager_mobile_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('first launch creates a multi-filament printer', (tester) async {
    SharedPreferences.setMockInitialValues({'language': 'en'});
    final controller = AppController(repository: MemoryPrinterRepository());
    await controller.initialize();

    await tester.pumpWidget(FilamentManagerApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('Add your first printer'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Printer name'),
      'XL-1',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Material'),
      'PL',
    );
    await tester.pumpAndSettle();
    expect(find.text('PLA'), findsOneWidget);
    await tester.tap(find.text('PLA'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Color'),
      'Black',
    );
    final addFilament = find.widgetWithText(
      OutlinedButton,
      'Add filament position',
    );
    await tester.drag(find.byType(ListView).first, const Offset(0, -260));
    await tester.pumpAndSettle();
    await tester.tap(addFilament);
    await tester.pump();

    final materialFields = find.widgetWithText(TextFormField, 'Material');
    final colorFields = find.widgetWithText(TextFormField, 'Color');
    await tester.enterText(materialFields.at(1), 'PETG');
    await tester.enterText(colorFields.at(1), 'White');
    final save = find.widgetWithText(FilledButton, 'Save');
    await tester.drag(find.byType(ListView).first, const Offset(0, -800));
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(find.text('XL-1'), findsOneWidget);
    expect(find.text('PLA · Black'), findsOneWidget);
    expect(find.text('PETG · White'), findsOneWidget);
    expect(controller.printers.single.slots, hasLength(2));
  });
}
