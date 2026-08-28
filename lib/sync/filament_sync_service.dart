import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../data/backup_service.dart';
import '../data/sqlite_printer_repository.dart';
import '../models/filament_slot.dart';
import '../models/printer_record.dart';
import 'filament_server_api.dart';

enum InitialSyncMode { upload, download, merge }

class InitialSyncPreview {
  const InitialSyncPreview({
    required this.snapshot,
    required this.localPrinterCount,
    required this.serverPrinterCount,
    required this.conflictingPrinterNames,
  });

  final Map<String, dynamic> snapshot;
  final int localPrinterCount;
  final int serverPrinterCount;
  final List<String> conflictingPrinterNames;
}

class SyncResult {
  const SyncResult({required this.conflictCount, required this.pendingCount});

  final int conflictCount;
  final int pendingCount;
}

class FilamentSyncService {
  FilamentSyncService({
    required this.repository,
    FilamentServerApi? api,
    FlutterSecureStorage? secureStorage,
  }) : _api = api ?? FilamentServerApi(),
       _secure =
           secureStorage ??
           const FlutterSecureStorage(
             aOptions: AndroidOptions(
               storageNamespace: 'filamentmanager_server_auth_v1',
               migrateWithBackup: true,
             ),
           );

  static const _uuid = Uuid();
  static const _sessionKey = 'filament_server_session';
  static const _deviceIdKey = 'filament_server_device_id';

  final SqlitePrinterRepository repository;
  final FilamentServerApi _api;
  final FlutterSecureStorage _secure;
  SharedPreferences? _preferences;
  Future<SyncResult>? _activeSynchronization;
  Future<String>? _activeTokenRefresh;
  String? _accessTokenCache;
  String? _refreshTokenCache;
  String _deviceId = '';

  bool enabled = false;
  String serverUrl = '';
  String username = '';
  String? serverVersion;
  String? role;
  String? displayName;
  DateTime? lastSyncAt;
  int pendingCount = 0;
  int conflictCount = 0;
  bool busy = false;

  bool get configured => serverUrl.isNotEmpty && username.isNotEmpty;
  bool get connected => enabled && configured && role != null;
  bool get canWrite => role != 'viewer';

  Future<void> initialize() async {
    _preferences = await SharedPreferences.getInstance();
    final db = await repository.database;
    await _ensureTables(db);
    enabled = _preferences!.getBool('filament_server_enabled') ?? false;
    serverUrl = _preferences!.getString('filament_server_url') ?? '';
    username = _preferences!.getString('filament_server_username') ?? '';
    serverVersion = _preferences!.getString('filament_server_version');
    role = _preferences!.getString('filament_server_role');
    displayName = _preferences!.getString('filament_server_display_name');
    _deviceId = _preferences!.getString(_deviceIdKey) ?? '';
    if (_deviceId.isEmpty) {
      _deviceId = _uuid.v4();
      await _preferences!.setString(_deviceIdKey, _deviceId);
    }
    final storedSession = await _loadTokenPair();
    if (enabled && role != null && storedSession == null) {
      role = null;
      displayName = null;
      await _preferences!.remove('filament_server_role');
      await _preferences!.remove('filament_server_display_name');
    }
    lastSyncAt = DateTime.tryParse(
      _preferences!.getString('filament_server_last_sync') ?? '',
    );
    await _refreshCounts();
  }

  Future<void> setEnabled(bool value) async {
    enabled = value;
    await _preferences!.setBool('filament_server_enabled', value);
  }

