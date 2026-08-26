import 'package:filamentmanager_mobile_app/app_controller.dart';
import 'package:filamentmanager_mobile_app/data/memory_printer_repository.dart';
import 'package:filamentmanager_mobile_app/models/printer_record.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('supports natural alphabetical and persisted custom order', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = MemoryPrinterRepository(const [
      PrinterRecord(id: 1, name: 'MK4-10', slots: []),
      PrinterRecord(id: 2, name: 'MK4-2', slots: []),
      PrinterRecord(id: 3, name: 'MK4-1', slots: []),
    ]);
    final controller = AppController(repository: repository);
    await controller.initialize();

    expect(controller.printers.map((printer) => printer.name), [
      'MK4-1',
      'MK4-2',
      'MK4-10',
    ]);

    await controller.setPrinterSortMode(PrinterSortMode.alphabeticalDescending);
    expect(controller.printers.map((printer) => printer.name), [
      'MK4-10',
      'MK4-2',
      'MK4-1',
    ]);

    await controller.setPrinterSortMode(PrinterSortMode.custom);
    await controller.reorderPrinters(0, 2);
    expect(controller.printers.map((printer) => printer.name), [
      'MK4-2',
      'MK4-1',
      'MK4-10',
    ]);

    final restored = AppController(repository: repository);
    await restored.initialize();
    expect(restored.printerSortMode, PrinterSortMode.custom);
    expect(restored.printers.map((printer) => printer.name), [
      'MK4-2',
      'MK4-1',
      'MK4-10',
    ]);
  });
}
