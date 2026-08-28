import 'package:filamentmanager_mobile_app/app_controller.dart';
import 'package:filamentmanager_mobile_app/data/memory_printer_repository.dart';
import 'package:filamentmanager_mobile_app/main.dart';
import 'package:filamentmanager_mobile_app/models/filament_slot.dart';
import 'package:filamentmanager_mobile_app/models/printer_record.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('saved printer card is visible in portrait orientation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({'language': 'en'});
    final controller = AppController(
      repository: MemoryPrinterRepository([
        const PrinterRecord(
          id: 1,
          name: 'MK3-1',
          status: 'inactive',
          slots: [
            FilamentSlot(
              id: 1,
              position: 0,
              material: 'PLA',
              colorName: 'Black',
              colorValue: 0xFF202020,
              remainingGrams: 500,
            ),
            FilamentSlot(
              position: 2,
              material: 'PETG',
              colorName: 'White',
              colorValue: 0xFFFFFFFF,
              remainingGrams: 600,
            ),
            FilamentSlot(
              position: 3,
              material: 'ASA',
              colorName: 'Red',
              colorValue: 0xFFFF0000,
              remainingGrams: 700,
            ),
            FilamentSlot(
              position: 4,
              material: 'TPU',
              colorName: 'Blue',
              colorValue: 0xFF0000FF,
              remainingGrams: 800,
            ),
            FilamentSlot(
              position: 5,
              material: 'PVA',
              colorName: 'Natural',
              colorValue: 0xFFE8E0C8,
              remainingGrams: 900,
            ),
          ],
        ),
      ]),
    );
    await controller.initialize();

    await tester.pumpWidget(FilamentManagerApp(controller: controller));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('MK3-1'), findsOneWidget);
    expect(find.byType(RefreshIndicator), findsOneWidget);
    expect(find.text('PLA · Black'), findsOneWidget);
    expect(find.text('500 g'), findsOneWidget);
    expect(find.text('PVA · Natural'), findsOneWidget);
    expect(find.text('900 g'), findsOneWidget);
    expect(find.text('Out of service'), findsOneWidget);
    expect(find.text('+2'), findsNothing);
  });
}
