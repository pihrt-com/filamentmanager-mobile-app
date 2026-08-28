import 'package:filamentmanager_mobile_app/sync/filament_server_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('server address is normalized without changing a subdirectory', () {
    final api = FilamentServerApi();

    expect(
      api.normalizeBaseUrl(' https://pihrt.com/filamentmanager/// '),
      'https://pihrt.com/filamentmanager',
    );
  });

  test('server address requires a scheme and host', () {
    final api = FilamentServerApi();

    expect(
      () => api.normalizeBaseUrl('pihrt.com/filamentmanager'),
      throwsA(isA<FilamentServerException>()),
    );
  });
}
