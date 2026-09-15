import 'dart:io';
import 'dart:typed_data';

import 'package:cbor/simple.dart';
import 'package:filamentmanager_mobile_app/nfc/open_print_tag.dart';
import 'package:flutter_test/flutter_test.dart';

const _cbor = CborSimpleCodec(parseDateTime: false, parseUri: false);

void main() {
  test('decodes the official OpenPrintTag NFC-V test vector', () {
    final memory = File('test/fixtures/openprinttag_01.bin').readAsBytesSync();
    final document = const OpenPrintTagCodec().decode(
      memory,
      Uint8List.fromList([0xE0, 0x04, 0x01, 0x08, 0x66, 0x2F, 0x6F, 0xBC]),
    );

    expect(document.data.uid, 'E0040108662F6FBC');
    expect(document.data.material, 'PLA');
    expect(document.data.materialName, 'PLA Prusa Galaxy Black');
    expect(document.data.brand, 'Prusament');
    expect(document.data.colorValue, 0xFF3D3E3D);
    expect(document.data.fullWeightGrams, 1012);
    expect(document.data.consumedWeightGrams, 0);
    expect(document.data.remainingWeightGrams, 1012);
    expect(document.data.emptyContainerWeightGrams, 280);
    expect(document.data.filamentDiameterMm, isNull);
    expect(document.data.hasAuxRegion, isTrue);
  });

  test('decodes all supported spool metadata and current diameter key', () {
    final purchaseTime = DateTime.utc(2026, 9, 10);
    final document = const OpenPrintTagCodec().decode(
      _completeTagMemory(purchaseTime),
      Uint8List.fromList([0xE0, 0x04, 0x01, 0x08, 0x66, 0x2F, 0x6F, 0xBC]),
    );

    expect(document.data.brand, 'Prusament');
    expect(document.data.materialName, 'PLA Galaxy Black');
    expect(document.data.fullWeightGrams, 1012);
    expect(document.data.emptyContainerWeightGrams, 201);
    expect(document.data.filamentDiameterMm, 1.75);
    expect(document.data.brandSpecificInstanceId, 'LOT-2026-09');
    expect(document.data.instanceId, '00010203-0405-0607-0809-0a0b0c0d0e0f');
    expect(document.data.purchaseTime, purchaseTime);
    expect(document.data.remainingWeightGrams, 500);
  });

  test('ignores malformed optional numbers without losing core tag data', () {
    final document = const OpenPrintTagCodec().decode(
      _completeTagMemory(double.infinity, diameter: double.infinity),
      Uint8List.fromList([0xE0, 0x04, 0x01, 0x08, 0x66, 0x2F, 0x6F, 0xBC]),
    );

    expect(document.data.material, 'PLA');
    expect(document.data.brand, 'Prusament');
    expect(document.data.remainingWeightGrams, 500);
    expect(document.data.filamentDiameterMm, isNull);
    expect(document.data.purchaseTime, isNull);
  });

  test('updates only blocks inside the official auxiliary region', () {
    final memory = File('test/fixtures/openprinttag_01.bin').readAsBytesSync();
    final document = const OpenPrintTagCodec().decode(
      memory,
      Uint8List.fromList([0xE0, 0x04, 0x01, 0x08, 0x66, 0x2F, 0x6F, 0xBC]),
    );

    final blocks = document.blocksForRemainingWeight(500);

    expect(blocks, isNotEmpty);
    expect(blocks.keys.every((block) => block >= 69), isTrue);
    expect(blocks.keys.every((block) => block <= 77), isTrue);

    final updatedMemory = Uint8List.fromList(memory);
    for (final entry in blocks.entries) {
      updatedMemory.setRange(entry.key * 4, entry.key * 4 + 4, entry.value);
    }
    final verified = const OpenPrintTagCodec().decode(
      updatedMemory,
      Uint8List.fromList([0xE0, 0x04, 0x01, 0x08, 0x66, 0x2F, 0x6F, 0xBC]),
    );
    expect(verified.data.consumedWeightGrams, 512);
    expect(verified.data.remainingWeightGrams, 500);
  });
}

Uint8List _completeTagMemory(Object purchaseTime, {Object diameter = 1750}) {
  final main = _cbor.encode({
    0: Uint8List.fromList(List<int>.generate(16, (index) => index)),
    5: 'LOT-2026-09',
    9: 0,
    10: 'PLA Galaxy Black',
    11: 'Prusament',
    17: 1012,
    18: 201,
    19: Uint8List.fromList([0x3D, 0x3E, 0x3D]),
    61: diameter,
  });
  final aux = _cbor.encode({
    0: 512,
    5: purchaseTime is DateTime
        ? purchaseTime.millisecondsSinceEpoch ~/ 1000
        : purchaseTime,
  });
  const mainOffset = 16;
  const mainSize = 160;
  const auxOffset = mainOffset + mainSize;
  const auxSize = 64;
  final payload = Uint8List(auxOffset + auxSize);
  final meta = _cbor.encode({
    0: mainOffset,
    1: mainSize,
    2: auxOffset,
    3: auxSize,
  });
  payload.setRange(0, meta.length, meta);
  payload.setRange(mainOffset, mainOffset + main.length, main);
  payload.setRange(auxOffset, auxOffset + aux.length, aux);

  final type = 'application/vnd.openprinttag'.codeUnits;
  final message = <int>[
    0xC2,
    type.length,
    0,
    0,
    0,
    payload.length,
    ...type,
    ...payload,
  ];
  final memory = Uint8List(512);
  memory.setRange(0, 4, [0xE1, 0x40, 64, 0x01]);
  memory.setRange(4, 8, [
    0x03,
    0xFF,
    message.length >> 8,
    message.length & 0xFF,
  ]);
  memory.setRange(8, 8 + message.length, message);
  memory[8 + message.length] = 0xFE;
  return memory;
}
