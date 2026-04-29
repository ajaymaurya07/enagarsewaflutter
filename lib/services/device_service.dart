import 'dart:io';
import 'dart:convert';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';

class DeviceService {
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  static const _securityChannel = MethodChannel('com.enagarsewa.app/device_security');

  /// Returns true if the device is rooted (Android) or jailbroken (iOS).
  static Future<bool> isDeviceRooted() async {
    if (Platform.isAndroid) {
      try {
        final result = await _securityChannel.invokeMethod<bool>('isRooted');
        if (result == true) return true;
      } catch (_) {}
    }

    if (Platform.isIOS) {
      return _isIosJailbroken();
    }

    return false;
  }

  /// iOS jailbreak detection via file system and sandbox escape checks.
  static bool _isIosJailbroken() {
    // Common jailbreak file paths
    const jailbreakPaths = [
      '/Applications/Cydia.app',
      '/Applications/Sileo.app',
      '/Applications/Zebra.app',
      '/Applications/Installer.app',
      '/Library/MobileSubstrate/MobileSubstrate.dylib',
      '/bin/bash',
      '/usr/sbin/sshd',
      '/etc/apt',
      '/usr/bin/ssh',
      '/private/var/lib/apt/',
      '/private/var/lib/cydia',
      '/private/var/stash',
      '/usr/libexec/sftp-server',
      '/usr/libexec/ssh-keysign',
    ];

    for (final path in jailbreakPaths) {
      if (File(path).existsSync()) return true;
    }

    // Sandbox escape check — jailbroken devices can write outside sandbox
    try {
      const testPath = '/private/jailbreak_test.txt';
      File(testPath).writeAsStringSync('test');
      File(testPath).deleteSync();
      return true; // write succeeded = jailbroken
    } catch (_) {}

    return false;
  }

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
