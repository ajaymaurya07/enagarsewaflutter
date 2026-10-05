import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'device_service.dart';
import 'pinned_http_client.dart';
import 'storage_service.dart';
import '../constants/app_constants.dart';

class IntegrityService {
  static const _channel = MethodChannel('com.enagarsewa.app/integrity');
  static const _storage = FlutterSecureStorage();

  static String get _verifyUrl =>
      '${AppConstants.baseUrl}api/house_tax/verify-integrity';
  static String get _iosVerifyUrl =>
      '${AppConstants.baseUrl}api/house_tax/ios-verify-integrity';
  static String get _nonceUrl =>
      '${AppConstants.baseUrl}api/Play_integrity/get_nonce';

// TODO: Set to false when the backend verify-integrity API goes live.
  static const bool _devMode = false; // PLAY INTEGRITY ENABLED

  // ─── Public API ────────────────────────────────────────────────────────────

  /// Checks secure storage first; skips the full verify flow if a cached
  /// integrity token already exists. Call this from the splash screen.
  static Future<bool> verify() async {
    if (_devMode) return true;
    final cached = await StorageService.getIntegrityToken();
    if (cached != null && cached.isNotEmpty) return true;
    return _runFullPlatformVerify();
  }

  /// Returns a valid integrity token, using the secure-storage cache when
  /// available. Runs the full verify flow only if no cached token exists.
  /// Call this before making payment API requests.
  static Future<String?> getValidToken() async {
    if (_devMode) return 'dev-mode-token';
    final cached = await StorageService.getIntegrityToken();
    if (cached != null && cached.isNotEmpty) return cached;
    final success = await _runFullPlatformVerify();
    if (!success) return null;
    return StorageService.getIntegrityToken();
  }

  /// Forces a full integrity re-verify, ignoring any cached token.
  /// Call this when a payment API responds with status_code 412.
  static Future<String?> refreshIntegrityToken() async {
    if (_devMode) return 'dev-mode-token';
    await StorageService.clearIntegrityToken();
    final success = await _runFullPlatformVerify();
    if (!success) return null;
    return StorageService.getIntegrityToken();
  }

  /// Runs the platform verify flow unconditionally (no cache check).
  static Future<bool> _runFullPlatformVerify() async {
    if (Platform.isAndroid) return _verifyAndroid();
    if (Platform.isIOS) return _verifyIos();
    return true;
  }

  // ─── Android — Play Integrity API ──────────────────────────────────────────

