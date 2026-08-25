import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../models/filament_slot.dart';
import '../models/printer_record.dart';
import 'printer_repository.dart';

class SqlitePrinterRepository implements PrinterRepository {
  Database? _database;

  Future<Database> get _db async {
    if (_database != null) return _database!;
    final databasePath = path.join(
      await getDatabasesPath(),
      'filament_manager.db',
    );
    _database = await openDatabase(
      databasePath,
      version: 1,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE printers (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL COLLATE NOCASE UNIQUE
          )
        ''');
        await db.execute('''
          CREATE TABLE filament_slots (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            printer_id INTEGER NOT NULL,
            position INTEGER NOT NULL,
            material TEXT NOT NULL,
            color_name TEXT NOT NULL,
            color_value INTEGER NOT NULL,
            remaining_grams REAL NOT NULL,
            FOREIGN KEY (printer_id) REFERENCES printers(id) ON DELETE CASCADE
          )
        ''');
      },
    );
    return _database!;
  }

  @override
  Future<List<PrinterRecord>> loadPrinters() async {
    final db = await _db;
    final printerRows = await db.query(
      'printers',
      orderBy: 'name COLLATE NOCASE',
    );
    final result = <PrinterRecord>[];
    for (final row in printerRows) {
      final id = row['id']! as int;
      final slotRows = await db.query(
        'filament_slots',
        where: 'printer_id = ?',
        whereArgs: [id],
        orderBy: 'position',
      );
      result.add(
        PrinterRecord(
          id: id,
          name: row['name']! as String,
          slots: slotRows
              .map(
                (slot) => FilamentSlot(
                  id: slot['id']! as int,
                  position: slot['position']! as int,
                  material: slot['material']! as String,
                  colorName: slot['color_name']! as String,
                  colorValue: slot['color_value']! as int,
                  remainingGrams: (slot['remaining_grams']! as num).toDouble(),
                ),
              )
              .toList(),
        ),
      );
    }
    return result;
  }

  @override
  Future<PrinterRecord> savePrinter(PrinterRecord printer) async {
    final db = await _db;
    late int printerId;
    await db.transaction((transaction) async {
      if (printer.id == null) {
        printerId = await transaction.insert('printers', {
          'name': printer.name,
        });
      } else {
        printerId = printer.id!;
        await transaction.update(
          'printers',
          {'name': printer.name},
          where: 'id = ?',
          whereArgs: [printerId],
        );
        await transaction.delete(
          'filament_slots',
          where: 'printer_id = ?',
          whereArgs: [printerId],
        );
      }
      for (var index = 0; index < printer.slots.length; index++) {
        final slot = printer.slots[index];
        await transaction.insert('filament_slots', {
          'printer_id': printerId,
          'position': index + 1,
          'material': slot.material,
          'color_name': slot.colorName,
          'color_value': slot.colorValue,
          'remaining_grams': slot.remainingGrams,
        });
      }
    });
    return printer.copyWith(id: printerId);
  }

  @override
  Future<void> deletePrinter(int id) async {
    final db = await _db;
    await db.delete('printers', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> replacePrinters(List<PrinterRecord> printers) async {
    final db = await _db;
    await db.transaction((transaction) async {
      await transaction.delete('filament_slots');
      await transaction.delete('printers');
      for (final printer in printers) {
        final printerId = await transaction.insert('printers', {
          'name': printer.name,
        });
        for (var index = 0; index < printer.slots.length; index++) {
          final slot = printer.slots[index];
          await transaction.insert('filament_slots', {
            'printer_id': printerId,
            'position': index + 1,
            'material': slot.material,
            'color_name': slot.colorName,
            'color_value': slot.colorValue,
            'remaining_grams': slot.remainingGrams,
          });
        }
      }
    });
  }
}
