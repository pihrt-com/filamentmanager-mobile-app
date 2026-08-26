import 'dart:typed_data';

import 'package:cbor/simple.dart';

const _mimeType = 'application/vnd.openprinttag';
const _cbor = CborSimpleCodec(parseDateTime: false, parseUri: false);

class OpenPrintTagData {
  const OpenPrintTagData({
    required this.uid,
    required this.material,
    required this.materialName,
    required this.brand,
    required this.colorValue,
    required this.fullWeightGrams,
    required this.consumedWeightGrams,
    required this.remainingWeightGrams,
    required this.instanceId,
    required this.hasAuxRegion,
  });

  final String uid;
  final String material;
  final String? materialName;
  final String? brand;
  final int? colorValue;
  final double? fullWeightGrams;
  final double consumedWeightGrams;
  final double? remainingWeightGrams;
  final String? instanceId;
  final bool hasAuxRegion;
}

class OpenPrintTagDocument {
  OpenPrintTagDocument._({
    required this.data,
    required this.memory,
    required this.auxOffset,
    required this.auxSize,
    required this.auxValues,
  });

  final OpenPrintTagData data;
  final Uint8List memory;
  final int? auxOffset;
  final int? auxSize;
  final Map<Object?, Object?> auxValues;

  Map<int, Uint8List> blocksForRemainingWeight(
    double remainingGrams, {
    int blockSize = 4,
  }) {
    final fullWeight = data.fullWeightGrams;
    if (auxOffset == null || auxSize == null || fullWeight == null) {
      throw const OpenPrintTagException(OpenPrintTagError.notWritable);
    }
    if (!remainingGrams.isFinite ||
        remainingGrams < 0 ||
        remainingGrams > fullWeight) {
      throw const OpenPrintTagException(OpenPrintTagError.invalidWeight);
    }

    final updated = Map<Object?, Object?>.of(auxValues);
    final consumed = fullWeight - remainingGrams;
    updated[0] = consumed == consumed.roundToDouble()
        ? consumed.toInt()
        : double.parse(consumed.toStringAsFixed(3));
    final encoded = Uint8List.fromList(_cbor.encode(updated));
    if (encoded.length > auxSize!) {
      throw const OpenPrintTagException(OpenPrintTagError.auxRegionFull);
    }

    final changedByteOffsets = <int>[];
    for (var index = 0; index < encoded.length; index++) {
      final absolute = auxOffset! + index;
      if (memory[absolute] != encoded[index]) changedByteOffsets.add(absolute);
    }
    if (changedByteOffsets.isEmpty) return const {};

    final firstBlock = changedByteOffsets.first ~/ blockSize;
    final lastBlock = changedByteOffsets.last ~/ blockSize;
    final result = <int, Uint8List>{};
    for (var block = firstBlock; block <= lastBlock; block++) {
      final start = block * blockSize;
      final bytes = Uint8List.fromList(
        memory.sublist(start, start + blockSize),
      );
      for (var index = 0; index < blockSize; index++) {
        final absolute = start + index;
        final relative = absolute - auxOffset!;
        if (relative >= 0 && relative < encoded.length) {
          bytes[index] = encoded[relative];
        }
      }
      if (!_listEquals(bytes, memory.sublist(start, start + blockSize))) {
        result[block] = bytes;
      }
    }
    return result;
  }
}

enum OpenPrintTagError {
  nfcUnsupported,
  nfcDisabled,
  scanTimeout,
  notNfcV,
  invalidTag,
  notOpenPrintTag,
  corruptData,
  noAuxRegion,
  notWritable,
  invalidWeight,
  auxRegionFull,
  differentTag,
  writeFailed,
}

class OpenPrintTagException implements Exception {
  const OpenPrintTagException(this.error, [this.details]);

  final OpenPrintTagError error;
  final Object? details;

  @override
  String toString() => 'OpenPrintTagException($error, $details)';
}

class OpenPrintTagCodec {
  const OpenPrintTagCodec();