  Future<InitialSyncPreview> connect({
    required String url,
    required String login,
    required String password,
    required String appVersion,
    required List<PrinterRecord> localPrinters,
  }) async {
    busy = true;
    try {
      final normalized = _api.normalizeBaseUrl(url);
      final info = await _api.serverInfo(normalized);
      final auth = await _api.login(
        normalized,
        username: login.trim(),
        password: password,
        appVersion: appVersion,
        deviceId: _deviceId,
      );
      await _storeTokenPair(auth);
      serverUrl = normalized;
      username = login.trim();
      serverVersion = info['version']?.toString();
      final user = _map(auth['user']);
      role = user?['role']?.toString();
      displayName = user?['displayName']?.toString();
      enabled = true;
      await _preferences!.setString('filament_server_url', serverUrl);
      await _preferences!.setString('filament_server_username', username);
      await _preferences!.setBool('filament_server_enabled', true);
      if (serverVersion != null) {
        await _preferences!.setString(
          'filament_server_version',
          serverVersion!,
        );
      }
      if (role != null) {
        await _preferences!.setString('filament_server_role', role!);
      }
      if (displayName != null) {
        await _preferences!.setString(
          'filament_server_display_name',
          displayName!,
        );
      }
      final snapshot = await _api.snapshot(normalized, await _accessToken());
      final serverNames = _list(snapshot['printers'])
          .map((item) => item['name']?.toString().toLowerCase())
          .whereType<String>()
          .toSet();
      final conflicts = localPrinters
          .where((printer) => serverNames.contains(printer.name.toLowerCase()))
          .map((printer) => printer.name)
          .toList();
      return InitialSyncPreview(
        snapshot: snapshot,
        localPrinterCount: localPrinters.length,
        serverPrinterCount: _list(snapshot['printers']).length,
        conflictingPrinterNames: conflicts,
      );
    } finally {
      busy = false;
    }
  }

  Future<SyncResult> completeInitialSync(
    InitialSyncPreview preview,
    InitialSyncMode mode,
    List<PrinterRecord> localPrinters,
  ) async {
    if (mode == InitialSyncMode.download) {
      await _createSafetyBackup(localPrinters);
      await repository.replacePrinters(_decodeSnapshot(preview.snapshot));
      await _markSynchronized(preview.snapshot);
    } else {
      var upload = localPrinters;
      if (mode == InitialSyncMode.merge) {
        final used = _list(preview.snapshot['printers'])
            .map((item) => item['name']?.toString().toLowerCase())
            .whereType<String>()
            .toSet();
        upload = localPrinters.map((printer) {
          var name = printer.name;
          if (used.contains(name.toLowerCase())) {
            var suffix = 2;
            var candidate = '${printer.name} (phone)';
            while (used.contains(candidate.toLowerCase())) {
              candidate = '${printer.name} (phone $suffix)';
              suffix++;
            }
            name = candidate;
          }
          used.add(name.toLowerCase());
          return printer.copyWith(name: name);
        }).toList();
      } else if (preview.serverPrinterCount > 0) {
        throw const FilamentServerException(
          'Uploading phone data is available only for an empty server.',
          statusCode: 409,
        );
      }
      await repository.replacePrinters(upload);
      final reloaded = await repository.loadPrinters();
      for (final printer in reloaded) {
        await queuePrinter(printer);
      }
      final result = await synchronize();
      if (result.conflictCount > 0) return result;
    }
    await _refreshCounts();
    return SyncResult(conflictCount: conflictCount, pendingCount: pendingCount);
  }

  Future<PrinterRecord> queuePrinter(PrinterRecord source) async {
    if (!enabled || !canWrite) return source;
    final printer = _assignIds(source);
    await repository.savePrinter(printer);
    await _queueGraph(printer);
    await _refreshCounts();
    return printer;
  }

  Future<void> queuePrinterDeletion(PrinterRecord printer) async {
    if (!enabled || !canWrite) return;
    for (final slot in printer.slots) {
      if (slot.serverSlotId != null) {
        await _queueMutation(
          type: 'printer_slot',
          id: slot.serverSlotId!,
          operation: 'delete',
          baseVersion: slot.serverSlotVersion,
          data: const {},
          priority: 10,
        );
      }
    }
    if (printer.serverId != null) {
      await _queueMutation(
        type: 'printer',
        id: printer.serverId!,
        operation: 'delete',
        baseVersion: printer.serverVersion,
        data: const {},
        priority: 20,
      );
    }
    await _refreshCounts();
  }

