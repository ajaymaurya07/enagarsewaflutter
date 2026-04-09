import 'dart:io';
import 'dart:convert';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:crypto/crypto.dart';

class DeviceService {
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  static Future<String> getDeviceId() async {
    try {
      String rawId = '';
      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await _deviceInfo.androidInfo;
        // Combining multiple properties to ensure uniqueness and stability
        rawId = '${androidInfo.brand}${androidInfo.model}${androidInfo.id}${androidInfo.hardware}';
      } else if (Platform.isIOS) {
        IosDeviceInfo iosInfo = await _deviceInfo.iosInfo;
        rawId = iosInfo.identifierForVendor ?? 'ios_device';
      } else {
        rawId = 'web_or_other_device';
      }

      // Create a 16-character hex hash to ensure correct format
      var bytes = utf8.encode(rawId);
      var digest = md5.convert(bytes);
      return digest.toString().substring(0, 16); // Returns a 16-char hex string
    } catch (e) {
      // Fallback to a random 16-char string if something fails
      return 'a1b2c3d4e5f6g7h8';
    }
  }
}
