import 'filament_slot.dart';

class PrinterRecord {
  const PrinterRecord({
    this.id,
    required this.name,
    required this.slots,
    this.manufacturer,
    this.model,
    this.description,
    this.status = 'active',
    this.serverId,
    this.serverVersion = 0,
  });

  final int? id;
  final String name;
  final List<FilamentSlot> slots;
  final String? manufacturer;
  final String? model;
  final String? description;
  final String status;
  final String? serverId;
  final int serverVersion;

  PrinterRecord copyWith({
    int? id,
    String? name,
    List<FilamentSlot>? slots,
    String? manufacturer,
    String? model,
    String? description,
    String? status,
    String? serverId,
    int? serverVersion,
  }) {
    return PrinterRecord(
      id: id ?? this.id,
      name: name ?? this.name,
      slots: slots ?? this.slots,
      manufacturer: manufacturer ?? this.manufacturer,
      model: model ?? this.model,
      description: description ?? this.description,
      status: status ?? this.status,
      serverId: serverId ?? this.serverId,
      serverVersion: serverVersion ?? this.serverVersion,
    );
  }
}
