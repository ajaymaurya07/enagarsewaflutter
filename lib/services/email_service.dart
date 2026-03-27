import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';

class EmailService {
  // Platform channel for accessing Android native code
  static const platform = MethodChannel('com.enagarsewa.app/sim');

  /// Get all email addresses from device contacts
  /// Requires READ_CONTACTS permission
  static Future<List<String>> getAvailableEmails() async {
    try {
      // Request contacts permission for email
      final status = await Permission.contacts.request();
      
      if (!status.isGranted) {
        // Permission denied - return empty list
        return [];
      }

      // Try to get actual emails from device using platform channel
      try {
        final List<dynamic> result = 
            await platform.invokeMethod<List<dynamic>>('getEmails') ?? [];
        
        final emails = result.cast<String>();
        
        // If we got real emails, return them
        if (emails.isNotEmpty) {
          return emails;
        }
      } catch (e) {
        print('Error getting emails from native: $e');
      }

      // Return empty list if no actual emails found
      return [];
    } catch (e) {
      print('Error getting emails: $e');
      return [];
    }
  }

  /// Request contacts permission to access email addresses
  static Future<bool> requestContactsPermission() async {
    try {
      final status = await Permission.contacts.request();
      return status.isGranted;
    } catch (e) {
      print('Error requesting contacts permission: $e');
      return false;
    }
  }

  /// Fetch all Gmail account emails using Google Account Manager
  /// This will retrieve all Gmail accounts registered on the device
  static Future<List<String>> getAllGmailEmails() async {
    try {
      final List<dynamic> result = 
          await platform.invokeMethod<List<dynamic>>('fetchEmailFromGmail') ?? [];
      
      final emails = result.cast<String>();
      
      if (emails.isNotEmpty) {
        return emails;
      }
    } catch (e) {
      print('Error getting Gmail emails from native: $e');
    }
    
    return [];
  }
}
