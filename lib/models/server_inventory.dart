import 'filament_slot.dart';

class ServerMaterial {
  const ServerMaterial({
    required this.id,
    required this.version,
    required this.materialType,
    required this.colorName,
    required this.colorValue,
    required this.diameterMm,
    this.commercialName,
    this.manufacturerId,
    this.manufacturerVersion = 0,
    this.manufacturerName,
  });

  final String id;
  final int version;
  final String materialType;
  final String colorName;
  final int colorValue;
  final double diameterMm;
  final String? commercialName;
  final String? manufacturerId;
  final int manufacturerVersion;
  final String? manufacturerName;

  String get label => [
    if (manufacturerName?.isNotEmpty == true) manufacturerName!,
    materialType,
    colorName,
    if (commercialName?.isNotEmpty == true) commercialName!,
    '${diameterMm.toStringAsFixed(2)} mm',
  ].join(' · ');
}

class ServerSpool {
  const ServerSpool({
    required this.id,
    required this.version,
    required this.status,
    required this.material,
    required this.remainingGrams,
    this.originalWeightGrams,
    this.tareWeightGrams,
    this.purchaseDate,
    this.locationId,
    this.locationVersion = 0,
    this.locationName,
    this.locationCode,
    this.tagUid,
    this.openPrintTagId,
    this.batchNumber,
    this.notes,
  });

  final String id;
  final int version;
  final String status;
  final ServerMaterial material;
  final double remainingGrams;
  final double? originalWeightGrams;
  final double? tareWeightGrams;
  final DateTime? purchaseDate;
  final String? locationId;
  final int locationVersion;
  final String? locationName;
  final String? locationCode;
  final String? tagUid;
  final String? openPrintTagId;
  final String? batchNumber;
  final String? notes;

  bool get isAvailable => status == 'in_stock';

  ServerSpool withStatus(String value) => ServerSpool(
    id: id,
    version: version,
    status: value,
    material: material,
    remainingGrams: remainingGrams,
    originalWeightGrams: originalWeightGrams,
    tareWeightGrams: tareWeightGrams,
    purchaseDate: purchaseDate,
    locationId: locationId,
    locationVersion: locationVersion,
    locationName: locationName,
    locationCode: locationCode,
    tagUid: tagUid,
    openPrintTagId: openPrintTagId,
    batchNumber: batchNumber,
    notes: notes,
  );

  String get label => [
    material.label,
    '${_formatWeight(remainingGrams)} g',
    if (locationName?.isNotEmpty == true) locationName!,
    if (batchNumber?.isNotEmpty == true) 'Lot $batchNumber',
    '#${id.substring(0, id.length < 8 ? id.length : 8)}',
  ].join(' · ');

  FilamentSlot toFilamentSlot({
    required int position,
    int? localId,
    String? serverSlotId,
    int serverSlotVersion = 0,
  }) => FilamentSlot(
    id: localId,
    position: position,
    material: material.materialType,
    colorName: material.colorName,
    colorValue: material.colorValue,
    remainingGrams: remainingGrams,
    tagUid: tagUid,
    tagInstanceId: openPrintTagId,
    tagBrand: material.manufacturerName,
    manufacturer: material.manufacturerName,
    commercialName: material.commercialName,
    diameterMm: material.diameterMm,
    originalWeightGrams: originalWeightGrams,
    tareWeightGrams: tareWeightGrams,
    purchaseDate: purchaseDate,
    storageLocation: locationName,
    storageLocationCode: locationCode,
    batchNumber: batchNumber,
    openPrintTagId: openPrintTagId,
    notes: notes,
    serverSlotId: serverSlotId,
    serverSlotVersion: serverSlotVersion,
    serverMaterialId: material.id,
    serverMaterialVersion: material.version,
    serverSpoolId: id,
    serverSpoolVersion: version,
    serverManufacturerId: material.manufacturerId,
    serverManufacturerVersion: material.manufacturerVersion,
    serverLocationId: locationId,
    serverLocationVersion: locationVersion,
  );
}

