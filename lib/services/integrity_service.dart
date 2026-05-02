import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';

class IntegrityService {
  static const _channel = MethodChannel('com.enagarsewa.app/integrity');
  static const _storage = FlutterSecureStorage();

  static String get _verifyUrl =>
      '${AppConstants.baseUrl}api/house_tax/verify-integrity';

  /// Set to false when the backend verify-integrity API goes live.
  static const bool _devMode = true;

  // ─── Public API ────────────────────────────────────────────────────────────

  /// Runs the platform-appropriate integrity check and returns true if the
  /// device/app is verified as genuine.
  /// Returns true on non-Android/iOS platforms (no-op).
  static Future<bool> verify() async {
    if (_devMode) return true;
    if (Platform.isAndroid) return _verifyAndroid();
    if (Platform.isIOS) return _verifyIos();
    return true;
  }

  // ─── Android — Play Integrity API ──────────────────────────────────────────

  /// Requests a Play Integrity token and sends it to the backend for
  /// server-side verification against the Google Play Integrity API.
  static Future<bool> _verifyAndroid() async {
    try {
      final nonce = _generateNonce();
      final token = await _channel.invokeMethod<String>(
        'getIntegrityToken',
        {'nonce': nonce},
      );
      if (token == null) return false;

      return _sendToBackend(
        platform: 'android',
        payload: {'token': token, 'nonce': nonce},
      );
    } on PlatformException catch (e) {
      debugPrint('[IntegrityService] Android error: ${e.code} — ${e.message}');
      return false;
    } catch (e) {
      debugPrint('[IntegrityService] Android unexpected error: $e');
      return false;
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

        final verified = await _sendToBackend(
          platform: 'ios',
          payload: {'keyId': keyId, 'attestation': attestation, 'nonce': nonce},
        );

        // Persist keyId only after successful backend attestation
        if (verified) {
          await _storage.write(key: 'app_attest_key_id', value: keyId);
        }
        return verified;
      } else {
        // ── Subsequent runs: generate assertion ──
        final nonce = _generateNonce();
        final clientDataHash = _sha256Base64(nonce);

        final assertion = await _channel.invokeMethod<String>(
          'generateAssertion',
          {'keyId': keyId, 'clientDataHash': clientDataHash},
        );
        if (assertion == null) return false;

        return _sendToBackend(
          platform: 'ios',
          payload: {'keyId': keyId, 'assertion': assertion, 'nonce': nonce},
        );
      }
    } on PlatformException catch (e) {
      if (e.code == 'NOT_SUPPORTED') {
        // Device doesn't support App Attest (simulator or older iOS)
        debugPrint('[IntegrityService] App Attest not supported: ${e.message}');
        return true;
      }
      // Attestation failed — treat as invalid device
      debugPrint('[IntegrityService] iOS error: ${e.code} — ${e.message}');
      // If attestation failed, clear stored key so next launch retries fresh
      if (e.code == 'ATTEST_ERROR') {
        await _storage.delete(key: 'app_attest_key_id');
      }
      return false;
    } catch (e) {
      debugPrint('[IntegrityService] iOS unexpected error: $e');
      return false;
    }
  }

  // ─── Backend communication ─────────────────────────────────────────────────

  /// POSTs the integrity payload to the backend.
  /// Expected response:
  ///   { "platform": "android"|"ios", "status": "success"|"fail", "message": "..." }
  static Future<bool> _sendToBackend({
    required String platform,
    required Map<String, String> payload,
  }) async {
    if (_devMode) {
      debugPrint('[IntegrityService] Dev mode — skipping backend verification.');
      return true;
    }
    try {
      final response = await http
          .post(
            Uri.parse(_verifyUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'platform': platform, ...payload}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final status = data['status'] as String? ?? '';
        final message = data['message'] as String? ?? '';
        debugPrint('[IntegrityService] $platform — $status: $message');
        return status == 'success';
      }
      debugPrint(
        '[IntegrityService] Backend returned ${response.statusCode}: ${response.body}',
      );
      return false;
    } catch (e) {
      debugPrint('[IntegrityService] Backend request failed: $e');
      return false;
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
