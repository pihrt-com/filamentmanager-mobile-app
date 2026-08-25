import '../models/printer_record.dart';

abstract interface class PrinterRepository {
  Future<List<PrinterRecord>> loadPrinters();
  Future<PrinterRecord> savePrinter(PrinterRecord printer);
  Future<void> deletePrinter(int id);
  Future<void> replacePrinters(List<PrinterRecord> printers);
}