  /// Requests a Play Integrity token and sends it to the backend for
  /// server-side verification against the Google Play Integrity API.
  static Future<bool> _verifyAndroid() async {
    try {
      final nonce = await _fetchBackendNonce();
      if (nonce == null) return false;

      final token = await _channel.invokeMethod<String>(
        'getIntegrityToken',
        {'nonce': nonce},
      );
      if (token == null) return false;

      final integrityToken = await _sendToBackend(
        platform: 'android',
        payload: {'token': token, 'nonce': nonce},
      );
      if (integrityToken == null) return false;
      await StorageService.saveIntegrityToken(integrityToken);
      return true;
    } on PlatformException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Fetches a server-generated nonce for Play Integrity.
  /// API: POST api/Play_integrity/get_nonce (multipart/form-data)
  /// Shared by Android (Play Integrity) and iOS (App Attest).
  static Future<String?> _fetchBackendNonce() async {
    try {
      final deviceId = await DeviceService.getDeviceId();
      final request = http.MultipartRequest('POST', Uri.parse(_nonceUrl));
      request.fields['device_id'] = deviceId;
      request.headers['X-App-Version'] = AppConstants.apiVersion;

      final client = await PinnedHttpClient.getInstance();
      final streamedResponse = await client
          .send(request)
          .timeout(const Duration(seconds: 10));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final statusCode = data['status_code']?.toString() ?? '';
      final nonce = data['nonce'] as String?;

      if (statusCode != '200' || nonce == null || nonce.isEmpty) return null;

      return nonce;
    } catch (_) {
      return null;
    }
  }

  // ─── iOS — App Attest ──────────────────────────────────────────────────────

  static const _attestKeyIdKey = 'app_attest_key_id';

  /// Mirrors the Android flow: every attestation / assertion is bound to a
  /// one-time nonce issued by the backend (clientDataHash = SHA-256(nonce)).
  ///
  /// No stored key: generate an App Attest key, attest it with Apple, and send
  /// the attestation to the backend for one-time registration.
  /// Stored key: generate an assertion and send it for verification.
  /// If Apple reports the stored key as invalid (e.g. the app was reinstalled —
  /// the Keychain survives but the Secure Enclave key does not), or the backend
  /// no longer knows the key (status_code 409), the key is discarded and a
  /// fresh one is attested in the same call.
  static Future<bool> _verifyIos() async {
    try {
      final keyId = await _storage.read(key: _attestKeyIdKey);
      if (keyId != null) {
        try {
          return await _assertIos(keyId);
        } on PlatformException catch (e) {
          if (e.code != 'INVALID_KEY') rethrow;
          await _storage.delete(key: _attestKeyIdKey);
        } on _AttestKeyNotRegistered {
          await _storage.delete(key: _attestKeyIdKey);
        }
      }
      return await _attestIos();
    } on PlatformException catch (e) {
      if (e.code == 'NOT_SUPPORTED') {
        // Simulator / Mac. No integrity token is issued, so payment APIs stay
        // blocked; only the splash gate is let through.
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _attestIos() async {
    final keyId = await _channel.invokeMethod<String>('generateKey');
    if (keyId == null) return false;

    final nonce = await _fetchBackendNonce();
    if (nonce == null) return false;

    final attestation = await _withServerRetry(() => _channel.invokeMethod<String>(
          'attestKey',
          {'keyId': keyId, 'clientDataHash': _sha256Base64(nonce)},
        ));
    if (attestation == null) return false;

    final integrityToken = await _sendIosToBackend({
      'type': 'attestation',
      'key_id': keyId,
      'nonce': nonce,
      'attestation': attestation,
    });
    if (integrityToken == null) return false;

    // Persist keyId only after the backend has stored its public key.
    await _storage.write(key: _attestKeyIdKey, value: keyId);
    await StorageService.saveIntegrityToken(integrityToken);
    return true;
  }

  static Future<bool> _assertIos(String keyId) async {
    final nonce = await _fetchBackendNonce();
    if (nonce == null) return false;

    final assertion = await _channel.invokeMethod<String>(
      'generateAssertion',
      {'keyId': keyId, 'clientDataHash': _sha256Base64(nonce)},
    );
    if (assertion == null) return false;

    final integrityToken = await _sendIosToBackend({
      'type': 'assertion',
      'key_id': keyId,
      'nonce': nonce,
      'assertion': assertion,
    });
    if (integrityToken == null) return false;

    await StorageService.saveIntegrityToken(integrityToken);
    return true;
  }

  /// POSTs an App Attest attestation / assertion to
  /// api/house_tax/ios-verify-integrity and returns the backend-issued
  /// integrity_token, or null on failure.
  /// Throws [_AttestKeyNotRegistered] when the backend replies status_code 409.
  static Future<String?> _sendIosToBackend(Map<String, String> fields) async {
    final String body;
    try {
      final deviceId = await DeviceService.getDeviceId();
      final client = await PinnedHttpClient.getInstance();
      final response = await client
          .post(
            Uri.parse(_iosVerifyUrl),
            headers: {
              'Content-Type': 'application/x-www-form-urlencoded',
              'X-App-Version': AppConstants.apiVersion,
              'X-Device-Id': deviceId,
            },
            body: fields,
          )
          .timeout(const Duration(seconds: 10));
      body = response.body;
    } catch (_) {
      return null;
    }

    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      final statusCode = data['status_code']?.toString() ?? '';
      if (statusCode == '409') throw const _AttestKeyNotRegistered();
      if (statusCode != '200') return null;
      final token = data['integrity_token'] as String?;
      return (token == null || token.isEmpty) ? null : token;
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  /// Apple recommends retrying attestKey with the same key when its servers
  /// are temporarily unavailable, instead of generating a new key.
  static Future<T?> _withServerRetry<T>(Future<T?> Function() fn) async {
    for (var attempt = 0; ; attempt++) {
      try {
        return await fn();
      } on PlatformException catch (e) {
        if (e.code != 'SERVER_UNAVAILABLE' || attempt >= 2) rethrow;
        await Future.delayed(Duration(seconds: 1 << attempt));
      }
    }
  }

  // ─── Backend communication ─────────────────────────────────────────────────

  /// POSTs the integrity payload to the backend and returns the
  /// backend-issued integrity_token on success, or null on failure.
  static Future<String?> _sendToBackend({
    required String platform,
    required Map<String, String> payload,
  }) async {
    if (_devMode) return 'dev-mode-token';
    try {
      final deviceId = await DeviceService.getDeviceId();
      final fields = {'platform': platform, ...payload};
      final headers = {
        'Content-Type': 'application/x-www-form-urlencoded',
        'X-App-Version': AppConstants.apiVersion,
        'X-Device-Id': deviceId,
      };

      final client = await PinnedHttpClient.getInstance();
      final response = await client
          .post(
            Uri.parse(_verifyUrl),
            headers: headers,
            body: fields,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final statusCode = data['status_code']?.toString() ?? '';
        if (statusCode != '200') return null;
        return data['integrity_token'] as String?;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  /// Returns the standard Base64-encoded SHA-256 hash of [input].
  /// Used as clientDataHash for App Attest (must decode to exactly 32 bytes).
  static String _sha256Base64(String input) {
    final digest = sha256.convert(utf8.encode(input));
    return base64.encode(digest.bytes);
  }
}

/// Backend has no public key for the App Attest keyId sent in an assertion.
class _AttestKeyNotRegistered implements Exception {
  const _AttestKeyNotRegistered();
}
