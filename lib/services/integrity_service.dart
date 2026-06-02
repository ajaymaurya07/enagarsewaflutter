import 'dart:convert';
import 'dart:io';
import 'dart:math';

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
  static String get _nonceUrl =>
      '${AppConstants.baseUrl}api/Play_integrity/get_nonce';

// TODO: navigate to relevant screen based on message.data
  /// Set to false when the backend verify-integrity API goes live.
  static const bool _devMode = true; // TEMPORARILY BYPASSED

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

  /// On first run: generates an App Attest key, attests it with Apple, and
  /// sends the attestation to the backend for one-time registration.
  /// On subsequent runs: generates an assertion for the current session and
  /// sends it to the backend for verification.
  static Future<bool> _verifyIos() async {
    try {
      String? keyId = await _storage.read(key: 'app_attest_key_id');

      if (keyId == null) {
        // ── First time: generate key + attest ──
        keyId = await _channel.invokeMethod<String>('generateKey');
        if (keyId == null) return false;

        final nonce = _generateNonce();
        final clientDataHash = _sha256Base64(nonce);

        final attestation = await _channel.invokeMethod<String>(
          'attestKey',
          {'keyId': keyId, 'clientDataHash': clientDataHash},
        );
        if (attestation == null) return false;

        final integrityToken = await _sendToBackend(
          platform: 'ios',
          payload: {'keyId': keyId, 'attestation': attestation, 'nonce': nonce},
        );

        // Persist keyId only after successful backend attestation
        if (integrityToken != null) {
          await _storage.write(key: 'app_attest_key_id', value: keyId);
          await StorageService.saveIntegrityToken(integrityToken);
        }
        return integrityToken != null;
      } else {
        // ── Subsequent runs: generate assertion ──
        final nonce = _generateNonce();
        final clientDataHash = _sha256Base64(nonce);

        final assertion = await _channel.invokeMethod<String>(
          'generateAssertion',
          {'keyId': keyId, 'clientDataHash': clientDataHash},
        );
        if (assertion == null) return false;

        final integrityToken = await _sendToBackend(
          platform: 'ios',
          payload: {'keyId': keyId, 'assertion': assertion, 'nonce': nonce},
        );
        if (integrityToken != null) {
          await StorageService.saveIntegrityToken(integrityToken);
        }
        return integrityToken != null;
      }
    } on PlatformException catch (e) {
      if (e.code == 'NOT_SUPPORTED') {
        // Device doesn't support App Attest (simulator or older iOS)
        return true;
      }
      // If attestation failed, clear stored key so next launch retries fresh
      if (e.code == 'ATTEST_ERROR') {
        await _storage.delete(key: 'app_attest_key_id');
      }
      return false;
    } catch (_) {
      return false;
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

  /// Generates a cryptographically random URL-safe Base64 nonce (no padding).
  /// Valid for Play Integrity (16–500 chars, URL-safe Base64).
  static String _generateNonce() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  /// Returns the standard Base64-encoded SHA-256 hash of [input].
  /// Used as clientDataHash for App Attest (must decode to exactly 32 bytes).
  static String _sha256Base64(String input) {
    final digest = sha256.convert(utf8.encode(input));
    return base64.encode(digest.bytes);
  }
}
