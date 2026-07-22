import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../controllers/bluetooth_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'dashboard_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _statusText = 'Checking Bluetooth...';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  Future<void> _boot() async {
    final bluetooth = context.read<BluetoothController>();

    await bluetooth.initialize();

    if (!bluetooth.isBluetoothSupported) {
      setState(() => _statusText = 'Bluetooth not supported on this device');
    } else if (!bluetooth.permissionsGranted) {
      setState(() => _statusText = 'Bluetooth ready — permission needed');
    } else {
      setState(() => _statusText = 'Bluetooth ready');
      // Fire-and-forget: dashboard shows "reconnecting" state while this runs.
      bluetooth.tryAutoReconnect();
    }

    // Keep the splash screen brief, not artificially long.
    await Future.delayed(const Duration(milliseconds: 700));

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.bluetoothAlpha(0.15),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.local_parking_rounded, color: AppColors.bluetooth, size: 44),
            ).animate().scale(duration: 450.ms, curve: Curves.easeOutBack),
            const SizedBox(height: 22),
            Text('SMART PARKING SYSTEM', style: AppTheme.display(size: 18, letterSpacing: 1))
                .animate()
                .fadeIn(delay: 200.ms, duration: 350.ms),
            const SizedBox(height: 10),
            Text(_statusText, style: AppTheme.mono(size: 11))
                .animate()
                .fadeIn(delay: 350.ms, duration: 350.ms),
            const SizedBox(height: 26),
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.bluetooth),
            ),
          ],
        ),
      ),
    );
  }
}
