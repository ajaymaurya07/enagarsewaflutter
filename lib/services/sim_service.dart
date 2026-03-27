import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';

class SimService {
  // Platform channel for accessing Android native code
  static const platform = MethodChannel('com.enagarsewa.app/sim');

  // Default available phone number options (fallback)
  static const List<String> defaultPhoneNumbers = [
    '+919876543210',
    '+918765432109',
    '+917654321098',
  ];

  /// Get all phone numbers from device SIM cards
  /// Requires READ_PHONE_STATE and READ_PHONE_NUMBERS permissions
  static Future<List<String>> getAvailablePhoneNumbers() async {
    try {
      // Request phone permission first
      final status = await Permission.phone.request();
      
      if (!status.isGranted) {
        // Permission denied - return empty list
        return [];
      }

      // Try to get actual phone numbers from device using platform channel
      try {
        final List<dynamic> result = 
            await platform.invokeMethod<List<dynamic>>('getPhoneNumbers') ?? [];
        
        final phoneNumbers = result.cast<String>();
        
        // If we got real numbers, return them
        if (phoneNumbers.isNotEmpty) {
          return phoneNumbers;
        }
      } catch (e) {
        print('Error getting phone numbers from native: $e');
      }

      // Fallback to default if no actual numbers found
      return defaultPhoneNumbers;
    } catch (e) {
      print('Error getting phone numbers: $e');
      return defaultPhoneNumbers;
    }
  }

  /// Request phone permission to access phone numbers
  static Future<bool> requestPhonePermission() async {
    try {
      final status = await Permission.phone.request();
      return status.isGranted;
    } catch (e) {
      print('Error requesting phone permission: $e');
      return false;
    }
  }
}


