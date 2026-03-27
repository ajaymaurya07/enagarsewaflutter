package com.example.enagarsewa

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.telephony.SubscriptionManager
import android.telephony.TelephonyManager
import android.content.Context
import android.provider.ContactsContract
import android.accounts.AccountManager

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.enagarsewa.app/sim"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getPhoneNumbers" -> {
                        val phoneNumbers = getPhoneNumbers()
                        result.success(phoneNumbers)
                    }
                    "getEmails" -> {
                        val emails = getEmails()
                        result.success(emails)
                    }
                    "fetchEmailFromGmail" -> {
                        val gmailEmails = fetchAllGmailEmails()
                        result.success(gmailEmails)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun getPhoneNumbers(): List<String> {
        val phoneNumbers = mutableListOf<String>()
        
        try {
            val subscriptionManager = SubscriptionManager.from(this)
            val activeSubscriptionInfoList = subscriptionManager.activeSubscriptionInfoList
            
            if (activeSubscriptionInfoList != null) {
                for (subscriptionInfo in activeSubscriptionInfoList) {
                    val number = subscriptionInfo.number
                    if (!number.isNullOrEmpty()) {
                        phoneNumbers.add(number)
                    }
                }
            }
            
            // If no numbers found from SubscriptionManager, try TelephonyManager
            if (phoneNumbers.isEmpty()) {
                val telephonyManager = getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
                val number = telephonyManager.line1Number
                if (!number.isNullOrEmpty()) {
                    phoneNumbers.add(number)
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        
        return phoneNumbers
    }

    private fun getEmails(): List<String> {
        val emails = mutableListOf<String>()
        
        try {
            val contentResolver = contentResolver
            val emailUri = ContactsContract.CommonDataKinds.Email.CONTENT_URI
            
            val projection = arrayOf(
                ContactsContract.CommonDataKinds.Email.ADDRESS,
                ContactsContract.CommonDataKinds.Email.TYPE
            )
            
            val cursor = contentResolver.query(
                emailUri,
                projection,
                null,
                null,
                null
            )
            
            cursor?.use {
                val emailIndex = it.getColumnIndex(ContactsContract.CommonDataKinds.Email.ADDRESS)
                
                while (it.moveToNext()) {
                    val email = it.getString(emailIndex)
                    if (!email.isNullOrEmpty() && !emails.contains(email)) {
                        emails.add(email)
                    }
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        
        return emails
    }

    private fun fetchAllGmailEmails(): List<String> {
        val gmailEmails = mutableListOf<String>()
        
        return try {
            // Get all Gmail accounts from AccountManager
            val accountManager = AccountManager.get(this)
            val accounts = accountManager.getAccountsByType("com.google")
            
            // Add all Gmail account emails to list
            for (account in accounts) {
                gmailEmails.add(account.name)
            }
            
            gmailEmails
        } catch (e: Exception) {
            e.printStackTrace()
            emptyList()
        }
    }
}
