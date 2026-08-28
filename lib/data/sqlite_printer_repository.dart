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
      version: 3,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE printers (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL COLLATE NOCASE UNIQUE,
            manufacturer TEXT,
            model TEXT,
            description TEXT,
            status TEXT NOT NULL DEFAULT 'active',
            server_id TEXT UNIQUE,
            server_version INTEGER NOT NULL DEFAULT 0
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
            tag_uid TEXT,
            tag_instance_id TEXT,
            tag_brand TEXT,
            tag_full_weight_grams REAL,
            tag_last_read_at TEXT,
            manufacturer TEXT,
            commercial_name TEXT,
            diameter_mm REAL NOT NULL DEFAULT 1.75,
            original_weight_grams REAL,
            tare_weight_grams REAL,
            purchase_date TEXT,
            storage_location TEXT,
            storage_location_code TEXT,
            batch_number TEXT,
            openprinttag_id TEXT,
            notes TEXT,
            server_slot_id TEXT UNIQUE,
            server_slot_version INTEGER NOT NULL DEFAULT 0,
            server_material_id TEXT,
            server_material_version INTEGER NOT NULL DEFAULT 0,
            server_spool_id TEXT,
            server_spool_version INTEGER NOT NULL DEFAULT 0,
            server_manufacturer_id TEXT,
            server_manufacturer_version INTEGER NOT NULL DEFAULT 0,
            server_location_id TEXT,
            server_location_version INTEGER NOT NULL DEFAULT 0,
            FOREIGN KEY (printer_id) REFERENCES printers(id) ON DELETE CASCADE
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE filament_slots ADD COLUMN tag_uid TEXT',
          );
          await db.execute(
            'ALTER TABLE filament_slots ADD COLUMN tag_instance_id TEXT',
          );
          await db.execute(
            'ALTER TABLE filament_slots ADD COLUMN tag_brand TEXT',
          );
          await db.execute(
            'ALTER TABLE filament_slots ADD COLUMN tag_full_weight_grams REAL',
          );
          await db.execute(
            'ALTER TABLE filament_slots ADD COLUMN tag_last_read_at TEXT',
          );
        }
        if (oldVersion < 3) {
          for (final statement in _version3Columns) {
            await db.execute(statement);
          }
        }
      },
    );
    return _database!;
  }

  Future<Database> get database => _db;

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
          manufacturer: row['manufacturer'] as String?,
          model: row['model'] as String?,
          description: row['description'] as String?,
          status: row['status'] as String? ?? 'active',
          serverId: row['server_id'] as String?,
          serverVersion: row['server_version'] as int? ?? 0,
          slots: slotRows
              .map(
                (slot) => FilamentSlot(
                  id: slot['id']! as int,
                  position: slot['position']! as int,
                  material: slot['material']! as String,
                  colorName: slot['color_name']! as String,
                  colorValue: slot['color_value']! as int,
                  remainingGrams: (slot['remaining_grams']! as num).toDouble(),
                  tagUid: slot['tag_uid'] as String?,
                  tagInstanceId: slot['tag_instance_id'] as String?,
                  tagBrand: slot['tag_brand'] as String?,
                  tagFullWeightGrams: (slot['tag_full_weight_grams'] as num?)
                      ?.toDouble(),
                  tagLastReadAt: DateTime.tryParse(
                    slot['tag_last_read_at'] as String? ?? '',
                  ),
                  manufacturer: slot['manufacturer'] as String?,
                  commercialName: slot['commercial_name'] as String?,
                  diameterMm: (slot['diameter_mm'] as num?)?.toDouble() ?? 1.75,
                  originalWeightGrams: (slot['original_weight_grams'] as num?)
                      ?.toDouble(),
                  tareWeightGrams: (slot['tare_weight_grams'] as num?)
                      ?.toDouble(),
                  purchaseDate: DateTime.tryParse(
                    slot['purchase_date'] as String? ?? '',
                  ),
                  storageLocation: slot['storage_location'] as String?,
                  storageLocationCode: slot['storage_location_code'] as String?,
                  batchNumber: slot['batch_number'] as String?,
                  openPrintTagId: slot['openprinttag_id'] as String?,
                  notes: slot['notes'] as String?,
                  serverSlotId: slot['server_slot_id'] as String?,
                  serverSlotVersion: slot['server_slot_version'] as int? ?? 0,
                  serverMaterialId: slot['server_material_id'] as String?,
                  serverMaterialVersion:
                      slot['server_material_version'] as int? ?? 0,
                  serverSpoolId: slot['server_spool_id'] as String?,
                  serverSpoolVersion: slot['server_spool_version'] as int? ?? 0,
                  serverManufacturerId:
                      slot['server_manufacturer_id'] as String?,
                  serverManufacturerVersion:
                      slot['server_manufacturer_version'] as int? ?? 0,
                  serverLocationId: slot['server_location_id'] as String?,
                  serverLocationVersion:
                      slot['server_location_version'] as int? ?? 0,
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
        printerId = await transaction.insert(
          'printers',
          _printerValues(printer),
        );
      } else {
        printerId = printer.id!;
        await transaction.update(
          'printers',
          _printerValues(printer),
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
          if (slot.id != null) 'id': slot.id,
          'printer_id': printerId,
          'position': index + 1,
          'material': slot.material,
          'color_name': slot.colorName,
          'color_value': slot.colorValue,
          'remaining_grams': slot.remainingGrams,
          ..._tagValues(slot),
          ..._detailValues(slot),
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
        final printerId = await transaction.insert(
          'printers',
          _printerValues(printer),
        );
        for (var index = 0; index < printer.slots.length; index++) {
          final slot = printer.slots[index];
          await transaction.insert('filament_slots', {
            'printer_id': printerId,
            'position': index + 1,
            'material': slot.material,
            'color_name': slot.colorName,
            'color_value': slot.colorValue,
            'remaining_grams': slot.remainingGrams,
            ..._tagValues(slot),
            ..._detailValues(slot),
          });
        }
      }
    });
  }

  Map<String, Object?> _tagValues(FilamentSlot slot) => {
    'tag_uid': slot.tagUid,
    'tag_instance_id': slot.tagInstanceId,
    'tag_brand': slot.tagBrand,
    'tag_full_weight_grams': slot.tagFullWeightGrams,
    'tag_last_read_at': slot.tagLastReadAt?.toUtc().toIso8601String(),
  };

  Map<String, Object?> _printerValues(PrinterRecord printer) => {
    'name': printer.name,
    'manufacturer': printer.manufacturer,
    'model': printer.model,
    'description': printer.description,
    'status': printer.status,
    'server_id': printer.serverId,
    'server_version': printer.serverVersion,
  };

  Map<String, Object?> _detailValues(FilamentSlot slot) => {
    'manufacturer': slot.manufacturer,
    'commercial_name': slot.commercialName,
    'diameter_mm': slot.diameterMm,
    'original_weight_grams': slot.originalWeightGrams,
    'tare_weight_grams': slot.tareWeightGrams,
    'purchase_date': slot.purchaseDate?.toIso8601String().split('T').first,
    'storage_location': slot.storageLocation,
    'storage_location_code': slot.storageLocationCode,
    'batch_number': slot.batchNumber,
    'openprinttag_id': slot.openPrintTagId,
    'notes': slot.notes,
    'server_slot_id': slot.serverSlotId,
    'server_slot_version': slot.serverSlotVersion,
    'server_material_id': slot.serverMaterialId,
    'server_material_version': slot.serverMaterialVersion,
    'server_spool_id': slot.serverSpoolId,
    'server_spool_version': slot.serverSpoolVersion,
    'server_manufacturer_id': slot.serverManufacturerId,
    'server_manufacturer_version': slot.serverManufacturerVersion,
    'server_location_id': slot.serverLocationId,
    'server_location_version': slot.serverLocationVersion,
  };
}

