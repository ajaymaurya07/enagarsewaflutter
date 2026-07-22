package com.vdsai.enagaesewa

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.telephony.SubscriptionManager
import android.telephony.TelephonyManager
import android.content.Context
import android.provider.ContactsContract
import android.accounts.AccountManager
import java.io.File
import android.os.Bundle
import android.view.WindowManager
import com.google.android.play.core.integrity.IntegrityManagerFactory
import com.google.android.play.core.integrity.IntegrityTokenRequest

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.enagarsewa.app/sim"
    private val SECURITY_CHANNEL = "com.enagarsewa.app/device_security"
    private val INTEGRITY_CHANNEL = "com.enagarsewa.app/integrity"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Prevent screenshots and screen recording across all screens.
        // TODO : secure flag
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }

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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SECURITY_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isRooted" -> result.success(isDeviceRooted())
                    "isDeveloperModeEnabled" -> result.success(isDeveloperModeEnabled())
                    "isTamperingDetected" -> {
                        // isFridaDetected() does blocking I/O (port check) — run off main thread
                        Thread {
                            val tampered = isTamperingDetected()
                            runOnUiThread { result.success(tampered) }
                        }.start()
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, INTEGRITY_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getIntegrityToken" -> {
                        val nonce = call.argument<String>("nonce") ?: ""
                        getPlayIntegrityToken(nonce, result)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun isDeviceRooted(): Boolean {
        return checkEmulator() || checkRootFiles() || checkSuOnPath()
    }

    /** Detect emulators via hardware fingerprints — no false positives on real devices. */
    private fun checkEmulator(): Boolean {
        return (android.os.Build.FINGERPRINT.startsWith("generic")
            || android.os.Build.FINGERPRINT.startsWith("unknown")
            || android.os.Build.FINGERPRINT.contains("emulator")
            || android.os.Build.MODEL.contains("google_sdk", ignoreCase = true)
            || android.os.Build.MODEL.contains("Emulator", ignoreCase = true)
            || android.os.Build.MODEL.contains("Android SDK built for x86", ignoreCase = true)
            || android.os.Build.MANUFACTURER.contains("Genymotion", ignoreCase = true)
            || android.os.Build.BRAND.startsWith("generic")
            || android.os.Build.DEVICE.startsWith("generic")
            || android.os.Build.PRODUCT.contains("sdk_gphone", ignoreCase = true)
            || android.os.Build.PRODUCT.contains("vbox86p", ignoreCase = true)
            || android.os.Build.HARDWARE.contains("goldfish", ignoreCase = true)
            || android.os.Build.HARDWARE.contains("ranchu", ignoreCase = true))
    }

    /** Check common root binary / app paths. */
    private fun checkRootFiles(): Boolean {
        val rootPaths = arrayOf(
            "/system/app/Superuser.apk",
            "/sbin/su",
            "/system/bin/su",
            "/system/xbin/su",
            "/data/local/xbin/su",
            "/data/local/bin/su",
            "/data/local/su",
            "/system/sd/xbin/su",
            "/system/bin/failsafe/su",
            "/system/app/SuperSU.apk",
            "/system/app/Kinguser.apk",
            "/data/adb/magisk",
            "/sbin/.magisk",
            "/sbin/.core/mirror",
            "/sbin/.core/img"
        )
        return rootPaths.any { File(it).exists() }
    }

    /** Try executing `su` — succeeds only on rooted devices. */
    private fun checkSuOnPath(): Boolean {
        return try {
            val process = Runtime.getRuntime().exec(arrayOf("/system/xbin/which", "su"))
            process.inputStream.bufferedReader().readLine() != null
        } catch (_: Exception) {
            false
        }
    }

    /**
     * Returns true if Developer Options or USB Debugging is enabled.
     * Both are checked because a user can enable ADB without fully enabling
     * Developer Options on some custom ROMs.
     */
    private fun isDeveloperModeEnabled(): Boolean {
        val devOptions = android.provider.Settings.Global.getInt(
            contentResolver,
            android.provider.Settings.Global.DEVELOPMENT_SETTINGS_ENABLED, 0
        )
        val adbEnabled = android.provider.Settings.Global.getInt(
            contentResolver,
            android.provider.Settings.Global.ADB_ENABLED, 0
        )
        return devOptions == 1 || adbEnabled == 1
    }

    /**
     * Requests a Play Integrity token using the provided nonce.
     * The token must be verified server-side via the Play Integrity API.
     *
     * TODO: Set your Google Cloud project number via setCloudProjectNumber() for production.
     * See: https://developer.android.com/google/play/integrity/setup
     */
    private fun getPlayIntegrityToken(nonce: String, result: MethodChannel.Result) {
        val integrityManager = IntegrityManagerFactory.create(applicationContext)
        val request = IntegrityTokenRequest.builder()
            .setNonce(nonce)
            .setCloudProjectNumber(777110300025L)
            .build()

        integrityManager.requestIntegrityToken(request)
            .addOnSuccessListener { response ->
                result.success(response.token())
            }
            .addOnFailureListener { exception ->
                result.error("INTEGRITY_ERROR", exception.message, null)
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
        } catch (_: Exception) {}
        
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
        } catch (_: Exception) {}
        
        return emails
    }

    // ── Anti-Tamper / Anti-Instrumentation ────────────────────────────────────

    /**
     * Master tamper check — returns true if Frida or Xposed is detected.
     * APK signature tamper is already covered server-side by Play Integrity API.
     * Called from Flutter SECURITY_CHANNEL on a background thread.
     */
    private fun isTamperingDetected(): Boolean {
        return isFridaDetected() || isXposedInstalled()
    }

    /**
     * Detects Frida dynamic instrumentation via:
     *   1. Known Frida server binary paths on disk
     *   2. /proc/self/maps scan for frida-agent injection
     *   3. Frida default listening port 27042 open on localhost
     */
    private fun isFridaDetected(): Boolean {
        val fridaPaths = arrayOf(
            "/data/local/tmp/frida-server",
            "/data/local/tmp/re.frida.server",
            "/data/local/frida-server",
            "/system/bin/frida-server",
            "/sbin/frida-server"
        )
        if (fridaPaths.any { java.io.File(it).exists() }) return true

        try {
            val maps = java.io.File("/proc/self/maps").readText()
            if (maps.contains("frida", ignoreCase = true) ||
                maps.contains("gadget", ignoreCase = true)) return true
        } catch (_: Exception) {}

        try {
            java.net.Socket().use { socket ->
                socket.soTimeout = 200
                socket.connect(java.net.InetSocketAddress("127.0.0.1", 27042), 200)
                return true // port open = Frida server is running
            }
        } catch (_: Exception) {}

        return false
    }

    /**
     * Detects Xposed Framework by checking for XposedBridge in the class loader.
     */
    private fun isXposedInstalled(): Boolean {
        return try {
            classLoader.loadClass("de.robv.android.xposed.XposedBridge") != null
        } catch (_: ClassNotFoundException) {
            false
        }
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
        } catch (_: Exception) {
            emptyList()
        }
    }
}
