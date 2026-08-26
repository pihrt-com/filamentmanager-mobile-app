import 'dart:io';
import 'dart:typed_data';

import 'package:filamentmanager_mobile_app/nfc/open_print_tag.dart';
import 'package:flutter_test/flutter_test.dart';

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
    expect(document.data.hasAuxRegion, isTrue);
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
