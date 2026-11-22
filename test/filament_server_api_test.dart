import 'dart:convert';

import 'package:filamentmanager_mobile_app/sync/filament_server_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

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

  test(
    'Restore Credentials uses the expected API routes and payloads',
    () async {
      final requests = <http.Request>[];
      final api = FilamentServerApi(
        client: MockClient((request) async {
          requests.add(request);
          if (request.url.path.endsWith('/registration/options') ||
              request.url.path.endsWith('/authentication/options')) {
            return http.Response(jsonEncode({'requestJson': '{}'}), 200);
          }
          if (request.url.path.endsWith('/authentication/complete')) {
            return http.Response(
              jsonEncode({'accessToken': 'access', 'refreshToken': 'refresh'}),
              201,
            );
          }
          return http.Response(jsonEncode({'ok': true}), 201);
        }),
      );

      await api.restoreRegistrationOptions('https://pihrt.com/server', 'token');
      await api.completeRestoreRegistration(
        'https://pihrt.com/server',
        'token',
        '{"id":"credential"}',
      );
      await api.restoreAuthenticationOptions(
        'https://pihrt.com/server',
        'user-id',
      );
      await api.completeRestoreAuthentication(
        'https://pihrt.com/server',
        userId: 'user-id',
        credentialJson: '{"id":"credential"}',
        appVersion: '1.5.0',
        deviceId: 'device-id',
      );

      expect(requests.map((request) => request.url.path), [
        '/server/api/v1/auth/restore/registration/options',
        '/server/api/v1/auth/restore/registration/complete',
        '/server/api/v1/auth/restore/authentication/options',
        '/server/api/v1/auth/restore/authentication/complete',
      ]);
      expect(requests[0].headers['authorization'], 'Bearer token');
      expect(requests[1].headers['authorization'], 'Bearer token');
      expect(jsonDecode(requests[1].body), {
        'credential': {'id': 'credential'},
      });
      expect(jsonDecode(requests[2].body), {'userId': 'user-id'});
      expect(jsonDecode(requests[3].body), {
        'userId': 'user-id',
        'credential': {'id': 'credential'},
        'deviceName': 'FilamentManager Android',
        'appVersion': '1.5.0',
        'deviceId': 'device-id',
      });
    },
  );
}
