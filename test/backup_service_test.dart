import 'package:filamentmanager_mobile_app/data/backup_service.dart';
import 'package:filamentmanager_mobile_app/models/filament_slot.dart';
import 'package:filamentmanager_mobile_app/models/printer_record.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('backup round-trip preserves printers and filament positions', () {
    final printers = [
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
            tagUid: 'E0040108662F6FBC',
            tagInstanceId: 'bf63e92d-9ca5-53d7-9fab-ffdd0240c585',
            tagBrand: 'Prusament',
            tagFullWeightGrams: 1012,
            tagLastReadAt: DateTime.utc(2026, 8, 26, 10, 30),
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
    expect(decoded.single.slots.first.tagUid, 'E0040108662F6FBC');
    expect(decoded.single.slots.first.tagBrand, 'Prusament');
    expect(decoded.single.slots.first.tagFullWeightGrams, 1012);
    expect(
      decoded.single.slots.first.tagLastReadAt,
      DateTime.utc(2026, 8, 26, 10, 30),
    );
    expect(decoded.single.slots.last.colorValue, 0xFFFFFFFF);
  });

  test('invalid backup is rejected', () {
    expect(
      () => BackupService().decode('{"printers":[]}'),
      throwsFormatException,
    );
  });

  test('schema version 1 backup remains importable', () {
    const source = '''
{"format":"filamentmanager-backup","schemaVersion":1,"printers":[{"name":"MK4-1","filaments":[{"position":1,"material":"PLA","colorName":"Black","colorValue":4279703319,"remainingGrams":500}]}]}
''';
    final decoded = BackupService().decode(source);

    expect(decoded.single.name, 'MK4-1');
    expect(decoded.single.slots.single.remainingGrams, 500);
    expect(decoded.single.slots.single.tagUid, isNull);
  });
}
