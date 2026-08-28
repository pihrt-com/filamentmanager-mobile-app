import 'package:filamentmanager_mobile_app/app_controller.dart';
import 'package:filamentmanager_mobile_app/data/memory_printer_repository.dart';
import 'package:filamentmanager_mobile_app/models/filament_slot.dart';
import 'package:filamentmanager_mobile_app/models/printer_record.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('unloading a spool keeps the printer and its other positions', () async {
    SharedPreferences.setMockInitialValues({});
    const first = FilamentSlot(
      id: 1,
      position: 1,
      material: 'PLA',
      colorName: 'Black',
      colorValue: 0xFF000000,
      remainingGrams: 500,
    );
    const second = FilamentSlot(
      id: 2,
      position: 2,
      material: 'PETG',
      colorName: 'White',
      colorValue: 0xFFFFFFFF,
      remainingGrams: 750,
    );
    final repository = MemoryPrinterRepository([
      const PrinterRecord(id: 1, name: 'XL-1', slots: [first, second]),
    ]);
    final controller = AppController(repository: repository);
    await controller.initialize();

    await controller.unloadSpool(controller.printers.single, second);

    expect(controller.printers, hasLength(1));
    expect(controller.printers.single.slots, [first]);
  });
}