  OpenPrintTagDocument decode(Uint8List memory, Uint8List uid) {
    try {
      final payloadLocation = _findPayload(memory);
      final payload = memory.sublist(
        payloadLocation.offset,
        payloadLocation.offset + payloadLocation.length,
      );
      final metaLength = _cborItemLength(payload, 0);
      final meta = _decodeMap(payload.sublist(0, metaLength));

      final mainRelative = _asInt(meta[0]) ?? metaLength;
      final auxRelative = _asInt(meta[2]);
      final mainSize =
          _asInt(meta[1]) ??
          _nextRegionStop(mainRelative, auxRelative, payload.length) -
              mainRelative;
      final mainLength = _cborItemLength(payload, mainRelative);
      if (mainLength > mainSize) {
        throw const FormatException('Main region exceeds its allocation.');
      }
      final main = _decodeMap(
        payload.sublist(mainRelative, mainRelative + mainLength),
      );

      var aux = <Object?, Object?>{};
      int? auxSize;
      if (auxRelative != null) {
        auxSize =
            _asInt(meta[3]) ??
            _nextRegionStop(auxRelative, mainRelative, payload.length) -
                auxRelative;
        final auxUsedSize = _cborItemLength(payload, auxRelative);
        if (auxUsedSize > auxSize) {
          throw const FormatException('Aux region exceeds its allocation.');
        }
        aux = _decodeMap(
          payload.sublist(auxRelative, auxRelative + auxUsedSize),
        );
      }

      final normalizedUid = _normalizeUid(uid);
      final fullWeight = _asDouble(main[17]) ?? _asDouble(main[16]);
      final consumed = _asDouble(aux[0]) ?? 0;
      final color = _asBytes(main[19]);
      final materialType = _asInt(main[9]);
      final materialName = main[10] is String ? main[10] as String : null;
      final material = _materialTypes[materialType] ?? materialName ?? '';
      final instanceBytes = _asBytes(main[0]);
      final data = OpenPrintTagData(
        uid: _hex(normalizedUid),
        material: material,
        materialName: materialName,
        brand: main[11] is String ? main[11] as String : null,
        colorValue: _colorArgb(color),
        fullWeightGrams: fullWeight,
        consumedWeightGrams: consumed,
        remainingWeightGrams: fullWeight == null
            ? null
            : (fullWeight - consumed).clamp(0, double.infinity),
        instanceId: instanceBytes?.length == 16 ? _uuid(instanceBytes!) : null,
        hasAuxRegion: auxRelative != null,
      );
      return OpenPrintTagDocument._(
        data: data,
        memory: memory,
        auxOffset: auxRelative == null
            ? null
            : payloadLocation.offset + auxRelative,
        auxSize: auxSize,
        auxValues: aux,
      );
    } on OpenPrintTagException {
      rethrow;
    } on FormatException catch (error) {
      throw OpenPrintTagException(OpenPrintTagError.corruptData, error);
    } on RangeError catch (error) {
      throw OpenPrintTagException(OpenPrintTagError.corruptData, error);
    }
  }

  _PayloadLocation _findPayload(Uint8List memory) {
    if (memory.length < 8 || memory[0] != 0xE1) {
      throw const OpenPrintTagException(OpenPrintTagError.invalidTag);
    }
    var offset = 4;
    while (offset < memory.length) {
      final tag = memory[offset++];
      if (tag == 0x00) continue;
      if (tag == 0xFE) break;
      if (offset >= memory.length) break;
      var length = memory[offset++];
      if (length == 0xFF) {
        if (offset + 2 > memory.length) break;
        length = (memory[offset] << 8) | memory[offset + 1];
        offset += 2;
      }
      if (offset + length > memory.length) {
        throw const OpenPrintTagException(OpenPrintTagError.corruptData);
      }
      if (tag == 0x03) return _findNdefRecord(memory, offset, length);
      offset += length;
    }
    throw const OpenPrintTagException(OpenPrintTagError.notOpenPrintTag);
  }

  _PayloadLocation _findNdefRecord(
    Uint8List memory,
    int messageOffset,
    int messageLength,
  ) {
    var offset = messageOffset;
    final end = messageOffset + messageLength;
    while (offset < end) {
      final header = memory[offset++];
      final shortRecord = header & 0x10 != 0;
      final hasId = header & 0x08 != 0;
      final typeLength = memory[offset++];
      int payloadLength;
      if (shortRecord) {
        payloadLength = memory[offset++];
      } else {
        payloadLength =
            (memory[offset] << 24) |
            (memory[offset + 1] << 16) |
            (memory[offset + 2] << 8) |
            memory[offset + 3];
        offset += 4;
      }
      final idLength = hasId ? memory[offset++] : 0;
      final type = String.fromCharCodes(
        memory.sublist(offset, offset + typeLength),
      );
      offset += typeLength + idLength;
      if (offset + payloadLength > end) {
        throw const OpenPrintTagException(OpenPrintTagError.corruptData);
      }
      if ((header & 0x07) == 0x02 && type == _mimeType) {
        return _PayloadLocation(offset, payloadLength);
      }
      offset += payloadLength;
    }
    throw const OpenPrintTagException(OpenPrintTagError.notOpenPrintTag);
  }
}

class _PayloadLocation {
  const _PayloadLocation(this.offset, this.length);
  final int offset;
  final int length;
}

Map<Object?, Object?> _decodeMap(List<int> bytes) {
  final value = _cbor.decode(bytes);
  if (value is! Map) throw const FormatException('Expected a CBOR map.');
  return Map<Object?, Object?>.from(value);
}