  Future<void> queueRemovedSlots(
    PrinterRecord previous,
    PrinterRecord current,
  ) async {
    if (!enabled || !canWrite) return;
    final currentIds = current.slots
        .map((slot) => slot.serverSlotId)
        .whereType<String>()
        .toSet();
    for (final slot in previous.slots) {
      if (slot.serverSlotId != null &&
          !currentIds.contains(slot.serverSlotId)) {
        await _queueMutation(
          type: 'printer_slot',
          id: slot.serverSlotId!,
          operation: 'delete',
          baseVersion: slot.serverSlotVersion,
          data: const {},
          priority: 5,
        );
      }
    }
    await _refreshCounts();
  }

  Future<SyncResult> synchronize() {
    final running = _activeSynchronization;
    if (running != null) return running;
    late final Future<SyncResult> operation;
    operation = _synchronize().whenComplete(() {
      if (identical(_activeSynchronization, operation)) {
        _activeSynchronization = null;
      }
    });
    _activeSynchronization = operation;
    return operation;
  }

  Future<SyncResult> _synchronize() async {
    if (!enabled || !configured) {
      return SyncResult(
        conflictCount: conflictCount,
        pendingCount: pendingCount,
      );
    }
    busy = true;
    try {
      var token = await _validAccessToken();
      final db = await repository.database;
      while (true) {
        final rows = await db.query(
          'sync_outbox',
          orderBy: 'priority, created_at',
          limit: 100,
        );
        if (rows.isEmpty) break;
        final mutations = rows
            .map((row) => jsonDecode(row['payload']! as String))
            .cast<Map<String, dynamic>>()
            .toList();
        Map<String, dynamic> response;
        try {
          response = await _api.push(serverUrl, token, mutations);
        } on FilamentServerException catch (error) {
          if (error.statusCode != 401) rethrow;
          token = await _refreshAccessToken();
          response = await _api.push(serverUrl, token, mutations);
        }
        for (final raw in _list(response['results'])) {
          final mutationId = raw['clientMutationId']?.toString();
          if (mutationId != null) {
            await db.delete(
              'sync_outbox',
              where: 'mutation_id = ?',
              whereArgs: [mutationId],
            );
          }
        }
        for (final conflict in _list(response['conflicts'])) {
          final type = conflict['type']?.toString();
          final id = conflict['id']?.toString();
          if (type == null || id == null) continue;
          final pending = await db.query(
            'sync_outbox',
            where: 'entity_type = ? AND entity_id = ?',
            whereArgs: [type, id],
            limit: 1,
          );
          await db.insert('sync_conflicts', {
            'entity_type': type,
            'entity_id': id,
            'local_payload': pending.isEmpty ? '{}' : pending.first['payload'],
            'server_payload': jsonEncode(conflict),
            'created_at': DateTime.now().toUtc().toIso8601String(),
          }, conflictAlgorithm: ConflictAlgorithm.replace);
          await db.delete(
            'sync_outbox',
            where: 'entity_type = ? AND entity_id = ?',
            whereArgs: [type, id],
          );
        }
        if (_list(response['conflicts']).isNotEmpty) break;
      }
      await _refreshCounts();
      if (conflictCount == 0 && pendingCount == 0) {
        Map<String, dynamic> snapshot;
        try {
          snapshot = await _api.snapshot(serverUrl, token);
        } on FilamentServerException catch (error) {
          if (error.statusCode != 401) rethrow;
          token = await _refreshAccessToken();
          snapshot = await _api.snapshot(serverUrl, token);
        }
        await repository.replacePrinters(_decodeSnapshot(snapshot));
        await _markSynchronized(snapshot);
      }
      await _refreshCounts();
      return SyncResult(
        conflictCount: conflictCount,
        pendingCount: pendingCount,
      );
    } finally {
      busy = false;
    }
  }

