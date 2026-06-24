import 'dart:convert';
import 'dart:typed_data';
import 'package:pointycastle/export.dart';

class RsaService {
  static const String _publicKeyPem = '''
-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA4s6sEpFv6IIu4goE2Qc6
euzyElJsvAUVJVfnXRljjsSq8qiFVHJpGUlFzI4IWOAz8GTk65i3fxLmbuKos2QD
+pxql2TluJ4lbvZXRqotAwVqilnDk52vW8OP6un/u+gG+2Wyhjsn67YNCBrXsJ8C
O+d7zcR7vcjpXT6oXyWqw3ePwVXTLOWonKpGvTS/ypzY0cDPOHv/x80lXguQj65U
qPy9eVljeSo8ackIc0ylM44weqIENTWFnUW05ueW1zrtUAwOCVyRjCPW5iNafy7B
Venhh8Htxfn6NT57fTPgDTMqMD6BB3U0PgpYjm4mFIPuP7YMUbfD6L3U4QY/COjL
EQIDAQAB
-----END PUBLIC KEY-----''';

  static RSAPublicKey _parsePublicKey() {
    final lines = _publicKeyPem
        .split('\n')
        .where((line) =>
            !line.startsWith('-----BEGIN') && !line.startsWith('-----END'))
        .join();
    final keyBytes = base64Decode(lines);

    // PKCS#8 SubjectPublicKeyInfo structure:
    //   SEQUENCE {
    //     SEQUENCE { algorithm OID, NULL }
    //     BIT STRING {
    //       SEQUENCE {
    //         INTEGER (modulus)
    //         INTEGER (exponent)
    //       }
    //     }
    //   }
    final outer = _derReadSequence(keyBytes, 0);
    final algoSeqEnd = _derSkipObject(keyBytes, outer.contentOffset);
    final bitString = _derReadTag(keyBytes, algoSeqEnd);

    // BIT STRING has a leading 0x00 "unused bits" byte
    final rsaKeyOffset = bitString.contentOffset + 1;
    final inner = _derReadSequence(keyBytes, rsaKeyOffset);
    final modulus = _derReadInteger(keyBytes, inner.contentOffset);
    final exponent = _derReadInteger(keyBytes, modulus.nextOffset);

    return RSAPublicKey(modulus.value, exponent.value);
  }

  static String encrypt(String plainText) {
    final publicKey = _parsePublicKey();
    final encryptor = OAEPEncoding(RSAEngine())
      ..init(true, PublicKeyParameter<RSAPublicKey>(publicKey));
    final plainBytes = Uint8List.fromList(utf8.encode(plainText));
    final encrypted = encryptor.process(plainBytes);
    return base64Encode(encrypted);
  }

  // --- Minimal DER parser helpers ---

  static ({int contentOffset, int contentLength, int nextOffset}) _derReadTag(
      Uint8List data, int offset) {
    // skip tag byte
    int pos = offset + 1;
    int length = data[pos++];
    if (length & 0x80 != 0) {
      final numBytes = length & 0x7F;
      length = 0;
      for (int i = 0; i < numBytes; i++) {
        length = (length << 8) | data[pos++];
      }
    }
    return (
      contentOffset: pos,
      contentLength: length,
      nextOffset: pos + length,
    );
  }

  static ({int contentOffset, int contentLength}) _derReadSequence(
      Uint8List data, int offset) {
    assert(data[offset] == 0x30); // SEQUENCE tag
    final tag = _derReadTag(data, offset);
    return (contentOffset: tag.contentOffset, contentLength: tag.contentLength);
  }

  static int _derSkipObject(Uint8List data, int offset) {
    final tag = _derReadTag(data, offset);
    return tag.nextOffset;
  }

  static ({BigInt value, int nextOffset}) _derReadInteger(
      Uint8List data, int offset) {
    assert(data[offset] == 0x02); // INTEGER tag
    final tag = _derReadTag(data, offset);
    final bytes =
        data.sublist(tag.contentOffset, tag.contentOffset + tag.contentLength);
    // Parse as unsigned big-endian
    BigInt value = BigInt.zero;
    for (final b in bytes) {
      value = (value << 8) | BigInt.from(b);
    }
    return (value: value, nextOffset: tag.nextOffset);
  }
}
