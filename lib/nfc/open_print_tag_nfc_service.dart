import 'dart:async';
import 'dart:typed_data';

import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';

import 'open_print_tag.dart';

class OpenPrintTagNfcService {
  OpenPrintTagNfcService([this._codec = const OpenPrintTagCodec()]);

  final OpenPrintTagCodec _codec;

  Future<OpenPrintTagData> read() async {
    final result = await _scan((tag) async {
      final reader = _NfcVReader.from(tag);
      final memory = await reader.readMemory();
      return _codec.decode(memory, reader.uid).data;
    });
    return result;
  }

  Future<OpenPrintTagData> writeRemainingWeight({
    required String expectedUid,
    required String? expectedInstanceId,
    required double remainingGrams,
  }) async {
    return _scan((tag) async {
      final reader = _NfcVReader.from(tag);
      final before = _codec.decode(await reader.readMemory(), reader.uid);
      if (before.data.uid != expectedUid ||
          (expectedInstanceId != null &&
              before.data.instanceId != expectedInstanceId)) {
        throw const OpenPrintTagException(OpenPrintTagError.differentTag);
      }
      final blocks = before.blocksForRemainingWeight(remainingGrams);
      for (final entry in blocks.entries) {
        await reader.writeBlock(entry.key, entry.value);
      }

      final verified = _codec.decode(await reader.readMemory(), reader.uid);
      final actual = verified.data.remainingWeightGrams;
      if (actual == null || (actual - remainingGrams).abs() > 0.01) {
        throw const OpenPrintTagException(OpenPrintTagError.writeFailed);
      }
      return verified.data;
    });
  }

  Future<T> _scan<T>(Future<T> Function(NfcTag tag) operation) async {
    final availability = await NfcManager.instance.checkAvailability();
    if (availability == NfcAvailability.unsupported) {
      throw const OpenPrintTagException(OpenPrintTagError.nfcUnsupported);
    }
    if (availability == NfcAvailability.disabled) {
      throw const OpenPrintTagException(OpenPrintTagError.nfcDisabled);
    }

    final completer = Completer<T>();
    var handlingTag = false;
    late final Timer timer;
    timer = Timer(const Duration(seconds: 30), () async {
      if (!completer.isCompleted) {
        completer.completeError(
          const OpenPrintTagException(OpenPrintTagError.scanTimeout),
        );
        await NfcManager.instance.stopSession();
      }
    });
    try {
      await NfcManager.instance.startSession(
        pollingOptions: const {NfcPollingOption.iso15693},
        onDiscovered: (tag) async {
          if (handlingTag || completer.isCompleted) return;
          handlingTag = true;
          try {
            completer.complete(await operation(tag));
          } on OpenPrintTagException catch (error, stackTrace) {
            completer.completeError(error, stackTrace);
          } catch (error, stackTrace) {
            completer.completeError(
              OpenPrintTagException(OpenPrintTagError.invalidTag, error),
              stackTrace,
            );
          } finally {
            await NfcManager.instance.stopSession();
          }
        },
      );
      return await completer.future;
    } finally {
      timer.cancel();
    }
  }
}

class _NfcVReader {
  const _NfcVReader(this._technology, this.uid, this._wireUid);

  factory _NfcVReader.from(NfcTag tag) {
    final technology = NfcVAndroid.from(tag);
    final androidTag = NfcTagAndroid.from(tag);
    if (technology == null || androidTag == null || androidTag.id.length != 8) {
      throw const OpenPrintTagException(OpenPrintTagError.notNfcV);
    }
    final raw = Uint8List.fromList(androidTag.id);
    final normalized = raw.first == 0xE0
        ? raw
        : Uint8List.fromList(raw.reversed.toList());
    final wireUid = Uint8List.fromList(normalized.reversed.toList());
    return _NfcVReader(technology, normalized, wireUid);
  }

  final NfcVAndroid _technology;
  final Uint8List uid;
  final Uint8List _wireUid;

  Future<Uint8List> readMemory() async {
    final firstBlock = await _readSingleBlock(0);
    if (firstBlock.length != 4 || firstBlock[0] != 0xE1) {
      throw const OpenPrintTagException(OpenPrintTagError.invalidTag);
    }
    final capacity = firstBlock[2] * 8;
    if (capacity < 8 || capacity > 2040 || capacity % 4 != 0) {
      throw const OpenPrintTagException(OpenPrintTagError.invalidTag);
    }
    final blockCount = capacity ~/ 4;
    final memory = BytesBuilder(copy: false)..add(firstBlock);
    var block = 1;
    while (block < blockCount) {
      final count = (blockCount - block).clamp(1, 16);
      try {
        memory.add(await _readMultipleBlocks(block, count));
        block += count;
      } catch (_) {
        memory.add(await _readSingleBlock(block));
        block++;
      }
    }
    return memory.takeBytes();
  }

  Future<void> writeBlock(int block, Uint8List bytes) async {
    if (bytes.length != 4 || block < 0 || block > 255) {
      throw const OpenPrintTagException(OpenPrintTagError.writeFailed);
    }
    final response = await _technology.transceive(
      Uint8List.fromList([0x22, 0x21, ..._wireUid, block, ...bytes]),
    );
    _checkResponse(response, OpenPrintTagError.writeFailed);
  }

  Future<Uint8List> _readSingleBlock(int block) async {
    final response = await _technology.transceive(
      Uint8List.fromList([0x22, 0x20, ..._wireUid, block]),
    );
    _checkResponse(response, OpenPrintTagError.invalidTag);
    if (response.length != 5) {
      throw const OpenPrintTagException(OpenPrintTagError.invalidTag);
    }
    return Uint8List.fromList(response.sublist(1));
  }

  Future<Uint8List> _readMultipleBlocks(int firstBlock, int count) async {
    final response = await _technology.transceive(
      Uint8List.fromList([0x22, 0x23, ..._wireUid, firstBlock, count - 1]),
    );
    _checkResponse(response, OpenPrintTagError.invalidTag);
    if (response.length != 1 + count * 4) {
      throw const OpenPrintTagException(OpenPrintTagError.invalidTag);
    }
    return Uint8List.fromList(response.sublist(1));
  }

  void _checkResponse(Uint8List response, OpenPrintTagError error) {
    if (response.isEmpty || response[0] & 0x01 != 0) {
      throw OpenPrintTagException(
        error,
        response.length > 1 ? response[1] : null,
      );
    }
  }
}
