import '../models/filament_slot.dart';

List<FilamentSlot> reuseManufacturerIdentities(
  List<FilamentSlot> slots,
  Iterable<Map<String, dynamic>> manufacturers,
  String Function() newId,
) {
  final known = <String, Map<String, dynamic>>{};
  for (final row in manufacturers) {
    final name = row['name']?.toString().trim().toLowerCase();
    if (name != null && name.isNotEmpty && row['id'] != null) {
      known.putIfAbsent(name, () => row);
    }
  }
  for (final slot in slots) {
    final name = slot.manufacturer?.trim().toLowerCase();
    if (name != null && name.isNotEmpty && slot.serverManufacturerId != null) {
      known.putIfAbsent(name, () => {
        'id': slot.serverManufacturerId,
        'version': slot.serverManufacturerVersion,
      });
    }
  }
  return slots.map((slot) {
    final name = slot.manufacturer?.trim().toLowerCase();
    if (name == null || name.isEmpty || slot.serverManufacturerId != null) {
      return slot;
    }
    final manufacturer = known.putIfAbsent(name, () => {
      'id': newId(),
      'version': 0,
    });
    return slot.copyWith(
      serverManufacturerId: manufacturer['id'].toString(),
      serverManufacturerVersion:
          int.tryParse(manufacturer['version'].toString()) ?? 0,
    );
  }).toList();
}
