import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:in_app_update/in_app_update.dart';
import 'login_screen.dart';
import 'search_property_screen.dart';
import 'dashboard_screen.dart';
import 'services/storage_service.dart';
import 'services/device_service.dart';
import 'services/integrity_service.dart';
import 'services/push_notification_service.dart';
import 'rooted_device_screen.dart';
import 'constants/app_constants.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeIn;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _fadeIn = CurvedAnimation(parent: _animController, curve: Curves.easeIn);
    _scaleAnim = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
    );
    _animController.forward();
    _checkLoginStatus();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  /// Checks Play Store for a pending update.
  /// Returns [AppUpdateInfo] if an immediate update is available, null otherwise.
  Future<AppUpdateInfo?> _checkForUpdate() async {
    try {
      final AppUpdateInfo info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability == UpdateAvailability.updateAvailable &&
          info.immediateUpdateAllowed) {
        return info;
      }
    } catch (_) {
      // Play Store not available or check failed — continue normally
    }
    return null;
  }

  /// Shows a non-dismissible bottom sheet informing the user about the update.
  /// The sheet can only be closed by tapping "Update Now".
  Future<void> _showUpdateSheet() async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PopScope(
        canPop: false,
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(28, 12, 28, 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 28),

              // Update icon
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFE67514).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.system_update_rounded,
                  size: 36,
                  color: Color(0xFFE67514),
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                'Update Available',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 10),

              // Subtitle
              Text(
                'A new version of ${AppConstants.appName} is available with improvements and important security updates. Please update to continue.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),

              // Update button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await InAppUpdate.performImmediateUpdate();
                  },
                  icon: const Icon(Icons.download_rounded, color: Colors.white),
                  label: Text(
                    'Update Now',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE67514),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Initializes Firebase and push notifications in the background.
  /// Never throws — notifications are non-critical.
  Future<void> _initFirebase() async {
    try {
      await Firebase.initializeApp()
          .timeout(const Duration(seconds: 10));
      FirebaseMessaging.onBackgroundMessage(
        firebaseMessagingBackgroundHandler,
      );
      await PushNotificationService.initialize()
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      // Push notifications unavailable on this device — app continues normally.
    }
  }

  Future<void> _checkLoginStatus() async {
    // Initialize Firebase concurrently with the 3-second splash delay.
    // UI renders immediately; Firebase never blocks runApp().
    await Future.wait([
      Future.delayed(const Duration(seconds: 3)),
      _initFirebase(),
    ]);

    if (!mounted) return;

    // Force update check — show UI sheet, user must tap "Update Now" to proceed
    final AppUpdateInfo? updateInfo = await _checkForUpdate();
    if (updateInfo != null) {
      await _showUpdateSheet();
      return;
    }

    if (!mounted) return;

    // Block developer mode / USB debugging enabled devices
    // TEMPORARILY DISABLED
    // final bool devMode = await DeviceService.isDeveloperModeEnabled();
    // if (devMode) {
    //   if (!mounted) return;
    //   Navigator.of(context).pushReplacement(
    //     MaterialPageRoute(
    //       builder: (_) => const RootedDeviceScreen(reason: BlockReason.developerMode),
    //     ),
    //   );
    //   return;
    // }

    if (!mounted) return;

    // Block Frida / Xposed instrumentation and APK signature tampering
    final bool tampered = await DeviceService.isTamperingDetected();
    if (tampered) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const RootedDeviceScreen(reason: BlockReason.tampered),
        ),
      );
      return;
    }

    // Block rooted / jailbroken devices
    final bool rooted = await DeviceService.isDeviceRooted();
    if (rooted) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const RootedDeviceScreen()),
      );
      return;
    }

    // Play Integrity (Android) / App Attest (iOS) — verifies device & app genuineness
    final bool integrityPassed = await IntegrityService.verify();
    if (!integrityPassed) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const RootedDeviceScreen()),
      );
      return;
    }

    final bool loggedIn = await StorageService.isLoggedIn();
    final bool propertyVerified = await StorageService.isPropertyVerified();

    if (!mounted) return;

    if (loggedIn) {
      if (propertyVerified) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const SearchPropertyScreen()),
        );
      }
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFFFFF), Color(0xFFFFFFFF), Color(0xFFFFFFFF)],
          ),
        ),
        child: FadeTransition(
          opacity: _fadeIn,
          child: ScaleTransition(
            scale: _scaleAnim,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 3),

                // Logo with glow
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE67514).withValues(alpha: 0.3),
                        blurRadius: 40,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/images/e_nagar_seva_logo.png',
                    width: 100,
                    height: 100,
                  ),
                ),
                const SizedBox(height: 28),

                // App Name
                Text(
                  AppConstants.appName,
                  style: GoogleFonts.poppins(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFE67514),
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Smart Urban Services at Your Fingertips',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFFE67514).withValues(alpha: 0.7),
                  ),
                ),

                const Spacer(flex: 2),

                // Loader
                SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFE67514)),
                    backgroundColor: const Color(0xFFE67514).withValues(alpha: 0.15),
                  ),
                ),

                const Spacer(flex: 1),

                // Version
                Text(
                  'Version ${AppConstants.appDisplayVersion}',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey.shade400,
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
