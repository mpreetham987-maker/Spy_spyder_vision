import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'data/services/bluetooth_service.dart';
import 'data/services/camera_stream_service.dart';
import 'data/services/preferences_service.dart';
import 'features/splash/screens/splash_screen.dart';
import 'providers/camera_provider.dart';
import 'providers/robot_provider.dart';
import 'providers/settings_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load persisted settings before the widget tree is built so every
  // provider starts with the user's saved configuration (robot name,
  // camera URL, walking speed, servo trims) rather than defaults that
  // would flash briefly on screen.
  final preferences = await PreferencesService.create();

  runApp(SpySpiderVisionApp(preferences: preferences));
}

/// Root widget. Wires up the three services (Bluetooth, camera
/// stream, preferences) and their corresponding [ChangeNotifier]
/// providers, then hands off to the splash screen.
class SpySpiderVisionApp extends StatelessWidget {
  const SpySpiderVisionApp({super.key, required this.preferences});

  final PreferencesService preferences;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<PreferencesService>.value(value: preferences),
        ChangeNotifierProvider<RobotProvider>(
          create: (_) => RobotProvider(RobotBluetoothService(), preferences),
        ),
        ChangeNotifierProvider<CameraProvider>(
          create: (_) => CameraProvider(CameraStreamService(), preferences),
        ),
        ChangeNotifierProvider<SettingsProvider>(
          create: (_) => SettingsProvider(preferences),
        ),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return MaterialApp(
            title: 'Spy Spider Vision',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: settings.themeMode,
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
