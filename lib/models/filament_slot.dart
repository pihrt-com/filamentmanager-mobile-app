class FilamentSlot {
  const FilamentSlot({
    this.id,
    required this.position,
    required this.material,
    required this.colorName,
    required this.colorValue,
    required this.remainingGrams,
  });

  final int? id;
  final int position;
  final String material;
  final String colorName;
  final int colorValue;
  final double remainingGrams;

  FilamentSlot copyWith({
    int? id,
    int? position,
    String? material,
    String? colorName,
    int? colorValue,
    double? remainingGrams,
  }) {
    return FilamentSlot(
      id: id ?? this.id,
      position: position ?? this.position,
      material: material ?? this.material,
      colorName: colorName ?? this.colorName,
      colorValue: colorValue ?? this.colorValue,
      remainingGrams: remainingGrams ?? this.remainingGrams,
    );
  }
}
