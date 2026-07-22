import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'controllers/bluetooth_controller.dart';
import 'controllers/parking_controller.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';

class SmartParkingApp extends StatelessWidget {
  const SmartParkingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ParkingController()),
        // BluetoothController is created once and wired directly to the
        // ParkingController instance above: every parsed protocol message
        // and every disconnect event is forwarded straight into parking
        // domain state. This is the ONE place the two controllers are
        // connected — everywhere else they stay fully independent.
        ChangeNotifierProxyProvider<ParkingController, BluetoothController>(
          create: (context) {
            final parking = context.read<ParkingController>();
            return BluetoothController(
              onMessage: parking.applyMessage,
              onDisconnected: parking.resetToUnknown,
            );
          },
          update: (context, parking, bluetooth) => bluetooth!,
        ),
      ],
      child: MaterialApp(
        title: 'Smart Parking System',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.themeData,
        home: const SplashScreen(),
      ),
    );
  }
}