int _cborItemLength(List<int> bytes, int start) {
  var offset = start;
  int readLength(int additional) {
    if (additional < 24) return additional;
    if (additional == 24) return bytes[offset++];
    if (additional == 25) {
      final value = (bytes[offset] << 8) | bytes[offset + 1];
      offset += 2;
      return value;
    }
    if (additional == 26) {
      final value =
          (bytes[offset] << 24) |
          (bytes[offset + 1] << 16) |
          (bytes[offset + 2] << 8) |
          bytes[offset + 3];
      offset += 4;
      return value;
    }
    if (additional == 27) {
      final high =
          (bytes[offset] << 24) |
          (bytes[offset + 1] << 16) |
          (bytes[offset + 2] << 8) |
          bytes[offset + 3];
      final low =
          (bytes[offset + 4] << 24) |
          (bytes[offset + 5] << 16) |
          (bytes[offset + 6] << 8) |
          bytes[offset + 7];
      offset += 8;
      return high * 0x100000000 + (low & 0xFFFFFFFF);
    }
    throw const FormatException('Invalid CBOR length.');
  }

  void scan() {
    final initial = bytes[offset++];
    final major = initial >> 5;
    final additional = initial & 0x1F;
    if (additional == 31) {
      if (major != 2 && major != 3 && major != 4 && major != 5) {
        throw const FormatException('Invalid indefinite CBOR item.');
      }
      while (bytes[offset] != 0xFF) {
        scan();
        if (major == 5) scan();
      }
      offset++;
      return;
    }
    final length = readLength(additional);
    if (major == 2 || major == 3) {
      offset += length;
    } else if (major == 4) {
      for (var index = 0; index < length; index++) {
        scan();
      }
    } else if (major == 5) {
      for (var index = 0; index < length; index++) {
        scan();
        scan();
      }
    } else if (major == 6) {
      scan();
    }
  }

  scan();
  return offset - start;
}

int _nextRegionStop(int offset, int? otherOffset, int payloadLength) {
  final candidates = [payloadLength, ?otherOffset]
    ..removeWhere((value) => value <= offset)
    ..sort();
  if (candidates.isEmpty) throw const FormatException('Invalid region offset.');
  return candidates.first;
}

int? _asInt(Object? value) => value is num ? value.toInt() : null;
double? _asDouble(Object? value) => value is num ? value.toDouble() : null;
Uint8List? _asBytes(Object? value) {
  if (value is Uint8List) return value;
  if (value is List<int>) return Uint8List.fromList(value);
  return null;
}

Uint8List _normalizeUid(Uint8List uid) {
  if (uid.length == 8 && uid.first == 0xE0) return Uint8List.fromList(uid);
  if (uid.length == 8 && uid.last == 0xE0) {
    return Uint8List.fromList(uid.reversed.toList());
  }
  return Uint8List.fromList(uid);
}

String _hex(List<int> bytes) => bytes
    .map((value) => value.toRadixString(16).padLeft(2, '0'))
    .join()
    .toUpperCase();

String _uuid(List<int> bytes) {
  final hex = _hex(bytes).toLowerCase();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
      '${hex.substring(20)}';
}

int? _colorArgb(Uint8List? bytes) {
  if (bytes == null || bytes.length < 3) return null;
  final alpha = bytes.length >= 4 ? bytes[3] : 0xFF;
  return (alpha << 24) | (bytes[0] << 16) | (bytes[1] << 8) | bytes[2];
}

bool _listEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var index = 0; index < a.length; index++) {
    if (a[index] != b[index]) return false;
  }
  return true;
}

const _materialTypes = <int, String>{
  0: 'PLA',
  1: 'PETG',
  2: 'TPU',
  3: 'ABS',
  4: 'ASA',
  5: 'PC',
  6: 'PCTG',
  7: 'PP',
  8: 'PA6',
  9: 'PA11',
  10: 'PA12',
  11: 'PA66',
  12: 'CPE',
  13: 'TPE',
  14: 'HIPS',
  15: 'PHA',
  16: 'PET',
  17: 'PEI',
  18: 'PBT',
  19: 'PVB',
  20: 'PVA',
  21: 'PEKK',
  22: 'PEEK',
  23: 'BVOH',
  24: 'TPC',
  25: 'PPS',
  26: 'PPSU',
  27: 'PVC',
  28: 'PEBA',
  29: 'PVDF',
  30: 'PPA',
  31: 'PCL',
  32: 'PES',
  33: 'PMMA',
  34: 'POM',
  35: 'PPE',
  36: 'PS',
  37: 'PSU',
  38: 'TPI',
  39: 'SBS',
  40: 'OBC',
  41: 'EVA',
  42: 'PA612',
};
