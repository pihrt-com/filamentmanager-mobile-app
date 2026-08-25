import '../models/printer_record.dart';
import 'printer_repository.dart';

class MemoryPrinterRepository implements PrinterRepository {
  MemoryPrinterRepository([List<PrinterRecord> seed = const []])
    : _printers = List.of(seed) {
    for (final printer in _printers) {
      if (printer.id != null && printer.id! >= _nextId) {
        _nextId = printer.id! + 1;
      }
    }
  }

  final List<PrinterRecord> _printers;
  int _nextId = 1;

  @override
  Future<void> deletePrinter(int id) async {
    _printers.removeWhere((printer) => printer.id == id);
  }

  @override
  Future<List<PrinterRecord>> loadPrinters() async => List.of(_printers);

  @override
  Future<PrinterRecord> savePrinter(PrinterRecord printer) async {
    final saved = printer.id == null
        ? printer.copyWith(id: _nextId++)
        : printer;
    final index = _printers.indexWhere((item) => item.id == saved.id);
    if (index == -1) {
      _printers.add(saved);
    } else {
      _printers[index] = saved;
    }
    return saved;
  }

  @override
  Future<void> replacePrinters(List<PrinterRecord> printers) async {
    _printers.clear();
    _nextId = 1;
    for (final printer in printers) {
      await savePrinter(printer.copyWith(id: null));
    }
  }
}
