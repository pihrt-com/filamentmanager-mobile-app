import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../models/filament_slot.dart';
import '../models/printer_record.dart';

class BackupService {
  static const schemaVersion = 2;

  String encode(List<PrinterRecord> printers, {DateTime? createdAt}) {
    final document = {
      'format': 'filamentmanager-backup',
      'schemaVersion': schemaVersion,
      'createdAt': (createdAt ?? DateTime.now()).toUtc().toIso8601String(),
      'printers': printers
          .map(
            (printer) => {
              'name': printer.name,
              'filaments': printer.slots
                  .map(
                    (slot) => {
                      'position': slot.position,
                      'material': slot.material,
                      'colorName': slot.colorName,
                      'colorValue': slot.colorValue,
                      'remainingGrams': slot.remainingGrams,
                      'tagUid': slot.tagUid,
                      'tagInstanceId': slot.tagInstanceId,
                      'tagBrand': slot.tagBrand,
                      'tagFullWeightGrams': slot.tagFullWeightGrams,
                      'tagLastReadAt': slot.tagLastReadAt
                          ?.toUtc()
                          .toIso8601String(),
                    },
                  )
                  .toList(),
            },
          )
          .toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(document);
  }

  List<PrinterRecord> decode(String source) {
    final value = jsonDecode(source);
    if (value is! Map<String, dynamic> ||
        value['format'] != 'filamentmanager-backup' ||
        (value['schemaVersion'] != 1 &&
            value['schemaVersion'] != schemaVersion) ||
        value['printers'] is! List) {
      throw const FormatException('Unsupported Filament Manager backup.');
    }
    return (value['printers'] as List).map((rawPrinter) {
      if (rawPrinter is! Map<String, dynamic> ||
          rawPrinter['name'] is! String ||
          rawPrinter['filaments'] is! List) {
        throw const FormatException('Invalid printer record.');
      }
      final name = (rawPrinter['name'] as String).trim();
      if (name.isEmpty) throw const FormatException('Empty printer name.');
      final slots = (rawPrinter['filaments'] as List).map((rawSlot) {
        if (rawSlot is! Map<String, dynamic> ||
            rawSlot['material'] is! String ||
            rawSlot['colorName'] is! String ||
            rawSlot['colorValue'] is! int ||
            rawSlot['remainingGrams'] is! num) {
          throw const FormatException('Invalid filament record.');
        }
        final weight = (rawSlot['remainingGrams'] as num).toDouble();
        if (weight < 0) {
          throw const FormatException('Negative filament weight.');
        }
        return FilamentSlot(
          position: (rawSlot['position'] as num?)?.toInt() ?? 1,
          material: (rawSlot['material'] as String).trim(),
          colorName: (rawSlot['colorName'] as String).trim(),
          colorValue: rawSlot['colorValue'] as int,
          remainingGrams: weight,
          tagUid: rawSlot['tagUid'] as String?,
          tagInstanceId: rawSlot['tagInstanceId'] as String?,
          tagBrand: rawSlot['tagBrand'] as String?,
          tagFullWeightGrams: (rawSlot['tagFullWeightGrams'] as num?)
              ?.toDouble(),
          tagLastReadAt: DateTime.tryParse(
            rawSlot['tagLastReadAt'] as String? ?? '',
          ),
        );
      }).toList();
      return PrinterRecord(name: name, slots: slots);
    }).toList();
  }

  Future<File> createExportFile(List<PrinterRecord> printers) async {
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    final stamp =
        '${now.year}${two(now.month)}${two(now.day)}-'
        '${two(now.hour)}${two(now.minute)}${two(now.second)}';
    final directory = await getTemporaryDirectory();
    final file = File(
      path.join(directory.path, 'filament-manager-$stamp.json'),
    );
    return file.writeAsString(encode(printers), flush: true);
  }
}
