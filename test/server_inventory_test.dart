import 'package:filamentmanager_mobile_app/models/server_inventory.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const materialId = '11111111-1111-4111-8111-111111111111';
  const spoolId = '22222222-2222-4222-8222-222222222222';

  Map<String, dynamic> snapshot({String status = 'in_stock'}) => {
    'manufacturers': [
      {
        'id': '33333333-3333-4333-8333-333333333333',
        'name': 'Prusament',
        'version': 2,
      },
    ],
    'materials': [
      {
        'id': materialId,
        'version': 4,
        'manufacturer_id': '33333333-3333-4333-8333-333333333333',
        'material_type': 'PETG',
        'commercial_name': 'Prusa Orange',
        'color_name': 'Orange',
        'color_hex': '#FF7A00',
        'diameter_mm': 1.75,
      },
    ],
    'locations': [
      {
        'id': '44444444-4444-4444-8444-444444444444',
        'name': 'Rack A',
        'code': 'A-01',
        'version': 3,
      },
    ],
    'spools': [
      {
        'id': spoolId,
        'version': 7,
        'material_id': materialId,
        'location_id': '44444444-4444-4444-8444-444444444444',
        'status': status,
        'current_net_weight_g': 642.5,
        'original_net_weight_g': 1000,
        'tare_weight_g': 201,
        'tag_uid': 'E004015023ABCD01',
        'openprinttag_id': 'OPT-42',
        'batch_number': 'B-9',
        'notes': 'Opened',
      },
    ],
  };

  test('decodes available server spool and shared material identities', () {
    final inventory = decodeServerInventory(snapshot());

    expect(inventory.materials, hasLength(1));
    expect(inventory.availableSpools, hasLength(1));
    expect(inventory.materials.single.id, materialId);
    expect(inventory.availableSpools.single.id, spoolId);
    expect(inventory.availableSpools.single.label, contains('Rack A'));
  });

  test('converts an existing spool into a slot without changing its IDs', () {
    final spool = decodeServerInventory(snapshot()).availableSpools.single;
    final slot = spool.toFilamentSlot(
      position: 2,
      localId: 17,
      serverSlotId: '55555555-5555-4555-8555-555555555555',
      serverSlotVersion: 6,
    );

    expect(slot.id, 17);
    expect(slot.position, 2);
    expect(slot.serverSpoolId, spoolId);
    expect(slot.serverSpoolVersion, 7);
    expect(slot.serverMaterialId, materialId);
    expect(slot.serverMaterialVersion, 4);
    expect(slot.serverSlotVersion, 6);
    expect(slot.material, 'PETG');
    expect(slot.remainingGrams, 642.5);
    expect(slot.storageLocation, 'Rack A');
  });

  test('does not offer a loaded spool as available inventory', () {
    final inventory = decodeServerInventory(snapshot(status: 'loaded'));

    expect(inventory.spools, hasLength(1));
    expect(inventory.availableSpools, isEmpty);
    expect(
      inventory.withSpoolStatus(spoolId, 'in_stock').availableSpools,
      hasLength(1),
    );
  });
}