class ServerInventory {
  const ServerInventory({required this.materials, required this.spools});

  static const empty = ServerInventory(materials: [], spools: []);

  final List<ServerMaterial> materials;
  final List<ServerSpool> spools;

  List<ServerSpool> get availableSpools =>
      spools.where((spool) => spool.isAvailable).toList(growable: false);

  ServerInventory withSpoolStatus(String id, String status) => ServerInventory(
    materials: materials,
    spools: spools
        .map((spool) => spool.id == id ? spool.withStatus(status) : spool)
        .toList(growable: false),
  );
}

ServerInventory decodeServerInventory(Map<String, dynamic> snapshot) {
  final manufacturers = {
    for (final row in _list(snapshot['manufacturers']))
      row['id'].toString(): row,
  };
  final locations = {
    for (final row in _list(snapshot['locations'])) row['id'].toString(): row,
  };
  final materials = <String, ServerMaterial>{};
  for (final row in _list(snapshot['materials'])) {
    final id = row['id']?.toString();
    if (id == null || id.isEmpty) continue;
    final manufacturer = manufacturers[row['manufacturer_id']?.toString()];
    materials[id] = ServerMaterial(
      id: id,
      version: _integer(row['version']),
      materialType: row['material_type']?.toString() ?? '',
      colorName: row['color_name']?.toString() ?? '',
      colorValue: _parseColor(row['color_hex']?.toString()),
      diameterMm: _number(row['diameter_mm'], fallback: 1.75),
      commercialName: row['commercial_name']?.toString(),
      manufacturerId: manufacturer?['id']?.toString(),
      manufacturerVersion: _integer(manufacturer?['version']),
      manufacturerName: manufacturer?['name']?.toString(),
    );
  }
  final spools = <ServerSpool>[];
  for (final row in _list(snapshot['spools'])) {
    final id = row['id']?.toString();
    final material = materials[row['material_id']?.toString()];
    if (id == null || id.isEmpty || material == null) continue;
    final location = locations[row['location_id']?.toString()];
    spools.add(
      ServerSpool(
        id: id,
        version: _integer(row['version']),
        status: row['status']?.toString() ?? '',
        material: material,
        remainingGrams: _number(row['current_net_weight_g']),
        originalWeightGrams: _nullableNumber(row['original_net_weight_g']),
        tareWeightGrams: _nullableNumber(row['tare_weight_g']),
        purchaseDate: DateTime.tryParse(row['purchase_date']?.toString() ?? ''),
        locationId: location?['id']?.toString(),
        locationVersion: _integer(location?['version']),
        locationName: location?['name']?.toString(),
        locationCode: location?['code']?.toString(),
        tagUid: row['tag_uid']?.toString(),
        openPrintTagId: row['openprinttag_id']?.toString(),
        batchNumber: row['batch_number']?.toString(),
        notes: row['notes']?.toString(),
      ),
    );
  }
  final materialList = materials.values.toList()
    ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
  spools.sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
  return ServerInventory(materials: materialList, spools: spools);
}

List<Map<String, dynamic>> _list(Object? value) => value is List
    ? value
          .whereType<Map>()
          .map((item) => item.cast<String, dynamic>())
          .toList()
    : const [];

int _integer(Object? value, {int fallback = 0}) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? fallback;

double _number(Object? value, {double fallback = 0}) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? fallback;

double? _nullableNumber(Object? value) => value == null
    ? null
    : value is num
    ? value.toDouble()
    : double.tryParse('$value');

int _parseColor(String? value) {
  final normalized = (value ?? '').replaceFirst('#', '');
  final parsed = int.tryParse(normalized, radix: 16);
  return parsed == null ? 0xFF171717 : 0xFF000000 | parsed;
}

String _formatWeight(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(1);
