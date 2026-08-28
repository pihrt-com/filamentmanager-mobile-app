class FilamentSlot {
  const FilamentSlot({
    this.id,
    required this.position,
    required this.material,
    required this.colorName,
    required this.colorValue,
    required this.remainingGrams,
    this.tagUid,
    this.tagInstanceId,
    this.tagBrand,
    this.tagFullWeightGrams,
    this.tagLastReadAt,
    this.manufacturer,
    this.commercialName,
    this.diameterMm = 1.75,
    this.originalWeightGrams,
    this.tareWeightGrams,
    this.purchaseDate,
    this.storageLocation,
    this.storageLocationCode,
    this.batchNumber,
    this.openPrintTagId,
    this.notes,
    this.serverSlotId,
    this.serverSlotVersion = 0,
    this.serverMaterialId,
    this.serverMaterialVersion = 0,
    this.serverSpoolId,
    this.serverSpoolVersion = 0,
    this.serverManufacturerId,
    this.serverManufacturerVersion = 0,
    this.serverLocationId,
    this.serverLocationVersion = 0,
  });

  final int? id;
  final int position;
  final String material;
  final String colorName;
  final int colorValue;
  final double remainingGrams;
  final String? tagUid;
  final String? tagInstanceId;
  final String? tagBrand;
  final double? tagFullWeightGrams;
  final DateTime? tagLastReadAt;
  final String? manufacturer;
  final String? commercialName;
  final double diameterMm;
  final double? originalWeightGrams;
  final double? tareWeightGrams;
  final DateTime? purchaseDate;
  final String? storageLocation;
  final String? storageLocationCode;
  final String? batchNumber;
  final String? openPrintTagId;
  final String? notes;
  final String? serverSlotId;
  final int serverSlotVersion;
  final String? serverMaterialId;
  final int serverMaterialVersion;
  final String? serverSpoolId;
  final int serverSpoolVersion;
  final String? serverManufacturerId;
  final int serverManufacturerVersion;
  final String? serverLocationId;
  final int serverLocationVersion;

  FilamentSlot copyWith({
    int? id,
    int? position,
    String? material,
    String? colorName,
    int? colorValue,
    double? remainingGrams,
    String? tagUid,
    String? tagInstanceId,
    String? tagBrand,
    double? tagFullWeightGrams,
    DateTime? tagLastReadAt,
    String? manufacturer,
    String? commercialName,
    double? diameterMm,
    double? originalWeightGrams,
    double? tareWeightGrams,
    DateTime? purchaseDate,
    String? storageLocation,
    String? storageLocationCode,
    String? batchNumber,
    String? openPrintTagId,
    String? notes,
    String? serverSlotId,
    int? serverSlotVersion,
    String? serverMaterialId,
    int? serverMaterialVersion,
    String? serverSpoolId,
    int? serverSpoolVersion,
    String? serverManufacturerId,
    int? serverManufacturerVersion,
    String? serverLocationId,
    int? serverLocationVersion,
  }) {
    return FilamentSlot(
      id: id ?? this.id,
      position: position ?? this.position,
      material: material ?? this.material,
      colorName: colorName ?? this.colorName,
      colorValue: colorValue ?? this.colorValue,
      remainingGrams: remainingGrams ?? this.remainingGrams,
      tagUid: tagUid ?? this.tagUid,
      tagInstanceId: tagInstanceId ?? this.tagInstanceId,
      tagBrand: tagBrand ?? this.tagBrand,
      tagFullWeightGrams: tagFullWeightGrams ?? this.tagFullWeightGrams,
      tagLastReadAt: tagLastReadAt ?? this.tagLastReadAt,
      manufacturer: manufacturer ?? this.manufacturer,
      commercialName: commercialName ?? this.commercialName,
      diameterMm: diameterMm ?? this.diameterMm,
      originalWeightGrams: originalWeightGrams ?? this.originalWeightGrams,
      tareWeightGrams: tareWeightGrams ?? this.tareWeightGrams,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      storageLocation: storageLocation ?? this.storageLocation,
      storageLocationCode: storageLocationCode ?? this.storageLocationCode,
      batchNumber: batchNumber ?? this.batchNumber,
      openPrintTagId: openPrintTagId ?? this.openPrintTagId,
      notes: notes ?? this.notes,
      serverSlotId: serverSlotId ?? this.serverSlotId,
      serverSlotVersion: serverSlotVersion ?? this.serverSlotVersion,
      serverMaterialId: serverMaterialId ?? this.serverMaterialId,
      serverMaterialVersion:
          serverMaterialVersion ?? this.serverMaterialVersion,
      serverSpoolId: serverSpoolId ?? this.serverSpoolId,
      serverSpoolVersion: serverSpoolVersion ?? this.serverSpoolVersion,
      serverManufacturerId: serverManufacturerId ?? this.serverManufacturerId,
      serverManufacturerVersion:
          serverManufacturerVersion ?? this.serverManufacturerVersion,
      serverLocationId: serverLocationId ?? this.serverLocationId,
      serverLocationVersion:
          serverLocationVersion ?? this.serverLocationVersion,
    );
  }
}
