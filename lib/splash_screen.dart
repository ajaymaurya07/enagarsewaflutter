import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'search_property_screen.dart';
import 'dashboard_screen.dart';
import 'services/storage_service.dart';
import 'constants/app_constants.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    // Show splash for 3 seconds
    await Future.delayed(const Duration(seconds: 3));
    
    // Check if user is logged in
    final bool loggedIn = await StorageService.isLoggedIn();
    
    // Check if property is verified
    final bool propertyVerified = await StorageService.isPropertyVerified();

    if (!mounted) return;

    if (loggedIn) {
      if (propertyVerified) {
        // If logged in AND property verified, go to Dashboard
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
        );
      } else {
        // If logged in BUT property NOT verified, go to Search Screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const SearchPropertyScreen()),
        );
      }
    } else {
      // If not logged in, go to Login Screen
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
            colors: [Color(0xFFFCEFD8), Color(0xFFFFFFFF)],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              flex: 2,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/images/e_nagar_seva_logo.png', width: 200, height: 200),
                  const SizedBox(height: 16),
                  Text(
                    'Welcome ${AppConstants.appName}',
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF0E3B90)),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 1,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF57C00)),
                    backgroundColor: Color(0xFFFFE6CC),
                    strokeWidth: 4,
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 1,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text(
                    'Smart Urban Services at Your Fingertips',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFFF57C00)),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'App Version ${AppConstants.appDisplayVersion}',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