  Future<void> resolveAllConflicts({required bool keepPhone}) async {
    final db = await repository.database;
    final rows = await db.query('sync_conflicts');
    for (final row in rows) {
      if (keepPhone) {
        final local = _map(jsonDecode(row['local_payload']! as String));
        final server = _map(jsonDecode(row['server_payload']! as String));
        if (local != null && server != null && local.isNotEmpty) {
          local['clientMutationId'] = _uuid.v4();
          local['baseVersion'] = server['serverVersion'] ?? 0;
          await db.insert('sync_outbox', {
            'mutation_id': local['clientMutationId'],
            'entity_type': local['type'],
            'entity_id': local['id'],
            'priority': 50,
            'payload': jsonEncode(local),
            'created_at': DateTime.now().toUtc().toIso8601String(),
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
    }
    await db.delete('sync_conflicts');
    await _refreshCounts();
  }

  Future<void> disconnect() async {
    final refresh = (await _loadTokenPair())?['refresh'];
    if (serverUrl.isNotEmpty && refresh != null) {
      try {
        await _api.logout(serverUrl, refresh);
      } on Object {
        // Local disconnection must also work while the server is offline.
      }
    }
    await _secure.delete(key: _sessionKey);
    _accessTokenCache = null;
    _refreshTokenCache = null;
    enabled = false;
    role = null;
    displayName = null;
    await _preferences!.setBool('filament_server_enabled', false);
    await _preferences!.remove('filament_server_role');
    await _preferences!.remove('filament_server_display_name');
  }

  PrinterRecord _assignIds(PrinterRecord printer) => printer.copyWith(
    serverId: printer.serverId ?? _uuid.v4(),
    slots: printer.slots.map((slot) {
      final hasManufacturer = slot.manufacturer?.trim().isNotEmpty == true;
      final hasLocation = slot.storageLocation?.trim().isNotEmpty == true;
      return slot.copyWith(
        serverSlotId: slot.serverSlotId ?? _uuid.v4(),
        serverMaterialId: slot.serverMaterialId ?? _uuid.v4(),
        serverSpoolId: slot.serverSpoolId ?? _uuid.v4(),
        serverManufacturerId: hasManufacturer
            ? slot.serverManufacturerId ?? _uuid.v4()
            : slot.serverManufacturerId,
        serverLocationId: hasLocation
            ? slot.serverLocationId ?? _uuid.v4()
            : slot.serverLocationId,
      );
    }).toList(),
  );

  Future<void> _queueGraph(PrinterRecord printer) async {
    await _queueMutation(
      type: 'printer',
      id: printer.serverId!,
      baseVersion: printer.serverVersion,
      priority: 10,
      data: {
        'name': printer.name,
        'manufacturer': printer.manufacturer,
        'model': printer.model,
        'description': printer.description,
        'status': printer.status,
        'sort_order': printer.id ?? 0,
      },
    );
    for (final slot in printer.slots) {
      if (slot.serverManufacturerId != null &&
          slot.manufacturer?.trim().isNotEmpty == true) {
        await _queueMutation(
          type: 'manufacturer',
          id: slot.serverManufacturerId!,
          baseVersion: slot.serverManufacturerVersion,
          priority: 20,
          data: {'name': slot.manufacturer!.trim()},
        );
      }
      await _queueMutation(
        type: 'material',
        id: slot.serverMaterialId!,
        baseVersion: slot.serverMaterialVersion,
        priority: 30,
        data: {
          'manufacturer_id': slot.serverManufacturerId,
          'material_type': slot.material,
          'commercial_name': slot.commercialName,
          'color_name': slot.colorName,
          'color_hex': _colorHex(slot.colorValue),
          'diameter_mm': slot.diameterMm,
        },
      );
      if (slot.serverLocationId != null &&
          slot.storageLocation?.trim().isNotEmpty == true) {
        await _queueMutation(
          type: 'location',
          id: slot.serverLocationId!,
          baseVersion: slot.serverLocationVersion,
          priority: 35,
          data: {
            'name': slot.storageLocation!.trim(),
            'code': slot.storageLocationCode,
          },
        );
      }
      await _queueMutation(
        type: 'spool',
        id: slot.serverSpoolId!,
        baseVersion: slot.serverSpoolVersion,
        priority: 40,
        data: {
          'material_id': slot.serverMaterialId,
          'location_id': slot.serverLocationId,
          'tag_uid': slot.tagUid,
          'openprinttag_id': slot.openPrintTagId ?? slot.tagInstanceId,
          'original_net_weight_g':
              slot.originalWeightGrams ??
              slot.tagFullWeightGrams ??
              slot.remainingGrams,
          'current_net_weight_g': slot.remainingGrams,
          'tare_weight_g': slot.tareWeightGrams,
          'purchase_date': slot.purchaseDate
              ?.toIso8601String()
              .split('T')
              .first,
          'batch_number': slot.batchNumber,
          'status': 'loaded',
          'notes': slot.notes,
        },
      );
      await _queueMutation(
        type: 'printer_slot',
        id: slot.serverSlotId!,
        baseVersion: slot.serverSlotVersion,
        priority: 50,
        data: {
          'printer_id': printer.serverId,
          'slot_number': slot.position,
          'loaded_spool_id': slot.serverSpoolId,
        },
      );
    }
  }

  Future<void> _queueMutation({
    required String type,
    required String id,
    String operation = 'upsert',
    required int baseVersion,
    required Map<String, dynamic> data,
    required int priority,
  }) async {
    final db = await repository.database;
    final existing = await db.query(
      'sync_outbox',
      where: 'entity_type = ? AND entity_id = ?',
      whereArgs: [type, id],
      limit: 1,
    );
    final mutationId = existing.isEmpty
        ? _uuid.v4()
        : existing.first['mutation_id']! as String;
    final oldPayload = existing.isEmpty
        ? null
        : _map(jsonDecode(existing.first['payload']! as String));
    final mutation = <String, dynamic>{
      'clientMutationId': mutationId,
      'type': type,
      'id': id,
      'operation': operation,
      'baseVersion': oldPayload?['baseVersion'] ?? baseVersion,
      'data': data,
    };
    await db.insert('sync_outbox', {
      'mutation_id': mutationId,
      'entity_type': type,
      'entity_id': id,
      'priority': priority,
      'payload': jsonEncode(mutation),
      'created_at': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  List<PrinterRecord> _decodeSnapshot(Map<String, dynamic> snapshot) {
    final manufacturers = {
      for (final row in _list(snapshot['manufacturers']))
        row['id'].toString(): row,
    };
    final materials = {
      for (final row in _list(snapshot['materials'])) row['id'].toString(): row,
    };
    final spools = {
      for (final row in _list(snapshot['spools'])) row['id'].toString(): row,
    };
    final locations = {
      for (final row in _list(snapshot['locations'])) row['id'].toString(): row,
    };
    final slotsByPrinter = <String, List<Map<String, dynamic>>>{};
    for (final slot in _list(snapshot['printerSlots'])) {
      slotsByPrinter
          .putIfAbsent(slot['printer_id'].toString(), () => [])
          .add(slot);
    }
    return _list(snapshot['printers'])
        .map((printer) {
          final slotRows = slotsByPrinter[printer['id'].toString()] ?? [];
          slotRows.sort(
            (a, b) =>
                _integer(a['slot_number'])
                    .compareTo(_integer(b['slot_number'])),
          );
          final slots = <FilamentSlot>[];
          for (final row in slotRows) {
            final spoolId = row['loaded_spool_id']?.toString();
            final spool = spoolId == null ? null : spools[spoolId];
            if (spool == null) continue;
            final material = materials[spool['material_id']?.toString()];
            if (material == null) continue;
            final manufacturer =
                manufacturers[material['manufacturer_id']?.toString()];
            final location = locations[spool['location_id']?.toString()];
            slots.add(
              FilamentSlot(
                position: _integer(
                  row['slot_number'],
                  fallback: slots.length + 1,
                ),
                material: material['material_type']?.toString() ?? '',
                colorName: material['color_name']?.toString() ?? '',
                colorValue: _parseColor(material['color_hex']?.toString()),
                remainingGrams: _number(spool['current_net_weight_g']),
                tagUid: spool['tag_uid']?.toString(),
                tagInstanceId: spool['openprinttag_id']?.toString(),
                tagBrand: manufacturer?['name']?.toString(),
                manufacturer: manufacturer?['name']?.toString(),
                commercialName: material['commercial_name']?.toString(),
                diameterMm: _number(material['diameter_mm'], fallback: 1.75),
                originalWeightGrams: _nullableNumber(
                  spool['original_net_weight_g'],
                ),
                tareWeightGrams: _nullableNumber(spool['tare_weight_g']),
                purchaseDate: DateTime.tryParse(
                  spool['purchase_date']?.toString() ?? '',
                ),
                storageLocation: location?['name']?.toString(),
                storageLocationCode: location?['code']?.toString(),
                batchNumber: spool['batch_number']?.toString(),
                openPrintTagId: spool['openprinttag_id']?.toString(),
                notes: spool['notes']?.toString(),
                serverSlotId: row['id']?.toString(),
                serverSlotVersion: _integer(row['version']),
                serverMaterialId: material['id']?.toString(),
                serverMaterialVersion: _integer(material['version']),
                serverSpoolId: spool['id']?.toString(),
                serverSpoolVersion: _integer(spool['version']),
                serverManufacturerId: manufacturer?['id']?.toString(),
                serverManufacturerVersion: _integer(manufacturer?['version']),
                serverLocationId: location?['id']?.toString(),
                serverLocationVersion: _integer(location?['version']),
              ),
            );
          }
          return PrinterRecord(
            name: printer['name']?.toString() ?? '',
            manufacturer: printer['manufacturer']?.toString(),
            model: printer['model']?.toString(),
            description: printer['description']?.toString(),
            status: printer['status']?.toString() ?? 'active',
            serverId: printer['id']?.toString(),
            serverVersion: _integer(printer['version']),
            slots: slots,
          );
        })
        .where((printer) => printer.name.isNotEmpty)
        .toList();
  }

  Future<void> _markSynchronized(Map<String, dynamic> snapshot) async {
    lastSyncAt = DateTime.now().toUtc();
    await _preferences!.setString(
      'filament_server_last_sync',
      lastSyncAt!.toIso8601String(),
    );
    await _preferences!.setInt(
      'filament_server_cursor',
      _integer(snapshot['cursor']),
    );
  }

  Future<File?> _createSafetyBackup(List<PrinterRecord> printers) async {
    if (printers.isEmpty) return null;
    final directory = await getApplicationDocumentsDirectory();
    final backupDirectory = Directory(
      path.join(directory.path, 'sync-backups'),
    );
    await backupDirectory.create(recursive: true);
    final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
    final file = File(
      path.join(backupDirectory.path, 'before-server-sync-$stamp.json'),
    );
    return file.writeAsString(BackupService().encode(printers), flush: true);
  }

  Future<String> _validAccessToken() async {
    final expiry = DateTime.tryParse(
      _preferences!.getString('filament_server_access_expiry') ?? '',
    );
    final access = (await _loadTokenPair())?['access'];
    if (access != null &&
        expiry != null &&
        expiry.isAfter(
          DateTime.now().toUtc().add(const Duration(seconds: 30)),
        )) {
      return access;
    }
    return _refreshAccessToken();
  }

  Future<String> _accessToken() async {
    final token = (await _loadTokenPair())?['access'];
    if (token == null) {
      throw const FilamentServerException(
        'Not connected.',
        kind: FilamentServerErrorKind.authenticationRequired,
      );
    }
    return token;
  }

  Future<String> _refreshAccessToken() {
    final running = _activeTokenRefresh;
    if (running != null) return running;
    late final Future<String> operation;
    operation = _performTokenRefresh().whenComplete(() {
      if (identical(_activeTokenRefresh, operation)) {
        _activeTokenRefresh = null;
      }
    });
    _activeTokenRefresh = operation;
    return operation;
  }

  Future<String> _performTokenRefresh() async {
    final refresh = (await _loadTokenPair())?['refresh'];
    if (refresh == null) {
      throw const FilamentServerException(
        'Sign in to the server again.',
        kind: FilamentServerErrorKind.authenticationRequired,
      );
    }
    final auth = await _api.refresh(serverUrl, refresh);
    await _storeTokenPair(auth);
    return _accessToken();
  }

  Future<void> _storeTokenPair(Map<String, dynamic> auth) async {
    final access = auth['accessToken']?.toString();
    final refresh = auth['refreshToken']?.toString();
    if (access == null || refresh == null) {
      throw const FilamentServerException(
        'Invalid authentication response.',
        kind: FilamentServerErrorKind.invalidResponse,
      );
    }
    final encoded = jsonEncode({'access': access, 'refresh': refresh});
    await _secure.write(key: _sessionKey, value: encoded);
    final verified = await _secure.read(key: _sessionKey);
    if (verified != encoded) {
      throw const FilamentServerException(
        'Secure token storage verification failed.',
        kind: FilamentServerErrorKind.invalidResponse,
      );
    }
    _accessTokenCache = access;
    _refreshTokenCache = refresh;
    final ttl = _integer(auth['accessTokenExpiresIn'], fallback: 900);
    await _preferences!.setString(
      'filament_server_access_expiry',
      DateTime.now().toUtc().add(Duration(seconds: ttl)).toIso8601String(),
    );
  }

  Future<Map<String, String>?> _loadTokenPair() async {
    if (_accessTokenCache != null && _refreshTokenCache != null) {
      return {'access': _accessTokenCache!, 'refresh': _refreshTokenCache!};
    }
    final encoded = await _secure.read(key: _sessionKey);
    if (encoded == null || encoded.isEmpty) return null;
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map) return null;
      final access = decoded['access']?.toString();
      final refresh = decoded['refresh']?.toString();
      if (access == null ||
          access.isEmpty ||
          refresh == null ||
          refresh.isEmpty) {
        return null;
      }
      _accessTokenCache = access;
      _refreshTokenCache = refresh;
      return {'access': access, 'refresh': refresh};
    } on FormatException {
      return null;
    }
  }

  Future<void> _refreshCounts() async {
    final db = await repository.database;
    pendingCount =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM sync_outbox'),
        ) ??
        0;
    conflictCount =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM sync_conflicts'),
        ) ??
        0;
  }

  Future<void> _ensureTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_outbox (
        mutation_id TEXT PRIMARY KEY,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        priority INTEGER NOT NULL,
        payload TEXT NOT NULL,
        created_at TEXT NOT NULL,
        UNIQUE(entity_type, entity_id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_conflicts (
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        local_payload TEXT NOT NULL,
        server_payload TEXT NOT NULL,
        created_at TEXT NOT NULL,
        PRIMARY KEY(entity_type, entity_id)
      )
    ''');
  }

  static List<Map<String, dynamic>> _list(Object? value) => value is List
      ? value
            .whereType<Map>()
            .map((item) => item.cast<String, dynamic>())
            .toList()
      : const [];

  static Map<String, dynamic>? _map(Object? value) =>
      value is Map ? value.cast<String, dynamic>() : null;

  static int _integer(Object? value, {int fallback = 0}) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? fallback;

  static double _number(Object? value, {double fallback = 0}) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? fallback;

  static double? _nullableNumber(Object? value) => value == null
      ? null
      : value is num
      ? value.toDouble()
      : double.tryParse('$value');

  static String _colorHex(int value) =>
      '#${(value & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  static int _parseColor(String? value) {
    final hex = (value ?? '').replaceFirst('#', '');
    return hex.length == 6
        ? 0xFF000000 | (int.tryParse(hex, radix: 16) ?? 0x808080)
        : 0xFF808080;
  }
}
