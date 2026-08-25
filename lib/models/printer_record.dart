import 'filament_slot.dart';

class PrinterRecord {
  const PrinterRecord({this.id, required this.name, required this.slots});

  final int? id;
  final String name;
  final List<FilamentSlot> slots;

  PrinterRecord copyWith({int? id, String? name, List<FilamentSlot>? slots}) {
    return PrinterRecord(
      id: id ?? this.id,
      name: name ?? this.name,
      slots: slots ?? this.slots,
    );
  }
}
