import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

enum BlockReason { rooted, developerMode }

class RootedDeviceScreen extends StatelessWidget {
  final BlockReason reason;
  const RootedDeviceScreen({super.key, this.reason = BlockReason.rooted});

  @override
  Widget build(BuildContext context) {
    final _Config cfg = _Config.from(reason);
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Spacer(),

                // Icon
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: cfg.iconBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    cfg.icon,
                    size: 48,
                    color: cfg.iconColor,
                  ),
                ),

                const SizedBox(height: 28),

                // Title
                Text(
                  cfg.title,
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A1A1A),
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 12),

                // Message
                Text(
                  cfg.message,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),

                const Spacer(),

                // Close button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () => SystemNavigator.pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cfg.iconColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Close App',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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

class _Config {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String message;

  const _Config({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.message,
  });

  factory _Config.from(BlockReason reason) {
    switch (reason) {
      case BlockReason.developerMode:
        return const _Config(
          icon: Icons.developer_mode_rounded,
          iconBg: Color(0xFFFFF3E0),
          iconColor: Color(0xFFE65100),
          title: 'Developer Mode Detected',
          message:
              'This app cannot run with Developer Options or USB Debugging enabled.\n\nPlease disable Developer Options from Settings and restart the app.',
        );
      case BlockReason.rooted:
        return const _Config(
          icon: Icons.security_rounded,
          iconBg: Color(0xFFFFEBEE),
          iconColor: Color(0xFFD32F2F),
          title: 'Device Not Supported',
          message:
              'This app cannot run on a rooted or modified device. Please use a standard device to continue.',
        );
    }
  }
}
