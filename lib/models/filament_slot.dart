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
    );
  }
}
