import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

void main() {
  test('English and Czech XML catalogs contain the same keys', () async {
    Future<Set<String>> keys(String path) async {
      final document = XmlDocument.parse(await File(path).readAsString());
      return document
          .findAllElements('string')
          .map((element) => element.getAttribute('name'))
          .whereType<String>()
          .toSet();
    }

    final english = await keys('assets/i18n/values/strings.xml');
    final czech = await keys('assets/i18n/values-cs/strings.xml');
    expect(english, isNotEmpty);
    expect(czech, english);
  });
}
