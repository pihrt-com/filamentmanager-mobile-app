import 'package:filamentmanager_mobile_app/platform/android_services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('public servers do not require local-network access', () {
    expect(
      requiresLocalNetworkAccess('https://pihrt.com/filamentmanager'),
      isFalse,
    );
    expect(requiresLocalNetworkAccess('http://203.0.113.20:8080'), isFalse);
  });

  test('private addresses require local-network access', () {
    for (final url in [
      'http://192.168.1.20',
      'http://10.0.0.2:8080',
      'http://172.31.4.5/server',
      'http://printer.local',
      'http://filamentmanager',
      'http://[fd00::1234]',
    ]) {
      expect(requiresLocalNetworkAccess(url), isTrue, reason: url);
    }
  });
}