const _version3Columns = <String>[
  'ALTER TABLE printers ADD COLUMN manufacturer TEXT',
  'ALTER TABLE printers ADD COLUMN model TEXT',
  'ALTER TABLE printers ADD COLUMN description TEXT',
  "ALTER TABLE printers ADD COLUMN status TEXT NOT NULL DEFAULT 'active'",
  'ALTER TABLE printers ADD COLUMN server_id TEXT',
  'ALTER TABLE printers ADD COLUMN server_version INTEGER NOT NULL DEFAULT 0',
  'CREATE UNIQUE INDEX IF NOT EXISTS printers_server_id_unique ON printers(server_id)',
  'ALTER TABLE filament_slots ADD COLUMN manufacturer TEXT',
  'ALTER TABLE filament_slots ADD COLUMN commercial_name TEXT',
  'ALTER TABLE filament_slots ADD COLUMN diameter_mm REAL NOT NULL DEFAULT 1.75',
  'ALTER TABLE filament_slots ADD COLUMN original_weight_grams REAL',
  'ALTER TABLE filament_slots ADD COLUMN tare_weight_grams REAL',
  'ALTER TABLE filament_slots ADD COLUMN purchase_date TEXT',
  'ALTER TABLE filament_slots ADD COLUMN storage_location TEXT',
  'ALTER TABLE filament_slots ADD COLUMN storage_location_code TEXT',
  'ALTER TABLE filament_slots ADD COLUMN batch_number TEXT',
  'ALTER TABLE filament_slots ADD COLUMN openprinttag_id TEXT',
  'ALTER TABLE filament_slots ADD COLUMN notes TEXT',
  'ALTER TABLE filament_slots ADD COLUMN server_slot_id TEXT',
  'ALTER TABLE filament_slots ADD COLUMN server_slot_version INTEGER NOT NULL DEFAULT 0',
  'ALTER TABLE filament_slots ADD COLUMN server_material_id TEXT',
  'ALTER TABLE filament_slots ADD COLUMN server_material_version INTEGER NOT NULL DEFAULT 0',
  'ALTER TABLE filament_slots ADD COLUMN server_spool_id TEXT',
  'ALTER TABLE filament_slots ADD COLUMN server_spool_version INTEGER NOT NULL DEFAULT 0',
  'ALTER TABLE filament_slots ADD COLUMN server_manufacturer_id TEXT',
  'ALTER TABLE filament_slots ADD COLUMN server_manufacturer_version INTEGER NOT NULL DEFAULT 0',
  'ALTER TABLE filament_slots ADD COLUMN server_location_id TEXT',
  'ALTER TABLE filament_slots ADD COLUMN server_location_version INTEGER NOT NULL DEFAULT 0',
  'CREATE UNIQUE INDEX IF NOT EXISTS slots_server_id_unique ON filament_slots(server_slot_id)',
];
