import 'package:filamentmanager_mobile_app/data/backup_service.dart';
import 'package:filamentmanager_mobile_app/models/filament_slot.dart';
import 'package:filamentmanager_mobile_app/models/printer_record.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('backup round-trip preserves printers and filament positions', () {
    const printers = [
      PrinterRecord(
        id: 42,
        name: 'XL-1',
        slots: [
          FilamentSlot(
            id: 10,
            position: 1,
            material: 'PLA',
            colorName: 'Black',
            colorValue: 0xFF171717,
            remainingGrams: 512.5,
          ),
          FilamentSlot(
            id: 11,
            position: 2,
            material: 'PETG',
            colorName: 'White',
            colorValue: 0xFFFFFFFF,
            remainingGrams: 800,
          ),
        ],
      ),
    ];

    final service = BackupService();
    final decoded = service.decode(
      service.encode(printers, createdAt: DateTime.utc(2026, 8, 25)),
    );

    expect(decoded, hasLength(1));
    expect(decoded.single.name, 'XL-1');
    expect(decoded.single.id, isNull);
    expect(decoded.single.slots, hasLength(2));
    expect(decoded.single.slots.first.material, 'PLA');
    expect(decoded.single.slots.first.remainingGrams, 512.5);
    expect(decoded.single.slots.last.colorValue, 0xFFFFFFFF);
  });

  test('invalid backup is rejected', () {
    expect(
      () => BackupService().decode('{"printers":[]}'),
      throwsFormatException,
    );
  });
}
