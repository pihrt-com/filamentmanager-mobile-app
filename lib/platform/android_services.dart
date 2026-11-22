import 'dart:io';

import 'package:flutter/services.dart';

bool requiresLocalNetworkAccess(String url) {
  final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
  if (host.isEmpty) return false;
  if (host == 'localhost' ||
      !host.contains('.') ||
      host.endsWith('.local') ||
      host.endsWith('.lan') ||
      host.endsWith('.home') ||
      host.endsWith('.home.arpa')) {
    return true;
  }
  final address = InternetAddress.tryParse(host);
  if (address == null) return false;
  if (address.isLoopback || address.isLinkLocal) return true;
  final bytes = address.rawAddress;
  if (address.type == InternetAddressType.IPv4) {
    return bytes[0] == 10 ||
        (bytes[0] == 172 && bytes[1] >= 16 && bytes[1] <= 31) ||
        (bytes[0] == 192 && bytes[1] == 168);
  }
  return (bytes[0] & 0xfe) == 0xfc;
}

class AndroidServices {
  const AndroidServices();

  static const _channel = MethodChannel(
    'com.pihrt.filamentmanager.mobile/android',
  );

  Future<bool> requestLocalNetworkAccess() async {
    if (!Platform.isAndroid) return true;
    return await _channel.invokeMethod<bool>('requestLocalNetworkAccess') ??
        false;
  }

  Future<String> createRestoreCredential(String requestJson) async {
    final response = await _channel.invokeMethod<String>(
      'createRestoreCredential',
      {'requestJson': requestJson},
    );
    if (response == null || response.isEmpty) {
      throw PlatformException(
        code: 'empty_restore_response',
        message: 'Credential Manager returned an empty registration response.',
      );
    }
    return response;
  }

  Future<String> getRestoreCredential(String requestJson) async {
    final response = await _channel.invokeMethod<String>(
      'getRestoreCredential',
      {'requestJson': requestJson},
    );
    if (response == null || response.isEmpty) {
      throw PlatformException(
        code: 'empty_restore_response',
        message:
            'Credential Manager returned an empty authentication response.',
      );
    }
    return response;
  }

  Future<void> clearRestoreCredential() async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('clearRestoreCredential');
  }
}
