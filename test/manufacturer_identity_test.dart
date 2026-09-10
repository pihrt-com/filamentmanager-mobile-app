import 'package:filamentmanager_mobile_app/models/filament_slot.dart';
import 'package:filamentmanager_mobile_app/sync/manufacturer_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const slot = FilamentSlot(
    position: 1, material: 'PLA', colorName: 'Black',
    colorValue: 0xFF000000, remainingGrams: 1000, manufacturer: ' ColorFil ',
  );
  test('reuses cached manufacturer UUID and version', () {
    final result = reuseManufacturerIdentities([slot], [
      {'name': 'colorfil', 'id': 'server-id', 'version': '7'},
    ], () => throw StateError('Must not allocate an ID'));
    expect(result.single.serverManufacturerId, 'server-id');
    expect(result.single.serverManufacturerVersion, 7);
  });
  test('two offline spools share a newly allocated manufacturer', () {
    var calls = 0;
    final result = reuseManufacturerIdentities([slot, slot], [], () => 'id-${++calls}');
    expect(calls, 1);
    expect(result[0].serverManufacturerId, result[1].serverManufacturerId);
  });
  test('keeps selected physical spool and manufacturer identities', () {
    final selected = slot.copyWith(
      serverManufacturerId: 'selected', serverManufacturerVersion: 3,
      serverMaterialId: 'material', serverSpoolId: 'physical-spool',
    );
    final result = reuseManufacturerIdentities([selected], [
      {'name': 'ColorFil', 'id': 'different-id', 'version': 9},
    ], () => throw StateError('Must not allocate an ID'));
    expect(identical(result.single, selected), isTrue);
  });
  test('server identity takes precedence over a pending legacy duplicate', () {
    final result = reuseManufacturerIdentities([slot], [
      {'name': 'ColorFil', 'id': 'server', 'version': 2},
      {'name': 'ColorFil', 'id': 'pending', 'version': 0},
    ], () => 'unused');
    expect(result.single.serverManufacturerId, 'server');
  });
}
