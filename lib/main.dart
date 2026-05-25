import 'package:flutter/material.dart';
import 'splash_screen.dart';
import 'constants/app_constants.dart';
import 'services/api_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConstants.init();
  // Firebase and push notifications are initialized inside SplashScreen
  // so the UI renders immediately without blocking on network services.
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      navigatorKey: ApiService.navigatorKey, // 👈 navigatorKey yahan add kiya
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFE67514)),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
