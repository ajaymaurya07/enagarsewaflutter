import 'dart:io';
import 'package:flutter/services.dart';
import 'package:http/io_client.dart';

/// HTTP client with certificate-chain pinning for iamsup.in.
///
/// Trust anchors (both embedded so the app survives a leaf-cert renewal):
///   [0] iamsup.in leaf cert          — expires 2026-09-27
///       SPKI SHA-256: 9cfpRdt3u5byy0K2nxVHhWnByC+qBa0BS+RG60siZpQ=
///   [1] RapidSSL TLS RSA CA G1 (DigiCert intermediate)
///                                    — expires 2027-11-02
///       SPKI SHA-256: E3tYcwo9CiqATmKtpMLW5V+pzIq+ZoDmpXSiJlXGmTo=
///
/// [SecurityContext(withTrustedRoots: false)] ensures that ONLY these two
/// certs are trusted — OS/user-added CAs are completely ignored, eliminating
/// the MITM risk from rogue CA certificates.
///
/// Renewal plan:
///   When the leaf cert is renewed (same CA), the intermediate pin still
///   matches and the app continues to work without a forced update.
///   When the intermediate CA changes, update [assets/certs/iamsup_chain.pem]
///   and both SPKI pins before deploying a new build.
class PinnedHttpClient {
  static IOClient? _instance;

  static Future<IOClient> getInstance() async {
    if (_instance != null) return _instance!;

    // Load the PEM bundle (leaf + intermediate CA) as raw bytes.
    // rootBundle.load() avoids any String encoding ambiguity.
    final byteData = await rootBundle.load('assets/certs/iamsup_chain.pem');
    final pemBytes = byteData.buffer
        .asUint8List(byteData.offsetInBytes, byteData.lengthInBytes);

    final context = SecurityContext(withTrustedRoots: false);
    // Both the leaf cert and the intermediate CA become trust anchors.
    // A connection succeeds only when the server's chain terminates at
    // one of these two certificates.
    context.setTrustedCertificatesBytes(pemBytes);

    final httpClient = HttpClient(context: context);
    // badCertificateCallback is the last line of defence: returning false
    // hard-rejects any cert that failed the above SecurityContext check.
    httpClient.badCertificateCallback =
        (X509Certificate cert, String host, int port) => false;

    _instance = IOClient(httpClient);
    return _instance!;
  }

  /// Reset the singleton — use in tests or after a hot-restart.
  static void reset() => _instance = null;
}
