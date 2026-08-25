import 'package:filamentmanager_mobile_app/app_controller.dart';
import 'package:filamentmanager_mobile_app/data/memory_printer_repository.dart';
import 'package:filamentmanager_mobile_app/models/printer_record.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'add import preserves existing printer and renames a collision',
    () async {
      final controller = AppController(
        repository: MemoryPrinterRepository(const [
          PrinterRecord(id: 1, name: 'MK4-1', slots: []),
        ]),
      );
      await controller.initialize();

      await controller.importPrinters(const [
        PrinterRecord(name: 'MK4-1', slots: []),
      ], ImportMode.add);

      expect(controller.printers.map((item) => item.name), [
        'MK4-1',
        'MK4-1 (2)',
      ]);
    },
  );

  test('replace import removes all previous printers', () async {
    final controller = AppController(
      repository: MemoryPrinterRepository(const [
        PrinterRecord(id: 1, name: 'Old printer', slots: []),
      ]),
    );
    await controller.initialize();

    await controller.importPrinters(const [
      PrinterRecord(name: 'XL-1', slots: []),
    ], ImportMode.replace);

    expect(controller.printers.map((item) => item.name), ['XL-1']);
  });
}
