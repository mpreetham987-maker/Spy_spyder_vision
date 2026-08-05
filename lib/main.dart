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
      // Selector, not Consumer: SettingsProvider.notifyListeners() also
      // fires on every walking-speed slider pixel and every robot-name
      // edit, and a Consumer<SettingsProvider> here rebuilds this
      // MaterialApp — and therefore every screen and every glass blur
      // beneath it — on each of those. Selecting just [ThemeMode] means
      // that full-tree rebuild only happens when the theme actually
      // changes; unrelated settings changes no longer touch this widget
      // at all. This is what was behind the app-wide lag on the
      // walking-speed slider and the robot-name field.
      child: Selector<SettingsProvider, ThemeMode>(
        selector: (_, settings) => settings.themeMode,
        builder: (context, themeMode, _) {
          return MaterialApp(
            title: 'Spy Spider Vision',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: themeMode,
            home: const SplashScreen(),
            // Wrapping the resolved theme in AnimatedTheme turns a Light
            // ⇄ Dark switch from an instant, all-at-once color snap
            // (which is what read as "laggy" — one huge frame doing all
            // the work at once) into a smooth ~420ms interpolation,
            // using the AppPalette.lerp already defined for exactly
            // this purpose.
            builder: (context, child) {
              return AnimatedTheme(
                data: Theme.of(context),
                duration: const Duration(milliseconds: 420),
                curve: Curves.easeInOutCubic,
                child: child ?? const SizedBox.shrink(),
              );
            },
          );
        },
      ),
    );
  }
}
